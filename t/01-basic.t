use LWP::UserAgent;
use Test;

plan *;

my $lwp = LWP::UserAgent.new;

is $lwp.timeout, 180, 'new';
