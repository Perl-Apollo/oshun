# NAME

Data::Checks - Declarative data validation for variables and subroutines

# VERSION

version 0.00001

# SYNOPSIS

```perl
use Data::Checks;

my $count :of(INT) = 0;
$count++;        # valid
undef $count;    # fatal: undef is not an integer

sub rand_arrayref :returns(ARRAY[INT]) ( $max_size :of(UINT) ) {
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

# USE DATA::CHECKS

The statement `use Data::Checks` is equivalent to:

```perl
use strict;
use warnings;
use v5.22;
use experimental 'signatures';
use Data::Checks::Parser;    # this is the magic
```

# CORE CHECKS

To have an MVP (minimum viable product), the first pass of Data::Checks is
designed to be as minimal as possible. As such, we currently only support
_core_ types of Perl, along with a few restrictive types such as `TUPLE` and
`DICT`.

These come in two forms:

- `:of(...)`

    This is how you attach a check to a variable:

    ```perl
    my @array :of(HASH[INT]);
    ```

    You can only assign hashrefs of integers to the individual elements of the array.

- `:returns(...)`

    This is attached to subroutines to express what they are allowed to return:

    ```perl
    sub fibonacci :returns(UINT) ($nth: of(UINT) {
        ...
    }
    ```

    Like `:of(...)` declarations, the can be complex data structures, but also include multiple
    values:

    ```perl
    sub foo :returns(INT, STR, LIST[INT]) { ... }
    ```

    The above is guaranteed to return two or more elements: a integer, a string, and zero or
    more integers after the string.

## Builtin Checks

For the below description of checks, we also check to see if the thing in
question is overloaded. So an object with overloaded stringification should
satify a `STR` check.

- `ANY`

    Matches anything

- `LIST`

    A list values. Can only be used with `:returns` checks, not `:of` checks.

- `VOID`

    Allows a void return. Can only be used with `:returns` checks, not `:of` checks.

    Almost all `:return` checks will fail in void context because there is no
    return value for the check to test. If you want to allow a checked return
    value to be discarded without complaint in void context, change the check
    from `:returns(WHATEVER)` to `:returns(WHATEVER | VOID)`.

- `UNDEF`

    The value must be undefined.

- `DEF`

    The value must be defined.

- `HANDLE`

    Must be an open filehandle.

- `NONREF`

    Must not be a reference.

- `REF`

    Must be a reference.

- `GLOB`

    Must be a typeglob.

- `BOOL`

    Must be able to evaluate as a boolean (overloaded boolean is fine).

- `NUM`

    Must be a number.

- `INT`

    Must be an integer.

- `UINT`

    Must be an unsigned integer.

- `STR`

    Must be a string.

- `VSTR`

    Must be a v-string.

- `CLASS`

    Must be a string. If parameterized (e.g., `my $animal :of(CLASS[Dog];`),
    the inner value is a string, assumed to be a classname, and any assigned value
    must pass an `isa` check.

- `ROLE`

    Similar to `CLASS`, but for roles. This is not yet implemented.

- `SCALAR`

    Must be a scalar references.

- `CODE`

    Must be a code reference.

- `ARRAY`

    Must be an array reference.

- `HASH`

    Must be a hash reference.

- `REGEXP`

    Must be a regular expression reference.

- `OBJ`

    Must be a blessed reference. Like `CLASS`, you may parameterize this with the name of a class.

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
