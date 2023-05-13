use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'DEF';

sub GOOD_VALUES {
    -1e99, -0.9e99, -10, -1, 0, 1, 7, 99,
    -10.0, -1.0, 0.0, 1.0, 7.0, 99.0,
    q{-10}, q{0}, q{1},
    0.9e99, 1e99,
    100000000000.1, -10.1, -1.1, 0.1, 1.1, 7.1, 99.9,
    q{}, q{string},
    v1, v1.2, v1.2.3,
    [], {}, *STDIN, qr{}, \1, sub{},
    Class::Base->new(),
    Class::NoOverload->new(),
    Class::WithOverload->new(),
}

sub BAD_VALUES  {
    undef
}


use Data::Checks;

no checks;


# Test assignment to scalars...
my    $my_scalar    :of(DEF);      # This won't fail because there are no actual checks!
our   $our_scalar   :of(DEF) = 0;
state $state_scalar :of(DEF) = 0;

# Variables have to be initialized with something that passes the DEF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { my $var    = $good_value }   "   my scalar = $good_value_str";
    OKAY { our $var   = $good_value }   "  our scalar = $good_value_str";
    OKAY { state $var = $good_value }   "state scalar = $good_value_str";
}

# Implicit undef DOESN'T pass the DEF check...
# (Note: can't check uninitialized our variable because that fails at compile-time)
OKAY { my $uninitialized :of(DEF)    }    'uninitialized my scalar';
OKAY { state $uninitialized :of(DEF) }    'uninitialized state scalar';

# Other explicit initializer values also don't pass the DEF check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    OKAY { my $uninitialized :of(DEF)    = $bad_value }  "   my scalar = $bad_value_str";
    OKAY { our $uninitialized :of(DEF)   = $bad_value }  "  our scalar = $bad_value_str";
    OKAY { state $uninitialized :of(DEF) = $bad_value }  "state scalar = $bad_value_str";
}

# Assignments must likewise pass the DEF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { $my_scalar    = $good_value }  "   my scalar = $good_value_str";
    OKAY { $our_scalar   = $good_value }  "  our scalar = $good_value_str";
    OKAY { $state_scalar = $good_value }  "state scalar = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    OKAY { $my_scalar    = $bad_value }  "   my scalar = $bad_value_str";
    OKAY { $our_scalar   = $bad_value }  "  our scalar = $bad_value_str";
    OKAY { $state_scalar = $bad_value }  "state scalar = $bad_value_str";
}


# Test subroutines: parameters, internal variables, return values...

      sub   old_sub :returns(DEF)                     { my $x :of(DEF) = shift; return $x }
      sub   new_sub :returns(DEF)  ($param :of(DEF))  { return $param }
my    sub    my_sub :returns(DEF)  ($param :of(DEF))  { return $param }
state sub state_sub :returns(DEF)  ($param :of(DEF))  { return $param }

      sub   old_ret_sub : returns(DEF)            { return shift  }
      sub   new_ret_sub : returns(DEF)  ($param)  { return $param }
my    sub    my_ret_sub : returns(DEF)  ($param)  { return $param }
state sub state_ret_sub : returns(DEF)  ($param)  { return $param }

# With values that should pass the DEF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # Scalar context return okay...
    OKAY { scalar   old_sub( $good_value ) }   "  old_sub( $good_value_str )";
    OKAY { scalar   new_sub( $good_value ) }   "  new_sub( $good_value_str )";
    OKAY { scalar    my_sub( $good_value ) }   "   my_sub( $good_value_str )";
    OKAY { scalar state_sub( $good_value ) }   "state_sub( $good_value_str )";

    # List context return okay if list length = 1...
    OKAY { () =     old_sub( $good_value ) }   "  old_sub( $good_value_str )";
    OKAY { () =     new_sub( $good_value ) }   "  new_sub( $good_value_str )";
    OKAY { () =      my_sub( $good_value ) }   "   my_sub( $good_value_str )";
    OKAY { () =   state_sub( $good_value ) }   "state_sub( $good_value_str )";

    # Void context return fails...
    OKAY {;   old_ret_sub( $good_value ) }   "  old_sub( $good_value_str )";
    OKAY {;   new_ret_sub( $good_value ) }   "  new_sub( $good_value_str )";
    OKAY {;    my_ret_sub( $good_value ) }   "   my_sub( $good_value_str )";
    OKAY {; state_ret_sub( $good_value ) }   "state_sub( $good_value_str )";
}

# With values that SHOULDN'T pass the DEF check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);

    # Can't pass invalid values as arguments...
    OKAY { scalar   old_sub( $bad_value ) }       "  old_sub( $bad_value_str )";
    OKAY { scalar   new_sub( $bad_value ) }       "  new_sub( $bad_value_str )";
    OKAY { scalar    my_sub( $bad_value ) }       "   my_sub( $bad_value_str )";
    OKAY { scalar state_sub( $bad_value ) }       "state_sub( $bad_value_str )";

    # Can't return invalid values in any context...
    OKAY { scalar   old_ret_sub( $bad_value ) }   "  old_sub( $bad_value_str )";
    OKAY { scalar   new_ret_sub( $bad_value ) }   "  new_sub( $bad_value_str )";
    OKAY { scalar    my_ret_sub( $bad_value ) }   "   my_sub( $bad_value_str )";
    OKAY { scalar state_ret_sub( $bad_value ) }   "state_sub( $bad_value_str )";
    OKAY { () =     old_ret_sub( $bad_value ) }   "  old_sub( $bad_value_str )";
    OKAY { () =     new_ret_sub( $bad_value ) }   "  new_sub( $bad_value_str )";
    OKAY { () =      my_ret_sub( $bad_value ) }   "   my_sub( $bad_value_str )";
    OKAY { () =   state_ret_sub( $bad_value ) }   "state_sub( $bad_value_str )";
    OKAY {;         old_ret_sub( $bad_value ) }   "  old_sub( $bad_value_str )";
    OKAY {;         new_ret_sub( $bad_value ) }   "  new_sub( $bad_value_str )";
    OKAY {;          my_ret_sub( $bad_value ) }   "   my_sub( $bad_value_str )";
    OKAY {;       state_ret_sub( $bad_value ) }   "state_sub( $bad_value_str )";
}

done_testing();




