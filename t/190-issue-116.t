#!perl6
use v6;
use HTTP::UserAgent;
use Test;

BEGIN {
    try require IO::Socket::SSL;
    if ::('IO::Socket::SSL') ~~ Failure {
        print("1..0 # Skip: IO::Socket::SSL not available\n");
        exit 0;
    }
}

my $ua = HTTP::UserAgent.new;

my HTTP::Response $res;
my $request = HTTP::Request.new(GET => 'http://httpstat.us/304');
lives-ok { $res = $ua.request($request) }, "another request that always results in 304 lives";
is $res.code , 304, "and it is actually a 304";

done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
