use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'NUM';

# All checks off everywhere, all the time...
use Data::Checks -K;

no checks;
my $disabled : of(NUM) = 0;
sub nonfunctional : returns(NUM) ( $x : of(NUM) ) { return 'defined' }

use checks;
my $enabled : of(NUM) = 0;
sub functional : returns(NUM) ( $x : of(NUM) ) { return 'defined' }

no checks;

OKAY { undef $disabled } 'undef disabled';
OKAY { scalar nonfunctional(1) } 'nonfunctional(1)';
OKAY { scalar nonfunctional(undef) } 'nonfunctional(1)';

OKAY { undef $enabled } 'undef enabled';
OKAY { scalar functional(1) } 'functional(1)';
OKAY { scalar functional(undef) } 'functional(undef)';

use checks;

OKAY { undef $disabled } 'undef disabled';
OKAY { scalar nonfunctional(1) } 'nonfunctional(1)';
OKAY { scalar nonfunctional(undef) } 'nonfunctional(1)';

OKAY { undef $enabled } 'undef enabled';
OKAY { scalar functional(1) } 'functional(1)';
OKAY { scalar functional(undef) } 'functional(undef)';

done_testing();

