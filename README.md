# HTTP::UserAgent [![Build Status](https://travis-ci.org/sergot/http-useragent.svg?branch=master)](https://travis-ci.org/sergot/http-useragent)

Web user agent class for Perl 6.



## Usage

```Perl6
use HTTP::UserAgent;

my $ua = HTTP::UserAgent.new;
$ua.timeout = 10;

my $response = $ua.get("URL");

if $response.is-success {
    say $response.content;
} else {
    die $response.status-line;
}
```

## Installation

To install it using Panda (a module management tool bundled with Rakudo Star):

```
$ panda update
$ panda install HTTP::UserAgent
```

## Testing

To run tests:

```
$ prove -e "perl6 -Ilib"
```

## Documentation

Please see the documentation links listed below:

- [HTTP::Cookies](https://github.com/sergot/http-useragent/blob/master/lib/HTTP/Cookies.pm6#L112)
    - [HTTP::Cookie](https://github.com/sergot/http-useragent/blob/master/lib/HTTP/Cookie.pm6#L17)
- [HTTP::Header](https://github.com/sergot/http-useragent/blob/master/lib/HTTP/Header.pm6#L109)
    - [HTTP::Header::Field](https://github.com/sergot/http-useragent/blob/master/lib/HTTP/Header/Field.pm6#L12)
- [HTTP::Message](https://github.com/sergot/http-useragent/blob/master/lib/HTTP/Message.pm6#L97)
- [HTTP::Request](https://github.com/sergot/http-useragent/blob/master/lib/HTTP/Request.pm6#L79)
- [HTTP::Response](https://github.com/sergot/http-useragent/blob/master/lib/HTTP/Response.pm6#L35)
- [HTTP::UserAgent](https://github.com/sergot/http-useragent/blob/master/lib/HTTP/UserAgent.pm6#L424)
    - [HTTP::UserAgent::Common](https://github.com/sergot/http-useragent/blob/master/lib/HTTP/UserAgent/Common.pm6#L20)


## To-do List and Future Ideas

~~strikethrough text~~ means **done**.

- clean up
- speed up

### HTTP::UserAgent
- ~~HTTP Auth~~
- let user set his own cookie jar
- ~~make getprint() return the code response~~
- ~~security fix - use File::Temp to create temporary cookie jar~~
- use Promises
- ~~make SSL dependency as optional~~

### HTTP::Cookies
- path restriction

### OpenSSL
- ~~fix NativeCall's int bug~~
- make it work on more platforms

### IO::Socket::SSL
- make it work on more platforms
- make SSL support more reliable
- add throwing exception on failing SSL
- more tests
