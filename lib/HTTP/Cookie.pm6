class HTTP::Cookie;

has $.name is rw;
has $.value is rw;
has $.secure is rw;
has $.httponly is rw;

has %.fields;

method Str {
    my $s = "$.name=$.value; {(%.fields.map( *.fmt("%s=%s") )).join('; ')}";
    $s ~= "; $.secure" if $.secure;
    $s ~= "; $.httponly" if $.httponly;
    $s;
}

=begin pod

=head1 NAME

HTTP::Cookie - HTTP cookie class

=head1 SYNOPSIS

    use HTTP::Cookie;

    my $cookie = HTTP::Cookie.new(:name<test_name>, :value<test_value>);
    say ~$cookie;

=head1 DESCRIPTION



=head1 METHODS

The following methods are provided:

=over 4

=item my $cookie = HTTP::Cookie.new

A constructor, it takes hash parameters, like:

    name:     name of a cookie
    value:    value of a cookie
    secure:   Secure param
    httponly: HttpOnly param
    fields:   hash of fields (field => value)

=item $cookie.Str

Returns a cookie (as String) in readable (RFC2109) form.

=head1 SEE ALSO

L<HTTP::Cookies>, L<HTTP::Request>, L<HTTP::Response>

=head1 AUTHOR

Filip Sergot (sergot)

=end pod
