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

my $ua;
lives_ok { $ua  = HTTP::UserAgent.new(GET => $url) }, 'new(GET => $url) lives';

my $get = ~$ua.get($url);

ok $get ~~ /'</html>'/, 'http -> https redirect get 1/1';