class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;
use HTTP::Cookies;
use HTTP::UserAgent::Common;

use IO::Socket::SSL;

use Encode;

use File::Temp;

class X::HTTP is Exception {
    has $.rc;
}

class X::HTTP::Response is X::HTTP {
    method message {
        "Response error: '$.rc'";
    }
}

class X::HTTP::Server is X::HTTP {
    method message {
        "Server error: '$.rc'";
    }
}

has Int $.timeout is rw = 180;
has $.useragent;
has $.cookies = HTTP::Cookies.new(
    file     => tempfile[0],
    autosave => 1,
);

# Helper method which implements the same logic as Str.split() but for Bufs.
multi _split_buf(Str $delimiter, Buf $input, $limit = Inf --> List) {
    _split_buf($delimiter.encode, $input, $limit);
}
multi _split_buf(Blob $delimiter, Buf $input, $limit = Inf --> List) {
    my @result;
    my @a            = $input.list;
    my @b            = $delimiter.list;
    my $old_delim_pos = 0;
    
    while $old_delim_pos >= 0 && +@result + 1 < $limit {
        my $new_delim_pos = @a.first-index({ @a[(state $i = -1) .. $i++ + @b] ~~ @b }) // last;
        last if $new_delim_pos < 0;
        @result.push: $input.subbuf($old_delim_pos, $new_delim_pos);
        $old_delim_pos = $new_delim_pos + $delimiter.bytes;
    }
    if $old_delim_pos < +@a {
        @result.push: $input.subbuf($old_delim_pos);
    }
    @result
}

submethod BUILD(:$!useragent?) {
    $!useragent = get-ua($!useragent) if $!useragent.defined;
}

