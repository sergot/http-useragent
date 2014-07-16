class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;
use HTTP::Cookies;

use HTTP::UserAgent::Common;

use IO::Socket::SSL;

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
    file     => '/tmp/cookies.dat',
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
    $url = _clear-url($url);

    my $response;

    for 1..5 {
        my $request = HTTP::Request.new(GET => $url);

        # add cookies to the request
        $.cookies.add-cookie-header($request) if $.cookies.cookies.elems;

        # set the useragent
        $request.headers.header(User-Agent => $.useragent) if $.useragent.defined;

        my $conn = $url.substr(4, 1) eq 's'
            ?? IO::Socket::SSL.new(:host(~$request.header('Host').values), :port(443), :timeout($.timeout))
            !! IO::Socket::INET.new(:host(~$request.header('Host').values), :port(80), :timeout($.timeout));

        if $conn.send($request.Str ~ "\r\n") {
            # We expect that the first chunk contains the entire header, including <CRLF><CRLF>.
            my $first-chunk  = $conn.recv( :bin );
            my @a            = $first-chunk.list;
            my @b            = "\r\n\r\n".ords;

            # Find the header/body separator in the chunk, which means we can parse the header seperately and are
            # able to figure out the correct encoding of the body.
            my $msg-body-pos = @a.first-index({ @a[(state $i = -1) .. $i++ + @b] ~~ @b });

            # +2 because we need a trailing CRLF in the header.
            $msg-body-pos   += 2 if $msg-body-pos >= 0;

            $response                    = HTTP::Response.new;
            my ($response-line, $header) = $first-chunk.decode('ascii').substr(0, $msg-body-pos).split("\r\n", 2);
            $response.code( $response-line.split(' ')[1].Int );
            $response.headers.parse( $header );

            my $content = buf8.new( @a[($msg-body-pos + 2)..*] );

            # We also need to handle 'Transfer-Encoding: chunked', which means that we request more chunks
            # and assemble the response body.
            if $response.headers.header('Transfer-Encoding') eq 'chunked' {
                my sub recv-entire-chunk($content is rw) {
                    if $content {
                        # The first line is our desired chunk size.
                        (my $chunk-size, $content) = _split_buf("\r\n", $content, 2);
                        $chunk-size                = :16($chunk-size.decode);
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
            elsif $response.headers.header('Content-Length').values[0] -> $content-length is copy {
                X::HTTP::Headers.new( :rc("Content-Length header value '$content-length' is not numeric") ).throw
                    unless $content-length = try +$content-length;
                # Let the content grow until we have reached the desired size.
                while $content-length > $content.bytes {
                    $content ~= $conn.recv($content-length - $content.bytes, :bin);
                }
            }

            # We have now the content as a Buf and need to decode it depending on some header informations.
            $response.content = $content;
            my $content-type  = $response.headers.header('Content-Type').values[0] // '';
            if $content-type ~~ /^ text / {
                my $charset = $content-type ~~ / charset '=' $<charset>=[ \S+ ] /
                            ?? $<charset>.Str.lc
                            !! 'ascii';
                $response.content.=decode($charset);
            }
        }
        $conn.close;

        last unless $response.status-line.substr(0, 1) eq '3' && $response.header('Location').defined;
        $url = ~$response.header('Location');
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
    return $ua.get($url).headers.headers<Content-Type Document-Length Modified-Time Expires Server>;
}

sub getprint(Str $url) is export(:simple) {
    my $response = get($url);
    print $response;
    # TODO: return response code
}

sub getstore(Str $url, Str $file) is export(:simple) {
    $file.IO.spurt: get($url);
}

sub _clear-url(Str $url is copy) {
    $url = "http://$url" if $url.substr(0, 5) ne any('http:', 'https');
    $url;
}

sub _latin2-to-u($ch) {
    my %latin2-to-u =
        0xA0 => 0x0a0,
        0xA1 => 0x104,
        0xA2 => 0x2d8,
        0xA3 => 0x141,
        0xA4 => 0x0a4,
        0xA5 => 0x13d,
        0xA6 => 0x15a,
        0xA7 => 0x0a7,
        0xA8 => 0x0a8,
        0xA9 => 0x160,
        0xAA => 0x15e,
        0xAB => 0x164,
        0xAC => 0x179,
        0xAD => 0x0ad,
        0xAE => 0x17d,
        0xAF => 0x17b,
        0xB0 => 0x0b0,
        0xB1 => 0x105,
        0xB2 => 0x2db,
        0xB3 => 0x142,
        0xB4 => 0x0b4,
        0xB5 => 0x13e,
        0xB6 => 0x15b,
        0xB7 => 0x2c7,
        0xB8 => 0x0b8,
        0xB9 => 0x161,
        0xBA => 0x15f,
        0xBB => 0x165,
        0xBC => 0x17a,
        0xBD => 0x2dd,
        0xBE => 0x17e,
        0xBF => 0x17c,
        0xC0 => 0x154,
        0xC1 => 0x0c1,
        0xC2 => 0x0c2,
        0xC3 => 0x102,
        0xC4 => 0x0c4,
        0xC5 => 0x139,
        0xC6 => 0x106,
        0xC7 => 0x0c7,
        0xC8 => 0x10c,
        0xC9 => 0x0c9,
        0xCA => 0x118,
        0xCB => 0x0cb,
        0xCC => 0x11a,
        0xCD => 0x0cd,
        0xCE => 0x0ce,
        0xCF => 0x10e,
        0xD0 => 0x110,
        0xD1 => 0x143,
        0xD2 => 0x147,
        0xD3 => 0x0d3,
        0xD4 => 0x0d4,
        0xD5 => 0x150,
        0xD6 => 0x0d6,
        0xD7 => 0x0d7,
        0xD8 => 0x158,
        0xD9 => 0x16e,
        0xDA => 0x0da,
        0xDB => 0x170,
        0xDC => 0x0dc,
        0xDD => 0x0dd,
        0xDE => 0x162,
        0xDF => 0x0df,
        0xE0 => 0x155,
        0xE1 => 0x0e1,
        0xE2 => 0x0e2,
        0xE3 => 0x103,
        0xE4 => 0x0e4,
        0xE5 => 0x13a,
        0xE6 => 0x107,
        0xE7 => 0x0e7,
        0xE8 => 0x10d,
        0xE9 => 0x0e9,
        0xEA => 0x119,
        0xEB => 0x0eb,
        0xEC => 0x11b,
        0xED => 0x0ed,
        0xEE => 0x0ee,
        0xEF => 0x10f,
        0xF0 => 0x111,
        0xF1 => 0x144,
        0xF2 => 0x148,
        0xF3 => 0x0f3,
        0xF4 => 0x0f4,
        0xF5 => 0x151,
        0xF6 => 0x0f6,
        0xF7 => 0x0f7,
        0xF8 => 0x159,
        0xF9 => 0x16f,
        0xFA => 0x0fa,
        0xFB => 0x171,
        0xFC => 0x0fc,
        0xFD => 0x0fd,
        0xFE => 0x163,
        0xFF => 0x2d9;

    $buf.list.map({ %latin2-to-u{$_} })>>.chr;
}
