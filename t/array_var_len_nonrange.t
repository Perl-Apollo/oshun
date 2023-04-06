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

my    @my_array    :of(7 => INT) = 1..7;
our   @our_array   :of(7 => INT) = 0..6;

# Variables have to be initialized with something that passes the 7=>INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);
    OKAY {  my @var :of(7 => INT) = ($good_value) x 7 }   "   my array = $good_value_str x 5";
    OKAY { our @var :of(7 => INT) = ($good_value) x 7 }   "  our array = $good_value_str x 5";
}

# Implicit empty list fails the 7=>INT check (doesn't have at leats 2 elems)...
FAIL_ON_LENGTH_INIT {  my @uninitialized :of(7=>INT);  }  'uninitialized my array';

# List assignments must be of the right size...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);
    FAIL_ON_LENGTH { @my_array  = ($good_value) x 6 } " my array = $good_value_str x 6";
    FAIL_ON_LENGTH { @our_array = ($good_value) x 6 } "our array = $good_value_str x 6";
              OKAY { @my_array  = ($good_value) x 7 } " my array = $good_value_str x 7";
              OKAY { @our_array = ($good_value) x 7 } "our array = $good_value_str x 7";
    FAIL_ON_LENGTH { @my_array  = ($good_value) x 8 } " my array = $good_value_str x 8";
    FAIL_ON_LENGTH { @our_array = ($good_value) x 8 } "our array = $good_value_str x 8";
}

for my $bad_value (BAD_VALUES) {
for my $good_value ((GOOD_VALUES)[1,4,9]) {
    my $good_value_str = Data::Checks::pp($good_value);
    my $bad_value_str = Data::Checks::pp($bad_value);
    FAIL_ON_LENGTH { @my_array  = $bad_value       } " my array = $bad_value_str";
    FAIL_ON_ASSIGN { @my_array  = ($bad_value) x 7 } " my array = $bad_value_str x 7";
    FAIL_ON_LENGTH { @our_array = $bad_value       } "our array = $bad_value_str";
    FAIL_ON_ASSIGN { @our_array = ($bad_value) x 7 } "our array = $bad_value_str x 7";
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

# Element assignments must be in the correct index range...
@my_array = (0..6);
@our_array = (0..6);
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);
    FAIL_ON_LENGTH {  $my_array[7] = $good_value }  "   my array[7]  = $good_value_str";
    FAIL_ON_LENGTH { $our_array[7] = $good_value }  "  our array[7]  = $good_value_str";
}

for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);

    @my_array = (0..6);
              OKAY { splice @my_array, 3, 1, $good_value }  "  splice my array, 3, 1, $good_value_str";
    FAIL_ON_LENGTH { splice @my_array, 3, 0, $good_value }  "  splice my array, 3, 0, $good_value_str";
    FAIL_ON_LENGTH { splice @my_array, 7, 1, $good_value }  "  splice my array, 7, 1, $good_value_str";
    FAIL_ON_LENGTH { push @my_array, $good_value         }  "    push my array, $good_value_str";
    FAIL_ON_LENGTH { unshift @my_array, $good_value      }  " unshift my array, $good_value_str";
    FAIL_ON_LENGTH { delete $my_array[-1];               }  "  delete my array[-1]";

    @our_array = (0..6);
              OKAY { splice @our_array, 3, 1, $good_value } "  splice our array, 3, 1, $good_value_str";
    FAIL_ON_LENGTH { splice @our_array, 3, 0, $good_value } "  splice our array, 3, 0, $good_value_str";
    FAIL_ON_LENGTH { splice @our_array, 7, 1, $good_value } "  splice our array, 7, 1, $good_value_str";
    FAIL_ON_LENGTH { push @our_array, $good_value         } "    push our array, $good_value_str";
    FAIL_ON_LENGTH { unshift @our_array, $good_value      } " unshift our array, $good_value_str";
    FAIL_ON_LENGTH { delete $our_array[-1];               } "  delete our array[-1]";
}
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::pp($bad_value);
    FAIL_ON_MODIFY { splice @my_array, 3, 1, $bad_value }   "  splice my array, 3, 1, $bad_value_str";
    FAIL_ON_MODIFY { splice @our_array, 3, 1, $bad_value }  "  splice our array, 3, 1, $bad_value_str";

    # Can't delete "internal" elements: the resulting undef fails the INT check...
    FAIL_ON_MODIFY { delete $my_array[2];                }  "  delete my array[2]";
    FAIL_ON_MODIFY { delete $our_array[2];               }  "  delete our array[2]";
}

# Test subroutines: parameters, internal variables, return values...

      sub   old_sub :returns(INT)                       { my @x :of(7=>INT) = @_; return $x[0] }
      sub   new_sub :returns(INT)  (@param :of(7=>INT)) { return $param[0] }
my    sub    my_sub :returns(INT)  (@param :of(7=>INT)) { return $param[0] }
state sub state_sub :returns(INT)  (@param :of(7=>INT)) { return $param[0] }

# With values that should pass the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);

    # List context return okay if list length = 1...
    FAIL_ON_LENGTH_OLD  { () =     old_sub( ($good_value) x 6 ) }   "  old_sub( $good_value_str  x 6)";
    FAIL_ON_LENGTH_INIT { () =     new_sub( ($good_value) x 6 ) }   "  new_sub( $good_value_str  x 6)";
    FAIL_ON_LENGTH_INIT { () =      my_sub( ($good_value) x 6 ) }   "   my_sub( $good_value_str  x 6)";
    FAIL_ON_LENGTH_INIT { () =   state_sub( ($good_value) x 6 ) }   "state_sub( $good_value_str  x 6)";

    OKAY { () =     old_sub( ($good_value) x 7 ) }   "  old_sub( $good_value_str  x 7)";
    OKAY { () =     new_sub( ($good_value) x 7 ) }   "  new_sub( $good_value_str  x 7)";
    OKAY { () =      my_sub( ($good_value) x 7 ) }   "   my_sub( $good_value_str  x 7)";
    OKAY { () =   state_sub( ($good_value) x 7 ) }   "state_sub( $good_value_str  x 7)";

    FAIL_ON_LENGTH_OLD  { () =     old_sub( ($good_value) x  8 ) }   "  old_sub( $good_value_str x 8)";
    FAIL_ON_LENGTH_INIT { () =     new_sub( ($good_value) x  8 ) }   "  new_sub( $good_value_str x 8)";
    FAIL_ON_LENGTH_INIT { () =      my_sub( ($good_value) x  8 ) }   "   my_sub( $good_value_str x 8)";
    FAIL_ON_LENGTH_INIT { () =   state_sub( ($good_value) x  8 ) }   "state_sub( $good_value_str x 8)";
}

# With values that SHOULDN'T pass the INT check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::pp($bad_value);

    # Can't pass invalid values as arguments...
    FAIL_ON_UNPACK { scalar   old_sub( ($bad_value) x 7 ) }       "  old_sub( $bad_value_str x 7 )";
    FAIL_ON_PARAM  { scalar   new_sub( ($bad_value) x 7 ) }       "  new_sub( $bad_value_str x 7 )";
    FAIL_ON_PARAM  { scalar    my_sub( ($bad_value) x 7 ) }       "   my_sub( $bad_value_str x 7 )";
    FAIL_ON_PARAM  { scalar state_sub( ($bad_value) x 7 ) }       "state_sub( $bad_value_str x 7 )";
}

done_testing();



