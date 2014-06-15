class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;

use HTTP::UserAgent::Common;

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

method get(Str $url is copy) {
    $url = _clear-url($url);

    my $response;

    for 1..5 -> $i {
        my $request = HTTP::Request.new(GET => $url);
        my $conn = IO::Socket::INET.new(:host(~$request.header('Host').values), :port(80), :timeout($.timeout));

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
            
            # TODO We also need to handle 'Transfer-Encoding: chunked', which might mean that we pass $conn to
            # some method in HTTP::Message which can request and assemble chunks...
            
            $response.content = buf8.new( @a[($msg-body-pos + 2)..*] );
            my $content-type  = $response.headers.header('Content-Type').values[0] // '';
            if $content-type ~~ /^ text .+? [ 'charset=' $<charset>=[ \S+ ] ]?/ {
                $response.content.=decode( $<charset> ?? $<charset>.Str.lc !! 'ascii');
            }
        }
        $conn.close;

        last unless $response.status-line.substr(0, 1) eq '3' && $response.header('Location').defined;
        $url = $response.header('Location');
    }

    X::HTTP::Response.new(:rc($response.status-line)).throw
        if $response.status-line.substr(0, 1) eq '4';

    X::HTTP::Server.new(:rc($response.status-line)).throw
        if $response.status-line.substr(0, 1) eq '5';

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
    $url = "http://$url" if $url.substr(0, 4) ne 'http';
    $url;
}
