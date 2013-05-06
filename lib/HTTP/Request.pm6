class HTTP::Request;

has $.method;

my $CRLF = "\r\n";

method request($domain, $file) {
    my $s = $.method.uc ~ " $file HTTP/1.1" ~ $CRLF;
    $s ~= "Host: $domain" ~ $CRLF;

    $s ~= $CRLF;
    return $s;
}
