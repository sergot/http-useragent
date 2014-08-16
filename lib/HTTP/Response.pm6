use HTTP::Message;
use HTTP::Status;

class HTTP::Response is HTTP::Message;

has $!status_line;
has $!code;

my $CRLF = "\r\n";

submethod BUILD(:$!code) {
    $!status_line = self.code($!code);
}

method new(Int $code? = 200, *%fields) {
    my $header = HTTP::Header.new(|%fields);
    self.bless(:$code, :$header);
}

method is-success {
    return True if $!code ~~ "200";
    return False;
}

method status-line {
    return $!status_line;
}

method code(Int $code) {
    $!code = $code;
    $!status_line = $code ~ " " ~ get_http_status_msg($code);
}

method Str {
    my $s = $.protocol ~ " " ~ self.status-line;
    $s ~= $CRLF ~ callwith($CRLF);
}

=begin pod

=head1 NAME

HTTP::Response - class encapsulating HTTP response message

=head1 SYNOPSIS

    use HTTP::Response;
    my $response = HTTP::Response.new(200);
    say $response.is-success; # it is

=head1 DESCRIPTION

Module provides functionality to easily manage HTTP responses.

Response object is returned by the .get() method of L<HTTP::UserAgent>.

=head1 METHODS

=head2 method new

    method new(Int $code = 200, *%fields)

A constructor, takes parameters like:

=item code   : code of the response
=item fields : hash of header fields (field_name => values)

    my $response = HTTP::Response.new(200, :h1<v1>);

=head2 method is-success

    method is-success(HTTP::Response:) returns Bool;

Returns True if response is successful (status == 2xx), False otherwise.

    my $response = HTTP::Response.new(200);
    say 'YAY' if $response.is-success;

=head2 method status-line

    method status-line(HTTP::Response:) returns Str;

Returns status line of the response.

    my $response = HTTP::Response.new(200);
    say $response.status-line;

=head2 method code

    method code(HTTP::Response:, Int $code)

Sets code of the response.

    my $response = HTTP::Response.new;
    $response.code: 200;

=head2 method Str

    method Str(HTTP::Response:) returns Str

Returns strigified object.

=head2 method parse

See L<HTTP::Message>.

For more documentation, see L<HTTP::Message>.

=head1 SEE ALSO

L<HTTP::Message>, L<HTTP::Response>

=end pod
