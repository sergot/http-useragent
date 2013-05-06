grammar HTTP::Response::Grammar;

token TOP {
    <status_line>.*?<content>
}

token status_line {
    HTTP\/<http_version>\s+<status>\s+.*?<CRLF>
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

token content {
    Content\-Type\:\s+<content_type><content_encoding><content_text>
}

token content_type {
    .*?\;
}

token content_text {
    .*
}

token content_encoding {
    .*?<CRLF>
}
