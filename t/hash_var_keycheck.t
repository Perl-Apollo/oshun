use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'STR[/^[a-z]\d+$/] => REF';

sub GOOD_VALUES {
    [], {}, \*STDIN, qr{}, \1, sub { },
      Class::WithOverload->new(),
      Class::Base->new(),
      Class::NoOverload->new(),;
}

sub BAD_VALUES {
    100000000000.1, -10.1,   -1.1, 0.1, 1.1, 7.1, 99.9,
      -1e99,        -0.9e99, -10,  -1,  0,   1,   7, 99,
      -10.0,        -1.0,    0.0,  1.0, 7.0, 99.0,
      q{-10},       q{0},    q{1},
      0.9e99,       1e99,
      q{},          q{string},
      v1, v1.2, v1.2.3,
      undef,;
}

use Data::Checks;

# Test assignment to hashs...

my %my_hash : of(STR[/^[a-z]\d+$/] => REF);
our %our_hash : of(STR[/^[a-z]\d+$/] => REF);

# Variables have to be initialized with something that passes the STR[/^[a-z]\d+$/] => REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { my %var : of(STR[/^[a-z]\d+$/] => REF) = ( g006431 => $good_value ) } "   my hash = g006431 => $good_value_str";
    OKAY { our %var : of(STR[/^[a-z]\d+$/] => REF) = ( g006431 => $good_value ) } "  our hash = g006431 => $good_value_str";
}

# Implicit empty list passes the STR[/^[a-z]\d+$/] => REF check (every element – all zero of them – is an integer)...
OKAY { my %uninitialized : of(STR[/^[a-z]\d+$/] => REF) } 'uninitialized my hash';
OKAY { our %uninitialized : of(STR[/^[a-z]\d+$/] => REF) } 'uninitialized our hash';

# Other explicit initializer values also don't pass the STR[/^[a-z]\d+$/] => REF check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_INIT { my %var : of(STR[/^[a-z]\d+$/] => REF) = ( badkey => $bad_value ) } "   my hash = badkey => $bad_value_str";
    FAIL_ON_INIT { our %var : of(STR[/^[a-z]\d+$/] => REF) = ( badkey => $bad_value ) } "  our hash = badkey => $bad_value_str";
}

# List assignments must likewise pass the STR[/^[a-z]\d+$/] => REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { %my_hash  = ( g006431 => $good_value ) } "my hash = $good_value_str";
    OKAY { %my_hash  = ( g006431 => $good_value, g006431 => $good_value ) } "my hash = $good_value_str x 2";
    OKAY { %our_hash = ( g006431 => $good_value ) } "our hash = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
    for my $good_value ( (GOOD_VALUES)[ 1, 4, 9 ] ) {
        my $bad_value_str  = Data::Checks::Parser::pp($bad_value);
        my $good_value_str = Data::Checks::Parser::pp($good_value);
        FAIL_ON_ASSIGN { %my_hash  = ( badkey  => $bad_value ) } "   my hash = badkey=>$bad_value_str";
        FAIL_ON_ASSIGN { %my_hash  = ( badkey  => $good_value ) } "   my hash = goodkey=>$good_value_str";
        FAIL_ON_ASSIGN { %my_hash  = ( g006431 => $good_value, badkey => $good_value ) } "   my hash = (gk=>good, badkey=>$good_value_str)";
        FAIL_ON_ASSIGN { %our_hash = ( badkey  => $good_value ) } "  our hash = goodkey=>$good_value_str";
        FAIL_ON_ASSIGN { %our_hash = ( g006431 => $good_value, badkey => $good_value ) } "   our hash = (gk=>good, badkey=>$good_value_str)";
        FAIL_ON_ASSIGN { %our_hash = ( badkey  => $bad_value ) } "  our hash = badkey=>$bad_value_str";
    }
}

# Element assignments must pass the STR[/^[a-z]\d+$/] => REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { $my_hash{k1}  = $good_value } "   my hash{k1} = $good_value_str";
    OKAY { $our_hash{k2} = $good_value } "  our hash{k2} = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_ASSIGN { $my_hash{k1}   = $bad_value } "   my hash{key} = $bad_value_str";
    FAIL_ON_ASSIGN { $our_hash{k1}  = $bad_value } "  our hash{key} = $bad_value_str";
    FAIL_ON_ASSIGN { $my_hash{key}  = $bad_value } "   my hash{key} = $bad_value_str";
    FAIL_ON_ASSIGN { $our_hash{key} = $bad_value } "  our hash{key} = $bad_value_str";
}

# Other modifications that can succeed or fail...
%my_hash = %our_hash = ();
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { @my_hash{ 'g1', 'g2' } = ( $good_value, $good_value ) } "\@my_hash{g1,g2) = $good_value_str";
    FAIL_ON_ASSIGN { @my_hash{ 'bad1', 'bad2' } = ( $good_value, $good_value ) } "\@my_hash{bad1,bad2) = $good_value_str";
}
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_ASSIGN { @my_hash{ 'b1', 'b2' } = ( $bad_value, $bad_value ) } "\@my_hash{bv1,bv2) = $bad_value_str";
}

# Test subroutines: parameters, internal variables, return values...

sub old_sub : returns(REF) { my %x : of(STR[/^[a-z]\d+$/] => REF) = @_; return $x{'g006'} }
sub new_sub : returns(REF) ( %param : of(STR[/^[a-z]\d+$/] => REF) ) { return $param{'g006'} }
my sub my_sub : returns(REF) ( %param : of(STR[/^[a-z]\d+$/] => REF) ) { return $param{'g006'} }
state sub state_sub : returns(REF) ( %param : of(STR[/^[a-z]\d+$/] => REF) ) { return $param{'g006'} }

# With values that should pass the STR[/^[a-z]\d+$/] => REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # List context return okay if list length = 1...
    OKAY { () = old_sub( g006 => $good_value ) } "  old_sub( $good_value_str )";
    OKAY { () = new_sub( g006 => $good_value ) } "  new_sub( $good_value_str )";
    OKAY { () = my_sub( g006 => $good_value ) } "   my_sub( $good_value_str )";
    OKAY { () = state_sub( g006 => $good_value ) } "state_sub( $good_value_str )";

    # Can't pass invalid keys as arguments...
    FAIL_ON_UNPACK { scalar old_sub( badkey => $good_value ) } "  old_sub( $good_value_str )";
    FAIL_ON_PARAM { scalar new_sub( badkey => $good_value ) } "  new_sub( $good_value_str )";
    FAIL_ON_PARAM { scalar my_sub( badkey => $good_value ) } "   my_sub( $good_value_str )";
    FAIL_ON_PARAM { scalar state_sub( badkey => $good_value ) } "state_sub( $good_value_str )";
}

# With values that SHOULDN'T pass the STR[/^[a-z]\d+$/] => REF check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);

    # Can't pass invalid values as arguments...
    FAIL_ON_UNPACK { scalar old_sub( g006 => $bad_value ) } "  old_sub( $bad_value_str )";
    FAIL_ON_PARAM { scalar new_sub( g006 => $bad_value ) } "  new_sub( $bad_value_str )";
    FAIL_ON_PARAM { scalar my_sub( g006 => $bad_value ) } "   my_sub( $bad_value_str )";
    FAIL_ON_PARAM { scalar state_sub( g006 => $bad_value ) } "state_sub( $bad_value_str )";
}

done_testing();

