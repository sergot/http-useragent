class HTTP::Response;
use HTTP::Response::Grammar;

has $!res;

method is_success() {
    return True if $!res<status> ~~ "200";
    return False;
}

method parse(Str $raw_response) {
    $!res = HTTP::Response::Grammar.new.parse($raw_response);
    return self;
}
