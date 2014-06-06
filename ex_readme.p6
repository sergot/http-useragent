use HTTP::UserAgent;

my $ua = HTTP::UserAgent.new;
$ua.timeout = 1;

my $response = $ua.get('http://filip.sergot.pl/');

if $response.is_success {
    say $response.content;
} else {
    die $response.status_line;
}

$response = $ua.get('http://filip.sergot.pl/404here');
