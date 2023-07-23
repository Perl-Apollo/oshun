use Test::More;

use Data::Checks;
use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'UINT';

sub foo ( $max_size :of(UINT) ) {
    $max_size = -2.43;
}

FAIL_ON_PARAM { foo(-42) } 'foo(-42)';

{
eval { foo(3) };
my $err = $@ // '';
like( $err, qr/\QCan't assign -2.43 to \E\$max_size: failed UINT check/, 'foo(3)' );
like( $err, qr{\Qat t/subroutines.t line 8\E}, '...at correct location' );
}

OKAY { no checks; foo(-42) } 'no checks; foo(-42)';

OKAY { no checks; foo(3) } 'no checks; foo(3)';

done_testing();
