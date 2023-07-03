# Note:

[This is a copy of the original specification Damian wrote](https://gist.github.com/thoughtstream/08b7fd48b09c99ae47d6d9f82b913986).

# Prologue: General Observations

_(If you don’t care about_ “typesystems” _or_ “design” _or_ “politics” _or (even worse!)_
“typesystem design politics”,<BR/>
_you can [skip straight to the actual proposal](#a-possible-design-for-runtime-checks).)_

## The Problem with _“Typing”_

> _“You keep using that word.<br/>
>  I do not think it means<br/>
>  what you think it means.”_<br/>
>  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &mdash; Inigo Montoya

The fundamental problem with type systems is that every individual programmer
knows exactly what they mean by – and want in – and need from – a _“type system”_
...but no two programmers can ever agree precisely what that is.

Hence the vast and incoherent panoply of types systems one finds
across programming languages: whether carefully designed into them,
or painstakingly retrofitted over them, or haphazardly bolted onto them.

And now it’s Perl’s turn to wade into the quagmire, stare into the abyss, and aim the footgun.

Be afraid. Be very afraid.


## Cutting the Gordonian Knot

> _“Life is pain, Highness.<br/>
>  Anyone who says differently<br/>
>  is selling something.”_<br/>
>  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &mdash; The Dread Pirate Roberts

The fundamental problem here is not the desire to improve Perl’s ability to detect
and signal behaviour that is inconsistent with the intended purpose of code.
The fundamental problem here is the word _“type”_ (and _“typing”_, and _“typesystem”_).

No two individuals can agree what these words mean
or how the things that they denote should actually work.

More importantly, when those words are used, most people will lean towards
thinking about a static type system: a compile-time semantic consistency checker
(like C++ or Java has). And the more ambitious folk will want it to be complete,
first-class, and inferential as well (like Haskell has).

I do not believe that static typing (of either kind) is a good fit for Perl,
nor for the majority of Perl users. So I don’t believe that encouraging people
to think in terms of static type systems will be helpful in this design process.

I could write a long article (or a short thesis) on why it would be a bad idea
to attempt to add static typing to Perl...but I won’t. Instead, I’ll summarize:

* Classic declarative static type systems without coercions result in the endless frustration
  of _“type creep”_, the phenomenon wherein you eventually find yourself needing to specify
  the type of everything before you can get anything to compile.

* Classic declarative static type systems with coercions sacrifice almost all the benefits
  of static typing, since coercible types too often get a pass on strict checks. _(Consider
  what could be passed to a Perl variable with the static type `STR` or `NUM`, given that
  **every** value in Perl can be auto-coerced to a string, and the vast majority of values
  can likewise to converted to numbers)._

* Modern inferential static type systems are “hard” (in all three senses of:
  _“difficult to design and implement correctly”, “not easy to use”,_ and _“uncompromising
  in their aversion to ‘sloppy’ techniques such as near-universal implicit coercions”)._

So, instead of pursuing a static type system, I think the extremely dynamic
and highly coercive nature of Perl’s existing behaviour means that we need
a purely run-time system.

And what we need is not _abstract_ consistency checking _(e.g. do the static annotations
on these two declarands indicate that they are related in a single abstraction hierarchy?),_
but a practical way to ensure that when any value that is assigned to a variable, or passed to
a parameter, or returned from a subroutine, that value conforms to
the designer’s original expectations and assumptions _(e.g. did our subroutine get passed
a positive integer and a filehandle, and did it return a reference to a hash of strings?)_

So my core suggestion is – in order to avoid endless debates about whether we need
an explicit type system, or a static type system, or a dynamic type system, or a strict type system,
or an inferential type system, or a gradual type system – that we simply stop using the word _“type”_ ,
or any other related terms, in any way whatsoever whenever we're discussing this project.
And maybe even to ban the _&lt;T-word&gt;_ entirely in any further discussion.

Because we’re **not** talking about adding typing or types or a type system to Perl;
we’re adding _“declarative runtime assertions”_.


## What’s in a name?

> _“In my day “television” was called a “book”._<br/>
>  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &mdash; The Grandpa

What I’m suggesting is that, rather than a full type system (whatever that might be),
what we need is a compile-time mechanism to permit users to specify runtime assertions
or prerequisites or requirements or preconditions or validations
or _&lt;some other equally sesquipedalian term&gt;_.

And that’s the first problem.

Because one of Perl’s less-obvious strengths is that it generally avoids long technical words.
In Perl we _“use”_ rather than _“import”_, we _“say”_ rather than _“printline”_,
we _“bless”_ rather than _“instantiate”_.

So we’re probably not going to be happy declaring or referring to these new components
of Perl with an `assertion` keyword. Nor with `prerequisite`, `requirement`, `precondition`,
or `validation` or `some_other_equally_sesquipedalian_keyword`.

In fact, I struggled to find the right term for this new feature, until I came across
the following entry in a dictionary:

> CHECK¹ | tʃɛk |
> 1. _(v)_ To verify, validate, or confirm some state, condition, or thing
> 2. _(v)_ To limit, constrain, or stop some (typically undesirable) process or behaviour
> 3. _(v)_ To consign something (such as a bag or a coat) temporarily to another’s care and supervision
> 4. _(v)_ To avoid risk by not raising the stakes (in poker)
> 5. _(v)_ To apply the threat of sudden death (in chess)
> 6. _(v)_ To pause momentarily to make sure something smells right (by a hound)
> 7. _(n)_ An examination to test or ascertain accuracy, quality, or satisfactory condition
> 8. _(n)_ A written instruction for the conditional transfer of a specified value (financial)

Given that we are going to want every single one of those eight capabilities in our assertion system,
I hereafter propose that we add ***“checks”*** and a ***“checking system”*** to Perl...via a new keyword: `check`.


## What do we need?

> _“We’ll never survive.”<br/>
>  “Nonsense. You’re only saying that<br/>
>  because no one ever has.”_<br/>
>  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &mdash; Buttercup and Westley


In my opinion, we need a simple, user-extensible mechanism to specify
one or more checks on any value that is assigned to a given variable,
or passed to a given parameter, or returned from a given subroutine.

These checks should not be limited to checking the internal consistency of some abstract
symbolic inheritance/composition graph (_i.e._ not just `isa` and `DOES` tests...though
they should certainly be supported). Checks should be allowed to be specified
as any arbitrary piece of code, though with an appropriate symbolic abstraction mechanism,
so that we can still give specific checks an appropriate name to better convey their meaning
(rather than just their behaviour).

We also need a rich set of predefined and built-in checks, to standardize the most common
desire-paths, to discourage excessive wheel-reinvention, to operate at maximum efficiency,
and to serve as the basis for users to create their own special-purpose checks from a starting-point
somewhere higher than the bare metal.

Ideally, these checks would be as consistent as possible with existing usages
in Perl. And here I specifically mean _nominatively_ consistent.
That is, Perl already recognizes (via the built-in `ref` and `reftype` functions)
specific kinds of reference values, which it labels `"ARRAY"`, `"HASH"`, `"CODE"`,
`"REGEXP"`, _etc._

Hence, the names for any built-in checks that validate these kinds of references
should be respectively: `ARRAY`, `HASH`, `SCALAR`, `CODE`, `REGEXP`, _etc._
And any other built-in checks should follow the same STENTORIAN naming convention:
`ANY`, `INT`, `STR`, `UNDEF`, `VALUE`, `REF`, `NONREF`, _etc._

This is **not** just for gratuitous lexicographic compatibility; it is also essential that
we distinguish built-in checks from user-defined checks (or from classnames),
which have typically been specified in camel-case: `PosInt`, `Password`, `Account`, _etc._

Keeping built-in checks and user-defined checks in two completely separate namespaces
is essential: it ensures that new built-in checks can be added in the future, without
stomping on anyone’s pre-existing user-defined check. And there is another significant,
but subtle, benefit to capitalizing all built-in checks, which will be [explored later](#why-built-in-checks-are-loud), after we have had time to see it in action.

Checks will, of course, need to be arranged in a hierarchy, so that more-specialized checks
can be built out of more-general ones in a DRY manner. This implies, despite each check
being merely a chunk of arbitrary code, that checks must be defined as far as possible
using a purely declarative syntax; one that can be completely resolved at compile-time.

That is: the name, the hierarchical relationship, and any configuration parameters
of a given check must be specified via a declarative syntax, and checks must be
syntactically a part of the definition of the variable, parameter, or subroutine
they are validating, not added to it afterwards. Only the actual code implementing
the check should be procedural.

We will also need a mechanism to allow checks to be parameterized.
It is not sufficient to be able to specify a check that requires a value to
be a number between 0 and 1. It must also be possible to define a single check
that requires a value to be a number between end-user-selectable _MIN_ and _MAX_,
or to be a string of at least _N_ characters, or a reference to an array
in which each element must pass an arbitrary subcheck.

Hence, checks must be able to take parameters at compile-time. And, less obviously,
if those parameters are themselves checks, they must be able to be explicitly applied
to data within the implementation code of the parameterized check.

It must be also possible to specify two or more checks on a single variable, parameter,
or return value. Moreover, it must be possible to combine those two or more checks
into a single logical check. In other words, we must be able to _compose_ checks
together as unions or intersections. So we need a algebra – or at least
higher-order composers – for checks. And, given that Perl is already an operator-rich language,
we probably want operators, rather than composers.

We must also be able to specify a new check that is the antithesis of an existing one
_(for example, to specify that a variable may accept anything ***except*** a reference,
or that a subroutine will ***never*** return a number)._ So we need a _NOT_ operator
or composer for checks as well.

Finally, it must be possible to define checks in a module and subsequently export
them to another _(preferably lexical!)_ scope.

## How would checks operate?

> _“Hello. My name is Inigo Montoya.<br/>
>   You killed my father. Prepare to die.”_ <br/>
>  &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &nbsp; &mdash; Inigo Montoya

The most fundamental decision to be made in designing a runtime data validation mechanism,
is how should that mechanism report validation failures. In other words, what should a
check do when confronted with an unacceptable value.

There are two possibilities: the check could issue a warning and allow the invalid value
to be assigned/passed/returned regardless, or the check could throw an exception and
thus prevent the propagation of an erroneous value.

To most people it will seem obvious that an exception is the safer and more appropriate response.
If the value is wrong, then the code producing that value was wrong and the code receiving that
wrong value will almost certainly go further awry when it is used. So the program really
shouldn’t be allowed to continue. Or, at best, it should be explicitly interrupted at that point
and then remediated by some kind of `try`/`catch` intervention. Code that is known to already be wrong
simply shouldn’t be allowed to keep getting worse.

But we also need to keep in mind that instantly fatal checks could actually make it harder
to retrofit checks into an existing Perl codebase. Precisely because Perl is often very forgiving
of certain kinds of data errors. If, for example, your subroutine returns an `undef`
instead of an expected number (or a string, or an array), in many contexts Perl will quietly
– or else with only a simple warning – upgrade that undefined value to a zero
(or to `""`, or to `[]`). That might not be the _correct_ behaviour, but at least
it doesn’t immediately crash the entire critical application just because someone’s
name (or their shoe-size, or their personal GUI config list) wasn’t returned as expected.

That’s a benefit that we should neither dismiss nor entirely forego. So, assuming that
failed checks are to throw exceptions (which **is** clearly the safest option),
then it must also be possible to downgrade those exceptions to mere warnings,
or to silence them entirely. And it will be essential to be able to select both
of those options either lexically or globally.


# A Possible Design for Runtime Checks

Given all of the above requirements, hereafter is one possible minimal-ish design
for a runtime data-checking system for Perl.
_(A proof-of-concept module, which implements everything specified here,
will also be forthcoming. Certainly by Christmas. ;-)_

## Applying a check to a scalar variable

You apply a check to a variable by declaring it with an `:of` attribute:
```perl
my $count  :of(INT)  = 0;
my $name   :of(STR)  = "";
my $score  :of(NUM)  = 0.0;
```
Thereafter, a new value can only be assigned to that variable if the specified check
succeeds (_i.e._ returns true) for that new value; if the check fails, an exception 
is immediately thrown instead.

A check’s test is applied regardless of how the assignment is invoked:
during initialization, during an explicit assignment, or as the result of some other mutator.
Hence all of the following would throw an exception:
```perl
my $count :of(INT);           # The implicit undef initialization does not pass the INT check

$name = ['Kim', 'Lee'];       # An arrayref does not pass the STR check

$score .= ' (pass)';          # "0.0 (pass)" does not pass the NUM check
```

Note that the exception on implicit initialization could even be raised at compile-time
(though this proposal does not require that), because the compiler could easily infer
that the implicit `undef` with which `$count` is default-initialized will never satisfy
the `INT` check. This compile-time checking could even be extended to variables
that are explicitly initialized with other “invalid” literals:
```perl
my $count :of(INT) = 'zero';     # Potential compile-time error
my $count :of(INT) = [];         # Likewise
my $count :of(INT) = *STDOUT;    # Et cetera
```


## Applying a check to an array variable

If a check is specified on an array, that check is applied to each element
of the array, every time any element is modified in any way (assigned to,
concatenated to, incremented, deleted, _etc._) For example:
```perl
my @scores  :of(NUM);       # Every element must be a number
my @data    :of(DEF);       # Every element must be defined
my @events  :of(OBJ);       # Every element must be a object
```
Note that a built-in check on an array _never_ applies collectively to the entire array;
it always applies individually to each element of the array.
If you want to specify some condition to be verified across the entire array,
you need to [create your own check](#user-defined-checks).

Unlike checked scalars, checked arrays generally do not have to be initialized,
because every element in an empty array trivially satisfies almost any possible check.

However, you can also specify the required length of an array, or a range of acceptable lengths,
by specifying a list of two components in the array’s `:of`. The first component must
then be an unsigned integer, or a range of unsigned integers, which indicate the
minimum/maximum number of elements the array is permitted to store. The second component
is the subcheck that will be applied to each element. Hence:
```perl
my @scores  :of(100    => NUM) = (0) x 100;     # Must store exactly 100 elements; each must be a number
my @data    :of(0..9   => DEF);                 # Must store no more than nine elements; each must be defined
my @events  :of(1..inf => OBJ) = get_events();  # Must store one or more elements; each must be an object
```

Note that arrays with a specified size that doesn’t include zero
***do*** have to be initialized appropriately.

To specify a size without limiting the kinds of values that the array can hold,
specify the second argument as `ANY`:
```perl
my @anydata :of(10 => ANY) = get_data_(10);     # Must store exactly ten elements, but each can be anything
```

## Applying a check to a hash variable

If a check is specified on a hash, that check is applied to the
value of each entry in the hash, whenever those values are assigned. For example:
```perl
my %seen   :of(INT);       # Every value in the hash must be an integer
my %record :of(DEF);       # Every value in the hash must be defined
my %events :of(HASH);      # Every value in the hash must a reference to a nested hash
```
Like checked arrays, checked hashes generally do not have to be initialized.
Also, as with arrays, checks on hashes never apply collectively to the entire hash;
only individually to each entry of the array _(though you can always [define your
own check](#user-defined-checks) that ***does*** apply to the hash as a whole)._

You can also set up a check on a hash that verifies keys as well as (or instead of)
values...by specifying an `:of` containing a list of two checks separated by a `=>`.
The first check is then applied to any key being added to the hash, and the second check
is applied to the corresponding value being added. Hence:
```perl
my %seen    :of( INT => ANY );                # Every key in the hash must be an integer;
                                              # Stored values can be anything

my %record  :of( STR[/^[XYZ]\d+/] => DEF );   # Every key must match the specified pattern;
                                              # Every value in the hash must be defined

my %events  :of( CLASS => OBJ );              # Every key must be the name of a class;
                                              # Every value in the hash must an object
```

## Applying a check to a parameter variable

Subroutine parameters are just a special kind of variable, so they may be checked
in exactly the same ways, by applying an `:of` attribute to them:
```perl
sub enlist ($N :of(INT), $oxford :of(BOOL), @terms :of(STR))  {
               ########          #########         ########
    my $max   = min($N, scalar @terms);
    my $comma = $oxford ? ',' : '';
    return $max < 3 ? join(' and ', @terms[0..$max-1])
                    : join(', ', @terms[0..$max-2]) . "$comma and $terms[$max-1]";
}
```

Such parameter checks operate exactly like regular variable checks, and will be
applied to any subsequent modifier operation on the parameter.

> | ***Commentary*** |
> | :--------------- |
> | _A check on an array or hash is not an ***invariant*** on that variable. It is, rather, a  ***prerequisite*** for assignment into that variable. This is an important difference. An “invariant on” would guarantee that the contents of the variable must ***always*** meet a given constraint; a “prerequisite into” only guarantees that each element must be assigned values that meet the constraint ***at the moment they are assigned***. So an array such as `my @data :of(HASH[INT])` only requires that each element of `@data` must be assigned a hash whose values are integers. If you were to subsequently modify an element like so: `$data[$idx]{$key} = 'not an integer"`, the check would ***not*** fail at that point...because the assignment is not modifying `@data` directly, only retrieving a value from it and modifying the contents of another variable through that retrieved reference value. This is also the approach that Type::Tiny takes in its Type::Tie submodule._ |
> | _Of course, we ***could*** specify that checks are invariants, instead of prerequisites, but that would require that any reference value stored within a checked array or hash would have to have checks automatically and recursively applied to them as well, which would greatly increase the cost of checking, and might also lead to unexpected action-at-a-distance, when the now-checked references are modified through some other access mechanism. Moreover, we would have to ensure that such auto-subchecked references were appropriately “de-checked” if they are ever removed from the checked container. To say nothing of how we might manage any conflict if the nested referents happened to have their own (possibly inconsistent) checks. I am currently exploring these issues further in the implementation module I am building._ |


## Applying a check to a subroutine return value

In addition to checking the values that may be stored in a variable,
you can also check the return value of a subroutine. To do so,
declare the subroutine with a `:returns` attribute:
```perl
sub count_active_accts  :returns(INT)  (@acct_list) {
                        #############
    return scalar grep { $_->is_active } @acct_list;
}
```

The check is applied to every return value from the subroutine,
whether it is the result of an explicit `return` statement,
or the implicit return of its final executed expression.

The specified check is applied to calls in any context (list, scalar, or void).
In scalar context, the check is simply applied to the single return value.

In list context, the check is applied to the entire list being returned
(***not*** to each list element individually).

Hence, because the vast majority of built-in checks require a single scalar value or reference to
test, most built-in checks will fail if a list-context call happens to return more than a single element.
And because a void-context return returns no value at all (not even `undef` or an empty list),
most built-in checks will also fail in void context. For example:
```perl
    sub get_positive  :returns(INT)  (@data)  { return grep {$_ > 0} @data }
                      #############

    # Always okay in scalar context...
    $count = get_positive(-1..1);   # Okay, because grep in scalar context returns an integer count
    $count = get_positive(-3..3);   # Ditto here (even though the count is now 3, not 1)

    # Only occasionally okay in list context...
    @valid = get_positive(-1..1);   # Okay, because INT check passes when passed the one-element list (1)
    @valid = get_positive(-3..3);   # EXCEPTION, because INT test fails when passed the list (1,2,3)

    # Never okay in void context...
             get_positive(-1..1);   # EXCEPTION, because INT check fails when passed no argument
             get_positive(-3..3);   # Ditto
```

### Contextually aware checks on return values

To better support list- and void-context returns, the built-in `LIST` and `VOID` checks
can be used.

Whereas every other built-in test implicitly tests a subroutine’s return value collectively,
as a single entity, a `:returns(LIST)` tests each element of the return list individually.
Likewise, a `:returns(VOID)` only passes when the checked subroutine returns no value whatsoever,
not even `undef` or an empty list (_i.e._ only when it is called in void context).

For example:
```perl
    sub generate_data  :returns(LIST)  ($n)    { return map {rand} 1..$n }
    sub count_users    :returns(INT)   ($pat)  { return scalar grep /$pat/, @USERS }
    sub clear_screen   :returns(VOID)  ()      { print "\n" x $SCREEN_HEIGHT }

    # and then...

    my @data  = generate_data(99);        # Okay (sub returned a list)
    my $datum = generate_data(99);        # Okay (sub returned a single value – i.e. a one-element list)
                generate_data(99);        # EXCEPTION (sub didn't return a list, not even an empty list)

    my @counts = count_users(qr/^\d+$/);  # Okay (sub returned an integer – from 'scalar grep...')
    my $count  = count_users(qr/^\d+$/);  # Okay (ditto)
                 count_users(qr/^\d+$/);  # EXCEPTION (sub didn't return an integer...or anything else)

    my @cleared = clear_screen();         # EXCEPTION: Can't call VOID 'clear_screen' in list context
    my $cleared = clear_screen();         # EXCEPTION: Can't call VOID 'clear_screen' in scalar context
                  clear_screen();         # Okay
```

The `LIST` check optionally takes a [configuration parameter](#the-parameterized-list-check)
that can be used to specify a subcheck on each element of the returned list.
In that case, the return-value check only passes if every element of the returned list
individually passes the specified subcheck. For example:
```perl
    # Each item of generated data must be a number in the range [0..1]
    sub generate_data  :returns(LIST[NUM])  ($n) { return map {rand} 1..$n }
                                    #####
```
Note that had this version of `generate_data()` been implemented:
```perl
    sub generate_data  :returns(LIST[NUM])  ($n) { return map {('a'..'z')[rand 26]} 1..$n;
                                                               ###################
```
...then the return-value check would fail because, although the subroutine still returns a list,
each element of that return list fails the `NUM` check.

If you want to be able to call a checked subroutine in void context as well
(_i.e._ to just silently throw away the returned value in void contexts),
you can use a [check expression](#check-expressions) to specify that void context
is also acceptable:
```perl
    # Subroutine returns a list of hash references in list context,
    # or just the next hash reference in scalar context,
    # but cannot be called in void context...
    sub get_events  :returns(LIST[HASH])  () { return wantarray ? splice @events : shift @events; }
                             ##########

    # Same as above, but we're also allowed to just throw away the return value in void context...
    sub get_events_maybe  :returns(LIST[HASH]|VOID)  () { get_events() }
                                   ###############
```

To summarize, a subroutine declared with:

* `:returns(LIST)` always returns successfully in list and scalar contexts;
  but always dies in void context
* `:returns(LIST[subcheck])` returns successfully in list and scalar contexts ***if*** all return values pass the subcheck;
  but always dies in void context
* `:returns(check)` returns successfully in scalar contexts ***if*** the return value passes the check;
  returns successfully in list context ***if*** the returned list contains exactly one element that also passes the check;
  but always dies in void context
* `:returns(VOID)` always dies in list and scalar contexts;
  but always returns successfully in void contexts

For example:

<table>
<thead>
  <tr>
    <th>Check on<BR/>return value</th>
    <th><code>return</code> statement</th>
    <th>Return value<BR/>in list context</th>
    <th>Return value<BR/>in scalar context</th>
    <th>Return behaviour<BR/>in void context</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td><code>:returns(LIST)</code></td>
    <td><code>return&nbsp;'a'..'z'</code></span></td>
    <td><code>('a'..'z')</code></td>
    <td><code>'z'</code>
    <td>EXCEPTION<BR/><em>(Attempts to return nothing but “nothing” is not a list, so that fails the <code>LIST</code> check)</em></td>
  </tr>
  <tr>
    <td><code>:returns(LIST)</code></td>
    <td><code>return 'x'</code></td>
    <td><code>('x')</code></td>
    <td><code>'x'</code>
    <td>EXCEPTION<BR/><em>(“Nothing" is not a list)</em></td>
  </tr>
  <tr>
    <td><code>:returns(LIST)</code></td>
    <td><code>return</code></td>
    <td><code>()</code></td>
    <td><code>undef</code>
    <td>EXCEPTION<BR/><em>(“Nothing" is not a list)</em></td>
  </tr>
  <tr>
    <td colspan="5"></td>
  </tr>
  <tr>
    <td><code>:returns(LIST[INT])</code></td>
    <td><code>return 0..2</code></td>
    <td><code>(0,1,2)</code></td>
    <td><code>2</code>
    <td>EXCEPTION<BR/><em>(“Nothing" is neither a list nor an integer)</em></td>
  </tr>
  <tr>
    <td><code>:returns(LIST[INT])</code></td>
    <td><code>return 1</code></td>
    <td><code>(1)</code></td>
    <td><code>1</code>
    <td>EXCEPTION<BR/><em>(“Nothing" is neither a list nor an integer)</em></td>
  </tr>
  <tr>
    <td><code>:returns(LIST[INT])</code></td>
    <td><code>return</code></td>
    <td><code>()</code></td>
    <td>EXCEPTION<BR/><em>(<code>undef</code> fails the <code>INT</code> subcheck)</em></td>
    <td>EXCEPTION<BR/><em>(“Nothing" is neither a list nor an integer)</em></td>
  </tr>
  <tr>
    <td colspan="5"></td>
  </tr>
  <tr>
    <td><code>:returns(INT)</code></td>
    <td><code>return 0..2</code></td>
    <td>EXCEPTION<BR/><em>(List of three elements fails the <code>INT</code> check)</em></td>
    <td><code>2</code>
    <td>EXCEPTION<BR/><em>(“Nothing” fails the <code>INT</code> test)</em></td>
  </tr>
  <tr>
    <td><code>:returns(INT)</code></td>
    <td><code>return 1</code></td>
    <td><code>(1)</code></td>
    <td><code>1</code>
    <td>EXCEPTION<BR/><em>(“Nothing” fails the <code>INT</code> test)</em></td>
  </tr>
  <tr>
    <td><code>:returns(INT)</code></td>
    <td><code>return</code></td>
    <td>EXCEPTION<BR/><em>(<code>()</code> fails the <code>INT</code> test)</em></td>
    <td>EXCEPTION<BR/><em>(<code>undef</code> fails the <code>INT</code> test)</em></td>
    <td>EXCEPTION<BR/><em>(“Nothing” fails the <code>INT</code> test)</em></td>
  </tr>
  <tr>
    <td colspan="5"></td>
  </tr>
  <tr>
    <td><code>:returns(VOID)</code></td>
    <td><code>return 'a'..'z'</code></td>
    <td>EXCEPTION<BR/><em>(<code>('a'..'z")</code> isn’t “nothing”, so it fails the <code>VOID</code> test)</em></td>
    <td>EXCEPTION<BR/><em>(<code>undef</code> fails the <code>VOID</code> test)</em></td>
    <td>returns successfully</td>
  </tr>
  <tr>
    <td><code>:returns(VOID)</code></td>
    <td><code>return 'x'</code></td>
    <td>EXCEPTION<BR/><em>(<code>('x')</code> fails the <code>VOID</code> test)</em></td>
    <td>EXCEPTION<BR/><em>(<code>'x'</code> fails the <code>VOID</code> test)</em></td>
    <td>returns successfully</td>
  </tr>
  <tr>
    <td><code>:returns(VOID)</code></td>
    <td><code>return</code></td>
    <td>EXCEPTION<BR/><em>(<code>()</code> fails the <code>VOID</code> test)</em></td>
    <td>EXCEPTION<BR/><em>(<code>undef</code> fails the <code>VOID</code> test)</em></td>
    <td>returns successfully</td>
  </tr>
</tbody>
</table>


## Built-in checks

As the preceding examples imply, Perl provides a considerable number of
built-in checks, which can be applied to any variable, parameter,
or return value without the need to define them first. These built-in
checks are arranged in a coherent hierarchy of increasingly stringent
requirements.

The following table summarizes the built-on checks that Perl provides:

| Check        | Based on    | When applied to a value `$V`, the check passes if...  |
| :----------- | :---------- | :----------------------------------------------------------------- |
| `ANY`        |         | Always trivially passes (no actual test applied) |
| `LIST`       | `ANY`       | _(in `:returns` only)_ sub is returning a list of values |
| `VOID`       | `ANY`       | _(in `:returns` only)_ sub is returning in void context |
| `UNDEF`      | `ANY`       | `defined($V)` returns a false value |
| `DEF`        | `ANY`       | `defined($V)` returns a true value |
| `NONREF`     | `DEF`       | `builtin::reftype($V)` returns a false value |
| `REF`        | `DEF`       | `builtin::reftype($V)` returns a true value |
| `HANDLE`       | `DEF`   | `Scalar::Util::openhandle($V)` returns a true value |
| `BOOL`       | `NONREF`    | `$V` is not a reference, or has a `'bool'` overloading |
| `NUM`        | `NONREF`    | `$V` looks like a number (but not `'Inf'` or `'NaN'`) or has a `'0+'` overloading |
| `INT`    | `NUM`   | `$V !~ /\.|[Ee]-/` |
| `STR`        | `NONREF`    | `$V` is neither a reference nor a typeglob, or has a `'""'` overloading |
| `GLOB`       | `NONREF`   | `$V` is a typeglob |
| `UINT`       | `INT`       | `$V` has no leading sign |
| `VSTR`    | `STR`       | `Scalar::Util::isvstring($V)` returns true  |
| `CLASS`      | `STR`       | `$V` is the name of any defined class |
| `ROLE`       | `STR`       | `$V` is the name of any defined role |
| `SCALAR`     | `REF`       | `builtin::reftype($V)` returns `'SCALAR'`, or `$V` has a `'${}'` overloading      |
| `REGEXP`     | `REF`       | `builtin::reftype($V)` returns `'REGEXP'`, or `$V` has a `'qr' `overloading       |
| `CODE`       | `REF`       | `builtin::reftype($V)` returns `'CODE'`,   or `$V` has a `'&{}'` overloading      |
| `ARRAY`      | `REF`       | `builtin::reftype($V)` returns `'ARRAY'`,  or `$V` has a `'@{}'` overloading      |
| `HASH`       | `REF`       | `builtin::reftype($V)` returns `'HASH'`,   or `$V` has a `'%{}'` overloading      |
| `OBJ`        | `REF`       | `builtin::blessed($V)` returns a true value |
| `CHECK`      | `CODE`      | `$V` is a reference to built-in or user-defined check that is currently in scope  |


## Parameterized checks

Perl also supplies a number of built-in checks that can be configured
via compile-time parameters. See [the following sections](#some-notes-on-the-behaviour-of-specific-parameterized-checks) for more details.

| Check                 | Based on  | Passes if the value being checked...               |
| :-------------------- | :-------- | :------------------------------------------------ |
| `NUM[`_targ<sub>1 </sub>, targ<sub>2 </sub>, etc_`]` | `NUM`       | ...passes one of the target subchecks, or matches one of the target regexes or ranges|
| `INT[`_targ<sub>1 </sub>, targ<sub>2 </sub>, etc_`]` | `INT` | ...passes one of the target subchecks, or matches one of the target regexes, ranges, or values |
| `UINT[`_targ<sub>1 </sub>, targ<sub>2 </sub>, etc_`]` | `UINT`       |  ...passes one of the target subchecks, or matches one of the target regexes, ranges, or values |
| `STR[`_targ<sub>1 </sub>, targ<sub>2 </sub>, etc_`]` | `STR`       |  ...passes one of the target subchecks, or matches one of the target regexes, ranges, or values |
| `REF[`_subcheck_`]`     | `REF`     | ...is a reference to something that passes the specified subcheck |
| `LIST[`_valcheck_`]`      | `LIST`      | ..._(in `:returns` only)_ is a list in which the value of every element passes the specified subcheck |
| `LIST[`_len_` => `_valcheck_`]`     | `LIST`     | ..._(in `:returns` only)_ is an list whose length is the value (or range) specified, and in which the value of every element passes the specified subcheck       |
| `SEQ[`_chk<sub>1 </sub>, chk<sub>2 </sub>, ... chk<sub>N</sub>_`]` | `LIST` | ..._(in `:returns` only)_ is a list with exactly _N_ elements, where the value of the *n<sup>th</sup>* element passes the *n<sup>th</sup>* subcheck          |
| `ARRAY[`_valcheck_`]`     | `ARRAY`     | ...is an array in which the value of every element passes the specified subcheck       |
| `ARRAY[`_len_` => `_valcheck_`]`     | `ARRAY`     | ...is an array whose length is the value (or range) specified, and in which the value of every element passes the specified subcheck       |
| `TUPLE[`_chk<sub>1 </sub>, chk<sub>2 </sub>, ... chk<sub>N</sub>_`]` | `ARRAY` | ...is an array with exactly _N_ elements, where the value of the *n<sup>th</sup>* element passes the *n<sup>th</sup>* subcheck          |
| `HASH[`_valcheck_`]`      | `HASH`      | ...is a hash in which every value in the hash passes the specified subcheck               |
| `HASH[`_keycheck_`=>`_valcheck_`]`      | `HASH`      | ...is a hash in which every key passes the key subcheck and every value passes the value subcheck  |
| `DICT[`_'k<sub>1</sub>'_`=>`_v<sub>1</sub>_`,`_'k<sub>2</sub>'_`=>`_etc_`]`      | `HASH`      | ...is a hash which has **all** of the specified literal keys, and where the value stored under a given key passes the corresponding subcheck |
| `CLASS[`_classname_`]`      | `CLASS`     | ...is the name of a defined class for which `->isa(`_classname_`)`  returns a true value            |
| `ROLE[`_rolename_`]`      | `ROLE`      | ...is the name of a defined role for which `->DOES(`_rolename_`)`  returns a true value            |
| `OBJ[`_name_`]`        | `OBJ`       | ...is an object that inherits from class _name_ or composes role _name_ (_i.e._ for which `->DOES(`_name_`)`  returns a true value)  |
| `OP[`_op_`]`       | `OBJ`       | ...is an object for which `overload::Method(`_obj,op_`)` returns a true value |
| `ISA[`_classname_`]`        | `CLASS\|OBJ` | ...is a class or object for which `->isa(`_classname_`)`  returns a true value            |
| `DOES[`_name_`]`        | `CLASS\|ROLE\|OBJ` | ...is a class, role, or object for which `->DOES(`_name_`)` returns a true value            |
| `CAN[`_methodname_`]`       | `CLASS\|ROLE\|OBJ` | ...is a class, role, or object for which `->can(`_methodname_`)` returns a true value            |


## The full built-in check hierarchy

The full hierarchy of Perl built-in checks is as follows:

    ANY
     ├───VOID
     ├───LIST
     │    │───LIST[valcheck]
     │    │───LIST[len => valcheck]
     │    └───SEQ[valcheck1, valcheck2, etc]
     │
     ├───UNDEF
     └───DEF
          ├───HANDLE
          │
          ├───NONREF
          │     ├───GLOB
          │     ├───BOOL
          │     │
          │     ├───NUM
          │     │    ├───NUM[target1, target2, etc]
          │     │    │
          │     │    └───INT
          │     │         ├───INT[target1, target2, etc]
          │     │         │
          │     │         └───UINT
          │     │              └───UINT[target1, target2, etc]
          │     └───STR
          │          ├───STR[target1, target2, etc]
          │          │
          │          ├───VSTR
          │          │
          │          ├───CLASS
          │          │     ├───CLASS[classname]
          │          │     ├┈┈┈ISA[classname]
          │          │     ├┈┈┈DOES[name]
          │          │     └┈┈┈CAN[methodname]
          │          │
          │          └───ROLE
          │                ├───ROLE[classname]
          │                │┈┈┈DOES[name]
          │                └┈┈┈CAN[methodname]
          └────REF
                ├───REF[subcheck]
                ├───SCALAR
                ├───REGEXP
                │
                ├───CODE
                │    └───CHECK
                │
                ├───ARRAY
                │    ├───ARRAY[valcheck]
                │    ├───ARRAY[len => valcheck]
                │    └───TUPLE[valcheck1, valcheck2, etc]
                │
                ├───HASH
                │    ├───HASH[valcheck]
                │    ├───HASH[keycheck => valcheck]
                │    └───DICT[kc1=>vc1, kc2=>vc2, kc3=>etc]
                │
                └───OBJ
                     ├───OBJ[classname]
                     ├┈┈┈ISA[classname]
                     ├┈┈┈DOES[name]
                     ├┈┈┈CAN[methodname]
                     └┈┈┈OP[opname]


> | ***Commentary*** |
> | :--------------- |
> | _This hierarchy of checks is culled and adapted from my own previous attempts at designing type systems and parameter constraints for modules such as `Dios::Types`, `Contextual::Return`, and `Multi::Dispatch`, as well as liberal amounts of ~~blatant theft~~inspiration from Toby Inkster’s wonderful `Type::Tiny` ecosystem. The set of built-in checks is intended to be usefully comprehensive, but not overwhelmingly exhaustive._ |
>
## Why built-in checks are _LOUD_

Apart from consistency with `ref` and `reftype`, and the imperative need to separate the
namespace of built-in checks from that of user-defined checks, there is a deeper and more
important reason for making all built-in checks uppercase. Using STENTORIAN names for builtins
ensures that those names are ***ugly***, which will make users less inclined to use them.

That might initially seem crazy and counter-productive, but we really don’t want developers
using the raw built-in checks more than is strictly necessary. We want them defining their own checks,
with more meaningful, more self-documenting, and more [_intentional_](https://en.wikipedia.org/wiki/Intentional_programming)
names. Consider the following fragment of code:
```perl
    my %key_distribution :of(TUPLE[INT, STR[/[[:alpha:]]\w*/]]);
                         ######################################

    sub get_events :returns(LIST[OBJ[Event]])  ($filter :of(CODE|REGEX)) {...}
                   ##########################           ###############
```

Can you tell whether those check specifications are correct? Or what kinds of data are
actually being passed, returned, or stored here? Or why?

But if the code is written as follows, with the raw built-in checks factored out
into user-defined checks with meaningful names, we get instead:
```perl
    my %key_distribution :of(KeyDist);
                         ############

    sub get_events :returns(EventList)  ($filter :of(SmartFilter) {...}
                   ###################           ################
```
...which is considerably more likely to be correct, and certainly more maintainable.
Especially if we later decide that `SmartFilters` can also be hashes, in which case we just
update the single user-defined check, rather than locating and changing ten instances of
`:of(CODE|REGEX)` to `:of(CODE|REGEX|HASH)` _(only eight of which instances will subsequently
prove to have been actually related to smartfiltering!)_

In other words, the choice of uppercase names for built-ins is a deliberate syntactic
[“disaffordance”](https://en.wikipedia.org/wiki/Affordance):
a carefully selected psychological disincentive to discourage the use these low-level and uninformative
checks directly, and a subtle encouragement to compose them into well-named, self-explanatory,
and vastly more maintainable user-defined checks instead.


## Some notes on the behaviour of specific parameterized checks

The following subsections discuss the particulars and subtleties
of some of the more complicated built-in parameterized checks...


### The parameterized “enumerables” checks

The built-in checks `INT`, `UINT`, and `STR` all have parameterized variants.
Each of them takes an enumerated list of _target values_ and succeeds if any of those values
“match” the value being tested, where the meaning of “match” is appropriate
to the kind of check and to the particular _target value_:

* If any _target value_ is a check, then the entire parameterized check passes
  if the value being tested passes that target subcheck.

* If any _target value_ is a regex (specified either as `/pat/` or `m/pat/` or `qr/pat/`),
  then the entire parameterized check passes
  if the value being tested satisfies an `=~` match on that target regex.

* If any _target value_ is an integer, then the entire parameterized check passes
  if the value being tested satisfies a `==` test against that target.

* If the _target value_ is anything else (effectively: a string),
  then the entire parameterized check passes
  if the value being tested passes an `eq` test against that target.

For example:
```perl
    # Can only specify text format as 'pod', 'markdown', 'HTML', or 'XHTML'...
    sub format_text_as ($text :of(STR), $format :of(STR['pod','markdown',/X?HTML/]) {...}
                                                    ##############################

    # Identify a specific Platonic solid by its number of faces...
    my $platonic_faces  :of(UINT[4,6,8,12,20])  = 4;
                            #################

    # Must return an integer in the range -100..100, inclusive...
    sub get_popularity  :returns(INT[-100..100])  {...}
                                 ##############
```

Note that, target lists that are specified as Perl ranges (_e.g._ `INT[-100..100]`
or `STR['AAA00000'..'ZZZ99999']`) are ***never*** expanded into an explicit list of –
for example – 202 integers or 1037845224 strings. They are, instead, always
internally implemented as: `(MIN <= $testvalue <= MAX)` or `(MIN le $testvalue le MAX)`.

Note too that strings may be specified using the `'...'` or `q{...}` notations,
or using the `"..."` or `qq{...}` notations. However, because these strings
are being specified inside an attribute (_i.e._ in the parens of an `:of(...)` or `:returns(...)`),
you ***cannot*** interpolate variables into the double-quoted forms.
Attributes are themselves mostly just a kind of single-quoted compile-time string,
so variables simply don’t interpolate into them at all. The same restriction applies
to regexes used in any parameterized check: they cannot include interpolated variables.


### The parameterized `NUM` check

There is no full equivalent “target-matching” parameterized version of `NUM`
(_i.e._ no version of `NUM[...]` that can accept an explicit list of numbers to match).
This is because the `==` operator is unreliable on non-integer numbers,
which would all too frequently lead to equally unreliable (_i.e._ completely useless) checks:
```perl
    # Hypothetical NUM with target list of permissible values (this is NOT actually allowed)...
    my $coefficient :of(NUM[0.1, 0.3, 0.5])  =  0.1 + 0.2;
                            #############
    # Because, if it were allowed, you'd get a frustrating runtime error like this:
    #
    #     Can't assign 0.3 to $coefficient: failed NUM[0.1, 0.3, 0.5] check
    #
    # ...unless the error message could somehow decide to show enough precision to make
    # the cause of the failure (marginally) less puzzling:
    #
    #     Can't assign 0.30000000000000004 to $coefficient: failed NUM[0.1, 0.3, 0.5] check
    #
    # ...which is still confusing because where the heck did that extra forty quintillionths
    # come from when adding two numbers as simple as 0.1 and 0.2???
```

However, there _is_ a parametric form of `NUM` that _does_ accept
a slightly more limited list of targets, namely: ranges, regexes, or subchecks:
```perl
    my $coefficient :of(NUM[0.1..0.5])        =  0.1 + 0.2;   # Okay (value within specified range)
                            ########

    my $coefficient :of(NUM[qr/^0\.[1-4]/])   =  0.1 + 0.2;   # Okay (value matches specified regex)
                            #############

    my $coefficient :of(NUM[LessThan[1]])     =  0.1 + 0.2;   # Okay (value passes user-defined subcheck)
                            ###########
```

Ranges are (of course) converted to tests of the form `MIN <= $value <= MAX`, but you can also
specify numeric ranges that _exclude_ one or both of their end-points, using a special non-standard
numeric-range syntax that adds a `<` to either end of the `..`, like so:
```perl
    my $probability  :of(NUM[0 ..< 1])        = rand();            # Requires: 0 <= $probability < 1
                               ###

    my $increment    :of(NUM[0 <.. 99.9])     = get_increment();   # Requires: 0 < $increment <= 99.9
                               ###

    my $offset       :of(NUM[-100 <..< 100])  = get_offset();      # Requires: -100 < $offset < 100
                                  ####
```

You can also specify semi-infinite numeric ranges:
```perl
    my $chess_ranking  :of(NUM[0..inf])   = 2882;       # Any number: zero or greater

    my $student_loan   :of(NUM[-inf..0])  = -1.234e56;  # Any number no greater than zero
```
However, if you do this, you still can’t assign actual infinite values to such variables:
```perl
    $chess_ranking = 'Inf';     # EXCEPTION, because NUM specifically excludes 'Inf' as a value

    $student_loan  = -INF;      # EXCEPTION, because NUM specifically excludes -Inf as a value too
```

Note that attempting to configure `NUM[...]` with an argument that is a single number
_(even sneakily, via something like: `NUM[0.3..0.3]`)_ ***always*** produces a compile-time error.

Keep in mind, however, that despite the various safeguards built into this check,
`NUM[...]` is still subject to all the limitations, unreliability, and general lack
of _do-what-I-meanness_ of regular floating-point numbers in Perl.

Even specifying a numeric check as a range will not always produce reliable outcomes,
especially for floating-point values on the boundaries of the range. For example:
```perl
    my $coefficient :of(NUM[0..0.3])  =  0.1 + 0.2;            # EXCEPTION (value NOT in specified range)

    my $summation   :of(NUM[1<..<9])  =  sum( (0.01) x 100 );  # NO EXCEPTION (value unexpectedly in range)
```

In particular, don’t use numeric ranges to validate monetary amounts:
```perl
    # We only accept payment in coins for totals under €1...
    sub accept_coin_payment_for ($amount :of(NUM[0.00 .. 0.99])) {...}

    # And later...
    accept_coin_payment_for( 0.1 + 0.2 + 0.3 + 0.39 );  # EXCEPTION (value NOT in specified range)
```


### The parameterized `REF` check

The `REF` check has a parameterized form that allows you to specify a check for a multi-level
reference. This is (very occasionally) needed because Perl does allow references-to-references,
references-to-references-to-references, _etc._, and you may need to check them.

The unparameterized `REF` check passes when the value it is checking is a reference to anything
(including to another reference). The parameterized `REF[`_subcheck_`]` check requires that
the value passed is a reference, and that its referent (the thing it is referring to)
also passes the specified subcheck.

For example:

| `REF[`_what_`]` | Description | Passes if `reftype($V)`) is true and... | For example... |
| :-------------- | :---------- | :-------------------------------------- | :------------- |
|`REF[STR]` | Reference to a string | ...`${$V}` passes `STR` check | `\"a string"` |
|`REF[GLOB]` | Reference to a typeglob | ...`${$V}` passes `GLOB` check | `\*STDIN` |
|`REF[VSTR]` | Reference to a vstring | ...`${$V}` passes `VSTR` check | `\v1.2.3` |
|`REF[INT]` | Reference to an integer | ...`${$V}` passes `INT` check | `\42` |
|`REF[ARRAY]` | Reference to an array reference | ...`${$V}` passes `ARRAY` check | `\\@data` or `\[1,2,3]` |
|`REF[REF]` | Reference to any kind of reference | ...`${$V}` passes `REF` check | `\\42` or or `\\"a string"` or `\\@data` |

Note that this also implies that the unparameterized `REF` check is equivalent to `REF[ANY]`.

Note too that if the subcheck is itself a referential check (e.g. `REF[REF]`, `REF[ARRAY]`, `REF[HASH]`,
_etc._), the parameterized `REF` check will only succeed when the value being assessed
is a “double-reference”. That is, a check such as `REF[ARRAY]` will pass only if the value
is a ***reference to a reference to*** an array (_e.g._ `\\@array` or `\[1,2,3]`),
but will not pass if the value is just a ***reference to*** an array (_e.g._ `\@array` or `[1,2,3]`).
That’s because:
```
                                    REF[ ARRAY ]
                                     │     │
    Match a reference to... ─────────┘     │
    ...a reference to an array ────────────┘

```

### The parameterized `ARRAY` check

The `ARRAY` check also has a parameterized form that can be configured with a single subcheck.
That subcheck is then applied to every element within the array. For example:
```perl
    # Scalar stores a reference to an array in which every element must be a number...
    my $scores_ref :of(ARRAY[NUM]) = [];
                       ##########

    # Subroutine expects an argument that is a reference to an array of hashrefs...
    sub process_records ($records_ref :of(ARRAY[HASH])) {...}
                                          ###########
```

A parameterized `ARRAY` check can also be configured with two arguments, in which case
the first argument is either an unsigned integer specifying the required length of the
array, or a range of unsigned integers specifying the allowable range of lengths. The
second argument must then be a subcheck that is (as usual) applied to every element within the array.
For example:
```perl
    # Scalar stores a reference to an array of exactly 10 numbers...
    my $scores_ref :of(ARRAY[10 => NUM]) = [0..9];
                            ######

    # Subroutine expects an argument that is a reference to an array of no more than three hashrefs...
    sub process_records ($records_ref :of(ARRAY[0..3 => HASH])) {...}
                                                #######

    # Subroutine returns a reference to an array of at least 3 Event objects...
    sub get_events :returns(ARRAY[3..inf => OBJ[Event]]) () {...}
                                  #########
```

To specify a required length for an array reference, without constraining what kinds of values
it can hold, simply make the second argument an `ANY`:
```perl
    # Subroutine returns a reference to an array with one or more elements of some kind...
    sub get_data :returns(ARRAY[1..inf => ANY]) () {...}
                                #########
```



### The parameterized `LIST` check

The `LIST` check also has a parameterized form, which is a close analogue
of the parameterized `ARRAY` check.

The `LIST` check can be configured with a single subcheck,
which is then applied to every element within the return list:
```perl
    # Subroutine must return a list of numbers...
    sub get_samples  :returns(LIST[NUM])  {...}
                              #########

    # Subroutine must return a list of objects of class Event (or some subclass thereof)...
    sub get_samples  :returns(LIST[OBJ[Event]])  {...}
                              ################
```

Like the `ARRAY` check, the parameterized `LIST` check can also be configured with two arguments,
to specify both a required length (or range of acceptable lengths) and a per-element subcheck:
```perl
    # Subroutine must return a list of 13 numbers...
    sub get_samples  :returns(LIST[13 => NUM])  {...}
                                   #########

    # Subroutine must return a list of one or more objects of class Event (or some subclass thereof)...
    sub get_samples  :returns(LIST[1..inf => OBJ[Event]])  {...}
                                   ####################
```

Note the difference between specifying a `LIST` check and an `ARRAY` check
for the `:returns` attribute of a subroutine:
```perl
    # Must return a single scalar value: a reference to an array that must contain only integers...
    sub get_next_client  :returns(ARRAY[INT])  () {...}
                                  ##########

    # Must return a list that must contain only integers...
    sub get_next_client  :returns(LIST[INT])   () {...}
                                  #########
```



### The parameterized `HASH` check

The `HASH` check also has a parameterized version. It can be configured
with a single argument that’s another check. That subcheck is then
applied to every value stored in the hash reference. For example:
```perl
    # Every exam result in the hashref must be an integer between -1 and 100...
    my $exam_results_ref  :of(HASH[ INT[-1..100] ])  = {};
                              ####################

    # Sub returns a reference to a hash of objects...
    sub get_event_handlers  :returns(HASH[OBJ])  {...}
                                     #########
```

When the `HASH` check is configured with two arguments, each of which is itself a check,
those subchecks are applied, respectively, to every key and every value stored in the hash reference.
For example:
```perl
    # Each key must match the specified pattern and each value must be a number between 0 and 1...
    my $client_rating  :of(STR[/[XYZ]\d+/] => NUM[0..1])  = {};
                           ############################

    # Reverse look-up table for exam results
    # (each key must be a -1..100 integer; each value must be a reference to an array of student names)...
    my $students_ref  :of(HASH[ INT[-1..100] => ARRAY[STR] ])  = {};
                          ##################################

    # Sub returns a reference to a hash of objects, where each key must be a classname...
    sub get_event_handlers  :returns(HASH[CLASS => OBJ])  {...}
                                     ##################
```


### The parameterized `TUPLE` check

The parameterized `TUPLE` check requires the value it is testing to be an array reference,
and that the array should also have a specific size and structure.

When configured with zero or more subchecks, the number of subchecks specifies the exact number
of elements the arrayref must contain, and that the _n<sup>th</sup>_ element in the array must
pass the _n<sup>th</sup>_ subcheck. In other words, this kind of check allows you to require an
arrayref that is a _fixed tuple_ with the specified format. For example:
```perl
    # A client record is areference to an array containing a name (a string),
    # an ID number (an integer), and some data (a hashref), in that order...
    sub get_next_client  :returns(TUPLE[STR,INT,HASH])  () {...}
                                  ###################

    # Track minimum and maximum values in a single arrayref...
    my $range  :of(TUPLE[NUM,NUM])  =  [0, $MAXNUM];
                   ##############
```


### The parameterized `SEQ` check

The `SEQ` check is a close analogue of the parameterized `TUPLE` check,
but exclusively applicable to subroutine return lists, instead of arrayrefs.

When a `SEQ` check is configured with zero or more arguments, the number of subchecks
specifies the exact number of elements the return list must contain, and that
the _n<sup>th</sup>_ element in the list must pass the _n<sup>th</sup>_ subcheck.
In other words, this kind of check requires a subroutine to return a _fixed tuple list_
with the specified structure. For example:
```perl
    # Subroutine returns a list of error information:
    # errorcode (an integer), severity level (a non-negative integer < 12), error handler (a subref)...
    sub get_error  :returns(SEQ[INT, UINT[0..11], CODE])  {...}
                            ###########################

    # Subroutine returns a list of exactly three names (family, middle, first).
    # The family name must contain at least one alphabetic character...
    sub get_name  :returns(SEQ[ STR[/[[:alpha:]]/], STR, STR ])  {...}
                           ###################################
```

Note the difference between specifying a `SEQ` check and an `TUPLE` check for
the `:returns` attribute of a subroutine:
```perl
    # Must return a single scalar value: a reference to an array with exactly three specific elements.
    sub get_next_client  :returns(TUPLE[STR,INT,HASH])  () {...}
                                  ###################

    # Must return a list with exactly three specific elements.
    # (This subroutine can only be called in list context, because it has to return three values)...
    sub get_next_client  :returns(SEQ[STR,INT,HASH])  () {...}
                                  #################
```

### The parameterized `DICT` check

The parameterized `DICT` is analogous to the `TUPLE` and `SEQ` checks, but for hashrefs.

When configured with a “KV” list of zero or more arguments (_i.e._ where every odd argument is a
string and the total number of arguments is a multiple of two), then the odd configuration arguments
specify the literal keys that the hash is required to contain, and the even arguments specify a set
of subchecks to be applied to the corresponding value for each key. In other words, this configuration
specifies that the hash must act as a _“fixed dictionary”_ with an exact set of keys whose
corresponding values pass specific subchecks. The order in which the keys are specified is,
of course, irrelevant.

For example:
```perl
    # An identity must be a hash with an ID number and a challenge code...
    my $ident :of(DICT[ 'ID' => UINT, 'challenge' => STR[qr/\d{6}/] ])  = get_identity();
                  ###################################################

    # Sub must be passed a reference to a hash with required keys 'name', 'age', and 'shoesize',
    # where each key's value must pass a check appropriate to that particular entry
    # (ages in whole years, shoe sizes in EU standard)...
    sub validate  ($candidate :of(DICT[ name=>STR, age=>UINT[0..120], shoesize=>NUM[33.5 .. 48] ]))  {...}
                                  ###############################################################
```


### Optional elements in tuples, sequences, and dictionaries

The `TUPLE`, `SEQ`, and `DICT` checks normally specify an exact number of elements that
must be present in an array, list, or hash. However it is possible to specify that
some of the elements you are specifying are ***optional*** and that the check
should still succeed if they are not present.

To specify an optional element in a `TUPLE`, `SEQ`, or `DICT`, simply enclose the
specific check for that element in an `OPT[...]`. For example:
```perl
    # Each client record is a list containing a name (a string), then an ID number (an integer),
    # then some data (a hashref), and finally an optional flag (a string)...
    sub get_next_client  :returns(SEQ[STR, INT, HASH, OPT[STR]])  () {...}
                                                      ########

    # Track minimum and maximum values in a single arrayref
    # The maximum value is optional...
    my $range  :of(TUPLE[NUM, OPT[NUM]])  =  [0];    # Okay to initialize with a 1-element arrayref
                              ########

    # Sub must be passed a reference to a hash with required keys 'name' and 'age'.
    # The hash may also have an optional 'shoesize' entry...
    sub validate ($data :of(DICT[ name=>STR, age=>UINT[0..120], OPT[shoesize=>NUM[33.5 .. 48]] ]))  {...}
                                                                ##############################
```

Note that any `OPT[...]` subchecks must always come after all non-`OPT` subchecks.

Note too that, when specifying optional components of a `DICT[...]`, both the key string
***and*** the value subcheck must be together inside the `OPT[...]`. _(It doesn’t make
sense to specify a required key with an optional value: if the key is present in
the hash, it ***will*** have some value, even if that value is only `undef`.)_

If you specify two or more optional elements in a `TUPLE` or `SEQ`, they become
_“progressively optional”_ (like optional parameters in a subroutine signature).
That is, once a `TUPLE` or `SEQ` omits any optional subcheck, it must omit
all the following ones as well. For example:

```perl
    # The final flag, counter, and callback are progressively optional...
    # (i.e. your list can be missing the final 1, 2, or 3 elements)...
    sub get_next_client  :returns(SEQ[STR, INT, HASH, OPT[STR], OPT[INT], OPT[CODE]])  () {...}
                                                      #############################
```


### Ignorable elements in tuples, sequences, and dictionaries

You can also specify that a `TUPLE`, `SEQ`, or `DICT` may contain zero or more extra trailing elements,
which need not be checked at all (_i.e._ analogous to a final slurpy parameter in a subroutine signature).
You do this by adding the special subcheck `ETC` as the final element (**without** an associated key, in
the case of a `DICT`).
For example:
```perl
    # Takes a single parameter: a reference to a hash with (at least) 'name' and 'ID' keys...
    sub add_client( $data :of(DICT['name' => STR, 'ID' => UINT, ETC]) ) {...}
                                                                ###

    # Returns 3 (or more) elements...
    sub call_context :returns( SEQ[STR, STR, UINT, ETC] ) {...}
                                                   ###
```

Note that you can specify both `OPT[...]` and `ETC` subchecks within the same
parameterized check. In such cases, the `ETC` must still be the final subcheck.


### Repeatable elements in tuples and sequences

Provided they don’t specify optional or slurpy components, the `TUPLE` and `SEQ` checks
each require the array or list they are validating to have exactly _N_ elements; one for
each subcheck they specify.

A common variation on this theme is to have an array or a list that contains zero or more
consecutive subsequences, each of _N_ elements. For example, a list of _(key, value, key, value, ...)_,
or an array containing triples of _[name, rank, serial-number, name, rank, serial-number, ...]_.

To allow checking of such repeated tuples and sequences, the built-in `REP` subcheck
is available. This subcheck can only be used as the final configuration argument within
a `TUPLE` or `SEQ` check. It takes _N_ subchecks and applies them to each successive
subsequence of _N_ elements in turn. For example:
```perl
    # The enlist() subroutine takes a reference to an array of any number of name-rank-ID triples
    # and converts those triples to a list of ID => object pairs...

    sub enlist  :returns(SEQ[REP[STR, OBJ[Soldier]]])  ($data :of(TUPLE[REP[STR, STR, UINT]]))  {...}
                             ######################                     ###################
```

A `REP` subcheck does not have to be the only configuration argument of its containing
`TUPLE` or `SEQ` check, merely the final one. For example, you could specify a tuple
that starts with an integer, then contains an alternating sequence of strings and hashrefs:
```perl
    # An arrayref containing an initial integer, then one-or-more string-hashref pairs...
    my $data  :of(TUPLE[INT, REP[STR, HASH]])  =  get_data();
                             ##############
```

Note that the trailing elements of an array or list that is being checked by a `REP`
subcheck must have in total some non-zero integer multiple of _N_ elements.
If you need to allow for the possibility that a repeated subarray or sublist
can repeat zero times, make the entire `REP` optional:
```perl
    # An arrayref containing an initial integer, then zero-or-more string-hashref pairs...
    my $data  :of(TUPLE[INT, OPT[REP[STR, HASH]]])  =  get_data();
                             ###################
```

### Summary of list- and container-related parameterized checks

<table>
<thead>
  <tr>
    <th colspan="3"><em></em></th>
  </tr>
  <tr>
    <th>Subroutine return lists</th>
    <th>Array references</th>
    <th>Hash references</th>
  </tr>
</thead>
<tbody>
  <tr>
    <td colspan="3"><br/><em>Every value in the list or container variable passes check <code>C</code></em></td>
  </tr>
  <tr>
    <td><code><strong>LIST[</strong>C<strong>]</strong></code></td>
    <td><code><strong>ARRAY[</strong>C<strong>]</strong></code></td>
    <td><code><strong>HASH[</strong>C<strong>]</strong></code></td>
  </tr>
  <tr>
    <td colspan="3"><br/><em>List or container variable has <code>N</code> values, each of which passes the same check <code>C</code></em></td>
  </tr>
  <tr>
    <td><code>LIST[<strong>N => C</strong>]</code></td>
    <td><code>ARRAY[<strong>N => C</strong>]</code></td>
    <td><em>n/a<em></td>
  </tr>
  <tr>
    <td colspan="3"><br/><em>Every key passes check <code>K</code>, and every value passes check <code>V</code></em></td>
  </tr>
  <tr>
    <td><em>n/a<em></td>
    <td><em>n/a<em></td>
    <td><code>HASH[<strong>K => V</strong>]</code></td>
  </tr>
  <tr>
    <td colspan="3"><br/><em>Has exactly <em>N</em> elements, where each element passes the corresponding check</em></td>
  </tr>
  <tr>
    <td><code><strong>SEQ[</strong>C<sub>1</sub>, C<sub>2</sub>, C<sub>3</sub><strong>]</strong></code></td>
    <td><code><strong>TUPLE[</strong>C<sub>1</sub>, C<sub>2</sub>, C<sub>3</sub><strong>]</strong></code></td>
    <td><code><strong>DICT[</strong>'k<sub>1</sub>'=>C<sub>1</sub>, 'k<sub>2</sub>'=>C<sub>2</sub>, 'k<sub>3</sub>'=>C<sub>3</sub><strong>]</strong></code></td>
  </tr>
  <tr>
    <td colspan="3"><br/><em>Trailing elements may be explicitly marked optional, or ignored entirely</em></td>
  </tr>
  <tr>
    <td>
    <code>SEQ[C<sub>req</sub>, <strong>OPT[</strong>C<sub>opt</sub><strong>]</strong>, <strong>ETC</strong>]</code>
    </td>
    <td>
    <code>TUPLE[C<sub>req</sub>, <strong>OPT[</strong>C<sub>opt</sub><strong>]</strong>, <strong>ETC</strong>]</code>
    </td>
    <td><code>DICT['k<sub>req</sub>'=>C<sub>req</sub>, <strong>OPT[</strong>'k<sub>opt</sub>'=>C<sub>opt</sub><strong>]</strong>, <strong>ETC</strong>]</code></td>
  </tr>
  <tr>
    <td colspan="3"><br/><em>Has some positive multiple of N elements, in which each successive subsequence of N elements passes the corresponding checks</em></td>
  </tr>
  <tr>
    <td>
    <code>SEQ[<strong>REP[</strong>C<sub>1</sub>, C<sub>2</sub>, C<sub>3</sub><strong>]</strong>]</code>
    </td>
    <td>
    <code>TUPLE[<strong>REP[</strong>C<sub>1</sub>, C<sub>2</sub>, C<sub>3</sub><strong>]</strong>]</code>
    </td>
    <td><em>n/a<em></td>
  </tr>
</tbody>
</table>


## Check expressions

Two or more checks can be composed into a new check using any combination
of the following operators (listed here in order of descending precedence):

| Operator | Resulting check... |
| :------: | :---------------------- |
| `(` _C_ `)`    | ...succeeds if its single operand check succeeds |
| `!` _C_      | ...succeeds if its single operand check fails |
| _C1_ `&` _C2_  | ...succeeds only if both its operand checks succeed (and short-circuits if the left check fails) |
| _C1_ `\|` _C2_ | ...succeeds if either of its operand checks succeeds (and short-circuits if the left check succeeds) |

Hence you can specify that a variable must store only subroutine references,
but that it can also be undefined:
```perl
    my $var :of(CODE|UNDEF);      # (Don’t need to initialize, because default initializer is undef)
                ##########
```
...or that a subroutine may return either a typeglob or an `IO::Handle` object:
```perl
    sub get_fh :returns(GLOB | OBJ[IO::Handle]) {...}
                        ######################
```
...or that an array stores a list of `Account` objects, but not if they’re implemented as
hashes or arrays:
```perl
    my @accounts :of(OBJ[Account] & !(HASH|ARRAY));
                     ############################
```
User-defined checks (see the next subsection) can also be used as operands
to these check operators.

> | ***Commentary*** |
> | :--------------- |
> | _The junctive operands on checks could have been `&&` and `\|\|`, but this would have made compound checks slightly less compact, which is likely to be a disadvantage in long multi-parameter lists. Far more importantly, however, using `&&` and `\|\|` as operators on checks would be replaying the tragedy of [magical `when` expressions](https://metacpan.org/dist/perl/view/pod/perlsyn.pod#Experimental-Details-on-given-and-when), by introducing yet another special case where these (normally) logical operators do not actually impose boolean context directly on their arguments. By using `&` and `\|` we are, admittedly, overloading the meaning of those two bitwise operators instead, but that is entirely acceptable in Perl because `&` and `\|` are [explicitly overloadable](https://metacpan.org/pod/overload#Overloadable-Operations), whereas `&&` and `\|\|` are ***not***._ |


## User-defined checks

The built-in checks provided by Perl cover a wide range of typical uses, but are certainly
not sufficient to handle every possible data-checking requirement.

In addition, the names of the built-in checks are accurate but not very informative:
in a check such as `TUPLE[REP[STR, STR, UINT]]` it is not obvious that each triple we
are expecting here represents a name, a rank, and an ID number.

Moreover, built-in checks like that can become unwieldy as they become more complex.
When you are attempting to check a large collection of related variables, parameters,
and/or return-values, it would be gratifying if you did _not_ have to respecify something
tedious like `DICT[ name => STR, age => UINT[0..120], shoesize => NUM[33.5..48] ]`
separately on every one of them.

So it is essential to be able to define new kinds of checks, and to be able to give
long check expressions a single, much shorter name; one which is also likely to be more
intentional and informative.

New checks can be specified using the keyword `check`:

<code>&nbsp;&nbsp;&nbsp;&nbsp;<strong>check</strong>  <em>NAME</em>  <em>ATTRS<sub>OPT</sub></em>  <strong>(</strong><em>CHECK_PARAMS<sub>OPT</sub></em><strong>)</strong>  <strong>{</strong> <em>IMPLEMENTATION</em> <strong>}</strong>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code>

And new names/aliases for existing checks can be specified using a variation of that same syntax:

<code>&nbsp;&nbsp;&nbsp;&nbsp;<strong>check</strong>  <em>NAME</em>  <strong>:isa(</strong><em>EXISTING_CHECK</em><strong>)</strong>  <em>OTHER_ATTRS<sub>OPT</sub></em> <strong>;</strong>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code>

Whereas Perl’s built-in checks are universally available, both these kinds of user-defined
checks are always ***lexical*** in scope, and hence only available from the first statement
after they are declared to the end of the surrounding block or file.

Specifically, checks are implemented a special kind of intangible lexical subroutine,
hidden in their own private namespace, so they are not directly callable for within
their scope (nor do they pollute that scope’s lexical subroutine namespace).
Hence you can specify a check and a subroutine with the same name;
there is no ambiguity or conflict between the two.

The _`NAME`_ of a check is an unqualified Perl identifier, which must contain
at least one upper-case character and at least one lower-case character.
Checks with purely upper-case names are reserved for current and future
built-in checks. Checks with purely lower-case names are also reserved
...for unspecified future use. It is a compile-time error to declare
a user-defined check with a single-cased name.

The implementation of the check is its block of code, which will be passed
the value to be tested via the check’s single parameter. You can, of course,
name that parameter whatever you wish:
```perl
    check OddNum         ($n)     { $n % 2 != 0      }
    check LongStr        ($str)   { length($str) > 8 }
    check NonEmptyArray  ($aref)  { $aref->@* != 0   }
```
...but however it is declared, that parameter must accept the scalar value
that it will be passed every time the check is called upon to test a variable assignment
or a subroutine’s return value.

The check block is expected to return a boolean value indicating whether
or not the check succeeded. If the code block returns a true value,
the check is considered to have succeeded and execution continues silently.
If the code block returns false, the check is considered to have failed
and a suitable exception is automatically thrown.

> | ***Commentary*** |
> | :--------------- |
> | _User-defined checks could have been be package-scoped or universal, but that would be considerably less robust than lexical scoping: two modules could define two distinct checks with the same name, which might make it impossible to use both modules in the same program, or would at least make it hard to be sure what a given check name means in each namespace._ |
> | _We could allow user-defined checks to have uppercased names in order to permit built-in checks to be lexically overridden within their scope. However, this would make it impossible to tell at a glance whether `:of(INT)` means what it appears to mean (_i.e._ what it usually means) without scanning for redefinitions upwards through all outer lexical scopes. It is safer to prohibit such cleverness...at least initially._ |


### Attributes for user-defined checks

User-defined check declarations may take any combination of the following four attributes,
all of which are optional:

| Attribute | Purpose |
| :-------- | :----------------------------------------------------------------------------- |
| `:isa`      | Specifies the base check(s) that the new check is extending...and which the new check must still pass. |
| `:params`   | Specifies the list of configuration parameters for a parametric check.         |
| `:on`       | Restricts the kinds of declarations to which a check may be applied.                |
| `:export`   | Specifies that the check is also to be made available in any lexical scope into which the current module is imported. |

The purpose and use of these attributes is described in the following subsections.


### Check inheritance

The `:isa` attribute indicates that a new check must first pass the “base” check
specified within the attribute, and must then also pass its own test (if any).
For example:
```perl
    # Value must be a number...that is also greater than zero...
    check PosNum  :isa(NUM)  ($value)  { $value > 0 }
                  #########

    # Value must be a reference to a container...that also has no elements/entries...
    check Empty   :isa(ARRAY|HASH)  ($value)  { (ref $value eq 'ARRAY' ? $value->@* : $value->%*) == 0 }
                  ################
```
The `:isa` attribute is optional, in which case the code block specifies the entire
check by itself:
```perl
    # Value must be a safe password (at least one alpha, numeric, and symbol)...
    check SafePwd  ($value)  { given ($value) { /[[:alpha:]]/ && /\d/ && /[[:punct:]]/ && !/password/i } }

    # Value must not be any kind of reference...
    check NonRef   ($value)  { !defined ref $value }
```

Inheritance is also the mechanism by which long compound checks
can be given simpler and more meaningful names. If the block
at the end of a check definition is omitted entirely,
then the check must specify an `:isa` and that check simply becomes an alias for
whatever its base check specifies (but under a more concise and comprehensible name).
For example:

```perl
    check IDNum          :isa( UINT );

    check MaybeCode      :isa( CODE|UNDEF );

    check Writeable      :isa( GLOB | OBJ[IO::Handle] );

    check NamesRanksIDs  :isa( TUPLE[REP[STR, STR, UINT]] );

    check ModernAccount  :isa( OBJ[Account] & !(HASH|ARRAY) );

    check ValidKeyVal    :isa( HASH[ STR['all', 'first', 'random'] => DEF ] );

    check ShoeData       :isa( DICT[name=>STR, age=>UINT[0..120], shoesize=>NUM[33.5..48]] );
```

With these check definitions in scope, we can then apply clearer and more meaningful
constraints to variables and subroutines:

```perl
    sub select_team :returns(NamesRanksIDs) ($selector :of(ValidKeyVal)) {...}
                             #############                 ###########

    my $shoe_spec :of(ShoeData) = get_shoe_data();
                      ########

    sub report_accounts ($to :of(Writeable), @accts :of(ModernAccount)) {...}
                                 #########              #############
```


### Parametric user-defined checks

If a check is specified with a `:params` attribute, the contents of that attribute are
interpreted as a _signature_ specifying the list of compile-time configuration parameters
that the check requires when it is subsequently used. These configuration arguments
are, as we have seen, passed to the check in a pair of square brackets placed
immediately after the check’s name (with no intervening space).

The arguments bound to those configuration parameters are then
available as runtime constants within the check’s body. For example:
```perl
    # Must be a number between MIN and MAX...
    check RangeNUM  :params($MIN, $MAX)  :isa(NUM)  ($value)  { $MIN <= $value <= $MAX }
                           ############                         ####              ####

    # Must be a string of at least N characters...
    check LongSTR   :params($N)          :isa(STR)  ($value)  { length $value >= $N }
                           ####                                                  ##

    # And then we can use the new parametric checks, by supplying them with appropriate arguments...

    my $scale  :of(RangeNum[-1, +1]) = 0;
                           ########

    my $passwd :of(LongStr[12])      = '?' x 12;
                          ####
```

Note that, as illustrated in the preceding examples, it is a convention (but not a requirement)
to specify configuration parameters with upper-case names, to reflect the fact that these
parameters are bound at compile-time and effectively become constants at run-time.

Furthermore, because the configuration parameters *are* bound at compile-time,
they can only be passed compile-time constants. Specifically, they ***cannot***
be passed variables of any kind.. The following will not work as desired:
```perl
    my ($from, $to) = (10,99);

    my $scale  :of(RangeNum[$from, $to]) = $to;
    my $passwd :of(LongStr[$from])        = '?' x $from;
```
...because the `$MIN` and `$MAX` configuration parameters would be passed the literal strings
`'$from'` and `'$to'`, rather than the contents of the variables `$from` and `$to`.

Instead you would need to create check aliases for the desired compile-time
minimal and maximal constants:
```perl
    check ActiveRange :isa(RangeNum[10,99]);
    check MinStrLen   :isa(LongStr[10]);

    my $scale  :of(ActiveRange) = $to;
    my $passwd :of(MinStrLen)   = '?' x $from;
```
...or else redesign the two checks so that you can pass them named compile-time constants
instead of literals:
```perl
    check RangeNUM  :params($MIN, $MAX)  :isa(NUM)  ($value)  {
        no strict 'refs';
        (eval{$MIN->()} // $MIN) <= $value <= (eval{$MAX->()} // $MAX);
    }

    check LongSTR   :params($N)          :isa(STR)  ($value)  {
        no strict 'refs';
        length $value >= (eval{$N->()} // $N);
    }

    use constant { FROM => 10, TO => 99 };

    my $scale  :of(RangeNum[FROM, TO]) = 0;
                           ##########

    my $passwd :of(LongStr[FROM])        = '?' x FROM;
                          ######
```

This is, of course, less than ideal, but is mandated by the fundamental limitations
of Perl attributes (namely, that they are compile-time literal strings,
not run-time expressions).

The configuration parameter list is just like any regular subroutine parameter list
(except for the `:params` prefix), so you can specify your final configuration parameter
as a slurpy array to allow parameterized checks to be configured with
an arbitrary number of positional configuration parameters. For example:
```perl
    # Like TUPLE[...], but the elements can be in any order...
    check UnorderedTuple  :params(@ELEM_CHECKS)  :isa(ARRAY)  ($aref) {
                                  ############
        # Fails if the number of elements is different from the number of checks...
        return 0 if $aref->@* != @ELEM_CHECKS;
                                 ############
        # Verify that every element passes one distinct check...
        my %already_used;
        ELEM:
        for my $next_elem ($aref->@*) {
            for my $next_subcheck (grep {!$already_used{$_}) @ELEM_CHECKS)) {
                # Remember which subchecks pass...           ############
                if ($next_subcheck->($next_elem)) {
                    $already_used{$next_subcheck}++;
                    next ELEM;
                }
            }
            # No subcheck satisfied by this element, so fail...
            return 0;
        }

        # Every element passed one subcheck, so succeed...
        return 1;
    }

    # And then...

    sub get_next_record :returns( UnorderedTuple[ARRAY[NUM], INT, STR] ) ($ID) {...}
                                  ####################################
        ...
        return [$count, \@scores, $name];   # Okay, even though order is: INT, ARRAY[NUM], STR
    }
```

Likewise, you can specify a suitably checked slurpy hash as a check’s final
(or only) parameter, to indicate that the check takes alternating _key_ => _value_
configuration arguments:
```perl
    # Must be a "KV" list containing the specified keys,
    # where each value passes the corresponding subcheck.
    # That is: Like a DICT, but for subroutine return lists...
    check KVList  :params(%STRUCTURE)  :isa(LIST)  ($listref) {
                          ##########
        # Fail if the actual number of KV pairs in the list
        # is not the same as the required number of entries...
        return 0 if $listref->@* != 2 * %STRUCTURE;
                                        ##########
        # Verify that each pair has a suitable key and value...
        for my ($next_key, $next_value) ($listref->@*) {
            # Fail if any required key is missing...
            return 0 if !exists $STRUCTURE{$next_key};
                                ##########
            # Fail if the corresponding value fails its individual check...
            return 0 if !$STRUCTURE{$next_key}->( $next_value );
        }                ##########
        return 1;
    }

    # And then...
    check CustomerRecord :isa( KVList[ name=>STR, pos=>INT, data=>ARRAY[OBJ[Transaction]] ] );
                               ##########################################################

    sub get_customer :returns(CustomerRecord) {...}
```

Like regular subroutine parameters, check-configuration parameters can also be given defaults:
```perl
    # If upper bound is omitted, there is no upper bound...
    check RangeNUM  :params($MIN, $MAX = 'Inf')  :isa(NUM)  ($value)  { $MIN <= $value <= $MAX }
                                  ############

    # Default to 10 characters, if no specific minimum length is configured...
    check LongSTR   :params($N = 10)             :isa(STR)  ($value)  { length $value >= $N }
                            #######
```
If all the configuration parameters are optional (or slurpy), the square brackets
also become optional when the check is used:
```perl
    my $passwd :of(LongStr[]) = 'open sesame 12345';   # Means: LongStr[10]

    my $passwd :of(LongStr)   = 'open sesame 12345';   # Means the same
```

In addition to specifying configuration parameters as scalars or slurpies,
you can also specify them with a `&` sigil _(which is ***not*** possible in regular
subroutine signatures)_. Configuration parameters specified in this way
can only be bound to some other check. They then become lexical subroutines
within the code block of the check, with those subroutines executing the
specified check test. For example:
```perl
    # Must be a value that satisfies a given check, or else is undef...
    check Maybe  :params(&SUBCHECK)  ($value)  { !defined $value || SUBCHECK($value) }
                 ##################                                 ########

    # Must be a reference to an array within which each element satisfies a nested check
    # (Note that this example is redundant, since the built-in ARRAY check
    # is already parameterized in precisely this way)...
    check ArrayOf  :params(&ELEMCHECK)  :isa(ARRAY)  ($aref)  {
                   ###################
        for my $elem ($aref->@*) {
            return 0 if !ELEMCHECK($elem);
        }                #########
        return 1;
    }

    # And then...

    my $verbose_flag :of(Maybe[BOOL]);      # No initialization required; default undef now okay
                               ####

    sub get_clients :returns(ArrayOf[OBJ[Client]])  {...}
                                     ###########

    my $ultimate_answer :of(Maybe[42]);    # Error: Configuration argument (42) is not a check
                                  ##
```

As the preceding examples illustrate, when the parameters of a check are themselves other checks,
those parametric checks are passed as subroutines (because checks really are just a special kind
of auto-applied subroutine). Hence, when a check is passed as the parameter of another check,
that parametric check can be invoked directly as part of the new check’s code block.

The configuration parameters specified by a `:param` are also immediately available
to any subsequent attributes specified in a `check` declaration. For example:
```perl
    check Maybe   :params(&CHECK)    :isa(CHECK | UNDEF);
                          ##### --------> #####

    check Blessed :params(&REFTYPE)  :isa(REF & REFTYPE)  ($ref) { builtin::blessed $ref }
                          ######## -----------> #######
```

#### Checking the parameters of a parameterized check

Checks can be applied to ***any*** variable...including to the configuration parameter variables
of another check. So it’s also possible to ensure that those configuration parameters
themselves meet specific requirements. For example:
```perl
    # Must be a number between the numbers MIN and MAX...
    check RangeNum  :params($MIN :of(NUM), $MAX :of(NUM))  :isa(NUM)  ($n)  { $MIN <= $n <= $MAX }
                                 ########       ########

    # Must be a string of at least N characters, where N is a positive integer...
    check LongStr   :params($N :of(PosInt))                :isa(STR)  ($n)  { length $n >= $N }
                               ###########

    # Must be one of a particular set of specified strings...
    check MatchStr  :params(@TARGETS :of(STR))             :isa(STR)  ($s)  { grep { $_ eq $s } @TARGETS }
                                     ########
```

Designating that any check parameter is itself a check (by giving it a `&` sigil)
causes the compiler to require the corresponding argument to be a named check
(or as an expression involving named checks), but you can also use the built-in
`CHECK` check to explicitly specify that a scalar or slurpy configuration parameter
must be bound to some kind of built-in or user-defined check. For example:
```perl
    check Maybe  :params($SUBCHECK :of(CHECK))  ($value)  { !defined $value || $SUBCHECK->($value) }
                         ####################                                  #########

    my $count :of(Maybe[INT]);    # Okay
    my $count :of(Maybe[0]);      # Compile-time error: configuration argument (0) failed INT check


    check UnorderedTuple  :params(@ELEM_CHECKS :of(CHECK))  :isa(ARRAY)  ($aref) {...}
                                  #######################

    sub get_data :returns(UnorderedTuple[INT,  STR,    HASH  ]) {...}   # Okay
    sub get_data :returns(UnorderedTuple['ID', 'name', 'data']) {...}   # Compile-time error
```


### Restricting checks to specific declarands

By default, a user-defined check is applicable to any kind of variable,
or to the return value of any subroutine. However, some kinds of checks can only
usefully be applied to variables, or to one particular kind of variable,
or only to subroutine return values.

The `:on` attribute provides a means to restrict a user-defined
check to a particular kind of declarand, as follows:

| `:on(`_WHAT_`)` | The check can only be used in... |
| :---------- | :------------------------------------------------------------------------ |
| `:on(SCALAR)` | ...an `:of()` attached to a scalar variable declaration (including scalar parameters) |
| `:on(ARRAY)`  | ...an `:of()` attached to an array declaration (including slurpy array parameters) |
| `:on(HASH)`   | ...an `:of()` attached to a hash declaration (including slurpy hash parameters) |
| `:on(CODE)`   | ...a `:returns()` attached to a subroutine |

For example, to define a check that prevents the use of references as hash values,
and which, therefore, is logically only applicable to hashes:
```perl
    check NoRefVals :on(HASH) :isa(!REF);
                    #########

    my %names  :of(NoRefVals);    # Okay
    my @scores :of(NoRefVals);    # Error: Check NoRefVals can only be applied to a hash
```

You can also specify check expressions in an `:on`, to allow a check to be applied
to two or more declarands. For example:

| `:on(`_WHAT_`)`        | The check can be used in...     |
| :----------------- | :----------------------------------- |
| `:on(ARRAY\|HASH)`   | ...the `:of()` of either an array or hash |
| `:on(!CODE)`         | ...any `:of()`, but not in a `:returns()`   |

Note that, if the check expression specified in an `:on(`...`)`
involves anything other than `SCALAR`, `ARRAY`, `HASH`, or `CODE`,
the attribute is invalid and will produce a compile-time error.

People are sometimes confused between the `:on` attribute and
the `:isa` attribute, both of which take a subcheck as their
configuration argument. The easiest way to remember the difference
is that:
* `:on` is an abbreviation of <code><strong>:on</strong>ly_applicable_to</code>
* `:isa` is the same as a class’s `:isa`: it specifies some pre-existing behaviour that the new entity must conform to

To visualize the difference between `:isa` and `:on`, consider the check declaration:
```perl
    check RecordQueue  :on(ARRAY) :isa(HASH)  ($href) { exists $href->{recordID} }
                       #####################
```
We could represent the `:isa` and `:on` relationships of this check like so:
```
                                                  ┏━━━━━━━━━━━━━━━┓
           $slr                                   ┃  check HASH   ┃
                                                  ┗━━━━━━━╽━━━━━━━┛
           %hsh                                           ┃ :isa(X) = must also pass check X
                   :on(Y) = only applies to Y   ┏━━━━━━━━━┻━━━━━━━━━┓
           @ary <┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┃ check RecordQueue ┃
                                                ┗━━━━━━━━━━━━━━━━━━━┛
           &sub
```


### Contextual information for check blocks

Normally the code block of a check receives any value to be tested
(_i.e._ any value being assigned to a checked variable or returned
from a checked subroutine) via its sole parameter variable.

However, sometimes a variable check will need more information than just
the proposed new value, in order to be able to determine if an assignment
is permitted.

For example, one could envisage a _monotonic variable_: a `$count` or `$sum`, for which
assignments must never decrease the stored value. Or a _finite array_ that must never store
more than _N_ elements. Or a _bijection_: a hash in which no two keys can store the same value.
Or a _restricted hash_ in which every key must conform to a specific pattern.

Each of these checks requires extra information to determine if an assignment
is permitted. The monotonic variable check requires access to the current value
stored in the variable; the finite array check requires access to the specific index
being updated (to ensure it’s less than _N_); the bijective hash check requires
access to all the values of the hash (to be able to ensure they’re all distinct);
the restricted hash check requires access to the specific key under which the new value
is to be stored.

To provide access to this extra information, you can add an extra slurpy hash
after the single required check parameter. If a check is specified with this
second parameter, it no longer receives just the value to be checked. Instead,
it is also passed a key/value sequence containing additional information about
the context in which the check is being applied. That information consists of:

* `old =>` _VALUE_<br/>
  This pair passes a readonly copy of the old (pre-modification) value of the checked scalar,
  array element, or hash value. This pair is passed to the slurpy parameter only
  if the check was applied to a variable.

* `key =>` _VALUE_<br/>
  This pair passes a copy of the hash key or array index within the container variable
  at which the new value is supposed to be assigned. This pair is passed to the slurpy parameter
  only if the check was applied to an array or hash.

* `var =>` _REFERENCE_<br/>
  This pair passes a readonly reference to the entire variable to which the check was applied.
  This pair is passed to the slurpy parameter only if the check is being applied to a variable.

* `name =>` _STRING_<br/>
  This pair passes the name of the checked variable or subroutine.
  This pair is always passed whenever the check has a slurpy parameter.

* `want =>` _STRING_<br/>
  This pair passes the call context (`'LIST'`, `'SCALAR'`, `'VOID'`) of the subroutine
  whose return value is being checked.
  This pair is only passed when the check is being applied to a subroutine return list.

Hence we could implement the various non-simple-value checks
described at the start of this subsection, as follows:
```perl
    # Newly assigned values must never decrease...
    check Monotonic  :isa(NUM)  :on(!CODE)  ($value, %value)  { $value >= $value{old} }
                                                     ######

    sub count :returns(Monotonic) {...}  # Error: Cannot apply check Monotonic to subroutine 'count'

    my $counter :of(Monotonic) = 0;      # Okay
    $counter++;                          # Okay
    $counter--;                          # EXCEPTION: Can't assign 0 to $counter: failed Monotonic check


    # The array cannot have more than N elements...
    check MaxElems  :params($N :of(UINT))  :on(ARRAY)  ($, %elem)  { $elem{key} < $N }
                                                           #####

    my %finalists :of(MaxElems[10]);     # Error: Cannot apply check MaxElems to %finalists (not an array)

    my @finalists :of(MaxElems[10]);     # Okay
    @finalists = ('a'..'j');             # Okay
    @finalists = ('a'..'k');             # EXCEPTION: Can't assign 'k' to index 10 of @finalists:
                                         #            failed MaxElems[10] check


    # The values of the hash must remain unique...
    check Bijective  :on(HASH)  ($new_value, %target)  {
                                             #######
        return $target{old} eq $new_value
               || not grep { $_ eq $new_value} } values $target{var}->%*;
    }

    my $mapping :of(Bijective);       # Error: Cannot apply check Bijective to $mapping (not a hash)

    my %mapping :of(Bijective);       # Okay
    %mapping = (a=>1, b=>2, c=>3);    # Okay
    $mapping{c} = 1;                  # EXCEPTION: Can't assign 1 to key 'c' of %mapping:
                                      #            failed Bijective check


    # The keys of the hash must conform to a given pattern...
    check KeyPat  :params($PATTERN :of(REGEXP))  :on(HASH) ($, %entry)  { $entry{key} =~ $PATTERN; }

    my @data :of(KeyPat[qr/[a-z]{3}\d{5}/]);    # Error: Cannot apply check KeyPat to @data (not a hash)

    my %data :of(KeyPat[qr/[a-z]{3}\d{5}/]);    # Okay
    $data{xyz12345} = 1;                        # Okay
    $data{XYZ678}   = 1;                        # EXCEPTION: Can't assign 1 to key 'XYZ678' of %data:
                                                #            failed KeyPat[qr/[a-z]{3}\d{5}/] check
```

> | ***Commentary*** |
> | :--------- |
> | _It is important that this context information be read-only...and preferably deeply read-only. It would be entirely counter-intuitive if checks were able to arbitrarily modify the variables they are supposed to be guarding, or change the new values that they are only supposed to be checking. But see also [“Coercions”](#coercions)._ |
> | _If/when Perl subroutines get declarative named arguments, the slurpy “context parameter” in each of the preceding examples could be replaced by suitable named parameters (plus a trailing nameless slurpy to soak up the unneeded named arguments). For example:_ |
> ```perl
>     check Monotonic :isa(NUM) :on(!CODE)  ($value, :$old, %)  { $value >= $old }
>                                                    ########
>
>     check Bijective :on(HASH)  ($new_value, :$old, :$var, %)  {
>         return $old eq $new_value           ###############
>             || not grep { $_ eq $new_value} } values $var->%*;
>     }
> ```


### User-defined error messages

Normally, the exceptions generated by user-defined checks are in the
same format as those of the built-in checks. But this can be changed.

Instead of returning a false value to indicate that the check failed,
the code block of a user-defined check can signal failure by throwing an exception.
This allows a new check to tailor a more appropriate error message,
if the standard autogenerated one would be insufficient for some reason.

For example:
```perl
    # Value must be a safe password (at least one alpha, numeric, and symbol)...
    check SafePwd  :isa(Str)  ($str)  {
        given ($str) {
            /[[:alpha:]]/ && /[[:digit:]]/ && /[[:punct]]/ && !/password/i
                or die "'$str' is not a safe password";
        }
    }

    # The array cannot have more than N elements...
    check MaxElems  :params($N :of(UINT))  :on(ARRAY)  ($value, %context))  {
        $context{key} < $N
            or die "Alas, the array $context{name} may not store more than $N elements.\n",
                   "You attempted to assign a value ($value) to index $context{key}\n",
                   "and for that wanton presumption...YOU SHALL PERISH!";
    }
```

Note that any exception thrown inside a user-defined check is automatically adjusted
to reflect the filename and line number of the operation for which the check actually failed,
rather than the file and line of the check’s own code block:
```perl
    my @finalists :of(MaxElems[10]);

    $finalists[86] = 'Max';
    # EXCEPTION: ...and for that wanton presumption...YOU SHALL PERISH! at demo.pl line 3
    #       NOT: ...and for that wanton presumption...YOU SHALL PERISH! at ArrayChecks.pm line 157
```

### Exporting user-defined checks

Because user-defined checks are lexically scoped, a check that
is declared in a module’s source file will only be available within
that module. This would make it difficult to create libraries
of reusable checks.

So a user-defined check can be declared with the `:export` attribute:

    package Checks::Integral;

    check NatInt   :isa(INT)  :export  ($n)  { $n >= 0 }
    check PosInt   :isa(INT)  :export  ($n)  { $n >  0 }
    check NegInt   :isa(INT)  :export  ($n)  { $n <  0 }

    check OddInt   :isa(INT)  :export  ($n)  { $n % 2 != 0  }
    check EvenInt  :isa(INT)  :export  ($n)  { $n % 2 == 0  }
    check PrimeInt :isa(INT)  :export  ($n)  { is_prime($n) }

Checks with this attribute are still available throughout their own lexical
scope, but are also automatically exported into any lexical scope where their
module is loaded. Hence:
```perl
    {
        use Checks::Integral;   # All checks marked :export are now available in this lexical scope

        sub add_odd :returns(EvenInt) ($x :of(OddInt), $y :of(OddInt)) {     # Okay
            return $x + $y;  #######          ######          ######
        }
    }

    my $result              = add_odd(7, 35);   # Okay

    my $result :of(EvenInt) = add_odd(7, 35);   # Compile-time error: Unknown check EvenInt
```

Exported checks can also be imported individually, by name, in the usual Perl manner:
```perl
    # Import only these two checks into this lexical scope...
    use Checks::Integral  'NatInt', 'PrimeInt';
```

Groups of exported attributes can also be designated for collective export.
The `:export` attribute can be given one or more arguments, which specify _tags_.
Just as with `Exporter` tags, these allow specific checks to be exported
either collectively (by default), individually (by name), or in groups (by tag):
```perl
    # Exported under:  use Check::Integral;
    check NatInt   :isa(INT)  :export        ($n)  { $n >= 0 }

    # Exported under:  use Check::Integral;
    #             or:  use Check::Integral ':Sign';
    check PosInt   :isa(INT)  :export(Sign)  ($n)  { $n >  0 }
    check NegInt   :isa(INT)  :export(Sign)  ($n)  { $n <  0 }

    # Exported under:  use Check::Integral;
    #             or:  use Check::Integral ':Pred';
    check OddInt   :isa(INT)  :export(Pred)  ($n)  { $n % 2 != 0  }
    check EvenInt  :isa(INT)  :export(Pred)  ($n)  { $n % 2 == 0  }
```
If you _don’t_ want a particular check exported by default, you can specify
it with the special tag: `OK`:
```perl
    # Exported only under:  use Check::Integral 'PrimeInt';
    check PrimeInt :isa(INT)  :export(OK)  ($n)  { is_prime($n) }
                              ###########
```
Note that this is equivalent to the `Exporter` module’s `@EXPORT_OK` mechanism.
You can also specify other tags along with the special `OK` tag, to allow
not-exported-by-default checks to still be exported as part of other export groups:
```perl
    # Exported only under:  use Check::Integral 'LuckyInt';
    #                  or:  use Check::Integral ':Pred'
    check LuckyInt :export(OK, Pred)  :isa(INT[2,3,5,11,17,41]);
                   #################
```

The following table summarizes the behaviour of the various `:export` options:
| Attribute             | Exports by name | Exports by default | Exports by tag |
| :------------------   | :-------------: | :----------------: | :------------: |
| `:export`             | ✔︎               | ✔︎                  | ✘              |
| `:export(Tagname)`    | ✔︎               | ✔︎                  | ✔︎              |
| `:export(OK)`         | ✔︎               | ✘                  | ✘              |
| `:export(OK,Tagname)` | ✔︎               | ✘                  | ✔︎              |


> | ***Commentary*** |
> | :--------------- |
> | _This approach will almost certainly require minor extensions to the internals of the `Exporter` module. I feel that would still be better than somehow exposing checks publicly and directly to the usual `Exporter` mechanism. Or, worse still, making user-defined checks global._ |


### Changing how checks report failure

When you apply a check to a variable or subroutine, that check becomes active
for the duration of the declarand’s existence. Any access to the variable or
call to the subroutine causes the check to execute and (potentially) an exception
to be thrown.

But over the development cycle this default behaviour may not always be optimal.
When retrofitting checks onto an existing codebase, you may want to turn checks “down”
in certain sections of the code, so that you still get the notification of a broken
expectation, but that notification doesn’t immediately terminate the program (which
may then allow you to find other problems later in the same execution). You may even want
to _globally_ downgrade checks in this way, so you can find all the problems at once,
without actually breaking a working(-ish) program at any point.

At other times you may want to turn checks off entirely, so that they are neither created,
nor attached to variables or subroutines, nor tested during execution. This would most
likely be when the code has been thoroughly tested and is about to be deployed. If it’s all
working correctly, there’s no need to activately watch for errors. At least, not all the time.
So you may either want to disable every check in the entire program, or maybe just turn off
all the “internal” checks within various software modules, leaving only the checks on
public API components active.

Downgrading checks to either warnings or no-ops is accomplished via the `checks` pragma.
Like all other pragmas, the effects of `checks` are lexical, and can therefore be used
to de-escalate or disable checking in any block or file scope...and, of course, to
re-enable or re-escalate checks in nested scopes.

You can downgrade all failed checks in a lexical scope from throwing exceptions to
merely issuing warnings like so:
```perl
    # Checks that fail anywhere in the remainder of this lexical scope just issue warnings...
    use checks 'NONFATAL';
    ...
    {
        ...
        {
            # Except in this block, where failed checks still throw exceptions...
            use checks 'FATAL';
            ...
        }
        # And we're back to issuing warnings here...
        ...
    }
```

Similarly, you can completely disable checks in a given lexical scope
in precisely the way you’d expect:
```perl
    # Checks aren't even tested in the remainder of this lexical scope...
    no checks;
    {
        ...
        {
            # Except in this block, where they're still fatal if they fail...
            use checks;
            ...
        }
        # And we're back to no checks at all from here...
        ...
    }
```

The `checks` pragma affects both the compile-time and runtime components of any check
within its scope. Specifically, a `no checks` turns off compile-time check declarations,
compile-time and runtime check attributions, and runtime check testing:
```perl
    # Turn off all check-related behaviours...
    no checks;

    # So this compile-time check definition becomes a no-op...
    check ActiveEvent :isa(OBJ[Event]) ($e) { $e->is_active }

    # And this compile-time check attribution also becomes a no-op...
    our $last_event :of(ActiveEvent|UNDEF);

    # And this runtime check attribution also becomes a no-op...
    state $next_event :of(ActiveEvent|UNDEF);

    # And these runtime check tests that would normally be invoked here also become no-ops...
    $last_event = $next_event;
    $next_event = get_event();
```

Note that turning off checks in this way, doesn’t invalidate the check-related ***syntax***
(you’d need to specify `no feature 'checks'` to disable that). This means that you can turn off
the effects of checks without having to remove the checks themselves from your code.
That’s handy when deploying your code _(you can leave the various check declarations
in place, but disabe their behaviour to boost performance)_, and handier still when a new bug
is discovered _(at which point you can temporarily turn all those automatic data
validations back on to help you track down the problem)._

Note too that, because the `checks` pragma is lexically scoped in its effect,
when your code is stable and well-tested, it is easy to switch off all run-time
checks throughout an entire module or file, but at the same time cordon off
a small subset of “API” subroutines, re-enabling just the public checks
on their parameters and return values. For example:
```perl
    package Data::Tools;

    no checks;  # The following checks are now turned off because this code is stable and deployed

    state %cache :of(CLASS => OBJ);

    # Internal utility functions...
    sub _build_data  :returns(ARRAY) ($source  :of(STR)  ) {...}
    sub _validate    :returns(ARRAY) ($data    :of(ARRAY)) {...}
    sub _reduce_data :returns(ARRAY) ($reducer :of(CODE) ) {...}

    {
        # These subs constitute the API, so leave their checks active to protect (the code from) users...
        use checks;

        sub get_data :returns(ARRAY) ($source :of(STR)   ) {...}
        sub set_data :returns(BOOL)  ($data   :of(ARRAY) ) {...}
        sub net_data :returns(ARRAY) ($addr   :of(URL)   ) {...}
    }
```


Like all pragmas, `use checks` and `no checks` are lexical in scope.
So you can’t use them turn checks down or off throughout your entire program
without adding the appropriate pragma at the start of every separate file and module.
Which is possible, but obviously not an ideal solution.

So it’s proposed that we should also add two new flags to the `perl` intepreter itself,
with which you can downgrade checks either to warnings, or to no-ops.

To downgrade every check throughout your source so that it merely issus warnings, rather than 
throwing exceptions, you would use the `-k` flag:
```shell
    # Run a program with all checks issuing only warnings...
    > perl -k myprog.pl
```
And to completely disable every check throughout your entire source, so that check declarations
are ignored and check tests never run, you would use the `-K` flag:
```shell
    # Run a program without any checks at all...
    > perl -K myprog.pl
```
_(The mnemonic here is that these two flags both “wea***k***en chec***k***s”,
and that the larger letter (`-K`) has the larger effect: the total removal of all checking.
Whereas the smaller letter (`-k`) has the smaller effect: removing only the lethality of failed checks)._

Note that the `-k` and `-K` flags also differ in the extent of their effects. The `-k` flag merely
sets the default failed-check response to warning at the start of each file, as if every file
started with an implicit: `use checks 'NONFATAL'`. Any explicit `use checks` or `no checks` pragma
within a file will still override that default.

In contrast, the `-K` flag universally overrides all in-code `checks` pragmas,
irrevocably disabling checks everywhere in your program.

> | ***Commentary*** |
> | :--------------- |
> | _The `use checks`/`no checks` mechanism described here is deliberately minimalist, at least initially. As experience is gained in the typical usage patterns of this pragma, it is possible that additional options could be introduced. For example, it might be useful to be able to de-escalate specific kinds of warnings, or to switch off warnings on regular variables but leave them active for parameters and subroutine return values, or to turn off user-defined checks without affecting built-in checks (or vice versa). So one day the mechanism might also support usages such as:_ |
> ```perl
>   # These might be added eventually, but are not part of the initial proposal...
>
>   use checks NONFATAL => qw( UNDEF STR NUM );     # Just warn for values that Perl can auto-coerce
>
>    no checks qw( HASH ARRAY );                    # No checks on containers
>
>   use checks qw( subs params );                   # Turn on checking for subroutine APIs
>    no checks qw( vars );                          # Turn off checking for other variables
>
>   use checks qw(  builtins -user );               # Enable built-in checks, but not user-defined checks
>   use checks qw( -builtins  user );               # Vice versa
> ```


## Coercions

Checks, whether built-in or user-defined, ***never*** modify the value that they are testing.
That is, a check verifies the value being assigned to a variable or returned from a subroutine,
but in a strictly _either/or_ way: either the value passes the check and is assigned/returned
unchanged, or else the value fails the check, a suitable exception is thrown, and so no value
at all is assigned or returned at that point.

But there is a related concept – the _“coercion”_ – which also asserts that a value
must pass some test. However, unlike a check, if the value fails the test then a coercion
can also attempt to _convert_ the value in some way, so that it does pass the test.

There are no built-in coercions, but you can define your own using the `coercion` keyword,
which has the following syntax:

<code>&nbsp;&nbsp;&nbsp;&nbsp;<strong>coercion</strong>  <em>NAME</em>  <strong>:to(</strong><em>TARGET</em><strong>)</strong>  <em>OTHER_ATTRS<sub>OPT</sub></em>  <strong>(</strong><em>PARAMS</em><strong>)  { </strong><em>IMPLEMENTATION</em> <strong>}</strong>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;</code>

A coercion declaration still defines something that can be used like a check (_i.e._ in the `:of`
of a variable, or the `:returns` of a subroutine). But a coercion has a slightly different
interface and different internal behaviour from a check.

Like checks, coercions receive the value they are supposed to verify as a read-only argument,
but, instead of returning true or false to indicate the outcome of the test (as a check does),
a coercion must return a value that successfully passes the target check (_i.e._ that passes
the check specified in the coercion’s mandatory `:to` attribute).

The value returned by the coercion can either be the original value being tested, or else
another value that is to ***replace*** the value being tested. Either way, this returned value
is then the value that is ultimately assigned to the coerced variable, or returned from the
coerced subroutine.

For example:
```perl
    # Must be a number with no significant digits after the decimal (if not, make it so)...
    coercion WholeNum  :to(INT)  ($n) {
        die "$n can't be converted to a number"  if !looks_like_number($n);
        return round($n);
    }

    my $average_score :of(WholeNum)  =  sum(@scores) / @scores;   # Average is rounded on assignment
                      #############


    # Must be a non-reference whose stringification is at least twelve characters long (if not, pad it)...
    coercion LongStr  :to(STR[/.{12}/])  ($value) {
        my $is_ref = reftype($value);
        die "$is_ref reference $value can't be converted to a LongStr" if $is_ref;
        return sprintf('%12s', $value) }
    }

    sub set_passwd ($new_passwd :of(LongStr)) {...}    # $new_passwd padded with spaces, if necessary
                                ############
```

When a coercion is applied to the value being assigned to a variable or being returned from a subroutine,
the original value being assigned or returned is processed as follows:
1. The original value is first checked against the target specified in the coercion’s `:to` attribute.
2. If the `:to` check passes, then the entire coercion is immediately considered to have succeeded,
   and the original value is passed through – unchanged – to the assignment or subroutine-return
   that the coercion is guarding. In such cases, the coercion’s code block is not invoked at all.
3. If the `:to` check fails, the code block of the coercion is executed and is passed the original value
   as its argument. The task of the code block is then to convert the
   original value into some other value; one that is acceptable to the `:to` check.
4. If the coercion’s code block throws an exception at any point, the coercion immediately fails.
   In which case, the exception propagates as usual, interrupting execution just like
   a failed check would.
5. If the coercion’s code block successfully returns a value, the `:to` check is then applied
   to that returned value.
6. If the returned value passes its `:to` check, the coercion is considered to have succeeded,
   and the new value returned by the coercion’s code block is passed through instead of
   the original value.
7. If the returned value fails its `:to` check, the entire coercion fails, and a suitable exception
   is thrown.

In other words, a coercion must return a value satisfying the check specified by its `:to` attribute
(either by automatically passing though the original value being tested, or by generating a suitable
replacement value in its code block), or else the coercion must signal failure by throwing an exception.

### Parametric coercions

Coercions can be parameterized in the same way as checks.
For example:
```perl
    # Must be a number in the range $MIN..$MAX (if not, make it so)...
    coercion NumBetween  :params($MIN :of(NUM), $MAX :of(NUM))  :to(NUM[$MIN..$MAX])  ($n)  {
                         #####################################
        die "$n can't be converted to a number"  if !looks_like_number($n);

        # If we get here, either $n < $MIN or $n > $MAX, so return whichever bound is appropriate...
        return $n < $MIN  ?  $MIN  :  $MAX;
    }

    my $probability :of(NumBetween[0,1])  =  readline();  # Adjust the input to be between 0 and 1
                        ###############


    # Must be a string at least N characters long (if not, pad it)...
    coercion LongStr  :params($N :of(UINT))  :to(STR[/.{$N}/])  ($value)  {
                      #####################
        my $is_ref = reftype($value);
        die "$is_ref reference $value can't be converted to a LongStr" if $is_ref;
        return sprintf('%*s', $N, $value);
    }

    sub set_passwd ($new_passwd :of(LongStr[20])) {...}   # We now require 20-character passwords
                                    ###########


```

### Preconditions on coercions

Note that, in all of the preceding examples, the coercion’s code block first had to
implement some underlying check (by throwing a suitable exception if the value
was not a number, or was a reference, or wasn’t an arrayref, respectively)
before implementing its own specific conversion of the original value.

You can avoid this tedious preliminary gate-keeping, by ***declaring***
that the value passed to the coercion must first satisfy some precondition,
before its code block can be entered. Such preconditions are declared using the `:from` attribute:
```perl
    # Must be a number in the range $MIN..$MAX (if not, make it so)...
    coercion NumBetween :params($MIN :of(NUM), $MAX :of(NUM)) :to(NUM[$MIN..$MAX])  :from(NUM)  ($n)  {
                                                                                    ##########
        return $n < $MIN  ?  $MIN  :  $MAX;
    }

    # Must be a string at least N characters long (if not, pad it)...
    coercion LongStr :params($N :of(UINT)) :to(STR[/.{12}/])  :from(!REF)  ($value)  {
                                                              ###########
        return sprintf('%*s', $N, $value);
    }

```

When a `:from` is specified, if the original value fails the initial `:to` check but _passes_
the `:from` check, then the code block is executed and the value it returns is then
retested against the `:to` check. To summarize:

| Preliminary `:to` check | Preliminary `:from` check | Final `:to` check | Final outcome of coercion |
| :---------------------: | :-----------------------: | :---------------: | :-----------------------: |
| **passes**                  | _(skipped)_                   | _(skipped)_           | **passes**         |
| fails                   | **passes**                    | **passes**            | **passes**         |
| fails                   | **passes**                    | fails             | fails          |
| fails                   | fails                     | _(skipped)_           | fails          |

Or, as a flowchart:
```

    [Original Value]
           ┆
    ┏━━━━━━V━━━━━━┓                                                                       ┏━━━━━━━━━━┓
    ┃     :to     ┠┄┄┄passes┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄❯          ┃
    ┗━━━━━━┯━━━━━━┛                                                                       ┃          ┃
           ┆                                                                              ┃  ENTIRE  ┃
         fails                                                                            ┃ COERCION ┃
           ┆                                                                              ┃  PASSES  ┃
    ┏━━━━━━V━━━━━━┓            ┏━━━━━━━━━━━━━━━━━┓               ┏━━━━━━━━━━━┓            ┃          ┃
    ┃    :from    ┠┄┄┄passes┄┄┄❯ code block runs ┠┈┈[New Value]┈┈❯    :to    ┠┄┄┄passes┄┄┄❯          ┃
    ┗━━━━━━┯━━━━━━┛            ┗━━━━━━━━┯━━━━━━━━┛               ┗━━━━━┯━━━━━┛            ┗━━━━━━━━━━┛
           ┆                            ┆                              ┆
         fails                      exception                        fails
           ┆                            ┆                              ┆
    ┏━━━━━━V━━━━━━━━━━━━━━━━━━━━━━━━━━━━V━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━V━━━━━┓
    ┃                       ENTIRE COERCION FAILS                            ┃
    ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛
```

### Other features of coercions

A coercion behaves in almost all other respects just like a check:

* It may be constrained to only be applied to particular kinds of variables,
  or to subroutine return values, by giving it
  [an `:on` attribute](#restricting-checks-to-specific-declarands).

* It may be exported into a caller’s lexical scope via
  [an `:export` attribute](#exporting-user-defined-checks).

* It may be specified with a second slurpy parameter, in which case it is passed
  [additional contextual information](#contextual-information-for-check-blocks).

With those features you could, for example, create a coercion to guard
and adapt the parameters of a particular subroutine. Suppose you need a subroutine
with a single parameter that must be an `Account` object. You could define a coercion
that verifies this constraint, but which also allows users to pass
an `Account::ID` object instead, in which case the coercion will look up the ID
and convert it to the corresponding account object. Like so:

```perl
    # Require an Account object, or an Account::ID object (which is converted to an Account)...
    coercion CoercedAccount  :to(OBJ[Account])  :from(OBJ[Account::ID])  :export  ($obj) {
        return $account_DB->find_by_ID( $obj )
            // die "Can't locate Account object for ID: " . $obj->ID_as_str();
    }

    # and later...

    sub update_account ($acct :of(CoercedAccount)) { ... }

    update_account( Account->new(%acct_data)    );  # Okay

    update_account( Account::ID->new($valid_ID) );  # Okay

    update_account( Account::ID->new($bad_ID)   );  # EXCEPTION: Can't locate Account object for ID: BaD1

    update_account( $bad_ID  );                     # EXCEPTION: Can't convert "Bad1" to OBJ[Account]

    update_account( \*STDOUT );                     # EXCEPTION: Can't convert \*STDOUT to OBJ[Account]
```

> | ***Commentary*** |
> | :--------------- |
> | <em>In large projects, it is strongly suggested that all coercions should be named with a consistent prefix. For example: <code><strong>Coerced</strong>Account</code>, <code><strong>Coerced</strong>Client</code> <code><strong>Coerced</strong>NumBetween</code>, <code><strong>Coerced</strong>LongStr</code>, <code><strong>Coerced</strong>ShortArray</code>, etc. The prefix need not be <code><strong>Coerced</strong></code> (though that ***does*** have the advantage of being extremely straightforward and unambiguous). But if you need something shorter you could instead prefix each coercion with <code><strong>To</strong></code>, or <code><strong>As</strong></code>, or <code><strong>Make</strong></code>, or <code><strong>Force</strong></code>, or even something more abstract like <code><strong>Cx</strong></code>. The point is: coercions introduce automatic behaviours that can make code harder to understand and harder to debug, so it’s useful to make them visually distinctive – and easy to search for – throughout the code. </em> |


### (Not) disabling coercions

Coercions are like checks, but they are not checks. In particular, because coercions can ***modify***
the behaviour of assignments and subroutine returns, coercions cannot ever be disabled or downgraded
without potentially changing the behaviour of the program they are part of.

Hence coercions are “always on” constructs and are excluded from the lexical effects of any
`checks` pragma and the global effects of the `-k` and `-K` flags.

This means that when you deploy your code, you can safely downgrade or deactivate all of your
internal checks, without disrupting any of your vital coercions.

