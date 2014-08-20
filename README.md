HTTP::UserAgent
=============

Web user agent class for Perl 6.



SYNOPSIS
========

    use HTTP::UserAgent;

    my $ua = HTTP::UserAgent.new;
    $ua.timeout = 10;

    my $response = $ua.get("URL");

    if $response.is-success {
        say $response.content;
    } else {
        die $response.status-line;
    }



INFO/DOC
=====================

See specific files.



TODO/IDEAS
=============


- make OpenSSL and IO::Socket::SSL work on more platforms
- fix NativeCall's int bug
- clean up
- make SSL support more reliable
- speed up
- make SSL dependency as optional (idea)
- ...
