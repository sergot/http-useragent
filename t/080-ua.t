use v6;
use HTTP::UserAgent;
use HTTP::UserAgent::Common;
use Test;

plan 9;

# new
my $ua = HTTP::UserAgent.new;
nok $ua.useragent, 'new 1/3';

$ua = HTTP::UserAgent.new(:useragent('test'));
is $ua.useragent, 'test', 'new 2/3';

my $newua = get-ua('chrome_linux');
$ua = HTTP::UserAgent.new(:useragent('chrome_linux'));
is $ua.useragent, $newua, 'new 3/3';

# user agent
is $ua.get('http://ua.offensivecoder.com/').content, "$newua\n", 'useragent 1/1';

# get
my $response = $ua.get('filip.sergot.pl/');
ok $response, 'get 1/3';
isa-ok $response, HTTP::Response, 'get 2/3';
ok $response.is-success, 'get 3/3';

# non-ascii encodings (github issue #35)
lives-ok { HTTP::UserAgent.new.get('http://www.baidu.com') }, 'Lived through gb2312 encoding';

# chunked encoding.

lives-ok { HTTP::UserAgent.new.get('http://rakudo.org') }, "issue#51 - get rakudo.org (chunked encoding foul-up results in incomplete UTF-8 data)";

