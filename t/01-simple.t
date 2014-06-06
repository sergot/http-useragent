use Test;
use HTTP::UserAgent :simple;

ok get('http://filip.sergot.pl') ~~ /filip.sergot.pl/, 'get 1/1';

throws_like "use HTTP::UserAgent :simple; get('filip.sergot.pl/404here')", X::HTTP::Response, message => "Response error: '404 Not Found'";
