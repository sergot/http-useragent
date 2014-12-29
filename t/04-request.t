use HTTP::Request;
use Test;

plan 19;

my $url = 'http://testsite.ext/cat/f.h';
my $file = '/cat/f.h';
my $host = 'testsite.ext';

# new
my $r1 = HTTP::Request.new(POST => $url, test_field => 'this_is_field');

is $r1.method, 'post'.uc, 'new 1/7'; 
is $r1.url, $url, 'new 2/7';
is $r1.file, $file, 'new 3/7';
is $r1.field('Host'), $host, 'new 4/7';
is $r1.field('test_field'), 'this_is_field', 'new 5/7';
isa_ok $r1, HTTP::Request, 'new 6/7';
isa_ok $r1, HTTP::Message, 'new 7/7';

# content
$r1.add-content('n1=v1&a');
is $r1.content, 'n1=v1&a', 'content 1/1';

# field
$r1.field(Accept => 'test');
is $r1.field('Accept'), 'test', 'field 1/2';
$r1.field(Accept => 'test2');
is $r1.field('Accept'), 'test2', 'field 2/2';

# uri
$r1.uri('http://test.com');
is $r1.url, 'http://test.com', 'uri 1/2';
is $r1.field('Host'), 'test.com', 'uri 2/2';

# set-method
$r1.set-method: 'TEST';
is $r1.method, 'TEST', 'set-method 1/1';

# parse
my $req = "GET /index HTTP/1.1\r\nHost: somesite\r\nAccept: test\r\n\r\nname=value&a=b\r\n";
$r1 = HTTP::Request.new.parse($req);

is $r1.method, 'get'.uc, 'parse 1/6';
is $r1.file, '/index', 'parse 2/6';
is $r1.url, 'http://somesite/index', 'parse 3/6';
is $r1.field('Accept'), 'test', 'parse 4/6';
is $r1.content, 'name=value&a=b', 'parse 5/6';
is $r1.Str, $req, 'parse 6/6';
