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
