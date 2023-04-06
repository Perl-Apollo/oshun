use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'VOID';

sub GOOD_VALUES {
    -1e99, -0.9e99, -10, -1, 0, 1, 7, 99,
    q{-10}, q{0}, q{1},
    0.9e99, 1e99,
    100000000000.1, -10.1, -1.1, 0.1, 1.1, 7.1, 99.9,
    q{}, q{string},
    v1, v1.2, v1.2.3,
    undef, [], {}, *STDIN, qr{}, \1, sub{},
    Class::Base->new(),
    Class::NoOverload->new(),
    Class::WithOverload->new(),
}

sub BAD_VALUES  {
    # There aren't any
}


use Data::Checks;

# Can't declare variables with a VOID check...
ok !eval q{ my $uninitialized :of(VOID)    }  =>  'uninitialized my scalar';
ok $@ =~ /\QCan't specify :of(VOID) on a scalar variable\E/ => '  \___with correct exception';
ok !eval q{ our $uninitialized :of(VOID|INT)   }  =>  'uninitialized our scalar';
ok $@ =~ /\QCan't specify :of(VOID|INT) on a scalar variable\E/ => '  \___with correct exception';
ok !eval q{ state $uninitialized :of(!VOID) }  =>  'uninitialized state scalar';
ok $@ =~ /\QCan't specify :of(!VOID) on a scalar variable\E/ => '  \___with correct exception';


# Test subroutines...

      sub   old_ret_sub : returns(VOID)            { return shift  }
      sub   new_ret_sub : returns(VOID)  ($param)  { return $param }
my    sub    my_ret_sub : returns(VOID)  ($param)  { return $param }
state sub state_ret_sub : returns(VOID)  ($param)  { return $param }

# With values that should pass the VOID check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::pp($good_value);

    # Scalar context return fails...
    FAIL_ON_RETURN { scalar   old_ret_sub( $good_value ) }   "  old_ret_sub( $good_value_str )";
    FAIL_ON_RETURN { scalar   new_ret_sub( $good_value ) }   "  new_ret_sub( $good_value_str )";
    FAIL_ON_RETURN { scalar    my_ret_sub( $good_value ) }   "   my_ret_sub( $good_value_str )";
    FAIL_ON_RETURN { scalar state_ret_sub( $good_value ) }   "state_ret_sub( $good_value_str )";

    # List context return fails...
    FAIL_ON_RETURN { () =     old_ret_sub( $good_value ) }   "  old_ret_sub( $good_value_str )";
    FAIL_ON_RETURN { () =     new_ret_sub( $good_value ) }   "  new_ret_sub( $good_value_str )";
    FAIL_ON_RETURN { () =      my_ret_sub( $good_value ) }   "   my_ret_sub( $good_value_str )";
    FAIL_ON_RETURN { () =   state_ret_sub( $good_value ) }   "state_ret_sub( $good_value_str )";

    # Void context return is okay...
    OKAY {;   old_ret_sub( $good_value ) }   "  old_ret_sub( $good_value_str )";
    OKAY {;   new_ret_sub( $good_value ) }   "  new_ret_sub( $good_value_str )";
    OKAY {;    my_ret_sub( $good_value ) }   "   my_ret_sub( $good_value_str )";
    OKAY {; state_ret_sub( $good_value ) }   "state_ret_sub( $good_value_str )";
}

done_testing();



