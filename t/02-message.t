use Test;

use HTTP::Message;

plan 19;

# new
my $m = HTTP::Message.new('somecontent', a => ['a1', 'a2']);

isa_ok $m, HTTP::Message, 'new 1/4';
isa_ok $m.headers, HTTP::Headers, 'new 2/4';
is $m.header('a'), 'a1, a2', 'new 3/4';
is $m.content, 'somecontent', 'new 4/4';

# push-headers
$m.push-header(a => 'a3');
is $m.header('a'), 'a1, a2, a3', 'push-header 1/2';
$m.push-header(a => <a4 a5>);
is $m.header('a'), 'a1, a2, a3, a4, a5', 'push-header 2/2';

# add-content
$m.add-content('some');
is $m.content, 'somecontentsome', 'add-content 1/2';

$m.add-content('line');
is $m.content, 'somecontentsomeline', 'add-content 2/2';

# remove-header
$m.remove-header('a');
is $m.header('a'), '', 'remove-header 1/1';

# parse
my $to_parse =    "GET site HTTP/1.0\r\na: b, c\r\na: d\r\n"
                ~ "\r\nline\r\n";
$m.parse($to_parse);
is $m.header('a'), 'b, c, d', 'parse 1/4';
is $m.header('a').values[0], 'b', 'parse 2/4';
is $m.content, 'line', 'parse 3/4';
is $m.protocol, 'HTTP/1.0', 'parse 4/4';

# Str
is $m.Str, "a: b, c, d\n\nline\n", 'Str 1/2';
is $m.Str("\r\n"), "a: b, c, d\r\n\r\nline\r\n", 'Str 2/2';

# clear
$m.clear;
is $m.Str, '', 'clear 1/2';
is $m.content, '', 'clear 2/2';

## parse a more complex example
# new
my $m2 = HTTP::Message.new;

my $CRLF = "\r\n";
# parse
$to_parse = "HTTP/1.1 200 OK\r\n"
          ~ "Server: Apache/2.2.3 (CentOS)\r\n"
          ~ "Last-Modified: Sat, 31 May 2014 16:39:02 GMT\r\n"
          ~ "ETag: \"16d3e2-20416-4fab4ccb03580\"\r\n"
          ~ "Vary: Accept-Encoding\r\n"
          ~ "Content-Type: text/plain; charset=UTF-8\r\n"
          ~ "Transfer-Encoding: chunked\r\n"
          ~ "Date: Mon, 02 Jun 2014 17:07:52 GMT\r\n"
          ~ "X-Varnish: 1992382947 1992382859\r\n"
          ~ "Age: 40\r\n"
          ~ "Via: 1.1 varnish\r\n"
          ~ "Connection: close\r\n"
          ~ "X-Served-By: eu3.develooper.com\r\n"
          ~ "X-Cache: HIT\r\n"
          ~ "X-Cache-Hits: 2\r\n"
          ~ "\r\n"
          ~ "008000\r\n"
          ~ "# Last updated Sat May 31 16:39:01 2014 (UTC)\n"
          ~ "# \n"
          ~ "# Explanation of the syntax:\n";
$m2.parse($to_parse);

is ~$m2.header('ETag'), '"16d3e2-20416-4fab4ccb03580"', 'parse complex 1/2';
is ~$m2.header('Transfer-Encoding'), 'chunked', 'parse complex 2/2';
