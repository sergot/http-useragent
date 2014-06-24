use v6;
use HTTP::UserAgent;
use HTTP::UserAgent::Common;
use Test;

plan 6;

# new
my $ua = HTTP::UserAgent.new;
is $ua.useragent, '', 'new 1/3';

$ua = HTTP::UserAgent.new(:useragent('test'));
is $ua.useragent, 'test', 'new 2/3';

my $newua = get-ua('chrome_linux');
$ua = HTTP::UserAgent.new(:useragent('chrome_linux'));
is $ua.useragent, $newua, 'new 3/3';

# get
my $response = $ua.get('filip.sergot.pl');
ok $response, 'get 1/?';
isa_ok $response, HTTP::Response, 'get 2/?';
ok $response.is-success, 'get 3/?';
