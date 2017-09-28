use v6;
use HTTP::UserAgent;
use Test;

plan 2;

#TODO:  This test could be done better locally.

unless %*ENV<NETWORK_TESTING> {
  diag "NETWORK_TESTING was not set";
  skip-rest("NETWORK_TESTING was not set");
  exit;
}

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
like($resp.content, rx/^^document.*'\')'$$/, 'resp' );

done-testing;
