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
    experimental->import::into( $caller, 'signatures', 'lexical_subs' );
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

=encoding utf8

=head1 SYNOPSIS

    use Data::Checks;

    my $count :of(INT) = 0;
    $count++;        # valid
    undef $count;    # fatal: undef is not an integer

    sub rand_arrayref :returns(ARRAY[INT]) ( $max_size :of(UINT) ) {
        my @array = map { int( 1 + rand($max_size) ) } 0 .. $max_size - 1;
        return \@array;
    }

    my $aref = rand_arrayref(4);

=head1 WARNING

This is a proof-of-concept release. It is not ready for production use. That means
B<I<DO NOT USE THIS IN PRODUCTION CODE>>.

The interface is going to change. The sementantics are going to change. This is here
merely as a testbed of ideas to get feedback on the general concept.

See [the Oshun project](https://github.com/Perl-Oshun/oshun) for more information.

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

=head1 USE DATA::CHECKS

The statement C<use Data::Checks> is equivalent to:

    use strict;
    use warnings;
    use v5.22;
    use experimental 'signatures', 'lexical_subs';
    use Data::Checks::Parser;    # this is the magic

=head1 CORE CHECKS

To have an MVP (minimum viable product), the first pass of Data::Checks is
designed to be as minimal as possible. As such, we currently only support
I<core> types of Perl, along with a few restrictive types such as C<TUPLE> and
C<DICT>.

These come in two forms:

=over 4

=item * C<:of(...)>

This is how you attach a check to a variable:

    my @array :of(HASH[INT]);

You can only assign hashrefs of integers to the individual elements of the array.

=item * C<:returns(...)>

This is attached to subroutines to express what they are allowed to return:

    sub fibonacci :returns(UINT) ($nth: of(UINT) {
        ...
    }

Like C<:of(...)> declarations, the can be complex data structures, but also include multiple
values:

   sub foo :returns(INT, STR, LIST[INT]) { ... }

The above is guaranteed to return two or more elements: a integer, a string, and zero or
more integers after the string.

=back

=head2 Builtin Checks

For the below description of checks, we also check to see if the thing in
question is overloaded. So an object with overloaded stringification should
satify a C<STR> check.

=over 4

=item * C<ANY>

Matches anything

=item * C<LIST>

A list values. Can only be used with C<:returns> checks, not C<:of> checks.

=item * C<VOID>

Allows a void return. Can only be used with C<:returns> checks, not C<:of> checks.

Almost all C<:return> checks will fail in void context because there is no
return value for the check to test. If you want to allow a checked return
value to be discarded without complaint in void context, change the check
from C<:returns(WHATEVER)> to C<:returns(WHATEVER | VOID)>.

=item * C<UNDEF>

The value must be undefined.

=item * C<DEF>

The value must be defined.

=item * C<HANDLE>

Must be an open filehandle.

=item * C<NONREF>

Must not be a reference.

=item * C<REF>

Must be a reference.

=item * C<GLOB>

Must be a typeglob.

=item * C<BOOL>

Must be able to evaluate as a boolean (overloaded boolean is fine).

=item * C<NUM>

Must be a number.

=item * C<INT>

Must be an integer.

=item * C<UINT>

Must be an unsigned integer.

=item * C<STR>

Must be a string.

=item * C<VSTR>

Must be a v-string.

=item * C<CLASS>

Must be a string. If parameterized (e.g., C<< my $animal :of(CLASS[Dog]; >>),
the inner value is a string, assumed to be a classname, and any assigned value
must pass an C<isa> check.

=item * C<ROLE>

Similar to C<CLASS>, but for roles. This is not yet implemented.

=item * C<SCALAR>

Must be a scalar references.

=item * C<CODE>

Must be a code reference.

=item * C<ARRAY>

Must be an array reference.

=item * C<HASH>

Must be a hash reference.

=item * C<REGEXP>

Must be a regular expression reference.

=item * C<OBJ>

Must be a blessed reference. Like C<CLASS>, you may parameterize this with the name of a class.

=back

=head1 DEPENDENCIES

Requires Perl 5.22 or later.

=head1 MAINTAINERS

=over 4

=item * Curtis "Ovid" Poe <ovid@cpan.org>

=back
