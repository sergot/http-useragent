use HTTP::Request;
use HTTP::Response;

my $url  = 'filip.sergot.pl';
my $file = 'index.html';

my $req = HTTP::Request.new( GET => "http://$url/$file" );

say 'Request:';
say $req.perl;
my $req_as_string = $req.Str;
say $req_as_string.perl;

say '--';

my $conn = IO::Socket::INET.new( host => $url, port => 80, timeout => 1 );

say 'Connection:';
say $conn.perl;

say '--';

my $sent = $conn.send: $req_as_string;
say 'Sent:';
say $sent.perl;

say '--';

my @read = $conn.lines;
say 'Read:';
say @read.perl;

say '--';

my $response = HTTP::Response.new(200).parse(@read.join("\n"));
say 'Response:';
say $response.perl;

say '--';
say 'get():';
say $response.Str;
