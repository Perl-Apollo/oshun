use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'LIST[2=>NUM]';

sub GOOD_VALUES {
    -1e99, -0.9e99, -10, -1, 0, 1, 7, 99,
    q{-10}, q{0}, q{1},
    0.9e99, 1e99,
    100000000000.1, -10.1, -1.1, 0.1, 1.1, 7.1, 99.9,
    Class::WithOverload->new(),
}

sub BAD_VALUES  {
    q{}, q{string},
    v1, v1.2, v1.2.3,
    undef, [], {}, *STDIN, qr{}, \1, sub{},
    Class::Base->new(),
    Class::NoOverload->new(),
}


use Data::Checks;

# Test subroutines...

      sub   old_ret_sub_good : returns(LIST[2=>NUM])            { my $x = shift; return ($x, $x);  }
      sub   new_ret_sub_good : returns(LIST[2=>NUM])  ($param)  { return ($param, $param) }
my    sub    my_ret_sub_good : returns(LIST[2=>NUM])  ($param)  { return ($param, $param) }
state sub state_ret_sub_good : returns(LIST[2=>NUM])  ($param)  { return ($param, $param) }

      sub   old_ret_sub_bad_len : returns(LIST[2=>NUM])            { my $x = shift; return ($x);  }
      sub   new_ret_sub_bad_len : returns(LIST[2=>NUM])  ($param)  { return ($param) }
my    sub    my_ret_sub_bad_len : returns(LIST[2=>NUM])  ($param)  { return ($param, $param, $param) }
state sub state_ret_sub_bad_len : returns(LIST[2=>NUM])  ($param)  { return () }

      sub   old_ret_sub_bad_num : returns(LIST[2=>NUM])            { return (shift, 'str')  }
      sub   new_ret_sub_bad_num : returns(LIST[2=>NUM])  ($param)  { return ($param, 'str') }
my    sub    my_ret_sub_bad_num : returns(LIST[2=>NUM])  ($param)  { return ($param, 'str') }
state sub state_ret_sub_bad_num : returns(LIST[2=>NUM])  ($param)  { return ('str', $param) }


# With values and subs that should pass the LIST[2=>NUM] check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # List context return is okay...
    OKAY { () =     old_ret_sub_good( $good_value ) }   "  old_ret_sub_good( $good_value_str )";
    OKAY { () =     new_ret_sub_good( $good_value ) }   "  new_ret_sub_good( $good_value_str )";
    OKAY { () =      my_ret_sub_good( $good_value ) }   "   my_ret_sub_good( $good_value_str )";
    OKAY { () =   state_ret_sub_good( $good_value ) }   "state_ret_sub_good( $good_value_str )";

    # Scalar context return always fails...
    FAIL_ON_RETURN { scalar   old_ret_sub_good( $good_value ) } "  old_ret_sub_good( $good_value_str )";
    FAIL_ON_RETURN { scalar   new_ret_sub_good( $good_value ) } "  new_ret_sub_good( $good_value_str )";
    FAIL_ON_RETURN { scalar    my_ret_sub_good( $good_value ) } "   my_ret_sub_good( $good_value_str )";
    FAIL_ON_RETURN { scalar state_ret_sub_good( $good_value ) } "state_ret_sub_good( $good_value_str )";

    # Void context return always fails...
    FAIL_ON_RETURN {;   old_ret_sub_good( $good_value ) }   "  old_ret_sub_good( $good_value_str )";
    FAIL_ON_RETURN {;   new_ret_sub_good( $good_value ) }   "  new_ret_sub_good( $good_value_str )";
    FAIL_ON_RETURN {;    my_ret_sub_good( $good_value ) }   "   my_ret_sub_good( $good_value_str )";
    FAIL_ON_RETURN {; state_ret_sub_good( $good_value ) }   "state_ret_sub_good( $good_value_str )";
}


# With values that should pass the LIST[2=>NUM] check, but subs that don't return the right length...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # List context fails...
    FAIL_ON_RETURN { () =     old_ret_sub_bad_len( $good_value ) } "  old_ret_sub_bad_len( $good_value_str )";
    FAIL_ON_RETURN { () =     new_ret_sub_bad_len( $good_value ) } "  new_ret_sub_bad_len( $good_value_str )";
    FAIL_ON_RETURN { () =      my_ret_sub_bad_len( $good_value ) } "   my_ret_sub_bad_len( $good_value_str )";
    FAIL_ON_RETURN { () =   state_ret_sub_bad_len( $good_value ) } "state_ret_sub_bad_len( $good_value_str )";

    # Scalar context return always fails...
    FAIL_ON_RETURN { scalar   old_ret_sub_bad_len( $good_value ) } "  old_ret_sub_bad_len( $good_value_str )";
    FAIL_ON_RETURN { scalar   new_ret_sub_bad_len( $good_value ) } "  new_ret_sub_bad_len( $good_value_str )";
    FAIL_ON_RETURN { scalar    my_ret_sub_bad_len( $good_value ) } "   my_ret_sub_bad_len( $good_value_str )";
    FAIL_ON_RETURN { scalar state_ret_sub_bad_len( $good_value ) } "state_ret_sub_bad_len( $good_value_str )";

    # Void context return always fails...
    FAIL_ON_RETURN {;   old_ret_sub_bad_len( $good_value ) } "  old_ret_sub_bad_len( $good_value_str )";
    FAIL_ON_RETURN {;   new_ret_sub_bad_len( $good_value ) } "  new_ret_sub_bad_len( $good_value_str )";
    FAIL_ON_RETURN {;    my_ret_sub_bad_len( $good_value ) } "   my_ret_sub_bad_len( $good_value_str )";
    FAIL_ON_RETURN {; state_ret_sub_bad_len( $good_value ) } "state_ret_sub_bad_len( $good_value_str )";
}


