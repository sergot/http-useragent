unit class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;
use HTTP::Cookies;
use HTTP::UserAgent::Common;

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

# placeholder role to make signatures nicer
# and enable greater abstraction
role Connection {
    method send-request(HTTP::Request $request ) {
        $request.field(Connection => 'close') unless $request.field('Connection');
        if $request.binary {
            self.print($request.Str(:bin));
            self.write($request.content);
        }
        else {
            self.print($request.Str ~ "\r\n");
        }
    }
}

has Int $.timeout is rw = 180;
has $.useragent;
has HTTP::Cookies $.cookies is rw = HTTP::Cookies.new(
    file     => tempfile[0],
    autosave => 1,
);
has $.auth_login;
has $.auth_password;
has Int $.max-redirects is rw;
has @.history;
has Bool $.throw-exceptions;
has $.debug;
has IO::Handle $.debug-handle;

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

submethod BUILD(:$!useragent, Bool :$!throw-exceptions, :$!max-redirects = 5, :$!debug) {
    $!useragent = get-ua($!useragent) if $!useragent.defined;
    if $!debug.defined {
        if $!debug ~~ Bool and $!debug == True {
            $!debug-handle = $*OUT;
        }
        if $!debug ~~ Str {
            say $!debug;
            $!debug-handle = open($!debug, :w);
            $!debug = True;
        }
        if $!debug ~~ IO::Handle {
            $!debug-handle = $!debug;
            $!debug = True;
        }
    }
}

method auth(Str $login, Str $password) {
    $!auth_login    = $login;
    $!auth_password = $password;
}

multi method get(URI $uri is copy, Bool :$bin,  *%header ) {
    my $request  = HTTP::Request.new(GET => $uri, |%header);
    self.request($request, :$bin);
}

multi method get(Str $uri is copy, Bool :$bin,  *%header ) {
    self.get(URI.new(_clear-url($uri)), :$bin, |%header);
}

multi method post(URI $uri is copy, %form , Bool :$bin,  *%header) {
    my $request = HTTP::Request.new(POST => $uri, |%header);
    $request.add-form-data(%form);
    self.request($request, :$bin);
}

multi method post(Str $uri is copy, %form, Bool :$bin, *%header ) {
    self.post(URI.new(_clear-url($uri)), %form, |%header);
}

