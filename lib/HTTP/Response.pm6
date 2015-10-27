use HTTP::Message;
use HTTP::Status;
use HTTP::Request;

unit class HTTP::Response is HTTP::Message;

has $.status-line is rw;
has $.code is rw;
has HTTP::Request $.request is rw;

my $CRLF = "\r\n";

class HTTP::Response::X is Exception {
    has $.message;
}

class HTTP::Response::X::ContentLength is HTTP::Response::X {
}

submethod BUILD(:$!code) {
    $!status-line = self.set-code($!code);
}

# This candidate makes it easier to test weird responses
multi method new(Blob $header-chunk) {
    my ( $rl, $header ) = $header-chunk.decode('ascii').split(/\x0d?\x0a/, 2);
    my $code = $rl.split(' ')[1].Int;
    my $response = self.new($code);
    $response.header.parse( $header.subst(/"\x0d"? "\x0a" $/, '') );
    return $response;
}

multi method new(Int $code? = 200, *%fields) {
    my $header = HTTP::Header.new(|%fields);
    self.bless(:$code, :$header);
}

method content-length() returns Int {
    my $content-length = self.field('Content-Length').values[0];

    if $content-length.defined {
        my $c = $content-length;
        if not ($content-length = try +$content-length).defined {
            HTTP::Response::X::ContentLength.new(message => "Content-Length header value '$c' is not numeric").throw;
        }
    }
    else {
        $content-length = Int
    }
    $content-length;
}

method is-success {
    return so is-success($!code);
}

# please extend as necessary
method has-content returns Bool {
    $!code == 204 ?? False !! True;
}

method is-chunked {
   return self.field('Transfer-Encoding') &&
          self.field('Transfer-Encoding') eq 'chunked' ?? True !! False;
}

method set-code(Int $code) {
    $!code = $code;
    $!status-line = $code ~ " " ~ get_http_status_msg($code);
}

method next-request() returns HTTP::Request {
    my HTTP::Request $new-request;

    my $location = ~self.header.field('Location').values;

    if $location.defined {
        # Special case for the HTTP status code 303 (redirection):
        # The response to the request can be found under another URI using
        # a separate GET method. This relates to POST, PUT, DELETE and PATCH methods.
        my $method = $!request.method;
        $method = "GET"
          if self.code == 303 &&
             $!request.method eq any('POST', 'PUT', 'DELETE', 'PATCH');

        my %args = $method => $location;
        $new-request = HTTP::Request.new(|%args);
        if not ~$new-request.field('Host').values {
            my $hh = ~$!request.field('Host').values;
            $new-request.field(Host => $hh);
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
