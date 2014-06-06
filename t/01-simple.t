use Test;
use HTTP::UserAgent :simple;

ok get('http://filip.sergot.pl') ~~ /filip.sergot.pl/, 'get 1/1';

throws_like "use HTTP::UserAgent :simple; get('filip.sergot.pl')", X::HTTP::Response, message => "Response error: '400 Bad Request'";
