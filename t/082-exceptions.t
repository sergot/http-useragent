#!/usr/bin/env perl6

use v6;
use lib 'lib';
use Test;
use HTTP::UserAgent;

my $ua = HTTP::UserAgent.new;
my $res;

lives-ok { $res = $ua.get('http://httpstat.us/404') }, "no exception - expect 404";

ok !$res.is-success, "and it isn't successful";
is $res.code, 404, "and a 404";

$ua = HTTP::UserAgent.new(:throw-exceptions);

throws-like {  $ua.get('http://httpstat.us/404') }, X::HTTP::Response, message => "Response error: '404 Not Found'", response => HTTP::Response;

done-testing;

# vim: expandtab shiftwidth=4 ft=perl6
