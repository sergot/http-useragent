use HTTP::Message;
use URI;
use URI::Escape;
use HTTP::MediaType;
use MIME::Base64;

unit class HTTP::Request is HTTP::Message;

subset RequestMethod of Str where any(<GET POST HEAD PUT DELETE PATCH>);

has RequestMethod $.method is rw;
has $.url is rw;
has $.file is rw;
has $.uri is rw;

has Str $.host is rw;
has Int $.port is rw;
has Str $.scheme is rw;

my $CRLF = "\r\n";

constant $HRC_DEBUG = %*ENV<HRC_DEBUG>.Bool;

multi method new(*%args) {

    if %args.keys.elems >= 1 {
        my ($method, $url, $file, %fields, $uri);
        for %args.kv -> $key, $value {
            if $key.lc ~~ any(<get post head put delete patch>) {
                $uri = $value.isa(URI) ?? $value !! URI.new($value);
                $method = $key.uc;
            } else {
                %fields{$key} = $value;
            }
        }

        my $header = HTTP::Header.new(|%fields);
    
        $method //= 'GET';

        self.new($method, $uri, $header);
    }
    else {
        self.bless;
    }
}

multi method new(*@a where *.elems == 0 ) {
    self.bless;
}

multi method new(RequestMethod $method, URI $uri, HTTP::Header $header) {
    my $url = $uri.grammar.parse_result.orig;
    my $file = $uri.path_query || '/';

    if not $header.field('Host').defined {
        $header.field(Host => get-host-value($uri));
    }

    self.bless(:$method, :$url, :$header, :$file, :$uri);
}



sub get-host-value(URI $uri --> Str) {
    my Str $host = $uri.host;

    if $host {
        if ( $uri.port != $uri.default_port ) {
            $host ~= ':' ~ $uri.port;
        }
    }
    $host;
}

method set-method($method) { $.method = $method.uc }

multi method uri($uri is copy where URI|Str) {
    $!uri = $uri.isa(Str) ?? URI.new($uri) !! $uri ;
    $!url = $!uri.grammar.parse_result.orig;
    $!file = $!uri.path_query || '/';
    self.field(Host => get-host-value($!uri));
    $!uri;
}

multi method uri() is rw {
    $!uri;
}

multi method host() returns Str is rw {
    if not $!host.defined {
         $!host = ~self.field('Host').values;
    }
    $!host;
}

multi method port() returns Int is rw {
    if not $!port.defined {
        # if there isn't a scheme the no default port
        if try self.uri.scheme {
            $!port = self.uri.port;
        }
    }
    $!port;
}

multi method scheme() returns Str is rw {
    if not $!scheme.defined {
        $!scheme = self.uri.scheme;

        CATCH {
            default {
                $!scheme = 'http';
            }
        }
    }
    $!scheme
}

method add-cookies($cookies) {
    if $cookies.cookies.elems {
        $cookies.add-cookie-header(self);
    }
}

multi method add-form-data(:$multipart, *%data) {
    self.add-form-data(%data.Array, :$multipart);
}

multi method add-form-data(%data, :$multipart) {
    self.add-form-data(%data.Array, :$multipart);
}

multi method add-form-data(Array $data, :$multipart) {
    my $ct = do {
        my $f = self.header.field('content-type');
        if $f {
            $f.values[0];
        } else {
            if $multipart {
                'multipart/form-data';
            }
            else {
                'application/x-www-form-urlencoded';
            }
        }
    };

    given $ct {
        when 'application/x-www-form-urlencoded' {
            my @parts;
            for @$data {
                @parts.push: uri-escape(.key) ~ "=" ~ uri-escape(.value);
            }
            self.content = @parts.join("&").encode;
            self.header.field(content-length => self.content.bytes.Str);
        }
        when m:i,^ "multipart/form-data" \s* ( ";" | $ ), {
            say 'generating form-data' if $HRC_DEBUG;

            my $mt = HTTP::MediaType.parse($ct);
            my Str $boundary = $mt.param('boundary') // self.make-boundary(10);
            (my $generated-content, $boundary) = self.form-data($data, $boundary);
            $mt.param('boundary', $boundary);
            $ct = $mt.Str;
            my Str $encoded-content = $generated-content;
            self.content = $encoded-content;
            self.header.field(content-length => $encoded-content.encode('ascii').bytes.Str);
        }
    }
    self.header.field(content-type => $ct);
}


