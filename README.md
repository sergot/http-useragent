HTTP::UserAgent
=============

Basics of Web user agent class for Perl 6.



SYNOPSIS
========

    use HTTP::UserAgent;

    my $ua = HTTP::UserAgent.new;
    $ua.timeout = 10;

    my $response = $ua.get("URL");

    if $response.is_success {
        say $response.content;
    } else {
        die $response.status_line;
    }



TODO
====

* built-in list of user agents, what will allow us to write only: e.g.

    my $lwp = HTTP::UserAgent.new(:useragent\<chrome_linux\>);



INFO (in progress...)
=====================

Constructors
------------

* new(
    parse_head,
    protocols_allowed, \# for now only HTTP
    max_redirect,
    timeout
)
    creates a HTTP::UserAgent object

* clone()
    returns a copy of HTTP::UserAgent object



Request methods
---------------

* get($url)
    GET request.
