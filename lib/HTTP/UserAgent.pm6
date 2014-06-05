class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;

use HTTP::UserAgent::Common;

class X::HTTP::Error is Exception {

}

has Int $.timeout is rw = 180;
has $.useragent;

method get(Str $url) {
    my $request = HTTP::Request.new(GET => $url);
    my $conn = IO::Socket::INET.new(:host($request.header('Host')), :port(80), :timeout($.timeout));

    my $s;
    if $conn.send($request.Str ~ "\r\n") {
        $s = $conn.lines.join("\n");
    }

    $conn.close;
    return HTTP::Response.new.parse($s);
}

# :simple
sub get(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new;
    return $ua.get($url).content;
}

sub head(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new;
    return $ua.get($url).headers.headers<Content-Type Document-Length Modified-Time Expires Server>;
}

sub getprint(Str $url) is export(:simple) {
    my $response = get($url);
    say $response;
    # TODO: return response code
}
