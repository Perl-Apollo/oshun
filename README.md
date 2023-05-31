# This is Heimdall

Heimdall is a Norse god who keeps watch for invaders and the onset of
Ragnarök. He is known for his keen eyesight and hearing.

In other words, he carefully watches to ensure that only those who are allowed
in are actually allowed in.

In software terms:

```perl
sub fibonacci :returns(UINT) ($nth :of(PositiveInt)) {
    ...
}
```

**Note**: do not worry about that syntax. It's not real. It's just a
placeholder for whatever will be agreed upon. We'll get to that later.

Heimdall is not a module to be installed (though there is code and almost 200K
tests). Instead, it's intended to be a specification like
[Corinna](https://github.com/Ovid/Cor), with the goal of seeing if we can get
it into the Perl core.

# History

In December of 2022, I again wrote about [a type system for
Perl](https://gist.github.com/Ovid/5ae3752e260219a575ddfdea4c2194f7). I've
done this before and the the discussion is usually positive, though given that
we're a community, there are those who disagree with the need to have them.

Shortly thereafter, Damian Conway and I started talking and he shared a
private gist with me. It was an incredibly detailed plan for runtime data
checks. (The term "type" is avoided because of the baggage it carries). A few
others were quietly invited to the conversation.

We spent a few months discussing this and he wrote a prototype, which is the
code in this repository. The protoype is **ALPHA** code and absolutely should
not be used in production. Instead, it's a proof of concept to explore the
problem space. It's also a way to get feedback from the community, which is
why this repository is here.

After a few months of discussion, [Damian rewrote that
gist](https://gist.github.com/thoughtstream/08b7fd48b09c99ae47d6d9f82b913986).
It covers the full spec, but it's long and daunting. I'll just touch on key
points here.

**Note**: Damian regrets that for personal reasons, he is not able to continue
working on Heimdall at this time. He might answer questions, but he does not
have much free time available right now.

# Why "data checks"?

We're not using the word "type" because:

1. Computer scientists have reasonable differences about what they want from a
type system
2. Computer programmers have screaming matches

We'd like to avoid screaming matches.

What I want out a "type system" is probably not feasible in Perl and certainly
won't match everyone's expectations. So we've taken a look at what Perl
developers currently do. [Type::Tiny](https://metacpan.org/pod/Type::Tiny) and
[Moose](https://metacpan.org/pod/Moose) (and `Moo`) are heavy inspirations for
this work. We also looked at [Dios](https://metacpan.org/pod/Dios),
[Zydeco](https://metacpan.org/pod/Zydeco), Raku, and other languages for
inspiration, but mostly this matches what Perl is doing today, keeping in mind
that popular systems are working within the limitation of Perl. Just as
Corinna is better because Sawyer X told me to design something great and not
worry about Perl's current limitations, so are data checks designed to give us
what we want without worrying about Perl's limitations.

# What we need to design

There are two aspects of data checks: syntax and semantics. Obviously these
are tightly coupled, but we can discuss them separately. If we can get basic
agreement on the syntax and core semantics (there will always be edge cases),
then we can move forward on writing up the full specification.

## Syntax

The syntax is probably the hard part. The initial design was made on the
possibly unfounded assumption that P5P would reject any syntax which might
impact existing code. This is why we have the `:returns` and `:of` keywords.
`perldoc -f my` has the following:

```
    my VARLIST
    my TYPE VARLIST
    my VARLIST : ATTRS
    my TYPE VARLIST : ATTRS
```

We very much want that `TYPE` syntax. Fortunately, because data checks are lexically
scoped and not global, it turns out that we probably _can_ have the type `TYPE` syntax,
but we need to be careful.

So we have the following syntax:

```perl
sub fibonacci :returns(UINT) ($nth :of(PositiveInt)) {
    ...
}
```

But let's dig in. We'll consider naming and declaration separately.

### Naming

We have two kinds of data check declarations: built-in and user-defined.
Built-in checks were defined as all uppercase: `INT`, `ARRAY`, `HASH`, etc.
The reason is this problem:

```perl
sub f_to_c :returns(NUM) ($f :of(NUM)) {...}
```

`f_to_c(32)` returns `0`. `f_to_c(-1000)` returns `-573.333333333333`.

However, that doesn't really make sense, since that's below absolute zero.
So we have user-defined checks:

```perl
check Celsius    :isa(NUM[-273.14..inf]);
check Fahrenheit :isa(NUM[−459.67..inf]);
```

Which gives us a much safer, and self-documenting signature:

```perl
sub f_to_c :returns(Celsius) ($f :of(Fahrenheit) {...}
```

Now, if you discover that your user-defined check is wrong, you can fix it and
it will be globally applied. This is a huge win (er, except when your code
doesn't really match the check).

UPPER-CASE CHECKS were designed to be a subtle disaffordance to encourage
people to write custom checks that more accurately reflect their intent.

They also clearly distinguished between built-in and user-defined checks.

However, the SHOUTY checks were a touch controversial in some earlier private
discussions. You don't always need a user-defined check. Sometimes it's just
burdensome and if you find a built-in check is wrong, you can later upgrade
that to a user-defined check.

Another benefit of data checks is that tests are easier. I used to program in
Java and I wrote tests using [JUnit](https://junit.org/junit5/). You know what
I didn't test? I didn't have to test what would happen if the type I passed in
was not an expected type. I didn't have to write tests to verify that the
structure I got back was correct. The compiler caught that for me. I could
focus on testing the actual functional bits of my code, not the
infrastructure. In a sense, Java tests could be more compact _and_ reliable
than Perl tests.

But getting back to the shouty checks ...

Or we could look at how other languages deal with this. For Java, primitive types
are lower-case and include things like `int`, `char`, `double`, and so on.
These map directly to what the underlying hardware supports. These correspond
to the "built-in" checks for Heimdall, with the caveat that we focus on types
that map naturally to what _perl_ supports, not what the underlying hardware
expects. For example, we have a `GLOB` type:

```perl
my    $my_scalar    :of(GLOB) = *STDOUT;
our   $our_scalar   :of(GLOB) = *STDERR;
state $state_scalar :of(GLOB) = *STDIN;
```

Java also has non-primitive types, which are defined by the programmer. These
correspond to our user-defined checks. In Java, these are defined using class
names. In Heimdall, we use `check` and the name of a check is an unqualified
Perl identifier, which must contain at least one upper-case character and at
least one lower-case character.

```perl
# Newly assigned values must never decrease...
check Monotonic :isa(NUM) ($value, %value) { $value >= $value{old} }
```

However, since SHOUTY checks are controversial, we could use all lower-case
for the built-in checks and require user-defined checks to start with an
upper-case letter.

```perl
# @data must be an array of hashes, where the hash keys must be integers
# and values must be arrayrefs of Account objects.
my @data :of(hash[int => array[obj[Account]]]);
```

### Declaration

That brings us to the next contentious issue: how do we declare data checks?

We used attributes because they were not likely to conflict with existing
code. Further, they correspond to the [KIM
syntax](https://ovid.github.io/articles/language-design-consistency.html)
which Corinna now uses:

```
# KEYWORD IDENTIFIER MODIFIERS                   SETUP
  sub     f_to_c     :returns(NUM) ($f :of(NUM)) {...}
```

Responses to this were mixed. Many people prefer a syntax like this:

```perl
my hash[int => array[obj[Account]]] @data;
my uint $count = 1;
```

Or this:

```perl
my @hash hash[int => array[obj[Account]]];
my $count uint = 1;
```

Still others were happy with the KIM syntax, but wanted to use anything other
than `:of`. `:is`, `:check`, `:contract` were all suggested. I won't take a
position here, other than to say that whatever syntax we should choose should
only be cumbersome for things we think we should actively discourage.

### Return Values From Subroutines

If we don't use the `:returns(...)` syntax for specifying the checks on values
subs/methods return, what then? Looking at [how Raku handles
this](https://docs.raku.org/language/functions#Return_type_constraints):

```perl
sub foo(--> Int)      {}; say &foo.returns; # OUTPUT: «(Int)␤»
sub foo() returns Int {}; say &foo.returns; # OUTPUT: «(Int)␤»
sub foo() of Int      {}; say &foo.returns; # OUTPUT: «(Int)␤»
my Int sub foo()      {}; say &foo.returns; # OUTPUT: «(Int)␤» 
```

I don't know the design discussions which led Raku to that place, but I don't
think it's controversial to suggest that Perl is not Raku and we probably
don't want that many different ways of declaring the return check. But if we
don't use `:returns(...)`, what then?

```perl
sub int num (str $name) {...}
```

What's the name of that subroutine? I think it's `num`, but it might look like
`int` to other. Who knows? We could do this:

```perl
int sub num (str $name) {...}
```

That's much clearer, but if `&int` is a function in this namespace, I imagine
that's going to create all sorts of parsing problems (not to mention that this
will likely confict with existing code). We could do this:

```perl
sub num (str $name) returns int {...}
```

I think that's the clearest, but it's also the most verbose. I have no strong
preference here, so long as whatever we do it doesn't conflict with existing
code and is easy to use.

## Semantics

For a full discussion of the semantics, [check Damian's
gist](https://gist.github.com/thoughtstream/08b7fd48b09c99ae47d6d9f82b913986).
Here's the short version, including the rather controversial final point.

### Checks are on the variable, not the data

```perl
my $foo :of(INT) = 4;
$foo = 'hello'; # fatal
```

However:

```perl
my $foo :of(INT) = 4;
my $bar = $foo;
$bar = 'hello'; # legal
```

This is because we don't want checks to have "infectious" side effects that
might surprise you. The developer should have full control over the data
checks.

### No type inference

No surprises. The developer should have full control over the data checks.

I can no longer find the article, but I read a long post from a company
explaining why they had abandoned their use of type inference.

The absolutely loved it, but they spent so much time trying to patch
third-party modules that they gave up. They were as much time trying to fix
other's code than writing their own.

This is one of the many dangers of retrofitting a system like "data checks"
onto an existing language. Thus, we're being extremely conservative.

### Signature checks

We need to work out the syntax, but the current plan is something like this:

```perl
sub count_valid :returns(UINT) (@customers :of(OBJ[Customer])) {
	...
}
```

The `@customers` variable should maintain the check in the body of the sub, but
the return check is applied once and only once on the data returned at the time
that it's returned.

### Scalars require valid assignments

```perl
my $total :of(NUM); # fatal, because undef fails the check
```

This is per previous discussions. Many languages allow this:

```perl
int foo;
```

But as soon as you assign something to `foo`, it's fatal if it's not an
integer.  For Perl, that's a bit tricky as there's no difference between
uninitialized and undefined. While using that variable prior to assignment is
fatal in many languages, that would be more difficult in Perl. Thus, we
require a valid assignment.

As a workaround, this is bad, but valid:

```perl
my $total :of(INT|UNDEF);
```

This restriction doesn't apply to arrays or hashes because being empty
trivially passes the check.

### Fatal

By default, a failed check is fatal. We have provisions to downgrade them to
warnings or disable them completely.

### Internal representation

```perl
my $foo :of(INT) = "0";
Dump($foo);
```

`0` naturally coerces to an integer, so that's allowed. However, we don't plan
(for the MVP) to guarantee that Dump shows an `IV` instead of a `PV`. We're
hoping that can be addressed post-MVP.

### User-defined checks

Users should be able to define their own checks:

```perl
check LongStr :params($N :of(PosInt)) :isa(STR) ($n) { length $n >= $N }
```

The above would allow this:

```perl
my $name :of(LongStr[10]) = get_name(); # must be at least 10 characters
```

The body of a check definition should return a true or false value, or
die/croak with a more useful message.

A user-defined check is not allowed to change the value of the variable passed
in. Otherwise, we could not safely disable checks on demand (coercions are not
planned for the MVP, but we have them specced and they use a separate syntax).

User-defined checks could be post-MVP, but it's unclear to me how useful
checks would be without them.

### Checks are on assignment to the variable

This is probably the most problematic bit.

A check applied to a variable is not an invariant on that variable. It's a
prerequisite for assignment to that variable.

An invariant on the variable would guarantee that the contents of the variable
must always meet a given constraint; a "prerequisite for assignment" only
guarantees that each element must be assigned values that meet the constraint
at the moment they are assigned.

So an array such as `my @data :of(HASH[INT])` only requires that each element
of `@data` must be assigned a hashref whose values are integers. If you were
to subsequently modify an element like so (with the caveat that the two lines
aren't exactly equivalent):

```perl
$data[$idx]       = { $key => 'not an integer' }; # fatal
$data[$idx]{$key} = 'not an integer";             # not fatal !
```

The second assignment is not modifying `@data` directly, only retrieving a
value from it and modifying the contents of an entirely different variable
through the retrieved reference value.

We *could* specify that checks are invariants, instead of prerequisites, but
that would require that any reference value stored within a checked arrayref
or hashref would have to have checks automatically and recursively applied to
them as well, which would greatly increase the cost of checking, and might
also lead to unexpected action-at-a-distance, when the now-checked references
are modified through some other access mechanism.

Moreover, we would have to ensure that such auto-subchecked references were
appropriately “de-checked” if they are ever removed from the checked
container. And how would we manage any conflict if the nested referents
happened to have their own (possibly inconsistent) checks?

So the checks are simply assertions on direct assignments, rather than
invariants over a variable’s entire nested data structure.

This is unsatisfying, but we're playing with the matches we have, not the
flamethrower we want.

# Coercions

Many people want coercions. We have a plan for them, but they're not part of
the MVP. However, we're trying to make sure that they can be added later if
necessary. Currently, there are some significant limitations to them. First,
if we downgrade checks to warnings or disable them, we can't do that with
coercions because the code expects the coerced value.

Second, coercions are action at a distance. Thus, if you're trying to debug
why a method failed, you might not realize that the method was passed a UUID
instead of a `Customer` object.

We're not ruling out coercions, but they introduce new problems we'd rather
not have in the MVP

# Compile-time checks

We're not planning on compile-time checks. We're not ruling them out, but
they're not for the MVP. However, we can envision a future where we have this
being a compile-time failure:

```perl
my $foo :of(INT) = "bar"
```

It would be nice to see this a a compile-time failure:

```perl
sub find_customer :returns(OBJ[Customer]) ($self, $id :of(UUID)) {
    ...
}

# in other code:
my $customer :of(HASH) = $object->find_customer($UUID);
```

However, due to the extreme late binding in Perl, that's like to be
impossible, so we're simply not worrying about it.

It's only mentioned now because people have asked about this a few times.

# About the `Data::Checks` module

The `Data::Checks` module is a proof-of-concept implementation of the above.
However, due to current limitations of Perl, it's an unholy combination of
[PPR](https://metacpan.org/pod/PPR), [Filter::Simple](https://metacpan.org/pod/Filter::Simple),
[Variable::Magic](https://metacpan.org/pod/Variable::Magic), and tied
variables. It's not pretty, but it works. However, Damian's very clear that
this is an unholy abomination (my words, not his, but I think he'd agree).
Amongst other issues:

* `Variable::Magic` has significant limitations with array and hashrefs
* Attributes are not allowed inside subroutine signatures

After he turned it over to me, I fixed a bug and rewrote part of it match some
expecations clearer. In particular, `use Data::Checks;` is equivalent to:

```perl
use strict;
ues warnings;
use v5.22;
use experimental 'signatures';
use Data::Checks::Parser;
```

The `Data::Checks::Parser` module is the core of the module and was originally
named `Data::Checks` (to be fair `Data::Checks::Parser` is a terrible name
because it's rewriting your code, not just parsing it).