method get(Str $url is copy) {
    my $port = _get-port($url);
    $url = _clear-url($url);

    my $response;

    for 1..5 {
        my $request = HTTP::Request.new(GET => $url);

        # add cookies to the request
        $.cookies.add-cookie-header($request) if $.cookies.cookies.elems;

        # set the useragent
        $request.header.field(User-Agent => $.useragent) if $.useragent.defined;

        my $conn = $url.substr(4, 1) eq 's'
            ?? IO::Socket::SSL.new(:host(~$request.header.field('Host').values), :port($port // 443), :timeout($.timeout))
            !! IO::Socket::INET.new(:host(~$request.header.field('Host').values), :port($port // 80), :timeout($.timeout));

        if $conn.send($request.Str ~ "\r\n") {
            my $first-chunk;
            my $msg-body-pos;
            my @a;
            my @b = "\r\n\r\n".ords;

            # Header can be longer than one chunk
            while my $t = $conn.recv( :bin ) {
                $first-chunk = Blob[uint8].new($first-chunk.list, $t.list);
                @a           = $first-chunk.list;

                # Find the header/body separator in the chunk, which means we can parse the header seperately and are
                # able to figure out the correct encoding of the body.
                $msg-body-pos = @a.first-index({ @a[(state $i = -1) .. $i++ + @b] ~~ @b });
                last if $msg-body-pos;
            }

            # +2 because we need a trailing CRLF in the header.
            $msg-body-pos   += 2 if $msg-body-pos >= 0;

            $response                    = HTTP::Response.new;
            my ($response-line, $header) = $first-chunk.decode('ascii').substr(0, $msg-body-pos).split("\r\n", 2);
            $response.set-code( $response-line.split(' ')[1].Int );
            $response.header.parse( $header );

            my $content = +@a <= $msg-body-pos + 2 ??
                            $conn.recv(6, :bin) !!
                            buf8.new( @a[($msg-body-pos + 2)..*] );

            # We also need to handle 'Transfer-Encoding: chunked', which means that we request more chunks
            # and assemble the response body.
            if $response.header.field('Transfer-Encoding') &&
            $response.header.field('Transfer-Encoding') eq 'chunked' {
                my sub recv-entire-chunk($content is rw) {
                    if $content {
                        # The first line is our desired chunk size.
                        (my $chunk-size, $content) = _split_buf("\r\n", $content, 2);
                        $chunk-size                = :16($chunk-size.decode);
                        $content = $conn.recv(4, :bin) unless $content;
                        if $chunk-size {
                            # Let the content grow until we have reached the desired size.
                            while $chunk-size > $content.bytes {
                                $content ~= $conn.recv($chunk-size - $content.bytes, :bin);
                            }
                        }
                    }
                    $content
                }

                my $chunk = $content;
                $content  = Buf.new;
                # We carry on as long as we receive something.
                while recv-entire-chunk($chunk) {
                    $content ~= $chunk;
                    # We only request five bytes here, and check if it is the message terminator, which is
                    # "\r\n0\r\n". When we would try to read more bytes we would block for a few seconds.
                    $chunk    = $conn.recv(5, :bin);
                    if !$chunk || $chunk.list eqv [0x0d, 0x0a, 0x30, 0x0d, 0x0a] {
                        # Done with this message!
                        last
                    }
                    else {
                        # Read more of this chunk, which includes the rest of a chunk-size field followed
                        # by <CRLF> and a single byte of the message content.
                        $chunk ~= $conn.recv(6, :bin);
                        $chunk.=subbuf(2)
                    }
                }
            }
            elsif $response.header.field('Content-Length').values[0] -> $content-length is copy {
                X::HTTP::Header.new( :rc("Content-Length header value '$content-length' is not numeric") ).throw
                    unless $content-length = try +$content-length;
                # Let the content grow until we have reached the desired size.
                while $content-length > $content.bytes {
                    $content ~= $conn.recv($content-length - $content.bytes, :bin);
                }
            }
            else {
                while my $new_content = $conn.recv(:bin) {
                    $content ~= $new_content;
                }
            }

            # We have now the content as a Buf and need to decode it depending on some header informations.
            $response.content = $content;
            my $content-type  = $response.header.field('Content-Type').values[0] // '';
            if $content-type ~~ /^ text / {
                my $charset = $content-type ~~ / charset '=' $<charset>=[ \S+ ] /
                            ?? $<charset>.Str.lc
                            !! 'ascii';
                $response.content = Encode::decode($charset, $response.content);
            }
        }
        $conn.close;

        last unless $response.status-line.substr(0, 1) eq '3' && $response.header.field('Location').defined;
        $url = ~$response.header.field('Location');
    }

    X::HTTP::Response.new(:rc($response.status-line)).throw
        if $response.status-line.substr(0, 1) eq '4';

    X::HTTP::Server.new(:rc($response.status-line)).throw
        if $response.status-line.substr(0, 1) eq '5';

    # save cookies
    $.cookies.extract-cookies($response);

    return $response;
}

# :simple
sub get(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new;
    my $response = $ua.get($url);

    return $response.decoded-content;
}

sub head(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new;
    return $ua.get($url).header.fields<Content-Type Content-Length Last-Modified Expires Server>;
}

sub getprint(Str $url) is export(:simple) {
    my $response = HTTP::UserAgent.new.get($url);
    print $response.decoded-content;
    $response.code;
}

sub getstore(Str $url, Str $file) is export(:simple) {
    $file.IO.spurt: get($url);
}

sub _clear-url(Str $url is copy) {
    $url = "http://$url" if $url.substr(0, 5) ne any('http:', 'https');
    $url;
}

sub _get-port(Str $url) {
    (~$/[0]).Int if $url ~~ m/':' (\d+) \/?/;
}

=begin pod

=head1 NAME

HTTP::UserAgent - Web user agent class

=head1 SYNOPSIS

    use HTTP::UserAgent;

    my $ua = HTTP::UserAgent.new;
    $ua.timeout = 10;

    my $response = $ua.get("URL");

    if $response.is-success {
        say $response.content;
    } else {
        die $response.status-line;
    }

=head1 DESCRIPTION

This module provides functionality to crawling the web with a handling cookies and correct User-Agent value.

It has TLS/SSL support.

=head1 METHODS

=head2 method new

Default constructor

=head2 method get

    method get(HTTP::UserAgent:, Str $url is copy) returns HTTP::Response

Requests the $url site, returns HTTP::Response on success, otherwise it throws exceptions.

=head2 routine get :simple

    sub get(Str $url) returns Str is export(:simple)

Like method get, but returns decoded content of the response.

=head2 routine head :simple

    sub head(Str $url) returns Parcel is export(:simple)

Returns values of following header fields:

=item Content-Type
=item Content-Length
=item Last-Modified
=item Expires
=item Server

=head2 routine getstore :simple

    sub getstore(Str $url, Str $file) is export(:simple)

Like routine get but writes the content to a file.

=head2 routine getprint :simple

    sub getprint(Str $url) is export(:simple)

Like routine get but prints the content and returns the response code.

=head1 SEE ALSO

L<HTTP::Message>

=end pod
