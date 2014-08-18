HTTP::UserAgent
=============

Basics of Web user agent class for Perl 6.



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



INFO
=====================

See specific files.
