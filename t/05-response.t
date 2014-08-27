use Test;

use HTTP::Response;

plan 13;

# new
my $r = HTTP::Response.new(200, a => 'a');

isa_ok $r, HTTP::Response, 'new 1/3';
isa_ok $r, HTTP::Message, 'new 2/3';
is $r.field('a'), 'a', 'new 3/3';

# field
$r.field(h => 'h');
is $r.field('h'), 'h', 'field 1/2';
$r.field(h => 'abc');
is $r.field('h'), 'abc', 'field 2/2';

# status-line
is $r.status-line, '200 OK', 'status-line 1/1';

# is-success
ok $r.is-success, 'is-success 1/2';
$r.set-code(404);
ok !$r.is-success, 'is-success  2/2';

# set-code
is $r.status-line, '404 Not Found', 'set-code 1/1';

# parse
my $res = "HTTP/1.1 200 OK\r\nHost: hoscik\r\n\r\ncontent\r\n";
$r = HTTP::Response.new.parse($res);
is $r.Str, $res, 'parse - Str 1/4';
is $r.content, 'content', 'parse - content 2/4';
is $r.status-line, '200 OK', 'parse - status-line 3/4';
is $r.protocol, 'HTTP/1.1', 'parse - protocol 4/4';
