class HTTP::Cookie;

has $.name is rw;
has $.value is rw;
has $.secure is rw;
has $.httponly is rw;

has %.fields;

method Str {
    my $s = "$.name=$.value; {(%.fields.map( *.fmt("%s=%s") )).join('; ')}";
    $s ~= "; $.secure" if $.secure;
    $s;
}
