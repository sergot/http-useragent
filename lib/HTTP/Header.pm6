use v6;

class HTTP::Header;

has $.name;
has @.values;

method Str {
    @.values.join(', ');
}
