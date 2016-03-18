use v6;

use HTTP::UserAgent;
BEGIN {
    try require IO::Socket::SSL;
    if ::('IO::Socket::SSL') ~~ Failure {
        print("1..0 # Skip: IO::Socket::SSL not available\n");
        exit 0;
    }
}

use Test;

plan 2;

throws-like 'use HTTP::UserAgent; my $ssl = HTTP::UserAgent.new(:throw-exceptions); $ssl.get("https://httpbin.org/status/403")', X::HTTP::Response, message => "Response error: '403 Forbidden'";

my $url = 'https://github.com/';

my $ssl = HTTP::UserAgent.new;
my $get = ~$ssl.get($url);

my $search-html = "</html>\n\n\r\n";
is $get.substr($get.chars - $search-html.chars), $search-html, 'get 1/1';
# it should definitely have more/better tests
