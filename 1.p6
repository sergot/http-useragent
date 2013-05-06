use LWP::UserAgent;

my $lwp = LWP::UserAgent.new;
my $response = $lwp.get("http");
say $response.is_success;
