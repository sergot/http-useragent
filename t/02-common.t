use v6;
use Test;

use HTTP::UserAgent::Common;

my $chrome_linux = 'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/34.0.1847.132 Safari/537.36';

is get_ua('chrome_linux'), $chrome_linux, 'get_ua 1/2';
is get_ua('im not exist'), 'im not exist', 'get_ua 2/2';
