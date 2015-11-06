#!perl6
use v6;
use HTTP::UserAgent;
use Test;

BEGIN {
    if ::('IO::Socket::SSL') ~~ Failure {
        print("1..0 # Skip: IO::Socket::SSL not available\n");
        exit 0;
    }
}

my $ua = HTTP::UserAgent.new;
my $request = HTTP::Request.new(GET => 'https://api.github.com/repos/jonathanstowe/http-useragent/git/commits/d1120986c0d9945bc35f5a137cc4a52f6f14340e');
$request.header.field(User-Agent => 'test');
$request.header.field(If-Modified-Since => 'Wed, 04 Nov 2015 19:09:35 GMT');

my HTTP::Response $res;

lives-ok { $res = $ua.request($request) }, "request that results in 304 lives";
todo("for some reason it is 403 on travis",1);
is $res.code , 304, "and it is actually a 304";

# Add another where it always going to 304
$request = HTTP::Request.new(GET => 'http://httpstat.us/304');
lives-ok { $res = $ua.request($request) }, "another request that always results in 304 lives";
is $res.code , 304, "and it is actually a 304";

done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
