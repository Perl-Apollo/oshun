use v5.22;

use Test::Most;
use Data::Checks;
use warnings;
no warnings 'experimental::signatures';

# There was a bug in subroutines where checks would be checked on subroutine
# entry, but not in the body. This test ensures that the checks are enforced
# in the body and subsequent changes don't skip that.
# https://github.com/Perl-Oshun/oshun/issues/1

sub bad_assigment_in_body ( $max_size : of(UINT) ) {
    my $new_value = $max_size;
    $max_size = -2.43 if $max_size == 3;
    return 1 + $new_value;
}

throws_ok { bad_assigment_in_body(3) } qr/Can't assign -2.43 to \$max_size: failed UINT check/,
  'Checks declared on arguments are enforced';
is bad_assigment_in_body(4), 5, '... but if we skip our bad assignment, we get the right answer';

done_testing,
