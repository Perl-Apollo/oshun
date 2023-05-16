use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;

use Data::Checks;

# Probably the most common usage...

my $my_scalar :of(INT|UNDEF);

for my $good_val ( 1, '86', undef ) {
    my $good_val_str = Data::Checks::Parser::pp($good_val);
    ok( eval { $my_scalar = $good_val; 1 }, "INT|UNDEF <--- $good_val_str" );
}

for my $bad_val ( 1.1, 'str', qr//, \99, \\99, [], {}, *STDIN ) {
    my $bad_val_str = Data::Checks::Parser::pp($bad_val);
    ok( !eval { $my_scalar = $bad_val; 1 }, "INT|UNDEF <-/- $bad_val_str" );
}

# A more complex example...

my @list :of(DEF & !(ARRAY | HASH | GLOB));

for my $good_val ( 1, 'str', qr//, \99, \\99 ) {
    my $good_val_str = Data::Checks::Parser::pp($good_val);
    ok( eval { push @list, $good_val; 1 }, "DEF & !(ARRAY | HASH) <--- $good_val_str" );
}

for my $bad_val ( undef, [], {}, *STDIN ) {
    my $bad_val_str = Data::Checks::Parser::pp($bad_val);
    ok( !eval { push @list, $bad_val; 1 }, "DEF & !(ARRAY | HASH) <-/- $bad_val_str" );
}

done_testing();

