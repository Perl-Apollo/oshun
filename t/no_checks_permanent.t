use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use lib qw< tlib t/tlib >;
use Data::Checks::TestUtils 'NUM';

use Data::Checks;

no checks;
    my $disabled :of(NUM) = 0;
    sub nonfunctional :returns(NUM) ($x :of(NUM)) { return 'defined' }

use checks;
    my $enabled :of(NUM) = 0;
    sub functional :returns(NUM) ($x :of(NUM)) { return 'defined' }

no checks;

    note 'These should pass because they were disabled on declaration...';
    OKAY { undef $disabled             } 'undef disabled';
    OKAY { scalar nonfunctional(1)     } 'nonfunctional(1)';
    OKAY { scalar nonfunctional(undef) } 'nonfunctional(1)';

    note 'These should pass because they are disabled in scope...';
    OKAY { undef $enabled              } 'undef enabled';
    OKAY { scalar functional(1)        } 'functional(1)';
    OKAY { scalar functional(undef)    } 'functional(undef)';

use checks;

    note 'These should pass because they were disabled on declaration...';
    OKAY           { undef $disabled             } 'undef disabled';
    OKAY           { scalar nonfunctional(1)     } 'nonfunctional(1)';
    OKAY           { scalar nonfunctional(undef) } 'nonfunctional(1)';

    note 'These should fail because they are enabled in scope...';
    FAIL_ON_ASSIGN { undef $enabled              } 'undef enabled';
    FAIL_ON_RETURN { scalar functional(1)        } 'functional(1)';
    FAIL_ON_PARAM  { scalar functional(undef)    } 'functional(undef)';

done_testing();





