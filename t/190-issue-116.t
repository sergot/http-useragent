#!perl6
use v6;
use HTTP::UserAgent;
use Test;

plan 2;

try require ::('IO::Socket::SSL');
if ::('IO::Socket::SSL') ~~ Failure {
    skip-rest("IO::Socket::SSL not available");
    exit 0;
}

my $ua = HTTP::UserAgent.new;

my HTTP::Response $res;
my $request = HTTP::Request.new(GET => 'http://httpbin.org/status/304');
lives-ok { $res = $ua.request($request) }, "another request that always results in 304 lives";
is $res.code , 304, "and it is actually a 304";

done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
