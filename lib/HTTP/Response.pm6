class HTTP::Response;
use HTTP::Response::Grammar;

has $!res;

method is_success() {
    return True if $!res<status_line><status> ~~ "200";
    return False;
}

method status_line() {
    return $!res<status_line>.Str;
}

method content() {
    return $!res<content><content_text>.Str;
}

method parse(Str $raw_response) {
    $!res = HTTP::Response::Grammar.new.parse($raw_response);
    return self;
}
