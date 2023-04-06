use strict;
use warnings;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME                => 'Data::Checks',
    AUTHOR              => 'Damian Conway <DCONWAY@CPAN.org>',
    VERSION_FROM        => 'lib/Data/Checks.pm',
    ABSTRACT_FROM       => 'lib/Data/Checks.pm',
    PL_FILES            => {},
    LICENSE             => 'artistic2',
    MIN_PERL_VERSION    => 5.022,
    PREREQ_PM => {
        'Test::More'      => 0,
        'PPR'             => 0.001004,
        'Variable::Magic' => 0.63,
    },
    dist                => { COMPRESS => 'gzip -9f', SUFFIX => 'gz', },
    clean               => { FILES => 'Data-Checks-*' },
);
