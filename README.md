LWP::UserAgent
=============

Basics of Web user agent class for Perl 6.



SYNOPSIS
========

`
use LWP::UserAgent;

my $ua = LWP::UserAgent.new;
$ua.timeout(10);

my $response = $ua.get("URL");

if $response.is_success {
    print $response.content;
} else {
    die $response.status_line;
}

`



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
    creates a LWP::UserAgent object

* clone()
    returns a copy of LWP::UserAgent object


Settings attributes
-------------------

* parse\_head(Bool)
    should we initialize response headers from the <head> ?

* protocols\_allowed(@)
    The default is undefined.
    @ is an list of protocols which the request methods will allow.

    protocols_allowed() to delete the list.

* max\_redirect(Int)
    Sets how many redirections will be allowed in a given request cycle.

* timeout(Int)
    After *timeout* seconds of no activity on the connection the request will be aborted.


Request methods
---------------

TODO
