class HTTP::Cookies;

use HTTP::Cookie;
use HTTP::Response;
use HTTP::Request;
use DateTime::Parse;

has @.cookies;
has $.file;
has $.autosave is rw = 0;

method extract-cookies(HTTP::Response $response) {
    self.set-cookie($_) for $response.header('Set-Cookie').map({ "Set-Cookie: $_" });
    self.save if $.autosave;
}

method add-cookie-header(HTTP::Request $request) {
    # TODO : domain and path restrictions
    for @.cookies -> $cookie {
        if $request.header('Cookie').defined {
            $request.push-header( Cookie => $cookie.Str );
        } else {
            $request.header( Cookie => $cookie.Str );
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
        @.cookies.push: HTTP::Cookie.new.parse($l.chomp);
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
    given HTTP::Cookie.new.parse($str) -> $new {
        @.cookies .= grep({ .name ne $new.name });
        $.cookies.push: $new;
    }

    self.save if $.autosave;
}

method Str {
    @.cookies.map({ "Set-Cookie: {$_.Str}" }).join("\n");
}
