use strict;
use warnings;

use 5.022;

use ExtUtils::MakeMaker;

my %WriteMakefileArgs = (
  "ABSTRACT" => "Declarative data validation for variables and subroutines",
  "AUTHOR" => "Damian Conway <damian\@conway.org>",
  "CONFIGURE_REQUIRES" => {
    "ExtUtils::MakeMaker" => 0
  },
  "DISTNAME" => "Data-Checks",
  "LICENSE" => "artistic_2",
  "MIN_PERL_VERSION" => "5.022",
  "NAME" => "Data::Checks",
  "PREREQ_PM" => {
    "Carp" => 0,
    "Data::Dump" => "0.25",
    "Filter::Simple" => 0,
    "Import::Into" => "1.002005",
    "PPR" => "0.001008",
    "PPR::X" => 0,
    "Scalar::Util" => 0,
    "Sub::Uplevel" => "0.2800",
    "Variable::Magic" => "0.63",
    "attributes" => 0,
    "experimental" => 0,
    "feature" => 0,
    "strict" => 0,
    "warnings" => 0
  },
  "TEST_REQUIRES" => {
    "Data::Checks::TestUtils" => 0,
    "ExtUtils::MakeMaker" => 0,
    "File::Spec" => 0,
    "Test::More" => 0,
    "Test::Most" => 0,
    "base" => 0,
    "checks" => 0,
    "experimentals" => 0,
    "lib" => 0,
    "overload" => 0
  },
  "VERSION" => "0.00001",
  "test" => {
    "TESTS" => "t/*.t"
  }
);


my %FallbackPrereqs = (
  "Carp" => 0,
  "Data::Checks::TestUtils" => 0,
  "Data::Dump" => "0.25",
  "ExtUtils::MakeMaker" => 0,
  "File::Spec" => 0,
  "Filter::Simple" => 0,
  "Import::Into" => "1.002005",
  "PPR" => "0.001008",
  "PPR::X" => 0,
  "Scalar::Util" => 0,
  "Sub::Uplevel" => "0.2800",
  "Test::More" => 0,
  "Test::Most" => 0,
  "Variable::Magic" => "0.63",
  "attributes" => 0,
  "base" => 0,
  "checks" => 0,
  "experimental" => 0,
  "experimentals" => 0,
  "feature" => 0,
  "lib" => 0,
  "overload" => 0,
  "strict" => 0,
  "warnings" => 0
);


unless ( eval { ExtUtils::MakeMaker->VERSION(6.63_03) } ) {
  delete $WriteMakefileArgs{TEST_REQUIRES};
  delete $WriteMakefileArgs{BUILD_REQUIRES};
  $WriteMakefileArgs{PREREQ_PM} = \%FallbackPrereqs;
}

delete $WriteMakefileArgs{CONFIGURE_REQUIRES}
  unless eval { ExtUtils::MakeMaker->VERSION(6.52) };

WriteMakefile(%WriteMakefileArgs);
