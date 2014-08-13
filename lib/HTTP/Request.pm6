use HTTP::Message;

class HTTP::Request is HTTP::Message;

has $.method is rw;
has $.url is rw;
has $.file is rw;

my $CRLF = "\r\n";

method new(*%args) {
    my ($method, $url, %headers);
    
    for %args.kv -> $key, $value {
        if $key.lc ~~ any(<get post head put>) {
            $method = $key.uc;
            $url = %args{$key};
        } else {
            %headers{$key} = $value;
        }
    }

    my $header = HTTP::Header.new(|%headers);
    my $file;

    if $url {
        $header.field(Host => _get_host($url));
        $file = _get_file($url);
    }


    self.bless(:$method, :$url, :$header, :$file);
}

method methods($method) { $.method = $method.uc }

method uri($url) {
    $.url = $url;
    
    my $host = _get_host($.url);
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

sub _get_host($url is copy) {
    $url ~~ s:i/http[s?]\:\/\///;
    $url ~~ s/\/.*//;
    $url;
}

sub _get_file($url is copy) {
    $url ~~ s:i/http[s?]\:\/\/.*?\//\//;
    $url;
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

=head2 method methods

    method methods(Str $method)

Sets a method of the request.

=head2 method uri

    method uri(Str $url)

Sets URL to request.

=head2 method Str

    method Str returns Str;

Returns stringified object.

=head2 method parse

    method parse(Str $raw_request) returns HTTP::Request

Parses raw HTTP request.

=head1 SEE ALSO

L<HTTP::Message>, L<HTTP::Response>

=end pod
