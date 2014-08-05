use v6;

class HTTP::Header::Field;

has $.name;
has @.values;

method Str {
    @.values.join(', ');
}

=begin pod

=head1 NAME

HTTP::Header::Field

=head1 SYNOPSIS

    use HTTP::Header::Field;
    my $header = HTTP::Header::Field.new(:name<Date>, values => (123, 456));

=head1 DESCRIPTION

This module provides a class encapsulating HTTP Message header field.

=head1 METHODS

=head2 method new

    multi method new(*%params) returns HTTP::Header::Field

=head2 method Str

    method Str(HTTP::Header::Field:) returns Str

=head1 SEE ALSO

L<HTTP::Header>

=head1 AUTHOR

Filip Sergot (sergot)

=end pod
