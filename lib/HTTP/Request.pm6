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

    my $headers = HTTP::Header.new(|%headers);
    my $file;

    if $url {
        $headers.header(Host => _get_host($url));
        $file = _get_file($url);
    }


    self.bless(:$method, :$url, :$headers, :$file);
}

method methods($method) { $.method = $method.uc }

method uri($url) {
    $.url = $url;
    
    my $host = _get_host($.url);
    $.headers.header(Host => $host);
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
