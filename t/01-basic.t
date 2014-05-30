use HTTP::UserAgent;
use Test;

plan *;

my $http = HTTP::UserAgent.new;

is $http.timeout, 180, 'new';
