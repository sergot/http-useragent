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


- clean up
- speed up

##HTTP::UserAgent
- make SSL dependency as optional
- HTTP Auth
- let user set his own cookie jar

##HTTP::Cookies
- ~~security fix - use File::Temp to create temporary cookie jar~~
- path restriction

##OpenSSL
- fix NativeCall's int bug
- make it work on more platforms

##IO::Socket::SSL
- make it work on more platforms
- make SSL support more reliable
- add throwing exception on failing SSL
