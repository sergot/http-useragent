use v6;

use HTTP::UserAgent;

use Test;

plan 2;

try require IO::Socket::SSL;
if ::('IO::Socket::SSL') ~~ Failure {
    skip-rest("IO::Socket::SSL not available");
    exit 0;
}

throws-like 'use HTTP::UserAgent; my $ssl = HTTP::UserAgent.new(:throw-exceptions); $ssl.get("https://httpbin.org/status/403")', X::HTTP::Response, message => "Response error: '403 Forbidden'";

my $url = 'https://github.com/';

my $ssl = HTTP::UserAgent.new;
my $get = ~$ssl.get($url);

my $search-html = "</html>\n\n\r\n";
is $get.substr($get.chars - $search-html.chars), $search-html, 'get 1/1';
# it should definitely have more/better tests
