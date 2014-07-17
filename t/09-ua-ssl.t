use v6;

use HTTP::UserAgent;
use Test;

plan 1;

throws_like 'use HTTP::UserAgent; my $ssl = HTTP::UserAgent.new; $ssl.get("https://filip.sergot.pl")', X::HTTP::Response, message => "Response error: '403 Forbidden'";

# it should definitely have more/better tests
