use v6;

use HTTP::UserAgent;

sub MAIN(Str $start_url) {
    my $c = HTTP::UserAgent.new(:useragent<chrome_linux>);

    my $content = $c.get($start_url).content;

    my @urls = get-urls($content);

    while my $url = @urls.shift {
        print "trying: $url ... ";
        try {
            my $r = $c.get(~$url);
            CATCH {
                when X::HTTP {
                    say '[ALMOST OK - X::HTTP exception]';
                }

                say '[NOT OK]';
            }
            default {
                say '[OK]';

                $content = $r.content;
                if $content ~~ Str {
                    #say ~$r.headers;
                    #say $content;
                    @urls.push: get-urls($content);
                }
            }
        }
    }
}

sub get-urls($content) {
    $content.match(/ \s 'href="' (<-["]>+) '"' /, :g).map({ $_[0] }).grep({ $_ ~~ m:i/^http/ });
}
