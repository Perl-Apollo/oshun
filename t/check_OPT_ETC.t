use v5.22;
use warnings;
use experimental qw< signatures lexical_subs >;

use Test::More;

use Data::Checks;

my @BAD_DECLS = (
    q{ my $var :of(OPT[HASH]);          },
    q{ sub foo ($arg :of(OPT[HASH])) {} },
    q{ sub foo :returns(OPT[HASH])   {} },

    q{ my $var :of(ETC);                },
    q{ sub foo ($arg :of(ETC))       {} },
    q{ sub foo :returns(ETC)         {} },
);

for my $bad_decl (@BAD_DECLS) {
    ok !eval("$bad_decl; 1")                                                         => $bad_decl;
    ok $@ =~ m{\QCan't specify \E .*? \Q here (only in a TUPLE, SEQ, or DICT)\E }xms => ' \__with correct exception:';
}

done_testing();
