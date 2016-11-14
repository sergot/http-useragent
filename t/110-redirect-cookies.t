#!perl6

use v6;

use Test;
use HTTP::UserAgent;
use Test::Util::ServerPort;

my $port = get-unused-port();

use lib $*PROGRAM.parent.child('lib').Str;

use TestServer;

%*ENV<NO_PROXY> = 'localhost';

my $test-server = test-server(my $done-promise = Promise.new, :$port);
my $ua          = HTTP::UserAgent.new;

plan 1;

ok $ua.get("http://localhost:$port/one").is-success, 'redirect preserves cookies';

$done-promise.keep("shutdown");

# vim: expandtab shiftwidth=4 ft=perl6
