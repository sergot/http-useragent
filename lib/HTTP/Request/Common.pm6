unit class HTTP::Request::Common;

use URI;
use URI::Escape;
use HTTP::Request;

# TODO: multipart/form-data
multi sub POST(URI $uri, %form, *%headers) is export {
    POST($uri, content => %form, |%headers);
}

multi sub POST(Str $uri, %form, *%headers) is export {
    POST(URI.new($uri), content => %form, |%headers)
}

multi sub POST(URI $uri, Array :$content, *%headers) is export {
    my $request  = HTTP::Request.new(POST => $uri);
    $request.header.field(|%headers);

    my $ct = 'application/x-www-form-urlencoded';
    my @parts;
    for @$content {
        @parts.push: uri-escape(.key) ~ "=" ~ uri-escape(.value);
    }
    $request.content = @parts.join("&").encode;
    $request.header.field(content-type => $ct);
    $request.header.field(content-length => $request.content.bytes.Str);

    return $request;
}

multi sub POST(URI $uri, Hash :$content, *%headers) is export {
    POST($uri, content => $content.Array, |%headers);
}

multi sub POST(Str $uri, :$content, *%headers) is export {
    POST(URI.new($uri), :$content, |%headers)
}

multi sub GET(URI $uri, *%headers) is export {
    my $request  = HTTP::Request.new(GET => $uri);
    $request.header.field(|%headers);
    return $request;
}

multi sub GET(Str $uri, *%headers) is export {
    GET(URI.new($uri), |%headers)
}

multi sub HEAD(URI $uri, *%headers) is export {
    my $request  = HTTP::Request.new(HEAD => $uri);
    $request.header.field(|%headers);
    return $request;
}

multi sub HEAD(Str $uri, *%headers) is export {
    HEAD(URI.new($uri), |%headers)
}

multi sub DELETE(URI $uri, *%headers) is export {
    my $request  = HTTP::Request.new(DELETE => $uri);
    $request.header.field(|%headers);
    return $request;
}

multi sub DELETE(Str $uri, *%headers) is export {
    DELETE(URI.new($uri), |%headers)
}

multi sub PUT(URI $uri, :$content, *%headers) is export {
    my $request  = HTTP::Request.new(PUT => $uri);
    $request.header.field(|%headers);
    $request.add-content: $content;
    return $request;
}

multi sub PUT(Str $uri, :$content, *%headers) is export {
    PUT(URI.new($uri), :$content, |%headers)
}

=begin pod

=head1 NAME

HTTP::Request::Common - Construct common HTTP::Request objects

=head1 SYNOPSIS

    use HTTP::Request::Common;

    my $ua = HTTP::UserAgent.new();
    my $res = $ua.request(GET 'http://google.com/');

=head1 DESCRIPTION

This module provide functions that return newly created "HTTP::Request"
objects. These functions are usually more convenient to use than the
standard "HTTP::Request" constructor for the most common requests. The
following functions are provided:

=head2 C<GET $url, Header => Value...>

The GET() function returns an C<HTTP::Request> object initialized with
the "GET" method and the specified URL.

=head2 C<HEAD $url>

=head2 C<HEAD $url, Header => Value,...>

Like GET() but the method in the request is "HEAD".

=item DELETE $url

=item DELETE $url, Header => Value,...

Like GET() but the method in the request is "DELETE".

=head2 C<PUT $url>

=head2 C<PUT $url, Header => Value,...>

=head2 C<PUT $url, Header => Value,..., content => $content>

Like GET() but the method in the request is "PUT".

=head2 C<POST $url>

=head2 C<POST $url, Header => Value,...>

=head2 C<POST $url, %form, Header => Value,...>

=head2 C<POST $url, Header => Value,..., content => $form_ref>

=head2 C<POST $url, Header => Value,..., content => $content>


=end pod
