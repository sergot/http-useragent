class HTTP::Message;

use HTTP::Header;
use Encode;

has $.headers;
has $.content is rw;

has $.protocol is rw = 'HTTP/1.1';

my $CRLF = "\r\n";

method new($content?, *%headers) {
    my $headers = HTTP::Header.new(|%headers);

    self.bless(:$headers, :$content);
}

method add-content($content) {
    $.content ~= $content;
}

method decoded-content {
    return $!content if $!content ~~ Str;
    my $decoded_content;
    my $content-type  = $!headers.header('Content-Type').values[0] // '';
    my $charset = $content-type ~~ / charset '=' $<charset>=[ \S+ ] /
                ?? $<charset>.Str.lc
                !! 'ascii';
    $decoded_content = Encode::decode($charset, $!content);

    $decoded_content;
}

multi method header(Str $h) {
    $.headers.header($h);
}

multi method header(*%headers) {
    $.headers.header(|%headers);
}

multi method push-header(*%headers) {
    $.headers.push-header(|%headers);
}

method remove-header(Str $header) {
    $.headers.remove-header($header);
}

method clear {
    $.headers.clear;
    $.content = '';
}

method parse($raw_message) {
    my @lines = $raw_message.split(/$CRLF/);

    my ($first, $second, $third);
    ($first, $second, $third) = @lines.shift.split(/\s+/);

    if $third.index('/') { # is a request
        $.protocol = $third;
    } else {               # is a response
        $.protocol = $first;
    }

    loop {
        last until @lines;

        my $line = @lines.shift;
        if $line {
            my ($k, $v) = $line.split(/\:\s*/, 2);
            if $k and $v {
                if $.headers.header($k) {
                    $.headers.push-header: |($k => $v.split(',')>>.trim);
                } else {
                    $.headers.header: |($k => $v.split(',')>>.trim);
                }
            }
        } else {
            $.content = @lines.grep({ $_ }).join("\n");
            last;
        }
    }

    self;
}

method Str($eol = "\n") {
    my $s = $.headers.Str($eol);
    $s ~= $eol ~ $.content ~ $eol if $.content;

    return $s;
}

=begin pod

=head1 NAME

HTTP::Message - class encapsulating HTTP message

=head1 SYNOPSIS

    use HTTP::Message;
    my $raw_msg = 'GET / HTTP/1.1\r\nHost: somehost\r\n\r\n';
    my $mess = HTTP::Message.new.parse($raw_msg);
    say $mess;

=head1 DESCRIPTION

This module provides a bunch of methods to easily manage HTTP message.

=head1 METHODS

=head2 method new

    method new($content?, *%headers)

A constructor, takes following parameters:

=item content : content of the message (optional)
=item headers : fields of the header section

=head2 method add-content

    method add-content(HTTP::Message:, Str $content)

Adds HTTP message content.

=head2 method decoded-content

    method decoded-content(HTTP::Message:)

Returns decoded content of the message (using L<Encode> module to decode).

=head2 method header

    multi method header(HTTP::Message:, HTTP::Header:, Str $s) returns HTTP::Header::Field
    multi method header(HTTP::Message:, HTTP::Header:, *%fields)

See L<HTTP::Header>.

=head2 method init-header

    method init-header(HTTP::Message:, HTTP::Header:, *%fields)

See L<HTTP::Header>.

=head2 method push-header

    method push-header(HTTP::Message:, HTTP::Header:, HTTP::Header::Field $field)

See L<HTTP::Header>.

=head2 method remove-header

    method remove-header(HTTP::Message:, HTTP::Header:, Str $field)

See L<HTTP::Header>.

=head2 method clear

    method clear(HTTP::Message:)

Removes the whole message.

=head2 method parse

    method parse(HTTP::Message:, Str $raw_message) returns HTTP::Message

Parses the whole HTTP message.

=head2 method Str

    method Str(HTTP::Message:, Str $eol = "\n") returns Str

Returns HTTP message in a readable form.

=head1 SEE ALSO

L<HTTP::Request>, L<HTTP::Response>, L<Encode>

=end pod
