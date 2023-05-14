package Data::Checks;

# ABSTRACT: Dynamic, optional data checks for Perl

use 5.022;
use warnings;
use experimental         ();
use feature              ();
use Data::Checks::Parser ();

our $VERSION = '0.00001';

sub import {
    my ( $class, @args ) = @_;
    my $caller = caller;
    strict->import::into($caller);
    warnings->import::into($caller);
    feature->import::into( $caller, ':5.22' );
    experimental->import::into( $caller, 'signatures' );
    Data::Checks::Parser->import::into( $caller, @args );
}

1;

__END__

For now, see the docs for Data::Checks::Parser.
