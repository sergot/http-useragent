class LWP::UserAgent;
use HTTP::Response;
use HTTP::Request;

has Int $.timeout is rw = 180;

method get(Str $url) {
    my ($domain, $file) = split_url($url);

    my $request = HTTP::Request.new(:method<GET>).request($domain, $file);
    my $conn = IO::Socket::INET.new(host => $domain, port => 80);
    $conn.send($request);

    my $s = $conn.lines.join("\n");

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
