use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'INT';

sub GOOD_VALUES {
    -1e99, -0.9e99, -10, -1, 0, 1, 7, 99,
    -10.0, -1.0, 0.0, 1.0, 7.0, 99.0,
    q{-10}, q{0}, q{1},
    0.9e99, 1e99,
    Class::WithOverload->new(),
}

sub BAD_VALUES  {
    100000000000.1, -10.1, -1.1, 0.1, 1.1, 7.1, 99.9,
    q{}, q{string},
    v1, v1.2, v1.2.3,
    undef, [], {}, *STDIN, qr{}, \1, sub{},
    Class::Base->new(),
    Class::NoOverload->new(),
}


use Data::Checks;


# Test assignment to arrays...

my    @my_array    :of(0..10 => INT);
our   @our_array   :of(0..10 => INT) = 0..9;

# Variables have to be initialized with something that passes the 0..10=>INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);
    OKAY {  my @var :of(0..10 => INT) = $good_value }   "   my array = $good_value_str";
    OKAY { our @var :of(0..10 => INT) = $good_value }   "  our array = $good_value_str";
}

# Implicit empty list passes the 0..10=>INT check (every element – all zero of them – is an integer)...
OKAY { my @uninitialized :of(INT)    }    'uninitialized my array';
OKAY { our @uninitialized :of(INT)   }    'uninitialized our array';

# Other explicit initializer values also don't pass the INT check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::pp($bad_value);
    FAIL_ON_INIT { my @var :of(INT)    = $bad_value }  "   my array = $bad_value_str";
    FAIL_ON_INIT { our @var :of(INT)   = $bad_value }  "  our array = $bad_value_str";
}

# List assignments must be of the right size...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);
              OKAY { @my_array  = ($good_value) x 10 } " my array = $good_value_str x 10";
              OKAY { @our_array = ($good_value) x 10 } "our array = $good_value_str x 10";
    FAIL_ON_LENGTH { @my_array  = ($good_value) x 11 } " my array = $good_value_str x 11";
    FAIL_ON_LENGTH { @our_array = ($good_value) x 11 } "our array = $good_value_str x 11";
}

for my $bad_value (BAD_VALUES) {
for my $good_value ((GOOD_VALUES)[1,4,9]) {
    my $good_value_str = Data::Checks::pp($good_value);
    my $bad_value_str = Data::Checks::pp($bad_value);
    FAIL_ON_ASSIGN { @my_array  = $bad_value                } " my array = $bad_value_str";
    FAIL_ON_ASSIGN { @my_array  = ($good_value, $bad_value) } " my array = (good, $bad_value_str)";
    FAIL_ON_ASSIGN { @our_array = $bad_value                } "our array = $bad_value_str";
    FAIL_ON_ASSIGN { @our_array = ($good_value, $bad_value) } "our array = (good, $bad_value_str)";
}
}

# Element assignments must pass the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);
    OKAY { $my_array[0]    = $good_value }  "   my array[0] = $good_value_str";
    OKAY { $our_array[0]   = $good_value }  "  our array[0] = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::pp($bad_value);
    FAIL_ON_ASSIGN { $my_array[0]    = $bad_value }  "   my array[0] = $bad_value_str";
    FAIL_ON_ASSIGN { $our_array[0]   = $bad_value }  "  our array[0] = $bad_value_str";
}

# Element assignments that introduce undef-gaps can never pass the INT check, even for good values...
@my_array = (0..6);
@our_array = (0..6);
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);
    FAIL_ON_ASSIGN {  $my_array[9]  = $good_value }  "   my array[9]   = $good_value_str";
    FAIL_ON_ASSIGN { $our_array[9]  = $good_value }  "  our array[9]   = $good_value_str";
    FAIL_ON_LENGTH {  $my_array[10] = $good_value }  "   my array[10]  = $good_value_str";
    FAIL_ON_LENGTH { $our_array[10] = $good_value }  "  our array[10]  = $good_value_str";
}

