use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'SEQ[NUM, UINT, OPT[STR], OPT[HASH], ETC]';

sub GOOD_VALUES {
    [ 1.1, 2, 'three', {} ],
      [ 1, 0, '', { a => 1, b => 2 } ],
      [ 1, 0, '', { a => 1, b => 2 }, 'extra element' ],
      [ 1, 0, '', { a => 1, b => 2 }, 1 .. 9 ],
      [ 1, 0, '' ],
      [ 1, 0 ],
      do { my @x = 1 .. 3; \@x },;
}

sub BAD_VALUES {
    [ 1, 0, '', 1 .. 3 ],
      [],
      [ -9 .. 9 ],
      [ -9 .. 9, 'str' ],
      [ 'a' .. 'z' ],
      [1.1],
      [q{}], [q{string}],
      [v1], [v1.2], [v1.2.3],
      [undef], [ {} ], [*STDIN], [qr{}], [ sub { } ], [ \1 ], [ \v1.2.3 ],
      Class::WithOverload->new(),;
}

use Data::Checks;

# Test subroutines: parameters, internal variables, return values...

sub old_sub : returns(SEQ[NUM, UINT, OPT[STR], OPT[HASH], ETC]) { return @{ $_[0] } }
sub new_sub : returns(SEQ[NUM, UINT, OPT[STR], OPT[HASH], ETC]) ($param) { return @{$param} }
my sub my_sub : returns(SEQ[NUM, UINT, OPT[STR], OPT[HASH], ETC]) ($param) { return @{$param} }
state sub state_sub : returns(SEQ[NUM, UINT, OPT[STR], OPT[HASH], ETC]) ($param) { return @{$param} }

# With values that should pass the SEQ[NUM, UINT, OPT[STR], OPT[HASH], ETC] check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # Scalar context return should always fail...
    FAIL_ON_RETURN { scalar old_sub($good_value) } "  old_sub( $good_value_str )";
    FAIL_ON_RETURN { scalar new_sub($good_value) } "  new_sub( $good_value_str )";
    FAIL_ON_RETURN { scalar my_sub($good_value) } "   my_sub( $good_value_str )";
    FAIL_ON_RETURN { scalar state_sub($good_value) } "state_sub( $good_value_str )";

    # List context return okay...
    OKAY { () = old_sub($good_value) } "  old_sub( $good_value_str )";
    OKAY { () = new_sub($good_value) } "  new_sub( $good_value_str )";
    OKAY { () = my_sub($good_value) } "   my_sub( $good_value_str )";
    OKAY { () = state_sub($good_value) } "state_sub( $good_value_str )";

    # Void context return fails...
    FAIL_ON_RETURN { ; old_sub($good_value) } "  old_sub( $good_value_str )";
    FAIL_ON_RETURN { ; new_sub($good_value) } "  new_sub( $good_value_str )";
    FAIL_ON_RETURN { ; my_sub($good_value) } "   my_sub( $good_value_str )";
    FAIL_ON_RETURN { ; state_sub($good_value) } "state_sub( $good_value_str )";
}

# With values that SHOULDN'T pass the SEQ[NUM, UINT, OPT[STR], OPT[HASH], ETC] check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);

    # Can't return invalid values in any context...
    FAIL_ON_RETURN { scalar old_sub($bad_value) } "  old_sub( $bad_value_str )";
    FAIL_ON_RETURN { scalar new_sub($bad_value) } "  new_sub( $bad_value_str )";
    FAIL_ON_RETURN { scalar my_sub($bad_value) } "   my_sub( $bad_value_str )";
    FAIL_ON_RETURN { scalar state_sub($bad_value) } "state_sub( $bad_value_str )";
    FAIL_ON_RETURN { () = old_sub($bad_value) } "  old_sub( $bad_value_str )";
    FAIL_ON_RETURN { () = new_sub($bad_value) } "  new_sub( $bad_value_str )";
    FAIL_ON_RETURN { () = my_sub($bad_value) } "   my_sub( $bad_value_str )";
    FAIL_ON_RETURN { () = state_sub($bad_value) } "state_sub( $bad_value_str )";
    FAIL_ON_RETURN { ; old_sub($bad_value) } "  old_sub( $bad_value_str )";
    FAIL_ON_RETURN { ; new_sub($bad_value) } "  new_sub( $bad_value_str )";
    FAIL_ON_RETURN { ; my_sub($bad_value) } "   my_sub( $bad_value_str )";
    FAIL_ON_RETURN { ; state_sub($bad_value) } "state_sub( $bad_value_str )";
}

done_testing();

