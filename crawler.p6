use v6;

use HTTP::UserAgent;

sub MAIN(Str $start_url) {
    my $c = HTTP::UserAgent.new(:useragent<chrome_linux>);

    my $content = $c.get($start_url).content;

    my @urls = get-urls($content);

    while my $url = @urls.shift {
        print "trying: $url ... ";
        try {
            $content = $c.get(~$url).content;
            CATCH {
                say '[NOT OK]';
            }
            default {
                say '[OK]';
                @urls.push: get-urls($content) if $content ~~ Str;
            }
        }
    }
}

sub get-urls($content) {
    $content.match(/ \s 'href="' (<-["]>+) '"' /, :g).map({ $_[0] }).grep({ $_ ~~ m:i/^http/ });
}
