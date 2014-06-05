use Test;
use HTTP::UserAgent :simple;

ok get('filip.sergot.pl') ~~ /filip.sergot.pl/, 'get 1/1';
