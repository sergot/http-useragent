unit class HTTP::Header;

use HTTP::Header::Field;

# headers container
has @.fields;

our grammar HTTP::Header::Grammar {
    token TOP {
        [ <message-header> \r?\n ]*
    }

    token message-header {
        $<field-name>=[ <-[:]>+ ] ':' <field-value>
    }

    token field-value {
        [ <!before \h>  $<field-content>=[ <-[\r\n]>+ ]  || \h+ ]* 
    }
    token quot {
        <['"]>
    }
}

our class HTTP::Header::Actions {
    method message-header($/) {
        my $k = ~$<field-name>;
        if $k && $<field-value>.made -> $v {
            if $*OBJ.field($k) {
                $*OBJ.push-field: |($k => $v);
            } else {
                $*OBJ.field: |($k => $v);
            }
        }
    }
    method field-value($/) {
        make $<field-content>
            ?? $<field-content>.Str.split(',')>>.trim !! Nil
    }
}

# we want to pass arguments like this: .new(a => 1, b => 2 ...)
method new(*%fields) {
    my @fields;

    for %fields.kv -> $k, $v {
        @fields.push: HTTP::Header::Field.new(:name($k), :values($v.list));
    }

    self.bless(:@fields);
}

# set fields
multi method field(*%fields) {
    for %fields.kv -> $k, $v {
        my $f = HTTP::Header::Field.new(:name($k), :values($v.list));
        if @.fields.first({ .name.lc eq $k.lc }) {
            @.fields[@.fields.first({ .name.lc eq $k.lc }, :k)] = $f;
        } else {
            @.fields.push: $f;
        }
    }
}

# get fields
multi method field($field) {
    return @.fields.first({ .name.lc eq $field.lc });
}

# initialize fields
method init-field(*%fields) {
    for %fields.kv -> $k, $v {
        if not @.fields.grep({ .name.lc eq $k.lc }) {
            @.fields.push: HTTP::Header::Field.new(:name($k), :values($v.list));
        }
    }
}

# add value to existing fields
method push-field(*%fields) {
    for %fields.kv -> $k, $v {
        @.fields.first({ .name.lc eq $k.lc }).values.append: $v.list;
    }
}

# remove a field
method remove-field(Str $field) {
    my $index = @.fields.first({ .name.lc eq $field.lc }, :k);
    @.fields.splice($index, 1);
}

# get fields names
method header-field-names() {
    @.fields>>.name;
}

# return the headers as name -> value hash
method hash() returns Hash {
    % = @.fields.map({ $_.name => $_.values });
}

# remove all fields
method clear() {
    @.fields = ();
}

# get header as string
method Str($eol = "\n") {
    @.fields.flatmap({ "{$_.name}: {self.field($_.name)}$eol" }).join;
}

method parse($raw) {
    my $*OBJ = self;
    HTTP::Header::Grammar.parse($raw, :actions(HTTP::Header::Actions));
}

=begin pod

=head1 NAME

HTTP::Header - class encapsulating HTTP message header

=head1 SYNOPSIS

    use HTTP::Header;
    my $h = HTTP::Header.new;
    $h.field(Accept => 'text/plain');
    say $h.field('Accept');
    $h.remove-field('Accept');

=head1 DESCRIPTION

This module provides a class with a set of methods making us able to easily handle HTTP message header.

=head1 METHODS

=head2 method new

    method new(*%fields) returns HTTP::Header

A constructor. Takes name => value pairs as arguments.

    my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);

=head2 method header

    multi method field(HTTP::Header:, Str $s) returns HTTP::Header::Field
    multi method field(HTTP::Header:, *%fields)

Gets/sets header field.

    my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);
    say $head.header('h1');

    my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);
    $head.header(:h3<v3>);

=head2 method init-field

    method init-field(HTTP::Header:, *%fields)

Initializes a header field: adds a field only if it does not exist yet.

    my $head = HTTP::Header.new;
    $head.header(:h1<v1>);
    $head.init-header(:h1<v2>, :h2<v2>); # it doesn't change the value of 'h1'
    say ~$head;

=head2 method push-header

    method push-field(HTTP::Header:, HTTP::Header::Field $field)

Pushes a new field. Does not check if exists.

    my $head = HTTP::Header.new;
    $head.push-header( HTTP::Header::Field.new(:name<n1>, :value<v1>) );
    say ~$head;

=head2 method remove-header

    method remove-field(HTTP::Header:, Str $field)

Removes a field of name $field.

    my $head = HTTP::Header.new;
    $head.header(:h1<v1>);
    $head.remove-header('h1');

=head2 method header-field-names

    method header-field-names(HTTP::Header:) returns Parcel

Returns a list of names of all fields.

    my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);
    my @names = $head.header-field-names;
    say @names; # h1, h2

=head2 method clear

    method clear(HTTP::Header:)

Removes all fields.

    my $head = HTTP::Header.new(:h1<v1>, :h2<v2>);
    $head.clear;

=head2 method Str

    method Str(HTTP::Header:, Str $eol = "\n")

Returns readable form of the whole header section.

=head2 method parse

    method parse(HTTP::Header:, Str $raw)

Parses the whole header section.

    my $head = HTTP::Header.new.parse("h1: v1\r\nh2: v2\r\n");
    say $head.perl;

=head1 SEE ALSO

L<HTTP::Header::Field>, L<HTTP::Message>

=end pod
