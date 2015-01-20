use HTTP::Message;

use URI;

class HTTP::Request is HTTP::Message;

has $.method is rw;
has $.url is rw;
has $.file is rw;

my $CRLF = "\r\n";

method new(*%args) {
    my ($method, $url, $file, %fields, $uri);
    
    for %args.kv -> $key, $value {
        if $key.lc ~~ any(<get post head put>) {
            $uri = $value.isa(URI) ?? $value !! URI.new($value);
            $url = $uri.grammar.parse_result.orig;
            $method = $key.uc;
            $file = $uri.path || '/';
            $file ~= "?{$uri.query}" if $uri.query;
        } else {
            %fields{$key} = $value;
        }
    }

    my $header = HTTP::Header.new(|%fields);
    $header.field(Host => $uri.host) if $uri;
    self.bless(:$method, :$url, :$header, :$file);
}

method set-method($method) { $.method = $method.uc }

method uri($uri is copy where URI|Str) {
    $uri = URI.new($uri) if $uri.isa(Str);
    $.url = $uri.grammar.parse_result.orig;
    $.header.field(Host => $uri.host);
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
    method uri(URI $uri)

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
