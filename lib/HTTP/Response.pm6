grammar HTTP::Response;

token TOP {
    .*?<status>.*?<CRLF>.*
}

token CRLF {
    \r\n
}

token status {
    \d\d\d
}
