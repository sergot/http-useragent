unit class HTTP::Request::Common;

use URI;
use URI::Escape;
use HTTP::Request;
use HTTP::MediaType;
use MIME::Base64;
use HTTP::Header;

constant $CRLF = "\x0d\x0a";
constant $HRC_DEBUG = %*ENV<HRC_DEBUG>.Bool;

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

    my $ct = do {
        my $f = $request.header.field('content-type');
        if $f {
            $f.values[0];
        } else {
            'application/x-www-form-urlencoded';
        }
    };

    given $ct {
        when 'application/x-www-form-urlencoded' {
            my @parts;
            for @$content {
                @parts.push: uri-escape(.key) ~ "=" ~ uri-escape(.value);
            }
            $request.content = @parts.join("&").encode;
            $request.header.field(content-length => $request.content.bytes.Str);
        }
        when m:i,^ "multipart/form-data" \s* ( ";" | $ ), {
            say 'generating form-data' if $HRC_DEBUG;

            my $mt = HTTP::MediaType.parse($ct);
            my Str $boundary = $mt.param('boundary') // make-boundary(10);
            (my $generated-content, $boundary) = form-data($content, $boundary, $request);
            $mt.param('boundary', $boundary);
            $ct = $mt.Str;
            my $encoded-content = $generated-content;
            $request.content = $encoded-content;
            $request.header.field(content-length => $encoded-content.encode('ascii').bytes.Str);
        }
    }
    $request.header.field(content-type => $ct);

    return $request;
}

my sub form-data(Array $content, Str $boundary, HTTP::Request $request) {
    my @parts;
    for @$content {
        my ($k, $v) = $_.key, $_.value;
        given $v {
            when Str {
                $k ~~ s:g/(<[\\ \"]>)/\\$1/;  # escape quotes and backslashes
                @parts.push: qq!Content-Disposition: form-data; name="$k"$CRLF$CRLF$v!;
            }
            when Array {
                my ($file, $usename, @headers) = @$v;
                unless defined $usename {
                    $usename = $file;
                    $usename ~~ s!.* "/"!! if defined($usename);
                }
                $k ~~ s:g/(<[\\ \"]>)/\\$1/;
                my $disp = qq!form-data; name="$k"!;
                if (defined($usename) and $usename.elems > 0) {
                    $usename ~~ s:g/(<[\\ \"]>)/\\$1/;
                    $disp ~= qq!; filename="$usename"!;
                }
                my $content;
                my $headers = HTTP::Header.new(|@headers);
                if ($file) {
                    # TODO: dynamic file upload support
                    $content = $file.IO.slurp;
                    unless $headers.field('content-type') {
                        # TODO: LWP::MediaTypes
                        $headers.field(content-type => 'application/octet-stream');
                    }
                }
                if $headers.field('content-disposition') {
                    $disp = $headers.field('content-disposition');
                    $headers.remove-field('content-disposition');
                }
                if $headers.field('content') {
                    $content = $headers.field('content');
                    $headers.remove-field('content');
                }
                my $head = ["Content-Disposition: $disp",
                            $headers.Str($CRLF),
                            ""].join($CRLF);
                given $content {
                    when Str {
                        @parts.push: $head ~ $content;
                    }
                    default {
                        die "NYI"
                    }
                }
            }
            default {
                die "unsupported type: {$v.WHAT.gist}({$content.perl})";
            }
        }
    }

    say $content if $HRC_DEBUG;
    say @parts if $HRC_DEBUG;
    return "", "none" unless @parts;

    my $contents;
    # TODO: dynamic upload support
    my $bno = 10;
    CHECK_BOUNDARY: {
        for @parts {
            if $_.index($boundary).defined {
                # must have a better boundary
                $boundary = make-boundary(++$bno);
                redo CHECK_BOUNDARY;
            }
        }
    }
    my $generated-content = "--$boundary$CRLF"
                ~ @parts.join("$CRLF--$boundary$CRLF")
                ~ "$CRLF--$boundary--$CRLF";

    return $generated-content, $boundary;
}

my sub make-boundary(int $size=10) {
    my $str = (1..$size*3).map({(^256).pick.chr}).join('');
    my $b = MIME::Base64.new.encode_base64($str, :oneline);
    $b ~~ s:g/\W/X/;  # ensure alnum only
    $b;
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

multi sub PATCH(URI $uri, :$content, *%headers) is export {
    my $request  = HTTP::Request.new(PATCH => $uri);
    $request.header.field(|%headers);
    $request.add-content: $content;
    return $request;
}

multi sub PATCH(Str $uri, :$content, *%headers) is export {
    PATCH(URI.new($uri), :$content, |%headers)
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
