class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;

use HTTP::UserAgent::Common;

has Int $.timeout is rw = 180;
has $.useragent;

# :simple
sub get(Str $url) is export(:simple) {
    my $request = HTTP::Request.new(GET => $url);
    my $conn = IO::Socket::INET.new(:host($request.header('Host')), :port(80), :timeout(1));

    my $s;
    if $conn.send($request.Str ~ "\r\n") {
        $s = $conn.lines.join("\n");
    }

    $conn.close;
    return HTTP::Response.new.parse($s).content;
}
