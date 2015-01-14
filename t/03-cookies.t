use Test;

use HTTP::Cookies;
use HTTP::Request;
use HTTP::Response;

plan 24;

BEGIN my $file = './cookies.dat';
LEAVE try $file.IO.unlink;

my $c = HTTP::Cookies.new(
    file     => $file,
);

# new
ok $c, 'new 1/3';
is $c.file, $file, 'new 2/3';
is $c.autosave, 0, 'new 3/3';

# set-cookie
$c.set-cookie(
    'Set-Cookie: name1=value1; expires=DATE; Path=/; Domain=gugle.com; Secure; HttpOnly'
);
my $c1 = $c.cookies[0];
ok $c1, 'set-cookie 1/11';
is $c1.name, 'name1', 'set-cookie 2/11';
is $c1.value, 'value1', 'set-cookie 3/11';
is $c1.fields.elems, 3, 'set-cookie 4/11';
is $c1.secure, 'Secure', 'set-cookie 5/11';
is $c1.httponly, 'HttpOnly', 'set-cookie 6/11';

$c.set-cookie(
    'Set-Cookie: name2=value2; expires=DATE2; Path=/path; Domain=gugle.com;'
);
my $c2 = $c.cookies[1];
ok $c2, 'set-cookie 7/11';
is $c2.name, 'name2', 'set-cookie 8/11';
is $c2.value, 'value2', 'set-cookie 9/11';
is $c2.fields.elems, 3, 'set-cookie 10/11';
ok !$c2.secure, 'set-cookie 11/11';

# Str
my $result = "Set-Cookie: name1=value1; expires=DATE; Path=/; Domain=gugle.com; Secure; HttpOnly\nSet-Cookie: name2=value2; expires=DATE2; Path=/path; Domain=gugle.com";
is $c.Str, $result, 'Str 1/1';

# save
my $file_header = "#LWP6-Cookies-0.1\n";
$c.save;
is $c.file.IO.slurp, $file_header ~ $result ~ "\n", 'save 1/1';

# clear
$c.clear;
ok !$c.cookies, 'clear 1/1';

# load
$c.load;
is $c.Str, $result, 'load 1/1';

$c = HTTP::Cookies.new(
    file     => $file,
    autosave => 1,
);
$c.load;

# add-cookie-header
$c.set-cookie(
    'Set-Cookie: namek=songo; expires=DATE2; Domain=gugyl.com;'
);

my $req = HTTP::Request.new(GET => 'http://gugyl.com');
$c.add-cookie-header($req);
# Domain restriction
is $req.field('Cookie').values.elems, 1, 'add-cookie-header 1/?';

$c.set-cookie(
    'Set-Cookie: name3=value3; expires=DATE2; Path=/;'
);
$req = HTTP::Request.new(GET => 'http://gugle.com');
$c.add-cookie-header($req);
# 'Domain'less cookies
#
# TODO:
#is $req.field('Cookie').values.elems, 2, 'add-cookie-header 2/3';

$req = HTTP::Request.new(GET => 'http://gugle.com/path');
$c.add-cookie-header($req);
# Path restriction
#
# TODO:
#is $req.field('Cookie').values.elems, 1, 'add-cookie-header 3/3';

# extract-cookkies
my $resp = HTTP::Response.new(200);
$resp.field(Set-Cookie => 'k=v');
$c.extract-cookies($resp);
is $c.cookies.elems, 5, 'extract-cookies 1/1';

# clear-expired
$c.set-cookie('Set-Cookie: n1=v1; Expires=Sun, 06 Nov 1994 08:49:37 GMT');
ok $c.clear-expired, 'clear-expired 1/3';
is $c.cookies.elems, 5, 'clear-expired 2/3';
ok ! $c.cookies.grep({ .name eq 'n1' }), 'clear-expired 3/3';

# autosave
$c.clear;
is $c.cookies.elems, 0, 'autosave 1/1';
