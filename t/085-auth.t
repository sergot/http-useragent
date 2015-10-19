#!/usr/bin/env perl6

use v6;

use lib 'lib';

use Test;
use HTTP::UserAgent;

my $ua = HTTP::UserAgent.new;

lives-ok { $ua.auth('test', 'TEST' ) }, "set credentials";

is $ua.auth_login, 'test', "login got set okay";
is $ua.auth_password, 'TEST', "password got set okay";

my $res;

lives-ok { $res = $ua.get('http://oha.it/t/auth/') }, "get site that requires auth";

is $res.code, 200, "and it's a 200";



done-testing;
