use HTTP::Message;
use HTTP::Status;
use HTTP::Request;

unit class HTTP::Response is HTTP::Message;

has $.status-line is rw;
has $.code is rw;
has HTTP::Request $.request is rw;

my $CRLF = "\r\n";

submethod BUILD(:$!code) {
    $!status-line = self.set-code($!code);
}

method new(Int $code? = 200, *%fields) {
    my $header = HTTP::Header.new(|%fields);
    self.bless(:$code, :$header);
}

method is-success {
    return so $!code ~~ "200";
}

method is-chunked {
   return self.header.field('Transfer-Encoding') &&
          self.header.field('Transfer-Encoding') eq 'chunked' ?? True !! False; 
}

method set-code(Int $code) {
    $!code = $code;
    $!status-line = $code ~ " " ~ get_http_status_msg($code);
}

method next-request() returns HTTP::Request {
    my HTTP::Request $new-request;

    my $location = ~self.header.field('Location').values;

    if $location.defined {
        my %args = $!request.method => $location;
        $new-request = HTTP::Request.new(|%args);
        if not ~$new-request.header.field('Host').values {
            my $hh = ~$!request.header.field('Host').values;
            $new-request.header.field(Host => $hh);
            $new-request.host = $!request.host;
            $new-request.port = $!request.port;
        }
    }

    $new-request;
}

method Str {
    my $s = $.protocol ~ " " ~ $!status-line;
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

=head2 method set-code

    method set-code(HTTP::Response:, Int $code)

Sets code of the response.

    my $response = HTTP::Response.new;
    $response.set-code: 200;

=head2 method Str

    method Str(HTTP::Response:) returns Str

Returns strigified object.

=head2 method parse

See L<HTTP::Message>.

For more documentation, see L<HTTP::Message>.

=head1 SEE ALSO

L<HTTP::Message>, L<HTTP::Response>

=end pod
