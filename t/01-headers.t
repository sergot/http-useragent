use Test;

use HTTP::Header;

plan 13;

# new
my $h = HTTP::Header.new(a => "A", b => "B");

is ~$h.header('b'), 'B', 'new';

# header
is ~$h.header('a'), 'A', 'header 1/3';

$h.header(a => ['a', 'a1']);
is ~$h.header('a'), 'a, a1', 'header 2/3';

$h.header(a => 'a');
is ~$h.header('a'), 'a', 'header 3/3';

# init-header
$h.init-header(b => 'b');
is ~$h.header('b'), 'B', 'init-header 1/1';

# push-header
$h.push-header(a => ['a2', 'a3']);
is ~$h.header('a'), 'a, a2, a3', 'push-header 1/1';

# header-field-names
is $h.header-field-names.elems, 2, 'header-field-names 1/3';
is any($h.header-field-names), 'a', 'header-field-names 2/3';
is any($h.header-field-names), 'b', 'header-field-names 3/3';

# Str
is $h.Str, "a: a, a2, a3\nb: B\n", 'Str 1/2';
is $h.Str('|'), 'a: a, a2, a3|b: B|', 'Str 2/2';

# remove-header
$h.remove-header('a');
ok not $h.header('a'), 'remove-header 1/1';

# clear
$h.clear;
ok not $h.header('b'), 'clear 1/1';
