module HTTP::UserAgent::Exception {
    use HTTP::Message;

    class X::HTTP is Exception {
        has $.rc;
        has HTTP::Message $.response;
    }

    class X::HTTP::Internal is Exception {
        has $.rc;
        has $.reason;

        method message {
            "Internal Error: '$.reason'";
        }
    }

    class X::HTTP::Response is X::HTTP {
        has $.message;
        method message {
            $!message //= "Response error: '$.rc'";
        }
    }

    class X::HTTP::Server is X::HTTP {
        method message {
            "Server error: '$.rc'";
        }
    }

    class X::HTTP::Header is X::HTTP::Server {
    }

    class X::HTTP::ContentLength is X::HTTP::Response {
    }

    class X::HTTP::NoResponse is X::HTTP::Response {
        has $.message = "missing or incomplete response line";
        has $.got;
    }
}

# vim: expandtab shiftwidth=4 ft=perl6
