use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

BEGIN {
    if ( $] < 5.028 ) {
        plan skip_all => 'State array initialization not available to test under pre-5.28 Perl';
        exit;
    }
}

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'INT';

sub GOOD_VALUES {
    -1e99,    -0.9e99, -10, -1,  0,   1, 7, 99,
      -10.0,  -1.0,    0.0, 1.0, 7.0, 99.0,
      q{-10}, q{0},    q{1},
      0.9e99, 1e99,
      Class::WithOverload->new(),;
}

sub BAD_VALUES {
    100000000000.1, -10.1, -1.1, 0.1, 1.1, 7.1, 99.9,
      q{}, q{string},
      v1, v1.2, v1.2.3,
      undef, [], {}, *STDIN, qr{}, \1, sub { },
      Class::Base->new(),
      Class::NoOverload->new(),;
}

use Data::Checks;

# Test assignment to arrays...

state @state_array : of(INT);

# Variables have to be initialized with something that passes the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { state @var = $good_value } "state array = $good_value_str";
}

# Implicit empty list passes the INT check (every element – all zero of them – is an integer)...
OKAY { state @uninitialized : of(INT) } 'uninitialized state array';

# Other explicit initializer values also don't pass the INT check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_INIT { state @var : of(INT) = $bad_value } "state array = $bad_value_str";
}

# List assignments must likewise pass the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { @state_array = $good_value } "state array = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
    for my $good_value ( (GOOD_VALUES)[ 1, 4, 9 ] ) {
        my $bad_value_str = Data::Checks::Parser::pp($bad_value);
        FAIL_ON_ASSIGN { @state_array = $bad_value } "state array = $bad_value_str";
    }
}

# Element assignments must pass the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { $state_array[0] = $good_value } "state array[0] = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_ASSIGN { $state_array[0] = $bad_value } "state array[0] = $bad_value_str";
}

# Element assignments that introduce undef-gaps can never pass the INT check, even for good values...
@state_array = ( 0 .. 2 );
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    FAIL_ON_ASSIGN { $state_array[13] = $good_value } "state array[13] = $good_value_str";
}

done_testing();
