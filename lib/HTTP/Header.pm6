class HTTP::Header;

use HTTP::Header::Field;

# headers container
has @.headers;

our grammar HTTP::Header::Grammar {
    token TOP {
        [ <message-header> "\r\n" ]*
    }

    token message-header {
        $<field-name>=[ <-[:]>+ ] ':' <field-value>
    }

    token field-value {
        [ <!before \h> $<field-content>=[ <-[\r\n]>+ ] | \h+ ]*
    }
}

our class HTTP::Header::Actions {
    method message-header($/) {
        my $k = ~$<field-name>;
        if $k && $<field-value>.made -> $v {
            if $*OBJ.header($k) {
                $*OBJ.push-header: |($k => $v);
            } else {
                $*OBJ.header: |($k => $v);
            }
        }
    }
    method field-value($/) {
        make $<field-content>
            ?? $<field-content>.Str.split(',')>>.trim !! Nil
    }
}

# we want to pass arguments like this: .new(a => 1, b => 2 ...)
method new(*%headers) {
    my @headers;

    for %headers.kv -> $k, $v {
        @headers.push: HTTP::Header::Field.new(:name($k), :values($v.list));
    }

    self.bless(:@headers);
}

# set headers
multi method header(*%headers) {
    for %headers.kv -> $k, $v {
        my $h = HTTP::Header::Field.new(:name($k), :values($v.list));
        if @.headers.first({ .name eq $k }) {
            @.headers[@.headers.first-index({ .name eq $k })] = $h;
        } else {
            @.headers.push: $h;
        }
    }
}

# get headers
multi method header($header) {
    return @.headers.first({ .name eq $header });
}

# initialize headers
method init-header(*%headers) {
    for %headers.kv -> $k, $v {
        if not @.headers.grep({ .name eq $k }) {
            @.headers.push: HTTP::Header::Field.new(:name($k), :values($v.list));
        }
    }
}

# add value to existing headers
method push-header(*%headers) {
    for %headers.kv -> $k, $v {
        @.headers.first({ .name eq $k }).values.push: $v.list;
    }
}

# remove a headers
method remove-header(Str $header) {
    my $index = @.headers.first-index({ .name eq $header });
    @.headers.splice($index, 1);
}

# get headers names
method header-field-names() {
    @.headers>>.name;
}

# remove all headers
method clear() {
    @.headers = ();
}

# get headers as string
method Str($eol = "\n") {
    @.headers.map({ "{$_.name}: {self.header($_.name)}$eol" }).join;
}

method parse($raw) {
    my $*OBJ = self;
    HTTP::Header::Grammar.parse($raw, :actions(HTTP::Header::Actions));
}
