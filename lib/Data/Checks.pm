package Data::Checks;

# ABSTRACT: Declarative data validation for variables and subroutines

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

sub unimport {
    my ( $class, $level ) = @_;

    my $caller = caller;

    strict->unimport::out_of($caller);
    warnings->unimport::out_of($caller);
    feature->unimport::out_of($caller);

    # don't unimport experimental signatures because
    # they have to have those to parse their signatures
    Data::Checks::Parser->unimport::out_of($caller);
}

1;

__END__

=head1 SYNOPSIS

    use Data::Checks;

    my $count :of(INT) = 0;

    sub rand_arrayref : returns(ARRAY[INT]) ( $max_size : of(UINT) ) {
        my @array = map { int( 1 + rand($max_size) ) } 0 .. $max_size - 1;
        return \@array;
    }

    my $aref = rand_arrayref(4);

=head1 CEÇI N'EST PAS UN TYPE

This is NOT a type system for Perl.

The fundamental problem with type systems is that every individual programmer
knows exactly what they mean by – and want in – and need from – a “type
system” ...but no two programmers can ever agree precisely what that is.

What most Perl users actually need is a practical way to ensure that, when a
value that is assigned to a variable, or passed to a parameter, or returned
from a subroutine, that value conforms to the designer’s original expectations
and assumptions (e.g. did their subroutine get passed a positive integer
and a filehandle, and did it return a reference to a hash of strings?)

So this is not a compile-time type-system for Perl.  It’s a runtime
data-checking system for Perl: a system of “checks”.

A check is an assertion about the value(s) that can be assigned to a variable,
passed to a parameter, or returned by a subroutine. This module provides a
large number of built-in checks and will eventually offer a mechanism for
specifying user-defined checks as well.

=head1 SPECIFICATION

See L<Data::Checks::Parser> for the full specification.

=head1 DEPENDENCIES

Requires Perl 5.22 or later.

=head1 MAINTAINERS

=over 4

=item * Curtis "Ovid" Poe <ovid@cpan.org>

=back
