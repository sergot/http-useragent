use HTTP::Message;
use HTTP::Status;

class HTTP::Response is HTTP::Message;

has $!status_line;
has $!code;

my $CRLF = "\r\n";

submethod BUILD(:$!code) {
    $!status_line = self.code($!code);
}

method new($code? = 200, *%headers) {
    my $headers = HTTP::Header.new(|%headers);
    self.bless(:$code, :$headers);
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

TODO

=head1 METHODS

=head2 method new

    method new(Int $code = 200, *%headers)

=head2 method is-success

    method is-success returns Bool;

=head2 method status-line

    method status-line returns Str;

=head2 method code

    method code(Int $code)

=head2 method Str

    method Str returns Str

=head1 SEE ALSO

L<HTTP::Message>, L<HTTP::Response>

=head1 AUTHOR

Filip Sergot (sergot)
Website: filip.sergot.pl
Contact: filip (at) sergot.pl

=end pod
