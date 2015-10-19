use v6;
use HTTP::UserAgent;
use Test;

#TODO:  This test could be done better locally.

my @recv_log;

my $wrapped = IO::Socket::INET.^find_method('recv').wrap(-> $o, |args {
    my \ret = callsame;
    @recv_log.push(${ args => args, ret => ret });
    ret;
});

my $resp = HTTP::UserAgent.new.get(
    'http://www.punoftheday.com/cgi-bin/todayspun.pl'
);

IO::Socket::INET.^find_method('recv').unwrap($wrapped);

is(@recv_log.elems, 1, 'recv calls');
like($resp.content, rx/^document.*'\')'\n$/, 'resp' );

done-testing;
