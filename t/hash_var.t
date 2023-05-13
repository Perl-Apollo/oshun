use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'REF';

sub GOOD_VALUES {
    [], {}, \*STDIN, qr{}, \1, sub{},
    Class::WithOverload->new(),
    Class::Base->new(),
    Class::NoOverload->new(),
}

sub BAD_VALUES  {
    100000000000.1, -10.1, -1.1, 0.1, 1.1, 7.1, 99.9,
    -1e99, -0.9e99, -10, -1, 0, 1, 7, 99,
    -10.0, -1.0, 0.0, 1.0, 7.0, 99.0,
    q{-10}, q{0}, q{1},
    0.9e99, 1e99,
    q{}, q{string},
    v1, v1.2, v1.2.3,
    undef,
}


use Data::Checks;


# Test assignment to hashs...

my    %my_hash    :of(REF);
our   %our_hash   :of(REF);

# Variables have to be initialized with something that passes the REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { my %var  :of(REF) = (goodkey => $good_value) }   "   my hash = goodkey => $good_value_str";
    OKAY { our %var :of(REF) = (goodkey => $good_value) }   "  our hash = goodkey => $good_value_str";
}

# Implicit empty list passes the REF check (every element – all zero of them – is an integer)...
OKAY { my %uninitialized :of(REF)    }    'uninitialized my hash';
OKAY { our %uninitialized :of(REF)   }    'uninitialized our hash';

# Other explicit initializer values also don't pass the REF check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_INIT { my %var :of(REF)    = (badkey => $bad_value) }  "   my hash = badkey => $bad_value_str";
    FAIL_ON_INIT { our %var :of(REF)   = (badkey => $bad_value) }  "  our hash = badkey => $bad_value_str";
}

# List assignments must likewise pass the REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { %my_hash    = (goodkey=>$good_value)                } "my hash = $good_value_str";
    OKAY { %my_hash    = (goodkey=>$good_value, goodkey2=>$good_value) } "my hash = $good_value_str x 2";
    OKAY { %our_hash   = (goodkey=>$good_value)               } "our hash = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
for my $good_value ((GOOD_VALUES)[1,4,9]) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_ASSIGN { %my_hash    = (badkey=>$bad_value)               } "   my hash = badkey=>$bad_value_str";
    FAIL_ON_ASSIGN { %my_hash    = (goodkey=>$good_value, badkey=>$bad_value) } "   my hash = (gk=>good, badkey=>$bad_value_str)";
    FAIL_ON_ASSIGN { %our_hash   = (badkey=>$bad_value)                } "  our hash = badkey=>$bad_value_str";
}
}

# Element assignments must pass the REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { $my_hash{key}  = $good_value }  "   my hash{key} = $good_value_str";
    OKAY { $our_hash{key} = $good_value }  "  our hash{key} = $good_value_str";
}

for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_ASSIGN { $my_hash{key}    = $bad_value }  "   my hash{key} = $bad_value_str";
    FAIL_ON_ASSIGN { $our_hash{key}   = $bad_value }  "  our hash{key} = $bad_value_str";
}

# Other modifications that can succeed or fail...
%my_hash = %our_hash = ();
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);
    OKAY { @my_hash{'gv1','gv2'} = ($good_value, $good_value) }  "\@my_hash{gv1,gv2) = $good_value_str";
}
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);
    FAIL_ON_ASSIGN { @my_hash{'bv1','bv2'} = ($bad_value, $bad_value) }  "\@my_hash{bv1,bv2) = $bad_value_str";
}

# Test subroutines: parameters, internal variables, return values...

      sub   old_sub :returns(REF)                     { my %x :of(REF) = @_; return $x{key} }
      sub   new_sub :returns(REF)  (%param :of(REF))  { return $param{key} }
my    sub    my_sub :returns(REF)  (%param :of(REF))  { return $param{key} }
state sub state_sub :returns(REF)  (%param :of(REF))  { return $param{key} }

# With values that should pass the REF check...
for my $good_value (GOOD_VALUES) {
    my $good_value_str = Data::Checks::Parser::pp($good_value);

    # List context return okay if list length = 1...
    OKAY { () =     old_sub( key => $good_value ) }   "  old_sub( $good_value_str )";
    OKAY { () =     new_sub( key => $good_value ) }   "  new_sub( $good_value_str )";
    OKAY { () =      my_sub( key => $good_value ) }   "   my_sub( $good_value_str )";
    OKAY { () =   state_sub( key => $good_value ) }   "state_sub( $good_value_str )";
}

# With values that SHOULDN'T pass the REF check...
for my $bad_value (BAD_VALUES) {
    my $bad_value_str = Data::Checks::Parser::pp($bad_value);

    # Can't pass invalid values as arguments...
    FAIL_ON_UNPACK { scalar   old_sub( key => $bad_value ) }       "  old_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar   new_sub( key => $bad_value ) }       "  new_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar    my_sub( key => $bad_value ) }       "   my_sub( $bad_value_str )";
    FAIL_ON_PARAM  { scalar state_sub( key => $bad_value ) }       "state_sub( $bad_value_str )";
}

done_testing();