# With values that should pass the LIST[2=>NUM] check, but subs that don't return the right values...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # List context fails...
    FAIL_ON_RETURN { () =     old_ret_sub_bad_num( $good_value ) } "  old_ret_sub_bad_num( $good_value_str )";
    FAIL_ON_RETURN { () =     new_ret_sub_bad_num( $good_value ) } "  new_ret_sub_bad_num( $good_value_str )";
    FAIL_ON_RETURN { () =      my_ret_sub_bad_num( $good_value ) } "   my_ret_sub_bad_num( $good_value_str )";
    FAIL_ON_RETURN { () =   state_ret_sub_bad_num( $good_value ) } "state_ret_sub_bad_num( $good_value_str )";

    # Scalar context return always fails...
    FAIL_ON_RETURN { scalar   old_ret_sub_bad_num( $good_value ) } "  old_ret_sub_bad_num( $good_value_str )";
    FAIL_ON_RETURN { scalar   new_ret_sub_bad_num( $good_value ) } "  new_ret_sub_bad_num( $good_value_str )";
    FAIL_ON_RETURN { scalar    my_ret_sub_bad_num( $good_value ) } "   my_ret_sub_bad_num( $good_value_str )";
    FAIL_ON_RETURN { scalar state_ret_sub_bad_num( $good_value ) } "state_ret_sub_bad_num( $good_value_str )";

    # Void context return always fails...
    FAIL_ON_RETURN {;   old_ret_sub_bad_num( $good_value ) } "  old_ret_sub_bad_num( $good_value_str )";
    FAIL_ON_RETURN {;   new_ret_sub_bad_num( $good_value ) } "  new_ret_sub_bad_num( $good_value_str )";
    FAIL_ON_RETURN {;    my_ret_sub_bad_num( $good_value ) } "   my_ret_sub_bad_num( $good_value_str )";
    FAIL_ON_RETURN {; state_ret_sub_bad_num( $good_value ) } "state_ret_sub_bad_num( $good_value_str )";
}


# With subs that should pass the LIST[2=>NUM] check, but values that don't...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);

    # List context return fails with these values...
    FAIL_ON_RETURN { () =     old_ret_sub_good( $bad_value ) }   "  old_ret_sub_good( $bad_value_str )";
    FAIL_ON_RETURN { () =     new_ret_sub_good( $bad_value ) }   "  new_ret_sub_good( $bad_value_str )";
    FAIL_ON_RETURN { () =      my_ret_sub_good( $bad_value ) }   "   my_ret_sub_good( $bad_value_str )";
    FAIL_ON_RETURN { () =   state_ret_sub_good( $bad_value ) }   "state_ret_sub_good( $bad_value_str )";

    # Scalar context return always fails...
    FAIL_ON_RETURN { scalar   old_ret_sub_good( $bad_value ) } "  old_ret_sub_good( $bad_value_str )";
    FAIL_ON_RETURN { scalar   new_ret_sub_good( $bad_value ) } "  new_ret_sub_good( $bad_value_str )";
    FAIL_ON_RETURN { scalar    my_ret_sub_good( $bad_value ) } "   my_ret_sub_good( $bad_value_str )";
    FAIL_ON_RETURN { scalar state_ret_sub_good( $bad_value ) } "state_ret_sub_good( $bad_value_str )";

    # Void context return always fails...
    FAIL_ON_RETURN {;   old_ret_sub_good( $bad_value ) }   "  old_ret_sub_good( $bad_value_str )";
    FAIL_ON_RETURN {;   new_ret_sub_good( $bad_value ) }   "  new_ret_sub_good( $bad_value_str )";
    FAIL_ON_RETURN {;    my_ret_sub_good( $bad_value ) }   "   my_ret_sub_good( $bad_value_str )";
    FAIL_ON_RETURN {; state_ret_sub_good( $bad_value ) }   "state_ret_sub_good( $bad_value_str )";
}


done_testing();





