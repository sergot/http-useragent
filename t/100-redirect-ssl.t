use v6;

use HTTP::UserAgent;

use Test;

plan 2;

try require ::('IO::Socket::SSL');
if ::('IO::Socket::SSL') ~~ Failure {
    skip-rest("IO::Socket::SSL not available");
    exit 0;
}


my $url = 'http://github.com';

my $ua  = HTTP::UserAgent.new;
my $get = ~$ua.get($url);

ok $get ~~ /'</html>'/, 'http -> https redirect get 1/1';

throws-like {
    temp $ua.max-redirects = 0;
    $ua.get($url);
}, X::HTTP::Response, "Max redirects exceeded";
