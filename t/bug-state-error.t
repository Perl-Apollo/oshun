#!/usr/bin/env perl

use Test::Most;
use Data::Checks;

explain <<'END';
There was a bug where feature 'state' wasn't always imported. Further, there
were redefined warnings. We have fixed both.
END

eval <<'END_SUB';
sub rand_arrayref :returns(ARRAY[INT]) ( $max_size : of(UINT) ) {
    my @array = map { int( 1 + rand($max_size) ) } 0 .. $max_size - 1;
    return \@array;
}
END_SUB
my $error = $@ // '';
is $error, '', 'We should not have errors compiling a sub with a signature';
ok my $aref = rand_arrayref(4),
  '... and we should have no errors when calling it as expected';
is scalar $aref->@*, 4, '... and we should get the correct number of elements';
my @terms = grep { /^\d+$/a } $aref->@*;
is scalar @terms, 4, '... and all of them should be integers'
  or explain \@terms;

done_testing();
