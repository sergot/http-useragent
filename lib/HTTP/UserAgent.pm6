class HTTP::UserAgent;
use HTTP::Response;
use HTTP::Request;

has Int $.timeout is rw = 180;

method get(Str $url) {
    my $request = HTTP::Request.new(GET => $url);
    my $conn = IO::Socket::INET.new(host => $request.header('Host'), port => 80, timeout => $.timeout);

    my $s;
    if $conn.send($request.Str) {
        $s = $conn.lines.join("\n");
    }

    $conn.close;
    return HTTP::Response.new.parse($s);
}

