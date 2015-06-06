unit class HTTP::Cookies;

use HTTP::Cookie;
use HTTP::Response;
use HTTP::Request;
use DateTime::Parse;

has @.cookies;
has $.file;
has $.autosave is rw = 0;

my grammar HTTP::Cookies::Grammar {
    token TOP {
        'Set-Cookie:' [\s* <cookie> ','?]*
    }

    token cookie   {
        <name> '=' <value> ';'? \s* [<arg> \s*]* <secure>? ';'? \s* <httponly>? ';'?
    }
    token name     { \w+ }
    token value    { <[\w \s , / : .]>+ }
    token arg      { <name> '=' <value> ';'? }
    token secure   { Secure }
    token httponly { HttpOnly }
}

my class HTTP::Cookies::Actions {
    method cookie($/) {
        my $h = HTTP::Cookie.new;
        $h.name     = ~$<name>;
        $h.value    = ~$<value>;
        $h.secure   = $<secure>.defined ?? ~$<secure> !! False;;
        $h.httponly = $<httponly>.defined ?? ~$<httponly> !! False;

        for $<arg>.list -> $a {
            $h.fields.push: $a<name> => ~$a<value>;
        }

        $*OBJ.push-cookie($h);
    }
}

method extract-cookies(HTTP::Response $response) {
    self.set-cookie($_) for $response.field('Set-Cookie').flatmap({ "Set-Cookie: $_" });
    self.save if $.autosave;
}

method add-cookie-header(HTTP::Request $request) {
    for @.cookies -> $cookie {
        next if $cookie.fields<Domain>.defined
                && $cookie.fields<Domain> ne $request.field('Host');
        # TODO : path restrictions

        if $request.field('Cookie').defined {
            $request.push-field( Cookie => $cookie.Str );
        } else {
            $request.field( Cookie => $cookie.Str );
        }
    }
}

method save {
    my $fh = open $.file, :w;

    # TODO : add versioning
    $fh.say: "#LWP6-Cookies-0.1";
    $fh.say: self.Str;

    $fh.close;
}

method load {
    for $.file.IO.lines -> $l {
        # we don't need #LWP6-Cookies-$VER
        next if $l.substr(0, 1) eq '#';
        self.set-cookie($l.chomp);
    }
}

method clear-expired {
    @.cookies .= grep({
        !.fields<Expires>.defined ||
        # we need more precision
        DateTime::Parse.new( .fields<Expires> ).Date > Date.today
    });
    self.save if $.autosave;
}

method clear {
    @.cookies = ();
    self.save if $.autosave;
}

method set-cookie($str) {
    my $*OBJ = self;
    HTTP::Cookies::Grammar.parse($str, :actions(HTTP::Cookies::Actions));

    self.save if $.autosave;
}

method push-cookie(HTTP::Cookie $c) {
    @.cookies .= grep({ .name ne $c.name });
    @.cookies.push: $c;

    self.save if $.autosave;
}

method Str {
    @.cookies.flatmap({ "Set-Cookie: {$_.Str}" }).join("\n");
}

=begin pod

=head1 NAME

HTTP::Cookies - HTTP cookie jars

=head1 SYNOPSIS

    use HTTP::Cookies;
    my $cookies = HTTP::Cookies.new(
        :file<./cookies>,
        :autosave(1)
    );
    $cookies.load;

=head1 DESCRIPTION

This module provides a bunch of methods to manage HTTP cookies.

=head1 METHODS

=head2 method new

    multi method new(*%params)

A constructor. Takes params like:

=item file     : where to write cookies
=item autosave : save automatically after every operation on cookies or not

    my $cookies = HTTP::Cookies.new(
        autosave => 1,
        :file<./cookies.here>
    );

=head2 method set-cookie

    method set-cookie(HTTP::Cookies:, Str $str)

Adds a cookie (passed as an argument $str of type Str) to the list of cookies.

    my $cookies = HTTP::Cookies.new;
    $cookies.set-cookie('Set-Cookie: name1=value1; HttpOnly');

=head2 method save

    method save(HTTP::Cookies:)

Saves cookies to the file ($.file).

    my $cookies = HTTP::Cookies.new;
    $cookies.set-cookie('Set-Cookie: name1=value1; HttpOnly');
    $cookies.save;

=head2 method load

    method load(HTTP::Cookies:)

Loads cookies from file ($.file).

    my $cookies = HTTP::Cookies.new;
    $cookies.load;

=head2 method extract-cookies

    method extract-cookies(HTTP::Cookies:, HTTP::Response $response)

Gets cookies ('Set-Cookie: ' lines) from the HTTP Response and adds it to the list of cookies.

    my $cookies = HTTP::Cookies.new;
    my $response = HTTP::Response.new(Set-Cookie => "name1=value; Secure");
    $cookies.extract-cookies($response);

=head2 method add-cookie-header

    method add-cookie-header(HTTP::Cookies:, HTTP::Request $request)

Adds cookies fields ('Cookie: ' lines) to the HTTP Request.

    my $cookies = HTTP::Cookies.new;
    my $request = HTTP::Request.new;
    $cookies.load;
    $cookies.add-cookie-header($request);

=head2 method clear-expired

    method clear-expired(HTTP::Cookies:)

Removes expired cookies.

    my $cookies = HTTP::Cookies.new;
    $cookies.set-cookie('Set-Cookie: name1=value1; Secure');
    $cookies.set-cookie('Set-Cookie: name2=value2; Expires=Wed, 09 Jun 2021 10:18:14 GMT');
    $cookies.clear-expired; # contains 'name1' cookie only

=head2 method clear

    method clear(HTTP::Cookies:)

Removes all cookies.

    my $cookies = HTTP::Cookies.new;
    $cookies.load; # contains something
    $cookies.clear; # will be empty after this action

=head2 method push-cookie

    method push-cookie(HTTP::Cookies:, HTTP::Cookie $c)

Pushes cookies (passed as an argument $c of type HTTP::Cookie) to the list of cookies.

    my $c = HTTP::Cookie.new(:name<a>, :value<b>, :httponly);
    my $cookies = HTTP::Cookies.new;
    $cookies.push-cookie: $c;

=head2 method Str

    method Str(HTTP::Cookies:)

Returns all cookies in human (and server) readable form.

=head1 SEE ALSO

L<HTTP::Request>, L<HTTP::Response>, L<HTTP::Cookie>

=end pod
