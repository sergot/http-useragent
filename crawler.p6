use v6;

use HTTP::UserAgent;

my $start_url = 'http://filip.sergot.pl/';
my $c = HTTP::UserAgent.new(:useragent<chrome_linux>);

my $content = $c.get($start_url).content;

my @urls = get-urls($content);

for @urls -> $url {
    print "trying: $url ... ";
    try {
        $c.get(~$url);
        CATCH {
            say '[NOT OK]';
        }
        default {
            say '[OK]';
        }
    }
}

sub get-urls($content) {
    $content.match(/ \s 'href="' (<-["]>+) '"' /, :g).map({ $_[0] }).grep({ $_ ~~ m:i/^http/ });
}
