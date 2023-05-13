use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;
use Data::Checks;

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

# Test assignment to arrays...

my    @my_array    :of(INT);
our   @our_array   :of(INT);

# Variables have to be initialized with something that passes the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { my @var    = $good_value }   "   my array = $good_value_str";
    OKAY { our @var   = $good_value }   "  our array = $good_value_str";
}

# Implicit empty list passes the INT check (every element – all zero of them – is an integer)...
OKAY { my @uninitialized :of(INT)    }    'uninitialized my array';
OKAY { our @uninitialized :of(INT)   }    'uninitialized our array';

# Other explicit initializer values also don't pass the INT check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_INIT { my @var :of(INT)    = $bad_value }  "   my array = $bad_value_str";
    FAIL_ON_INIT { our @var :of(INT)   = $bad_value }  "  our array = $bad_value_str";
}

# List assignments must likewise pass the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { @my_array    = $good_value                } "my array = $good_value_str";
    OKAY { @my_array    = ($good_value, $good_value) } "my array = $good_value_str";
    OKAY { @our_array   = $good_value                } "our array = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
for my $good_value ((GOOD_VALUES)[1,4,9]) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_ASSIGN { @my_array    = $bad_value                } "   my array = $bad_value_str";
    FAIL_ON_ASSIGN { @my_array    = ($good_value, $bad_value) } "   my array = (good, $bad_value_str)";
    FAIL_ON_ASSIGN { @our_array   = $bad_value                } "  our array = $bad_value_str";
}
}

# Element assignments must pass the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { $my_array[0]    = $good_value }  "   my array[0] = $good_value_str";
    OKAY { $our_array[0]   = $good_value }  "  our array[0] = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_ASSIGN { $my_array[0]    = $bad_value }  "   my array[0] = $bad_value_str";
    FAIL_ON_ASSIGN { $our_array[0]   = $bad_value }  "  our array[0] = $bad_value_str";
}

# Element assignments that introduce undef-gaps can never pass the INT check, even for good values...
@my_array = @our_array = (0..2);
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    FAIL_ON_ASSIGN { $my_array[4]     = $good_value }  "   my array[4]  = $good_value_str";
    FAIL_ON_ASSIGN { $our_array[7]    = $good_value }  "  our array[7]  = $good_value_str";
}

# Other modifications that can succeed or fail...
my @undef_array :of(UNDEF) = (undef) x 10;
my @any_array :of(ANY) = (0..9);
@my_array = @our_array = (0..9);
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { splice @my_array, 7, 0, $good_value }  "  splice my array, 23, 0, $good_value_str";
    OKAY { push @my_array, $good_value         }  "    push my array, $good_value_str";
    OKAY { unshift @my_array, $good_value      }  " unshift my array, $good_value_str";
    OKAY { delete $my_array[-1];               }  "  delete my array[-1]";

    OKAY { splice @our_array, 7, 0, $good_value }  "  splice our array, 23, 0, $good_value_str";
    OKAY { push @our_array, $good_value         }  "    push our array, $good_value_str";
    OKAY { unshift @our_array, $good_value      }  " unshift our array, $good_value_str";
    OKAY { delete $our_array[-1];               }  "  delete our array[-1]";

    # Can delte "internal" elements if check allows undef...
    OKAY { delete $undef_array[2];              }  "  delete our undef_array[2]";
    OKAY { delete $any_array[7];                }  "  delete our any_array[7]";
}
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_MODIFY { splice @my_array, 7, 0, $bad_value }  "  splice my array, 23, 0, $bad_value_str";
    FAIL_ON_MODIFY { push @my_array, $bad_value         }  "    push my array, $bad_value_str";
    FAIL_ON_MODIFY { unshift @my_array, $bad_value      }  " unshift my array, $bad_value_str";

    FAIL_ON_MODIFY { splice @our_array, 7, 0, $bad_value }  "  splice our array, 23, 0, $bad_value_str";
    FAIL_ON_MODIFY { push @our_array, $bad_value         }  "    push our array, $bad_value_str";
    FAIL_ON_MODIFY { unshift @our_array, $bad_value      }  " unshift our array, $bad_value_str";

    # Can't delete "internal" elements: the resulting undef fails the INT check...
    FAIL_ON_MODIFY { delete $my_array[2];               }  "  delete my array[2]";
    FAIL_ON_MODIFY { delete $our_array[2];               }  "  delete our array[2]";
}

# Test subroutines: parameters, internal variables, return values...

      sub   old_sub :returns(INT)                     { my @x :of(INT) = @_; return $x[0] }
      sub   new_sub :returns(INT)  (@param :of(INT))  { return $param[0] }
my    sub    my_sub :returns(INT)  (@param :of(INT))  { return $param[0] }
state sub state_sub :returns(INT)  (@param :of(INT))  { return $param[0] }

# With values that should pass the INT check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # List context return okay if list length = 1...
    OKAY { () =     old_sub( $good_value ) }   "  old_sub( $good_value_str )";
    OKAY { () =     new_sub( $good_value ) }   "  new_sub( $good_value_str )";
    OKAY { () =      my_sub( $good_value ) }   "   my_sub( $good_value_str )";
    OKAY { () =   state_sub( $good_value ) }   "state_sub( $good_value_str )";
}

# With values that SHOULDN'T pass the INT check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);

    # Can't pass invalid values as arguments...
    FAIL_ON_UNPACK { scalar   old_sub( $bad_value ) }       "  old_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar   new_sub( $bad_value ) }       "  new_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar    my_sub( $bad_value ) }       "   my_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar state_sub( $bad_value ) }       "state_sub( $bad_value_str )";
}

done_testing();
