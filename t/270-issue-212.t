use v6;
use Test;
use HTTP::UserAgent;

plan 1;

unless %*ENV<NETWORK_TESTING> {
  diag "NETWORK_TESTING was not set";
  skip-rest("NETWORK_TESTING was not set");
  exit;
}

my $ua = HTTP::UserAgent.new(:debug);
lives-ok { $ua.get("http://httpbin.org/image/png") };
