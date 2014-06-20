use Test;
use HTTP::UserAgent :simple;
use Test::IO::Capture;

plan 4;

my $url = 'http://filip.sergot.pl';

my $get = get $url;

is $get.substr($get.chars - 7), '</html>', 'get 1/1';
prints-stdout-ok { getprint $url }, $get, 'getprint 1/1';
getstore $url, 'newfile';
is slurp('newfile'), $get, 'getstore 1/1';
unlink 'newfile';

throws_like "use HTTP::UserAgent :simple; get('filip.sergot.pl/404here')", X::HTTP::Response, message => "Response error: '404 Not Found'";
