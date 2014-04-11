use LWP::UserAgent;

my $ua = LWP::UserAgent.new;
$ua.timeout = 1;

my $response = $ua.get('http://filip.sergot.pl/');

if $response.is_success {
    say $response.content;
} else {
    die $response.status_line;
}
