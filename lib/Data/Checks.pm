package Data::Checks 0.000001;

use 5.022;
use warnings;
use experimental         ();
use feature              ();
use Data::Checks::Parser ();

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