method form-data(Array $content, Str $boundary) {
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
                $boundary = self.make-boundary(++$bno);
                redo CHECK_BOUNDARY;
            }
        }
    }
    my $generated-content = "--$boundary$CRLF"
                ~ @parts.join("$CRLF--$boundary$CRLF")
                ~ "$CRLF--$boundary--$CRLF";

    return $generated-content, $boundary;
}


method make-boundary(int $size=10) {
    my $str = (1..$size*3).map({(^256).pick.chr}).join('');
    my $b = MIME::Base64.new.encode_base64($str, :oneline);
    $b ~~ s:g/\W/X/;  # ensure alnum only
    $b;
}


method Str (:$debug) {
    my $s = "$.method $.file $.protocol";
    $s ~= $CRLF ~ callwith($CRLF, :debug($debug));
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

    self.uri = URI.new($.url) ;

    nextsame;

    self;
}

=begin pod

=head1 NAME

HTTP::Request - class encapsulating HTTP request message

=head1 SYNOPSIS

    use HTTP::Request;
    my $request = HTTP::Request.new(GET => 'http://www.example.com/');

=head1 DESCRIPTION

Module provides functionality to easily manage HTTP requests.

=head1 METHODS

=head2 method new

    multi method new(*%args)
    multi method new(Str $method, URI $uri, HTTP::Header $header);

A constructor, the first form takes parameters like:

=item method => URL, where method can be POST, GET ... etc.
=item field => values, header fields

    my $req = HTTP::Request.new(:GET<example.com>, :h1<v1>);

The second form takes the key arguments as simple positional parameters and
is designed for use in places where for example the request method may be
calculated and the headers pre-populated.

=head2 method set-method

    method set-method(Str $method)

Sets a method of the request.

    my $req = HTTP::Request.new;
    $req.set-method: 'POST';

=head2 method uri

    method uri(Str $url)
    method uri(URI $uri)

Sets URL to request.

    my $req = HTTP::Request.new;
    $req.uri: 'example.com';

=head2 method add-cookies

    method add-cookies(HTTP::Cookies $cookies)

This will cause the appropriate cookie headers to be added from the
supplied HTTP::Cookies object.

=head2 method add-form-data

        multi method add-form-data(%data, :$multipart)
        multi method add-form-data(:$multipart, *%data);
        multi method add-form-data(Array $data, :$multipart)

Adds the form data, supplied either as a Hash, an Array of Pair,
or in a named parameter style, to the POST request (it doesn't
make sense on most other request types.) The default is to use
'application/x-www-form-urlencoded' and 'multipart/form-data' can be used
by providing the ':multipart' adverb.  Alternatively a previously applied
"content-type" header of either 'application/x-www-form-urlencoded'
or 'multipart/form-data' will be respected and in the latter case any
applied boundary marker will be retained.

As a special case for multipart data if the value for some key in the data
is an Array of at least one item then it is taken to be a description of a
file to be "uploaded" where the first item is the path to the file to be
inserted, the second (optional) an alternative name to be used in the
content disposition header and the third an optional Array of Pair that
will provide addtional header lines for the part.

    
=head2 method Str

    method Str returns Str;

Returns stringified object.

=head2 method parse

    method parse(Str $raw_request) returns HTTP::Request

Parses raw HTTP request.
See L<HTTP::Message>

For more documentation, see L<HTTP::Message>.

=head1 SEE ALSO

L<HTTP::Message>, L<HTTP::Response>

=end pod
