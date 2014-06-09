class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;

use HTTP::UserAgent::Common;

class X::HTTP is Exception {
    has $.rc;
}

class X::HTTP::Response is X::HTTP {
    method message {
        "Response error: '$.rc'";
    }
}

class X::HTTP::Server is X::HTTP {
    method message {
        "Server error: '$.rc'";
    }
}

has Int $.timeout is rw = 180;
has $.useragent;

method get(Str $url is copy) {
    $url = _clear-url($url);

    my $response;

    for 1..* -> $i {
        # a loop of redirections
        last if $i > 5;

        my $request = HTTP::Request.new(GET => $url);
        my $conn = IO::Socket::INET.new(:host($request.header('Host')), :port(80), :timeout($.timeout));

        my $s = $conn.lines.join("\n")
            if $conn.send($request.Str ~ "\r\n");
        $conn.close;

        $response = HTTP::Response.new.parse($s);
        last unless $response.status-line.substr(0, 1) eq '3' && $response.header('Location').defined;
        $url = $response.header('Location');
    }

    X::HTTP::Response.new(:rc($response.status-line)).throw
        if $response.status-line.substr(0, 1) eq '4';

    X::HTTP::Server.new(:rc($response.status-line)).throw
        if $response.status-line.substr(0, 1) eq '5';

    return $response;
}

# :simple
sub get(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new;
    my $response = $ua.get($url);

    return $response.decoded-content;
}

sub head(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new;
    return $ua.get($url).headers.headers<Content-Type Document-Length Modified-Time Expires Server>;
}

sub getprint(Str $url) is export(:simple) {
    my $response = get($url);
    say $response;
    # TODO: return response code
}

sub getstore(Str $url, Str $file) is export(:simple) {
    $file.IO.spurt: get($url);
}

sub _clear-url(Str $url is copy) {
    $url = "http://$url" if $url.substr(0, 4) ne 'http';
    $url;
}
