use v6;
use Test;
use HTTP::UserAgent;

plan 1;

if %*ENV<NETWORK_TESTING> {
    my $ua = HTTP::UserAgent.new(:debug);
    lives-ok { $ua.get("http://httpbin.org/image/png") };
}
