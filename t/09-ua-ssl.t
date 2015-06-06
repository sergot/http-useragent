use v6;

use HTTP::UserAgent;
BEGIN {
    if ::('IO::Socket::SSL') ~~ Failure {
        print("1..0 # Skip: IO::Socket::SSL not available\n");
        exit 0;
    }
}

use Test;

plan 2;

throws-like 'use HTTP::UserAgent; my $ssl = HTTP::UserAgent.new; $ssl.get("https://filip.sergot.pl/")', X::HTTP::Response, message => "Response error: '403 Forbidden'";

my $url = 'https://github.com/';

my $ssl = HTTP::UserAgent.new;
my $get = ~$ssl.get($url);

is $get.substr($get.chars - 10), "</html>\n\r\n", 'get 1/1';
# it should definitely have more/better tests
