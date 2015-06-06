unit class HTTP::Cookie;

has $.name is rw;
has $.value is rw;
has $.secure is rw;
has $.httponly is rw;

has %.fields;

method Str {
    my $s = "$.name=$.value; {(%.fields.flatmap( *.fmt("%s=%s") )).join('; ')}";
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

This module encapsulates single HTTP Cookie.

=head1 METHODS

The following methods are provided:

=head2 method new

    method new(HTTP::Cookie:, *%params)

A constructor, it takes hash parameters, like:

    name:     name of a cookie
    value:    value of a cookie
    secure:   Secure param
    httponly: HttpOnly param
    fields:   hash of fields (field => value)

Example:

    my $c = HTTP::Cookie.new(:name<a_cookie>, :value<a_value>, :secure, fields => (a => b));

=head2 method Str

    method Str(HTTP::Cookie:)

Returns a cookie (as a String) in readable (RFC2109) form.

=head1 SEE ALSO

L<HTTP::Cookies>, L<HTTP::Request>, L<HTTP::Response>

=end pod
