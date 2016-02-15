unit class HTTP::Request::Common;

use URI;
use URI::Escape;
use HTTP::Request;
use HTTP::MediaType;
use MIME::Base64;
use HTTP::Header;

constant $CRLF = "\x0d\x0a";
my $HRC_DEBUG = %*ENV<HRC_DEBUG>.Bool;

# TODO: multipart/form-data
multi sub POST(URI $uri, %form, *%headers) is export {
    samewith($uri, content => %form, |%headers);
}

multi sub POST(Str $uri, %form, *%headers) is export {
    samewith(URI.new($uri), content => %form, |%headers)
}

multi sub POST(URI $uri, Array :$content, *%headers) is export {
    my $request  = get-request('POST', $uri, |%headers);
    $request.add-form-data($content);
    return $request;
}

multi sub POST(Str $uri, :$content, *%headers) is export {
    samewith(URI.new($uri), :$content, |%headers)
}

multi sub POST(URI $uri, Hash :$content, *%headers) is export {
    samewith($uri, content => $content.Array, |%headers);
}

multi sub POST(URI $uri, Str :$content, *%headers) is export {
    send-text-content('POST', $uri, :$content, |%headers);
}

my sub get-request(Str $meth, URI $uri, Bool :$bin, *%headers) returns HTTP::Request {
    my $request  = HTTP::Request.new(|($meth.uc => $uri), :$bin);
    $request.header.field(|%headers);
    $request;
}

my sub send-text-content(Str $meth, URI $uri, :$content, *%headers is copy ) returns HTTP::Request {
    my $request = get-request($meth, $uri, |%headers);

    if $content.defined {
        $request.add-content: $content;
    }
    $request;
}


my sub send-binary-content(Str $meth, URI $uri, Blob :$content, *%headers is copy) {
    %headers<Content-Length> = $content.elems;
    if ! ( %headers<Content-Type>:exists or %headers<content-type>:exists ) {
        %headers<Content-Type> = 'application/octet-stream';
    }
    my $request = get-request($meth, $uri, |%headers, :bin);
    $request.content = $content;
    $request;
}

multi sub POST(Str $uri, Blob :$content, *%headers ) is export {
    samewith(URI.new($uri), :$content, |%headers);
}

multi sub POST(URI $uri, Blob :$content, *%headers ) is export {
    send-binary-content('POST', $uri, :$content, |%headers);
}


multi sub GET(URI $uri, *%headers) is export {
    get-request('GET', $uri, |%headers);
}

multi sub GET(Str $uri, *%headers) is export {
    samewith(URI.new($uri), |%headers)
}

multi sub HEAD(URI $uri, *%headers) is export {
    get-request('HEAD', $uri, |%headers);
}

multi sub HEAD(Str $uri, *%headers) is export {
    samewith(URI.new($uri), |%headers)
}

multi sub DELETE(URI $uri, *%headers) is export {
    get-request('DELETE', $uri, |%headers);
}

multi sub DELETE(Str $uri, *%headers) is export {
    samewith(URI.new($uri), |%headers)
}

multi sub PUT(URI $uri, Str :$content, *%headers) is export {
    send-text-content('PUT', $uri, :$content, |%headers);
}

multi sub PUT(Str $uri, Str :$content, *%headers) is export {
    PUT(URI.new($uri), :$content, |%headers)
}

multi sub PUT(Str $uri, Blob :$content, *%headers) is export {
    samewith(URI.new($uri), :$content, |%headers);
}

multi sub PUT(URI $uri, Blob :$content, *%headers ) is export {
    send-binary-content('PUT', $uri, :$content, |%headers);
}

multi sub PATCH(URI $uri, :$content, *%headers) is export {
    send-text-content('PATCH', $uri, :$content, |%headers);
}

multi sub PATCH(Str $uri, :$content, *%headers) is export {
    samewith(URI.new($uri), :$content, |%headers)
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

=head2 C<PATCH $url>

=head2 C<PATCH $url, Header => Value,...>

=head2 C<PATCH $url, Header => Value,..., content => $content>

Like GET() but the method in the request is "PATCH".

=head2 C<POST $url>

=head2 C<POST $url, Header => Value,...>

=head2 C<POST $url, %form, Header => Value,...>

=head2 C<POST $url, Header => Value,..., content => $form_ref>

=head2 C<POST $url, Header => Value,..., content => $content>

=end pod
