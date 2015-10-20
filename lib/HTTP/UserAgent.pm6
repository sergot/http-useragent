unit class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;
use HTTP::Cookies;
use HTTP::UserAgent::Common;

try require IO::Socket::SSL;

use Encode;
use URI;

use File::Temp;
use MIME::Base64;

constant CRLF = Buf.new(13, 10);

class X::HTTP is Exception {
    has $.rc;
    has HTTP::Response $.response;
}

class X::HTTP::Internal is Exception {
    has $.reason;

    method message {
        "Internal Error: '$.reason'";
    }
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

class X::HTTP::Header is X::HTTP::Server {
}

has Int $.timeout is rw = 180;
has $.useragent;
has $.cookies = HTTP::Cookies.new(
    file     => tempfile[0],
    autosave => 1,
);
has $.auth_login;
has $.auth_password;
has Int $.max-redirects is rw;
has @.history;
has Bool $.throw-exceptions;

my sub search-header-end(Blob $input) {
    my $i = 0;
    my $input-bytes = $input.bytes;
    while $i+2 <= $input-bytes {
        # CRLF
        if $i+4 <= $input-bytes && $input[$i] == 0x0d && $input[$i+1]==0x0a && $input[$i+2]==0x0d && $input[$i+3]==0x0a {
            return $i+4;
        }
        # LF
        if $input[$i] == 0x0a && $input[$i+1]==0x0a {
            return $i+2;
        }
        $i++;
    }
    return Nil;
}

my sub _index_buf(Blob $input, Blob $sub) {
    my $end-pos = 0;
    while $end-pos < $input.bytes {
        if $sub eq $input.subbuf($end-pos, $sub.bytes) {
            return $end-pos;
        }
        $end-pos++;
    }
    return -1;
}

submethod BUILD(:$!useragent, Bool :$!throw-exceptions, :$!max-redirects = 5) {
    $!useragent = get-ua($!useragent) if $!useragent.defined;
}

method auth(Str $login, Str $password) {
    $!auth_login    = $login;
    $!auth_password = $password;
}

multi method get(URI $uri is copy ) {
    my $request  = HTTP::Request.new(GET => $uri);
    self.request($request);
}

multi method get(Str $uri is copy ) {
    self.get(URI.new(_clear-url($uri)));
}

multi method request(HTTP::Request $request) {
    my HTTP::Response $response;

    # add cookies to the request
    $.cookies.add-cookie-header($request) if $.cookies.cookies.elems;

    # set the useragent
    $request.field(User-Agent => $.useragent) if $.useragent.defined;

    # use HTTP Auth
    $request.field(
        Authorization => "Basic " ~ MIME::Base64.encode-str("{$!auth_login}:{$!auth_password}")
    ) if $!auth_login.defined && $!auth_password.defined;

    my $host = $request.host;
    my $port = $request.port;
    my $http_proxy = %*ENV<http_proxy> || %*ENV<HTTP_PROXY>;

    if $http_proxy {
        $request.file = "http://$host" ~ $request.file;
        my ($proxy_host, $proxy_auth) = $http_proxy.split('/').[2].split('@', 2).reverse;
        ($host, $port) = $proxy_host.split(':');
        $port.=Int;
        $request.field(
            Proxy-Authorization => "Basic " ~ MIME::Base64.encode-str($proxy_auth)
        ) if $proxy_auth;
        $request.field(Connection => 'close');
    }
    my $conn;
    if $request.scheme eq 'https' {
        die "Please install IO::Socket::SSL in order to fetch https sites" if ::('IO::Socket::SSL') ~~ Failure;
        $conn = ::('IO::Socket::SSL').new(:$host, :port($port // 443), :timeout($.timeout))
    }
    else {
        $conn = IO::Socket::INET.new(:$host, :port($port // 80), :timeout($.timeout));
    }

    if $conn.print($request.Str ~ "\r\n") {
        my Blob[uint8] $first-chunk = Blob[uint8].new;
        my $msg-body-pos;

        # Header can be longer than one chunk
        while my $t = $conn.recv( :bin ) {
            $first-chunk ~= $t;

            # Find the header/body separator in the chunk, which means we can parse the header seperately and are
            # able to figure out the correct encoding of the body.
            $msg-body-pos = search-header-end($first-chunk);
            last if $msg-body-pos.defined;
        }

        if !$msg-body-pos.defined {
            X::HTTP::Internal.new(rc => 500, reason => "server returned no data").throw;
        }

        my ($response-line, $header) = $first-chunk.subbuf(0, $msg-body-pos)
            .decode('ascii')
            .split(/\x0d?\x0a/, 2);
        $response .= new( $response-line.split(' ')[1].Int );
        $response.header.parse( $header.subst(/"\x0d"? "\x0a" $/, '') );
        $response.request = $request;

        # 4: "\r\n\r\n".elems
        my $content = $first-chunk.subbuf($msg-body-pos);

        if $response.has-content {
            # We also need to handle 'Transfer-Encoding: chunked', which means
            # that we request more chunks and assemble the response body.
            if $response.is-chunked {
                my Buf $chunk = $content.clone;
                $content  = Buf.new;
                # We carry on as long as we receive something.
                PARSE_CHUNK: loop {
                    my $end_pos = _index_buf($chunk, CRLF);
                    if $end_pos >= 0 {
                        my $size = $chunk.subbuf(0, $end_pos).decode;
                        # remove optional chunk extensions
                        $size = $size.subst(/';'.*$/, '');
                        # www.yahoo.com sends additional spaces(maybe invalid)
                        $size = $size.subst(/' '*$/, '');
                        $chunk = $chunk.subbuf($end_pos+2);
                        my $chunk-size = :16($size);
                        if $chunk-size == 0 {
                            last PARSE_CHUNK;
                        }
                        while $chunk-size+2 > $chunk.bytes {
                            $chunk ~= $conn.recv($chunk-size+2-$chunk.bytes, :bin);
                        }
                        $content ~= $chunk.subbuf(0, $chunk-size);
                        $chunk = $chunk.subbuf($chunk-size+2);
                    } else {
                        # XXX Reading 1 byte is inefficient code.
                        #
                        # But IO::Socket#read/IO::Socket#recv reads from socket until
                        # fill the requested size.
                        #
                        # It cause hang-up on socket reading.
                        $chunk ~= $conn.recv(1, :bin);
                    }
                };
            }
            elsif $response.field('Content-Length').values[0] -> $content-length is copy {
                X::HTTP::Header.new( :rc("Content-Length header value '$content-length' is not numeric"), :response($response) ).throw
                    unless ($content-length = try +$content-length).defined;
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

            $response.content = $content andthen $response.content = $response.decoded-content;
        }
    }
    $conn.close;
    
    X::HTTP::Response.new(:rc('No response')).throw unless $response;
    
    # Is there a better way to save history without saving content?
    # Or should content be optionally cached? (useful for serving 304 Not Modified)
    my $response-copy = $response.clone();
    $response-copy.content = $response.content.WHAT;
    @.history.push($response-copy);

    given $response.code {
        when /^3/ { 
            when $.max-redirects < +@.history
            && all(@.history.reverse[0..$.max-redirects]>>.code)  {
                X::HTTP::Response.new(:rc('Max redirects exceeded'), :response($response)).throw;
            }
            default {
                my $new-request = $response.next-request();
                return self.request($new-request);
            }
        } 
        if $!throw-exceptions {
            when /^4/ { 
                X::HTTP::Response.new(:rc($response.status-line), :response($response)).throw 
            }
            when /^5/ { 
                X::HTTP::Server.new(:rc($response.status-line), :response($response)).throw 
            }
        }
    }        

    # save cookies
    $.cookies.extract-cookies($response);
    return $response;
}

# :simple
our sub get($target where URI|Str) is export(:simple) {
    my $ua = HTTP::UserAgent.new(:throw-exceptions);
    my $response = $ua.get($target);

    return $response.decoded-content;
}

our sub head(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new(:throw-exceptions);
    return $ua.get($url).header.fields<Content-Type Content-Length Last-Modified Expires Server>;
}

our sub getprint(Str $url) is export(:simple) {
    my $response = HTTP::UserAgent.new(:throw-exceptions).get($url);
    print $response.decoded-content;
    $response.code;
}

our sub getstore(Str $url, Str $file) is export(:simple) {
    $file.IO.spurt: get($url);
}

sub _clear-url(Str $url is copy) {
    $url = "http://$url" if $url.substr(0, 5) ne any('http:', 'https');
    $url;
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

    method new(HTTP::UserAgent:U: :$!useragent, Bool :$!throw-exceptions, :$!max-redirects = 5) returns HTTP::UserAgent

Default constructor.

There are three optional named arguments:

=item useragent 

A string that specifies what will be provided in the C<User-Agent> header in
the request.  A number of standard user agents are described in
L<HTTP::UserAgent::Common>, but a string that is not specified there will be
used verbatim.

=item throw-exceptions 

By default the C<request> method will not throw an exception if the
response from the server indicates that the request was unsuccesful, in
this case you should check C<is-success> to determine the status of the
L<HTTP::Response> returned.  If this is specified then an exception will
be thrown if the request was not a success, however you can still retrieve
the response from the C<response> attribute of the exception object.

=item max-redirects

This is the maximum number of redirects allowed for a single request, if
this is exceeded then an exception will be thrown (this is not covered by
C<no-exceptions> above and will always be throw,) the default value is 5.

=head2 method auth

    method auth(HTTP::UserAgent:, Str $login, Str $password)

Sets username and password needed to HTTP Auth.

=head2 method get

    multi method get(HTTP::UserAgent:, Str $url is copy) returns HTTP::Response
    multi method get(HTTP::UserAgent: URI $uri) returns HTTP::Response

Requests the $url site, returns HTTP::Response, except if throw-exceptions
is set as described above whereby an exception will be thrown if the
response indicates that the request wasn't successfull.

=head2 method request

    method request(HTTP::UserAgent: HTTP::Request $request) returns HTTP::Response

Performs the request described by the supplied L<HTTP::Request>, returns
a L<HTTP::Response>, except if throw-exceptions is set as described above
whereby an exception will be thrown if the response indicates that the
request wasn't successfull.

You can use the helper subroutines defined in L<HTTP::Request::Common> to
create the L<HTTP::Request> for you or create it yourself if you have more
complex requirements.

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