for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);

    @my_array = (0..6);
    OKAY { splice @my_array, 7, 0, $good_value }  "  splice my array, 7, 0, $good_value_str";
    OKAY { push @my_array, $good_value         }  "    push my array, $good_value_str";
    OKAY { unshift @my_array, $good_value      }  " unshift my array, $good_value_str";
    OKAY { delete $my_array[-1];               }  "  delete my array[-1]";

    @our_array = (0..6);
    OKAY { splice @our_array, 7, 0, $good_value }  "  splice our array, 7, 0, $good_value_str";
    OKAY { push @our_array, $good_value         }  "    push our array, $good_value_str";
    OKAY { unshift @our_array, $good_value      }  " unshift our array, $good_value_str";
    OKAY { delete $our_array[-1];               }  "  delete our array[-1]";
}
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::pp($bad_value);
    FAIL_ON_MODIFY { splice @my_array, 7, 0, $bad_value }  "  splice my array, 7, 0, $bad_value_str";
    FAIL_ON_MODIFY { push @my_array, $bad_value         }  "    push my array, $bad_value_str";
    FAIL_ON_MODIFY { unshift @my_array, $bad_value      }  " unshift my array, $bad_value_str";

    FAIL_ON_MODIFY { splice @our_array, 7, 0, $bad_value }  "  splice our array, 7, 0, $bad_value_str";
    FAIL_ON_MODIFY { push @our_array, $bad_value         }  "    push our array, $bad_value_str";
    FAIL_ON_MODIFY { unshift @our_array, $bad_value      }  " unshift our array, $bad_value_str";

    # Can't delete "internal" elements: the resulting undef fails the INT check...
    FAIL_ON_MODIFY { delete $my_array[2];                }  "  delete my array[2]";
    FAIL_ON_MODIFY { delete $our_array[2];               }  "  delete our array[2]";
}

# Test subroutines: parameters, internal variables, return values...

      sub   old_sub :returns(INT)                           { my @x :of(0..10=>INT) = @_; return $x[0] }
      sub   new_sub :returns(INT)  (@param :of(0..10=>INT)) { return $param[0] }
my    sub    my_sub :returns(INT)  (@param :of(0..10=>INT)) { return $param[0] }
state sub state_sub :returns(INT)  (@param :of(0..10=>INT)) { return $param[0] }

# With values that should pass the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);

    # List context return okay if list length = 1...
    OKAY { () =     old_sub( $good_value ) }   "  old_sub( $good_value_str )";
    OKAY { () =     new_sub( $good_value ) }   "  new_sub( $good_value_str )";
    OKAY { () =      my_sub( $good_value ) }   "   my_sub( $good_value_str )";
    OKAY { () =   state_sub( $good_value ) }   "state_sub( $good_value_str )";

    OKAY { () =     old_sub( ($good_value) x 10 ) }   "  old_sub( $good_value_str )";
    OKAY { () =     new_sub( ($good_value) x 10 ) }   "  new_sub( $good_value_str )";
    OKAY { () =      my_sub( ($good_value) x 10 ) }   "   my_sub( $good_value_str )";
    OKAY { () =   state_sub( ($good_value) x 10 ) }   "state_sub( $good_value_str )";

    FAIL_ON_LENGTH_OLD  { () =     old_sub( ($good_value) x 11 ) }   "  old_sub( $good_value_str )";
    FAIL_ON_LENGTH_INIT { () =     new_sub( ($good_value) x 11 ) }   "  new_sub( $good_value_str )";
    FAIL_ON_LENGTH_INIT { () =      my_sub( ($good_value) x 11 ) }   "   my_sub( $good_value_str )";
    FAIL_ON_LENGTH_INIT { () =   state_sub( ($good_value) x 11 ) }   "state_sub( $good_value_str )";
}

# With values that SHOULDN'T pass the INT check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::pp($bad_value);

    # Can't pass invalid values as arguments...
    FAIL_ON_UNPACK { scalar   old_sub( $bad_value ) }       "  old_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar   new_sub( $bad_value ) }       "  new_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar    my_sub( $bad_value ) }       "   my_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar state_sub( $bad_value ) }       "state_sub( $bad_value_str )";
}

done_testing();

