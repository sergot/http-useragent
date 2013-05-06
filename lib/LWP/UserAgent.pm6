class LWP::UserAgent;
use HTTP::Response;

has Int $.timeout = 180;

method get(Str $url) {
    my ($domain, $file) = split_url($url);

    # GET REQUEST
    ## TODO
    my $s = "HTTP/1.0 200 OK\r\nlalalala\r\nkasldasd";
    return HTTP::Response.new.parse($s);
}

sub split_url($url is copy) {
    $url .= lc;
    if $url.index('http://') && $url.index('http://') == 0 {
        $url = $url.substr($url.index('/')+2);
    }
    my $file = !$url.index('/') ?? '/' !! $url.substr($url.index('/'));

    if $url.index('/') {
        $url = $url.substr(0, $url.index('/'));
    }
    return ($url, $file);
}
