use Test;

use HTTP::Header;

plan 18;

# new
my $h = HTTP::Header.new(a => "A", b => "B");

is ~$h.field('b'), 'B', 'new';

# field
is ~$h.field('a'), 'A', 'field 1/4';

$h.field(a => ['a', 'a1']);
is ~$h.field('a'), 'a, a1', 'field 2/4';

$h.field(a => 'a');
is ~$h.field('a'), 'a', 'field 3/4';

# case insensitive
is ~$h.field('A'), 'a', 'field 4/4';

# init-field
$h.init-field(b => 'b');
is ~$h.field('b'), 'B', 'init-field 1/1';

# push-field
$h.push-field(a => ['a2', 'a3']);
is ~$h.field('a'), 'a, a2, a3', 'push-field 1/1';

# header-field-names
is $h.header-field-names.elems, 2, 'header-field-names 1/3';
is any($h.header-field-names), 'a', 'header-field-names 2/3';
is any($h.header-field-names), 'b', 'header-field-names 3/3';

# Str
is $h.Str, "a: a, a2, a3\nb: B\n", 'Str 1/2';
is $h.Str('|'), 'a: a, a2, a3|b: B|', 'Str 2/2';

# remove-field
$h.remove-field('a');
ok not $h.field('a'), 'remove-field 1/1';

# clear
$h.clear;
ok not $h.field('b'), 'clear 1/1';

$h = HTTP::Header.new(One => "one", Two => "two");

is $h.hash<One>, "one", "Got one (hash 1/2)";
is $h.hash<Two>, "two", "Got two (hash 2/2)";

$h = HTTP::Header.new();

lives-ok { $h.parse('ETag: "1201-51b0ce7ad3900"') }, "parse";
is ~$h.field('ETag'), "1201-51b0ce7ad3900", "got the value we expected";
