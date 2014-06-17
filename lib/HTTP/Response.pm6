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
    my $headers = HTTP::Headers.new(|%headers);
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
