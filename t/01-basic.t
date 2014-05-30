use HTTP::UserAgent;
use Test;

plan *;

my $lwp = HTTP::UserAgent.new;

is $lwp.timeout, 180, 'new';
