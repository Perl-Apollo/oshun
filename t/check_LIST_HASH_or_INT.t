use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'LIST[HASH]|INT';

sub GOOD_VALUES_SCALAR {
    -1e6,     -0.9e6, -10, -1, 0, 1, 7, 99,
      q{-10}, q{0},   q{1},
      0.9e99, 1e99,
      Class::WithOverload->new(),;
}

sub GOOD_VALUES_LIST {
    {},;
}

sub BAD_VALUES {
    100000000000.1, -10.1, -1.1, 0.1, 1.1, 7.1, 99.9,
      -1e99,        -0.9e99,
      q{},          q{string},
      v1, v1.2, v1.2.3,
      undef, [], {}, *STDIN, qr{}, \1, sub { },
      Class::Base->new(),
      Class::NoOverload->new(),;
}

use Data::Checks;

# Can't declare variables with a LIST|INT check...
ok !eval q{ my $uninitialized :of(LIST[HASH]|INT)    }                      => 'uninitialized my scalar';
ok $@ =~ /\QCan't specify :of(LIST[HASH]|INT) on a scalar variable\E/       => '  \___with correct exception';
ok !eval q{ our $uninitialized :of(LIST[HASH]|INT|ARRAY)   }                => 'uninitialized our scalar';
ok $@ =~ /\QCan't specify :of(LIST[HASH]|INT|ARRAY) on a scalar variable\E/ => '  \___with correct exception';
ok !eval q{ state $uninitialized :of(!LIST[HASH]|INT) }                     => 'uninitialized state scalar';
ok $@ =~ /\QCan't specify :of(!LIST[HASH]|INT) on a scalar variable\E/      => '  \___with correct exception';

# Test subroutines...

sub old_ret_sub : returns(LIST[HASH]|INT) { return shift }
sub new_ret_sub : returns(LIST[HASH]|INT) ($param) { return ($param) }
my sub my_ret_sub : returns(LIST[HASH]|INT) ($param) { return ( $param, $param ) }
state sub state_ret_sub : returns(LIST[HASH]|INT) ($param) { return ( $param, $param, $param ) }

# With values that should pass the INT half of the LIST[HASH]|INT check...
for my $good_value (GOOD_VALUES_SCALAR) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # Scalar context return is okay...
    OKAY { scalar old_ret_sub($good_value) } "  old_ret_sub( $good_value_str )";
    OKAY { scalar new_ret_sub($good_value) } "  new_ret_sub( $good_value_str )";

    # List context return is okay...
    OKAY { () = old_ret_sub($good_value) } "  old_ret_sub( $good_value_str )";
    OKAY { () = new_ret_sub($good_value) } "  new_ret_sub( $good_value_str )";

    # Void context return always fails...
    FAIL_ON_RETURN { ; old_ret_sub($good_value) } "  old_ret_sub( $good_value_str )";
    FAIL_ON_RETURN { ; new_ret_sub($good_value) } "  new_ret_sub( $good_value_str )";
}

# With values that should pass the LIST part of the LIST[HASH]|INT check...
for my $good_value (GOOD_VALUES_LIST) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # Scalar context return is okay...
    OKAY { scalar my_ret_sub($good_value) } "   my_ret_sub( $good_value_str )";
    OKAY { scalar state_ret_sub($good_value) } "state_ret_sub( $good_value_str )";

    # List context return is okay...
    OKAY { () = my_ret_sub($good_value) } "   my_ret_sub( $good_value_str )";
    OKAY { () = state_ret_sub($good_value) } "state_ret_sub( $good_value_str )";

    # Void context return always fails...
    FAIL_ON_RETURN { ; my_ret_sub($good_value) } "   my_ret_sub( $good_value_str )";
    FAIL_ON_RETURN { ; state_ret_sub($good_value) } "state_ret_sub( $good_value_str )";
}

done_testing();

