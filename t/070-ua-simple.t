use Test;
use HTTP::UserAgent :simple;
use Test::IO::Capture;

plan 5;

my $url = 'http://filip.sergot.pl/';

my $get = get $url;

is $get.substr($get.chars - 9), "</html>\n\n", 'get 1/1';
my $code;
prints-stdout-ok { $code = getprint $url }, $get, 'getprint 1/2';
is $code, 200, 'getprint 2/2';
getstore $url, 'newfile';
is slurp('newfile'), $get, 'getstore 1/1';
unlink 'newfile';

throws-like "use HTTP::UserAgent :simple; get('http://filip.sergot.pl/404here')", X::HTTP::Response, message => "Response error: '404 Not Found'";
