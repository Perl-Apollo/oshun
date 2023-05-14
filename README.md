# NAME

Data::Checks - Declarative data validation for variables and subroutines

# VERSION

version 0.00001

# SYNOPSIS

```perl
use Data::Checks;

my $count :of(INT) = 0;

sub rand_arrayref : returns(ARRAY[INT]) ( $max_size : of(UINT) ) {
    my @array = map { int( 1 + rand($max_size) ) } 0 .. $max_size - 1;
    return \@array;
}

my $aref = rand_arrayref(4);
```

# CEÇI N'EST PAS UN TYPE

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

# SPECIFICATION

See [Data::Checks::Parser](https://metacpan.org/pod/Data%3A%3AChecks%3A%3AParser) for the full specification.

# DEPENDENCIES

Requires Perl 5.22 or later.

# MAINTAINERS

- Curtis "Ovid" Poe <ovid@cpan.org>

# AUTHOR

Damian Conway <damian@conway.org>

# COPYRIGHT AND LICENSE

This software is Copyright (c) 2023 by Damian Conway.

This is free software, licensed under:

```
The Artistic License 2.0 (GPL Compatible)
```
