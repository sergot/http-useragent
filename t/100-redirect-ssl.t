use v6;

use HTTP::UserAgent;
BEGIN {
    if ::('IO::Socket::SSL') ~~ Failure {
        print("1..0 # Skip: IO::Socket::SSL not available\n");
        exit 0;
    }
}

use Test;

plan 2;

my $url = 'http://github.com';

my $ua  = HTTP::UserAgent.new;
my $get = ~$ua.get($url);

ok $get ~~ /'</html>'/, 'http -> https redirect get 1/1';

throws-like {
    temp $ua.max-redirects = 0;
    $ua.get($url);
}, X::HTTP::Response, "Max redirects exceeded";
