class LWP::UserAgent;
use HTTP::Response;
use HTTP::Request;

has Int $.timeout is rw = 180;

method get(Str $url) {
    my ($domain, $file) = split_url($url);

    my $request = HTTP::Request.new(GET => $url);
    my $conn = IO::Socket::INET.new(host => $domain, port => 80, timeout => $.timeout);

    my $s;
    if $conn.send($request.as_string) {
        $s = $conn.lines.join("\n");
    }

    $conn.close;
    return HTTP::Response.new.parse($s);
}

sub split_url($url is copy) {
    $url .= lc;
    if $url.index('http://') == 0 {
        $url = $url.substr($url.index('/')+2);
    }
    my $file = !$url.index('/') ?? '/' !! $url.substr($url.index('/'));

    if $url.index('/') {
        $url = $url.substr(0, $url.index('/'));
    }
    return ($url, $file);
}
