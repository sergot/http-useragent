class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;

use HTTP::UserAgent::Common;

has Int $.timeout is rw = 180;
has $.useragent;

sub _get(Str $url) {
    my $request = HTTP::Request.new(GET => $url);
    my $conn = IO::Socket::INET.new(:host($request.header('Host')), :port(80), :timeout(1));

    my $s;
    if $conn.send($request.Str ~ "\r\n") {
        $s = $conn.lines.join("\n");
    }

    $conn.close;
    return HTTP::Response.new.parse($s);
}

# :simple
sub get(Str $url) is export(:simple) {
    return _get($url).content;
}

sub head(Str $url) is export(:simple) {
    return _get($url).headers.headers<Content-Type Document-Length Modified-Time Expires Server>;
}

sub getprint(Str $url) is export(:simple) {
    say get($url);
}
