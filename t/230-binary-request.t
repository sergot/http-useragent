#!perl6

use v6;

use Test;
use HTTP::UserAgent;
use HTTP::Request::Common;

use URI;
my $u = URI.new;

sub server(Promise $done-promise) returns Promise {
    my $server-promise = start {
        sub _index_buf(Blob $input, Blob $sub) {
            my $end-pos = 0;
            while $end-pos < $input.bytes {
                if $sub eq $input.subbuf($end-pos, $sub.bytes) {
                    return $end-pos;
                }
                $end-pos++;
            }
            return -1;
        }
        react {
            whenever $done-promise {
                die $_;
                done;
            }
            whenever IO::Socket::Async.listen('localhost',3333) -> $conn {
                my Buf $in-buf = Buf.new;
                whenever $conn.Supply(:bin) -> $buf { 
                    if $in-buf.elems == 0 {
                        my $header-end = _index_buf($buf, Buf.new(13,10));
                        $in-buf ~= $buf.subbuf($header-end + 2);
                    }
                    else {
                        $in-buf ~= $buf;
                    }


                    if (my $header-end = _index_buf($in-buf, Buf.new(13,10,13,10))) > 0 {
                        my $header = $in-buf.subbuf(0, $header-end).decode('ascii');

                        if $header ~~ /Content\-Length\:\s+$<length>=[\d+]/ {
                            my $length = $<length>.Int; 
                            if $in-buf.subbuf($header-end + 4) == $length {
                                await $conn.write: "HTTP/1.0 200 OK\r\n".encode ~ $in-buf ;
                                $conn.close;
                            }
                        }
                    }
                } 
            }
        }
    }

    sleep 2;

    $server-promise;
}


my sub get-rand-buff() {
    Buf.new((0 .. 0xFF).pick((10 .. 75).pick));
}

my $p = Promise.new;
my $s  = server($p);

subtest {
    my $ua = HTTP::UserAgent.new;
    my $buf = get-rand-buff();
    my $req;
    lives-ok { $req = POST('http://localhost:3333', content => $buf);  }, "create POST with Buf";
    ok $req.content ~~ Blob, "content is a blob";
    is $req.content.elems, $buf.elems, "content is right length";
    is ~$req.header.field('Content-Length'), $buf.elems, "right 'Content-Length'";
    is ~$req.header.field('Content-Type'), 'application/octet-stream', "right (default) Content-Type";
    ok $req.binary, "and binary is good";
    my $res;
    lives-ok { $res = $ua.request($req) }, "make request";
    is $res.content-type, 'application/octet-stream', "got the right ct back";
    ok $res.is-binary, "got binary response";
    is $res.content.elems, $buf.elems, "and we got back what we sent";
    ok $res.content eqv $buf, "and buffer looks the same";

}, "POST (with defaults)";
subtest {
    my $ua = HTTP::UserAgent.new;
    my $buf = get-rand-buff();
    my $req;
    lives-ok { $req = POST('http://localhost:3333', content => $buf, Content-Type => 'image/x-something', Content-Length => 158); }, "create POST with Buf (supplying Content-Type and Content-Length";
    ok $req.content ~~ Blob, "content is a blob";
    is $req.content.elems, $buf.elems, "content is right length";
    is ~$req.header.field('Content-Length'), $buf.elems, "right 'Content-Length'";
    is ~$req.header.field('Content-Type'), 'image/x-something', "right explicit Content-Type";
    ok $req.binary, "and binary is good";
    my $res;
    lives-ok { $res = $ua.request($req) }, "make request";
    is $res.content-type, 'image/x-something', "got the right ct back";
    ok $res.is-binary, "got binary response";
    is $res.content.elems, $buf.elems, "and we got back what we sent";
    ok $res.content eqv $buf, "and buffer looks the same";

}, "POST (with explicit Content-Type)";

