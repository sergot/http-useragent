#!perl6

use v6;

use Test;
use HTTP::UserAgent;
use Test::Util::ServerPort;

my $port = get-unused-port();

# Start a really bad server that just closes the connection
# without sending anything.
my $p = start {
    react {
        whenever IO::Socket::Async.listen('localhost', $port) -> $conn {
            $conn.close;
        }
    }

}

%*ENV<NO_PROXY> = 'localhost';

my $ua = HTTP::UserAgent.new;

my $res;

throws-like { $res = $ua.get("http://localhost:$port/") }, X::HTTP::Internal, rc => 500, "throws the correct exception";


done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
