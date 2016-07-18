use v6;
use HTTP::UserAgent;
use HTTP::UserAgent::Common;
use Test;

plan 10;

# new
my $ua = HTTP::UserAgent.new;
nok $ua.useragent, 'new 1/3';

$ua = HTTP::UserAgent.new(:useragent('test'));
is $ua.useragent, 'test', 'new 2/3';

my $newua = get-ua('chrome_linux');
$ua = HTTP::UserAgent.new(:useragent('chrome_linux'));
is $ua.useragent, $newua, 'new 3/3';

unless %*ENV<NETWORK_TESTING> {
  diag "NETWORK_TESTING was not set";
  skip-rest("NETWORK_TESTING was not set");
  exit;
}

# user agent
like $ua.get('http://httpbin.org/user-agent').content, /$newua/, 'useragent 1/1';

# get
my $response = $ua.get('filip.sergot.pl/');
ok $response, 'get 1/3';
isa-ok $response, HTTP::Response, 'get 2/3';
ok $response.is-success, 'get 3/3';

# non-ascii encodings (github issue #35)
lives-ok { HTTP::UserAgent.new.get('http://www.baidu.com') }, 'Lived through gb2312 encoding';

# chunked encoding.

lives-ok { HTTP::UserAgent.new.get('http://rakudo.org') }, "issue#51 - get rakudo.org (chunked encoding foul-up results in incomplete UTF-8 data)";

subtest {
    my Bool $have-json = True;
    CATCH {
        when X::CompUnit::UnsatisfiedDependency {
            $have-json = False;
        }
    }
    require JSON::Fast <&from-json>;
    
    my $uri = 'http://httpbin.org/post';
    my %data = (foo => 'bar', baz => 'quux');
    subtest {
        my $ua = HTTP::UserAgent.new;
        my $res;
        lives-ok { $res = $ua.post(URI.new($uri), %data, X-Foo => "foodle") }, "make post";
        my $ret-data;

        if $have-json {
            lives-ok { $ret-data = from-json($res.decoded-content) }, "get JSON body";

            is $ret-data<headers><X-Foo>, 'foodle', "has got our header";
            is $ret-data<headers><Content-Type>, "application/x-www-form-urlencoded", "and got the content type we expected";
            is-deeply $ret-data<form>, %data, "and we sent the right params";
        }
        else {
            skip("no json parser", 4);
        }
    }, "with URI object";
    subtest {
        my $ua = HTTP::UserAgent.new;
        my $res;
        lives-ok { $res = $ua.post($uri, %data, X-Foo => "foodle") }, "make post";
        my $ret-data;
        if $have-json {
            lives-ok { $ret-data = from-json($res.decoded-content) }, "get JSON body";

            is $ret-data<headers><X-Foo>, 'foodle', "has got our header";
            is $ret-data<headers><Content-Type>, "application/x-www-form-urlencoded", "and got the content type we expected";
            is-deeply $ret-data<form>, %data, "and we sent the right params";
        }
        else {
            skip("no json parser", 4);

        }
    }, "with URI string";
}, "post";
# vim: expandtab shiftwidth=4 ft=perl6
