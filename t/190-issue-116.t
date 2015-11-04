#!perl6
use v6;
use HTTP::UserAgent;
use Test;

my $ua = HTTP::UserAgent.new;
my $request = HTTP::Request.new(GET => 'https://api.github.com/users/fayland');
$request.header.field(User-Agent => 'test');
$request.header.field(If-Modified-Since => 'Thu, 08 Oct 2015 18:37:54 GMT');

my HTTP::Response $res;

lives-ok { $res = $ua.request($request) }, "request that results in 304 lives";
is $res.code , 304, "and it is actually a 304";



done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
