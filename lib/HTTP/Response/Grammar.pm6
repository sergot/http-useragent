grammar HTTP::Response::Grammar;

token TOP {
    HTTP\/<http_version>\s+<status>\s+.*?<CRLF>.*
}

token status {
    \d\d\d
}

token http_version {
    \d\.\d
}

token CRLF {
    \r\n
}
