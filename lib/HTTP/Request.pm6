use HTTP::Message;

use URI;

class HTTP::Request is HTTP::Message;

has $.method is rw;
has $.url is rw;
has $.file is rw;

my $CRLF = "\r\n";

method new(*%args) {
    my ($method, $url, %fields);
    
    for %args.kv -> $key, $value {
        if $key.lc ~~ any(<get post head put>) {
            $method = $key.uc;
            $url = %args{$key};
        } else {
            %fields{$key} = $value;
        }
    }

    my $header = HTTP::Header.new(|%fields);
    my $file;

    if $url {
        my $uri = URI.new($url);
        $header.field(Host => $uri.host);
        $file = $uri.path;
    }


    self.bless(:$method, :$url, :$header, :$file);
}

method set-method($method) { $.method = $method.uc }

method uri($url) {
    $.url = $url;
    
    my $host = URI.new($.url).host;
    $.header.field(Host => $host);
}

method Str {
    my $s = "$.method $.file $.protocol";
    $s ~= $CRLF ~ callwith($CRLF);
}

method parse($raw_request) {
    my @lines = $raw_request.split($CRLF);
    ($.method, $.file) = @lines.shift.split(' ');

    $.url = 'http://';

    for @lines -> $line {
        if $line ~~ m:i/host:/ {
            $.url ~= $line.split(/\:\s*/)[1];
        }
    }

    $.url ~= $.file;

    nextsame;

    self;
}

=begin pod

=head1 NAME

HTTP::Request - class encapsulating HTTP request message

=head1 SYNOPSIS

    use HTTP::Request;
    my $request = HTTP::Request.new(GET => 'http://www.example.com/');

=head1 DESCRIPTION

Module provides functionality to easily manage HTTP requests.

=head1 METHODS

=head2 method new

    method new(*%args)

A constructor, takes parameters like:

=item method => URL, where method can be POST, GET ... etc. 
=item field => values, header fields

    my $req = HTTP::Request.new(:GET<example.com>, :h1<v1>);

=head2 method set-method

    method set-method(Str $method)

Sets a method of the request.

    my $req = HTTP::Request.new;
    $req.set-method: 'POST';

=head2 method uri

    method uri(Str $url)

Sets URL to request.

    my $req = HTTP::Request.new;
    $req.uri: 'example.com';

=head2 method Str

    method Str returns Str;

Returns stringified object.

=head2 method parse

    method parse(Str $raw_request) returns HTTP::Request

Parses raw HTTP request.
See L<HTTP::Message>

For more documentation, see L<HTTP::Message>.

=head1 SEE ALSO

L<HTTP::Message>, L<HTTP::Response>

=end pod
