use HTTP::UserAgent;

my $ua = HTTP::UserAgent.new;
$ua.timeout = 1;

my $response = $ua.get('https://github.com');

if $response.is-success {
    say $response.content;
} else {
    die $response.status-line;
}

$response = $ua.get('http://filip.sergot.pl/404here');
