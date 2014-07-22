class HTTP::Cookie;

has $.name is rw;
has $.value is rw;
has $.secure is rw;

has %.fields;

my grammar Cookie {
    token TOP {
        'Set-Cookie:' [\s* <cookie> ','?]*
    }

    token cookie   {
        <name> '=' <value> ';'? \s* [<arg> \s*]* <secure>? ';'? \s* <httponly>? ';'?
    }
    token name     { \w+ }
    token value    { <[\w \s ,]>+ }
    token arg      { <name> '=' <value> ';'? }
    token secure   { Secure }
    token httponly { HttpOnly }
}

multi method parse(Str $s is copy) {
    # 11 = 'set-cookies:'.chars
    $s .= substr(11) if $s ~~ m:i/^ 'set-cookie' /;

    # name=value pairs separated by ';'
    for $s.split(';')>>.trim -> $elem {
        my @e = $elem.split('=');
        if @e.elems > 1 {
            if !$.name.defined {
                $.name  = @e[0];
                $.value = @e[1];
            } else {
                %.fields.push: @e;
            }
        } else {
            # at the end we can find: secure, HttpOnly...
            # TODO : HttpOnly
            $.secure = @e[0];
        }
    }

    self;
}

method Str {
    my $s = "$.name=$.value; {(%.fields.map( *.fmt("%s=%s") )).join('; ')}";
    $s ~= "; $.secure" if $.secure;
    $s;
}
