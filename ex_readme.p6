use LWP::UserAgent;

my $ua = LWP::UserAgent.new;
$ua.timeout = 10;

my $response = $ua.get("http://google.pl/");

if $response.is_success {
    say $response.content;
} else {
    die $response.status_line;
}
