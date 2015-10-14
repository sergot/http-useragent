use v6;
use Test;
use HTTP::MediaType;

is-deeply(
    HTTP::MediaType.parse('text/html; charset=ISO-8859-1'),
    HTTP::MediaType.new(
        type       => 'text/html',
        parameters => [
            charset => 'ISO-8859-1',
        ],
    )
);
is-deeply(
    HTTP::MediaType.parse('text/html'),
    HTTP::MediaType.new(
        type       => 'text/html',
        parameters => [],
    )
);
is HTTP::MediaType.new(
    type       => 'text/html',
    parameters => [],
).Str, "text/html";
is HTTP::MediaType.new(
    type       => 'text/html',
    parameters => [charset => 'iso-8859-1'],
).Str, "text/html; charset=iso-8859-1";

subtest {
    my $mt = HTTP::MediaType.new(
        type       => 'multipart/form-data',
    );
    $mt.param('boundary', 'XxYyZ');
    is $mt.Str, 'multipart/form-data; boundary=XxYyZ';
}, 'update param';

done-testing;

