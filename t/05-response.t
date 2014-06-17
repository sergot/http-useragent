use Test;

use HTTP::Response;

plan 13;

# new
my $r = HTTP::Response.new(200, a => 'a');

isa_ok $r, HTTP::Response, 'new 1/3';
isa_ok $r, HTTP::Message, 'new 2/3';
is $r.header('a'), 'a', 'new 3/3';

# header
$r.header(h => 'h');
is $r.header('h'), 'h', 'header 1/2';
$r.header(h => 'abc');
is $r.header('h'), 'abc', 'header 2/2';

# status-line
is $r.status-line, '200 OK', 'status-line 1/1';

# is-success
ok $r.is-success, 'is-success 1/2';
$r.code(404);
ok !$r.is-success, 'is-success  2/2';

# code
is $r.status-line, '404 Not Found', 'code 1/1';

# parse
my $res = "HTTP/1.1 200 OK\r\nHost: hoscik\r\n\r\ncontent\r\n";
$r = HTTP::Response.new.parse($res);
is $r.Str, $res, 'parse - Str 1/4';
is $r.content, 'content', 'parse - content 2/4';
is $r.status-line, '200 OK', 'parse - status-line 3/4';
is $r.protocol, 'HTTP/1.1', 'parse - protocol 4/4';
