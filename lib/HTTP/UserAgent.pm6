class HTTP::UserAgent;

use HTTP::Response;
use HTTP::Request;

use HTTP::UserAgent::Common;

class X::HTTP is Exception {
    has $.rc;
}

class X::HTTP::Response is X::HTTP {
    method message {
        "Response error: '$.rc'";
    }
}

class X::HTTP::Server is X::HTTP {
    method message {
        "Server error: '$.rc'";
    }
}

has Int $.timeout is rw = 180;
has $.useragent;

# Helper method which implements the same logic as Str.split() but for Bufs.
multi _split_buf(Str $delimiter, Buf $input, $limit = Inf --> List) {
    _split_buf($delimiter.encode, $input, $limit);
}
multi _split_buf(Blob $delimiter, Buf $input, $limit = Inf --> List) {
    my @result;
    my @a            = $input.list;
    my @b            = $delimiter.list;
    my $old_delim_pos = 0;
    
    while $old_delim_pos >= 0 && +@result + 1 < $limit {
        my $new_delim_pos = @a.first-index({ @a[(state $i = -1) .. $i++ + @b] ~~ @b }) // last;
        last if $new_delim_pos < 0;
        @result.push: $input.subbuf($old_delim_pos, $new_delim_pos);
        $old_delim_pos = $new_delim_pos + $delimiter.bytes;
    }
    if $old_delim_pos < +@a {
        @result.push: $input.subbuf($old_delim_pos);
    }
    @result
}

method get(Str $url is copy) {
    $url = _clear-url($url);

    my $response;

    for 1..5 {
        my $request = HTTP::Request.new(GET => $url);
        my $conn = IO::Socket::INET.new(:host(~$request.header('Host').values), :port(80), :timeout($.timeout));

        if $conn.send($request.Str ~ "\r\n") {
            # We expect that the first chunk contains the entire header, including <CRLF><CRLF>.
            my $first-chunk  = $conn.recv( :bin );
            my @a            = $first-chunk.list;
            my @b            = "\r\n\r\n".ords;

            # Find the header/body separator in the chunk, which means we can parse the header seperately and are
            # able to figure out the correct encoding of the body.
            my $msg-body-pos = @a.first-index({ @a[(state $i = -1) .. $i++ + @b] ~~ @b });

            # +2 because we need a trailing CRLF in the header.
            $msg-body-pos   += 2 if $msg-body-pos >= 0;

            $response                    = HTTP::Response.new;
            my ($response-line, $header) = $first-chunk.decode('ascii').substr(0, $msg-body-pos).split("\r\n", 2);
            $response.code( $response-line.split(' ')[1].Int );
            $response.headers.parse( $header );

            my $content = buf8.new( @a[($msg-body-pos + 2)..*] );

            # We also need to handle 'Transfer-Encoding: chunked', which means that we request more chunks
            # and assemble the response body.
            if $response.headers.header('Transfer-Encoding') eq 'chunked' {
                my sub recv-entire-chunk($content is rw) {
                    if $content {
                        # The first line is our desired chunk size.
                        (my $chunk-size, $content) = _split_buf("\r\n", $content, 2);
                        $chunk-size                = :16($chunk-size.decode);
                        if $chunk-size {
                            # Let the content grow until we have reached the desired size.
                            while $chunk-size > $content.bytes {
                                $content ~= $conn.recv($chunk-size - $content.bytes, :bin);
                            }
                        }
                    }
                    $content
                }

                my $chunk = $content;
                $content  = Buf.new;
                # We carry on as long as we receive something.
                while recv-entire-chunk($chunk) {
                    $content ~= $chunk;
                    # We only request five bytes here, and check if it is the message terminator, which is
                    # "\r\n0\r\n". When we would try to read more bytes we would block for a few seconds.
                    $chunk    = $conn.recv(5, :bin);
                    if !$chunk || $chunk.list eqv [0x0d, 0x0a, 0x30, 0x0d, 0x0a] {
                        # Done with this message!
                        last
                    }
                    else {
                        # Read more of this chunk, which includes the rest of a chunk-size field followed
                        # by <CRLF> and a single byte of the message content.
                        $chunk ~= $conn.recv(6, :bin);
                        $chunk.=subbuf(2)
                    }
                }
            }

            # We have now the content as a Buf and need to decode it depending on some header informations.
            $response.content = $content;
            my $content-type  = $response.headers.header('Content-Type').values[0] // '';
            if $content-type ~~ /^ text / {
                my $charset = $content-type ~~ / charset '=' $<charset>=[ \S+ ] /
                            ?? $<charset>.Str.lc
                            !! 'ascii';
                $response.content.=decode($charset);
            }
        }
        $conn.close;

        last unless $response.status-line.substr(0, 1) eq '3' && $response.header('Location').defined;
        $url = $response.header('Location');
    }

    X::HTTP::Response.new(:rc($response.status-line)).throw
        if $response.status-line.substr(0, 1) eq '4';

    X::HTTP::Server.new(:rc($response.status-line)).throw
        if $response.status-line.substr(0, 1) eq '5';

    return $response;
}

# :simple
sub get(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new;
    my $response = $ua.get($url);

    return $response.decoded-content;
}

sub head(Str $url) is export(:simple) {
    my $ua = HTTP::UserAgent.new;
    return $ua.get($url).headers.headers<Content-Type Document-Length Modified-Time Expires Server>;
}

sub getprint(Str $url) is export(:simple) {
    my $response = get($url);
    print $response;
    # TODO: return response code
}

sub getstore(Str $url, Str $file) is export(:simple) {
    $file.IO.spurt: get($url);
}

sub _clear-url(Str $url is copy) {
    $url = "http://$url" if $url.substr(0, 4) ne 'http';
    $url;
}
