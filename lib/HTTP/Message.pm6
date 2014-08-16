class HTTP::Message;

use HTTP::Header;
use Encode;

has $.header;
has $.content is rw;

has $.protocol is rw = 'HTTP/1.1';

my $CRLF = "\r\n";

method new($content?, *%fields) {
    my $header = HTTP::Header.new(|%fields);

    self.bless(:$header, :$content);
}

method add-content($content) {
    $.content ~= $content;
}

method decoded-content {
    return $!content if $!content ~~ Str;
    my $decoded_content;
    my $content-type  = $!header.field('Content-Type').values[0] // '';
    my $charset = $content-type ~~ / charset '=' $<charset>=[ \S+ ] /
                ?? $<charset>.Str.lc
                !! 'ascii';
    $decoded_content = Encode::decode($charset, $!content);

    $decoded_content;
}

multi method field(Str $f) {
    $.header.field($f);
}

multi method field(*%fields) {
    $.header.field(|%fields);
}

method push-field(*%fields) {
    $.header.push-field(|%fields);
}

method remove-field(Str $field) {
    $.header.remove-field($field);
}

method clear {
    $.header.clear;
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
                if $.header.field($k) {
                    $.header.push-field: |($k => $v.split(',')>>.trim);
                } else {
                    $.header.field: |($k => $v.split(',')>>.trim);
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
    my $s = $.header.Str($eol);
    $s ~= $eol ~ $.content ~ $eol if $.content;

    return $s;
}

=begin pod

=head1 NAME

HTTP::Message - class encapsulating HTTP message

=head1 SYNOPSIS

    use HTTP::Message;
    my $raw_msg = "GET / HTTP/1.1\r\nHost: somehost\r\n\r\n";
    my $mess = HTTP::Message.new.parse($raw_msg);
    say $mess;

=head1 DESCRIPTION

This module provides a bunch of methods to easily manage HTTP message.

=head1 METHODS

=head2 method new

    method new($content?, *%fields)

A constructor, takes following parameters:

=item content : content of the message (optional)
=item fields : fields of the header section

=head2 method add-content

    method add-content(HTTP::Message:, Str $content)

Adds HTTP message content.

=head2 method decoded-content

    method decoded-content(HTTP::Message:)

Returns decoded content of the message (using L<Encode> module to decode).

=head2 method field

    multi method field(HTTP::Message:, Str $s) returns HTTP::Header::Field
    multi method field(HTTP::Message:, *%fields)

See L<HTTP::Header>.

=head2 method init-field

    method init-field(HTTP::Message:, *%fields)

See L<HTTP::Header>.

=head2 method push-field

    method push-field(HTTP::Message:, HTTP::Header::Field $field)

See L<HTTP::Header>.

=head2 method remove-field

    method remove-field(HTTP::Message:, Str $field)

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