subtest {
    my $ua = HTTP::UserAgent.new;
    # need the "\n" because our server is so crap
    my $buf = "Hello, World!\r\n".encode;
    my $req;
    lives-ok { $req = POST('http://localhost:3333', content => $buf, Content-Type => 'text/plain', Content-Length => 158); }, "create POST with Buf (supplying Content-Type and Content-Length";
    ok $req.content ~~ Blob, "content is a blob";
    is $req.content.elems, $buf.elems, "content is right length";
    is ~$req.header.field('Content-Length'), $buf.elems, "right 'Content-Length'";
    is ~$req.header.field('Content-Type'), 'text/plain', "right explicit Content-Type";
    ok $req.binary, "and binary is good";
    my $res;
    lives-ok { $res = $ua.request($req) }, "make request";
    is $res.content-type, 'text/plain', "got the right ct back";
    nok $res.is-binary, "inferred text response";
    ok  $res.is-text, "and it's text";
    is $res.content.encode.elems, $buf.elems, "and we got back what we sent";
    is $res.content , "Hello, World!\r\n", "and content looks the same";

}, "POST (with something that will be text coming back)";

subtest {
    my $ua = HTTP::UserAgent.new;
    my $buf = get-rand-buff();
    my $req;
    lives-ok { $req = PUT('http://localhost:3333', content => $buf); }, "create PUT with Buf";
    ok $req.content ~~ Blob, "content is a blob";
    is $req.content.elems, $buf.elems, "content is right length";
    is ~$req.header.field('Content-Length'), $buf.elems, "right 'Content-Length'";
    is ~$req.header.field('Content-Type'), 'application/octet-stream', "right (default) Content-Type";
    ok $req.binary, "and binary is good";
    my $res;
    lives-ok { $res = $ua.request($req) }, "make request";
    is $res.content-type, 'application/octet-stream', "got the right ct back";
    ok $res.is-binary, "got binary response";
    is $res.content.elems, $buf.elems, "and we got back what we sent";
    ok $res.content eqv $buf, "and buffer looks the same";

}, "PUT (with defaults)";
subtest {
    my $ua = HTTP::UserAgent.new;
    my $buf = get-rand-buff();
    my $req;
    lives-ok { $req = PUT('http://localhost:3333', content => $buf, Content-Type => 'image/x-something', Content-Length => 158); }, "create PUT with Buf (supplying Content-Type and Content-Length";
    ok $req.content ~~ Blob, "content is a blob";
    is $req.content.elems, $buf.elems, "content is right length";
    is ~$req.header.field('Content-Length'), $buf.elems, "right 'Content-Length'";
    is ~$req.header.field('Content-Type'), 'image/x-something', "right explicit Content-Type";
    ok $req.binary, "and binary is good";
    my $res;
    lives-ok { $res = $ua.request($req) }, "make request";
    is $res.content-type, 'image/x-something', "got the right ct back";
    ok $res.is-binary, "got binary response";
    is $res.content.elems, $buf.elems, "and we got back what we sent";
    ok $res.content eqv $buf, "and buffer looks the same";

}, "PUT (with explicit Content-Type)";
subtest {
    my $ua = HTTP::UserAgent.new;
    # need the "\n" because our server is so crap
    my $buf = "Hello, World!\n".encode;
    my $req;
    lives-ok { $req = PUT('http://localhost:3333', content => $buf, Content-Type => 'text/plain', Content-Length => 158); }, "create PUT with Buf (supplying Content-Type and Content-Length";
    ok $req.content ~~ Blob, "content is a blob";
    is $req.content.elems, $buf.elems, "content is right length";
    is ~$req.header.field('Content-Length'), $buf.elems, "right 'Content-Length'";
    is ~$req.header.field('Content-Type'), 'text/plain', "right explicit Content-Type";
    ok $req.binary, "and binary is good";
    my $res;
    lives-ok { $res = $ua.request($req) }, "make request";
    is $res.content-type, 'text/plain', "got the right ct back";
    nok $res.is-binary, "inferred text response";
    ok  $res.is-text, "and it's text";
    is $res.content.encode.elems, $buf.elems, "and we got back what we sent";
    is $res.content , "Hello, World!\n", "and content looks the same";

}, "PUT (with something that will be text coming back)";

$p.keep("shutdown");
#try await $s;

done-testing;
# vim: expandtab shiftwidth=4 ft=perl6