method request(HTTP::Request $request, Bool :$bin) returns HTTP::Response {
    my HTTP::Response $response;

    # add cookies to the request
    $request.add-cookies($.cookies);

    # set the useragent
    $request.field(User-Agent => $.useragent) if $.useragent.defined;

    # if auth has been provided add it to the request
    self.setup-auth($request);
    $.debug-handle.say("==>>Send\n" ~ $request.Str(:debug)) if $.debug;
    my Connection $conn = self.get-connection($request);

    if $conn.send-request($request) {
         $response = self.get-response($request, $conn, :$bin);
    }
    $conn.close;
    
    X::HTTP::Response.new(:rc('No response')).throw unless $response;
    
    self.save-response($response);
    $.debug-handle.say("<<==Recv\n" ~ $response.Str(:debug)) if $.debug;

    given $response.code {
        when /^30<[0123]>/ { 
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

# When we have a content-length
multi method get-content(Connection $conn, Blob $content is rw, $content-length) returns Blob {
    # Let the content grow until we have reached the desired size.
    while $content-length > $content.bytes {
        $content ~= $conn.recv($content-length - $content.bytes, :bin);
    }
    $content;
}

# fallback when not chunked and no content length
multi method get-content(Connection $conn, Blob $content is rw ) returns Blob {
    while my $new_content = $conn.recv(:bin) {
        $content ~= $new_content;
    }
    $content;
}

method get-chunked-content(Connection $conn, Blob $content is rw ) returns Blob {
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

    return $content;
}

method get-response(HTTP::Request $request, Connection $conn, Bool :$bin) returns HTTP::Response {
    my Blob[uint8] $first-chunk = Blob[uint8].new;
    my $msg-body-pos;


    # Header can be longer than one chunk
    while my $t = $conn.recv( :bin ) {
        $first-chunk ~= $t;

        # Find the header/body separator in the chunk, which means
        # we can parse the header seperately and are  able to figure
        # out the correct encoding of the body.
        $msg-body-pos = search-header-end($first-chunk);
        last if $msg-body-pos.defined;
    }


    # If the header would indicate that there won't
    # be any content there may not be a \r\n\r\n at
    # the end of the header.
    my $header-chunk = do if $msg-body-pos.defined {
        $first-chunk.subbuf(0, $msg-body-pos);
    } 
    else {
        # Assume we have the whole header because if the server
        # didn't send it we're stuffed anyway
        $first-chunk;
    }

    my HTTP::Response $response = HTTP::Response.new($header-chunk);
    $response.request = $request;

    if $response.has-content {
        if !$msg-body-pos.defined {
            X::HTTP::Internal.new(rc => 500, reason => "server returned no data").throw;
        }

        my $content = $first-chunk.subbuf($msg-body-pos);
        # Turn the inner exceptions to ours
        # This may really want to be outside
        CATCH {
            when HTTP::Response::X::ContentLength {
                X::HTTP::Header.new( :rc($_.message), :response($response) ).throw
            }
        }
        # We also need to handle 'Transfer-Encoding: chunked', which means
        # that we request more chunks and assemble the response body.
        if $response.is-chunked {
            $content = self.get-chunked-content($conn, $content);
        }
        elsif $response.content-length -> $content-length is copy {
            $content = self.get-content($conn, $content, $content-length);
        }
        else {
            $content = self.get-content($conn, $content);
        }

        $response.content = $content andthen $response.content = $response.decoded-content(:$bin);
    }
    return $response;
}

method save-response(HTTP::Response $response) {
    # Is there a better way to save history without saving content?
    # Or should content be optionally cached? 
    # (useful for serving 304 Not Modified)
    my $response-copy = $response.clone();
    $response-copy.content = $response.content.WHAT;
    @!history.push($response-copy);
}


multi method get-connection(HTTP::Request $request ) returns Connection {
    my $host = $request.host;
    my $port = $request.port;


    if self.get-proxy($request) -> $http_proxy {
        $request.file = $request.url;
        my ($proxy_host, $proxy_auth) = $http_proxy.split('/').[2].split('@', 2).reverse;
        ($host, $port) = $proxy_host.split(':');
        $port.=Int;
        if $proxy_auth.defined {
            $request.field(Proxy-Authorization => basic-auth-token($proxy_auth));
        }
        $request.field(Connection => 'close');
    }
    self.get-connection($request, $host, $port);
}

multi method get-connection(HTTP::Request $request, Str $host, Int $port?) returns Connection {
    my $conn;
    if $request.scheme eq 'https' {
        try require IO::Socket::SSL;
        die "Please install IO::Socket::SSL in order to fetch https sites" if ::('IO::Socket::SSL') ~~ Failure;
        $conn = ::('IO::Socket::SSL').new(:$host, :port($port // 443), :timeout($.timeout))
    }
    else {
        $conn = IO::Socket::INET.new(:$host, :port($port // 80), :timeout($.timeout));
    }
    $conn does Connection;
    $conn;
}

# want the request to possibly match scheme, no_proxy etc
method get-proxy(HTTP::Request $request) {
    %*ENV<http_proxy> || %*ENV<HTTP_PROXY>;
}

multi sub basic-auth-token(Str $login, Str $passwd ) returns Str {
    basic-auth-token("{$login}:{$passwd}");

}

multi sub basic-auth-token(Str $creds where * ~~ /':'/) returns Str {
    "Basic " ~ MIME::Base64.encode-str($creds);
}

method setup-auth(HTTP::Request $request) {
    # use HTTP Auth
    if self.use-auth($request) {
        $request.field(Authorization => basic-auth-token($!auth_login,$!auth_password));
    }
}

method use-auth(HTTP::Request $request) {
    $!auth_login.defined && $!auth_password.defined;
}

# :simple
our sub get($target where URI|Str) is export(:simple) {
    my $ua = HTTP::UserAgent.new(:throw-exceptions);
    my $response = $ua.get($target);

    return $response.decoded-content;
}

our sub head(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new(:throw-exceptions);
    return $ua.get($url).header.hash<Content-Type Content-Length Last-Modified Expires Server>;
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

    method new(HTTP::UserAgent:U: :$!useragent, Bool :$!throw-exceptions, :$!max-redirects = 5, :$!debug) returns HTTP::UserAgent

Default constructor.

There are four optional named arguments:

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

=item debug

It can etheir be a Bool like simply C<:debug> or you can pass it a IO::Handle
or a file name. Eg C<:debug($*ERR)> will ouput on stderr C<:debug("mylog.txt")>
will ouput on the file.

=head2 method auth

    method auth(HTTP::UserAgent:, Str $login, Str $password)

Sets username and password needed to HTTP Auth.

=head2 method get

    multi method get(Str $url is copy, :bin?, *%headers) returns HTTP::Response
    multi method get(URI $uri, :bin?, *%headers) returns HTTP::Response

Requests the $url site, returns HTTP::Response, except if throw-exceptions
is set as described above whereby an exception will be thrown if the
response indicates that the request wasn't successfull.

If the Content-Type of the response indicates that the content is text the
C<content> of the Response will be a decoded string, otherwise it will be
left as a L<Blob>.

If the ':bin' adverb is supplied this will force the response C<content> to
always be an undecoded L<Blob>

Any additional named arguments will be applied as headers in the request.

=head2 method post

    multi method post(URI $uri, %form, *%header ) -> HTTP::Response
    multi method post(Str $uri, %form, *%header ) -> HTTP::Response

Make a POST request to the specified uri, with the provided Hash of %form
data in the body encoded as "application/x-www-form-urlencoded" content.
Any additional named style arguments will be applied as headers in the
request.

An L<HTTP::Response> will be returned, except if throw-exceptions has been set
and the response indicates the request was not successfull.

If the Content-Type of the response indicates that the content is text the
C<content> of the Response will be a decoded string, otherwise it will be
left as a L<Blob>.

If the ':bin' adverb is supplied this will force the response C<content> to
always be an undecoded L<Blob>

If greater control over the content of the request is required you should
create an L<HTTP::Request> directly and populate it as needed,

=head2 method request

    method request(HTTP::Request $request, :bin?) returns HTTP::Response

Performs the request described by the supplied L<HTTP::Request>, returns
a L<HTTP::Response>, except if throw-exceptions is set as described above
whereby an exception will be thrown if the response indicates that the
request wasn't successful.

If the response has a 'Content-Encoding' header that indicates that the
content was compressed, then it will attempt to inflate the data using
L<Compress::Zlib>, if the module is not installed then an exception will
be thrown. If you do not have or do not want to install L<Compress::Zlib>
then you should be able to send an 'Accept-Encoding' header with a value
of 'identity' which should cause a well behaved server to send the content
verbatim if it is able to.

If the Content-Type of the response indicates that the content is text the
C<content> of the Response will be a decoded string, otherwise it will be
left as a L<Blob>. The content-types that are always considered to be
binary (and thus left as a L<Blob> ) are those with the major-types of
'image','audio' and 'video', certain 'application' types are considered to
be 'text' (e.g. 'xml', 'javascript', 'json').

If the ':bin' adverb is supplied this will force the response C<content> to
always be an undecoded L<Blob>

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
