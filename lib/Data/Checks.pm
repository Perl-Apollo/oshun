package Data::Checks 0.000001;

use 5.022;
use warnings;
use experimental qw< lexical_subs signatures >;
use Filter::Simple;
use PPR::X;
use Scalar::Util qw< looks_like_number blessed reftype isvstring openhandle >;
use Import::Into;
use Sub::Uplevel;
use feature ();

# These override global behaviours...
my ($K_MODE, $loaded_at) = (q{}, undef);

# Hide the built-in modules from croak calls...
use Carp;
our @CARP_NOT = qw< attributes Filter::Simple >;

# Modify Data::Dump to report objects less verbosely...
use Data::Dump;
sub pp { (reftype($_[0])//q{}) eq 'IO' ? 'IO object'
       : blessed($_[0])                ? blessed($_[0]) . ' object'
       :                                 &Data::Dump::pp
}

# Source code templates that define built-in unparameterized checks...
my %CHECK = (
    ANY      => q(( 1 )),
    LIST     => q(( do{BEGIN{die q{Can't use LIST check in an :of}}} )),
    VOID     => q(( do{BEGIN{die q{Can't use VOID check in an :of}}} )),
    UNDEF    => q(( !defined(§) && \§ != \$Data::Checks::VOID )),
    DEF      => q(( defined(§) )),
    HANDLE   => q(( «DEF» && Data::Checks::openhandle(§) )),
    NONREF   => q(( «DEF» && !Data::Checks::reftype(§) )),
    REF      => q(( Data::Checks::reftype(§) )),
    GLOB     => q(( «NONREF» && Data::Checks::reftype(\§) eq 'GLOB' )),
    BOOL     => q(( «NONREF» || overload::Method(§,'bool') )),
    NUM      => q(( «NONREF» && Data::Checks::looks_like_number(§) && § !~ /inf|nan/i || «OBJ» && overload::Method(§,'0+') )),
    INT      => q(( «NUM» && (0+§) !~ /\./ )),
    UINT     => q(( «NUM» && (0+§) =~ /\A [+]? \d+ (?:E[+-]?\d+)? \z/ix )),
    STR      => q(( defined(§) && (Data::Checks::reftype(\\(§)) eq 'SCALAR' || overload::Method(§,'""')) )),
    VSTR     => q(( Data::Checks::isvstring(§) )),
    CLASS    => q(( «STR» && length(§) > 0 && (§)->isa(§) )),
    ROLE     => q(( Carp::croak "ROLE check failed (can't yet detect roles)" )),
    SCALAR   => q(( (Data::Checks::reftype(§)//'') eq 'SCALAR' || overload::Method(§,'${}') )),
    CODE     => q(( (Data::Checks::reftype(§)//'') eq 'CODE'   || overload::Method(§,'&{}') )),
    ARRAY    => q(( (Data::Checks::reftype(§)//'') eq 'ARRAY'  || overload::Method(§,'@{}') )),
    HASH     => q(( (Data::Checks::reftype(§)//'') eq 'HASH'   || overload::Method(§,'%{}') )),

    REGEXP   => q(( (Data::Checks::reftype(§)//'') eq 'REGEXP' || overload::Method(§,'qr') )),
    OBJ      => q((  Data::Checks::blessed(§) && (Data::Checks::reftype(§)//'') ne 'REGEXP'  )),
    CHECK    => q(( «STR» && length(§) > 0 && Data::Checks::_is_check(§) )),
);

# Cache information as it generated...
my %CHECK_UNAVAILABLE;
my %CHECK_IMPL;

# Normalize and instantiate built-in checks...
for my $CHECK_NAME (keys %CHECK) {
    # Expand nested checks...
    1 while $CHECK{$CHECK_NAME} =~ s{«([A-Z]+)»}{$CHECK{$1}}xmsg;

    # Disable checks that rely on unavailable features...
    if ( $] < 5.036 && $CHECK{$CHECK_NAME} =~ /\bbuiltin::/ ) {
        $CHECK_UNAVAILABLE{$CHECK_NAME} = "Check $CHECK_NAME is only available under Perl 5.36 or later";
    }

    # Instantiate...
    # TODO
}

# Returns checks need a little extra contextual verification...
my %RETURNS_CHECK = %CHECK;
s{\A\(}{(«SCALAR»&&}xms for values %RETURNS_CHECK;
$RETURNS_CHECK{LIST} = q((«LIST»));
$RETURNS_CHECK{VOID} = q((«VOID»));

# Is this a known check???
sub _is_check ($check) {
    if ((reftype($check)//q{}) eq 'CODE') {
        return blessed($check) eq 'Data::Checks::CheckImpl';
    }
    else {
        return exists $CHECK{$check // q{}};
    }
}

# These regexes match checks and/or subsets of the corresponding PPR rules
# (those subsets being reasonable restrictions applying to check declarations...and much faster)...

# Optional whotespace...
my $PERLOWS = qr{
    (?: \s++ | \# \N*+ (\n|\z) )*+
}xms;

# String literals...
my $PERLSTRING = qr{
    (?> qq? \b (?! \s*+ => ) |  (?= ["'] ) )
    \s*+
    (?&uninterpolated_string_contents)

    (?(DEFINE)
        (?<uninterpolated_string_contents>
            # Backslash as delimiter has no special cases...
            \\ .*? \\

        |   # Brackets as delimiters can be nested...
            \{ (?&curly_contents)  \}
        |   \[ (?&square_contents) \]
        |   \( (?&round_contents)  \)
        |   \< (?&angled_contents) \>

        |   # Any other delimiter just matches up to the first unescaped delimiter...
            (?<delim> \S )
            (?: \s++ | \\. | (?: (?! \g{delim} ) . ) )*+
            \g{delim}
        )

        # These handle the nesting of the four bracket-form delimiters...
        (?<curly_contents>  (?: [^{}]++ | \\. | \{ (?&curly_contents)  \} )*+ )
        (?<square_contents> (?: [^][]++ | \\. | \[ (?&square_contents) \] )*+ )
        (?<round_contents>  (?: [^()]++ | \\. | \( (?&round_contents)  \) )*+ )
        (?<angled_contents> (?: [^<>]++ | \\. | \< (?&angled_contents) \> )*+ )
    )
}xms;

# Regex and match literals...
my $PERLREGEX = qr{
        (?> \/\/
    |   (?> (?: m | qr) \b (?! \s*+ => )  |  (?= \/ [^/] ) )
        \s*+
        (?&uninterpolated_regex_contents)
    )
    [msixpodualgcn]*+

    (?(DEFINE)
        (?<uninterpolated_regex_contents>
            # Backslash as delimiter has no special cases...
            \\ .*? \\

        |   # Brackets as delimiters can be nested...
            \{ (?&curly_contents)  \}
        |   \[ (?&square_contents) \]
        |   \( (?&round_contents)  \)
        |   \< (?&angled_contents) \>

        |   # Any other delimiter just matches up to the first unescaped delimiter...
            (?<delim> \S )
            (?: \s++ | \\. | (?: (?! \g{delim} ) . ) )*+
            \g{delim}
        )

        # These handle the nesting of the four bracket-form delimiters...
        (?<curly_contents>  (?: [^{}]++ | \\. | \{ (?&curly_contents)  \} )*+ )
        (?<square_contents> (?: [^][]++ | \\. | \[ (?&square_contents) \] )*+ )
        (?<round_contents>  (?: [^()]++ | \\. | \( (?&round_contents)  \) )*+ )
        (?<angled_contents> (?: [^<>]++ | \\. | \< (?&angled_contents) \> )*+ )
    )
}xms;

# The syntax of parametric checks...
my $PARAMETERIZED_CHECK = qr{
    (?<check> [[:alpha:]][[:alnum:]_]*+ )
    (?: \[
        (?<params> (?>(?&quotelike_contents)) )
        \]
    )?+
    (?(DEFINE)
        (?<quotelike_contents>
            (?: [^][\\]++
            |   \\.
            |   \[ (?>(?&quotelike_contents)) \]
            )*+
        )
    )
}xms;

# The check algebra...
my $CHECK_EXPR = qr{
    (?&check_expr)

    (?(DEFINE)
        (?<check_expr>  (?>(?&check_atom)) (?: \s*+ [&|] \s*+ (?>(?&check_atom)) )*+  )
        (?<check_atom>  \( $PERLOWS (?>(?&check_expr)) $PERLOWS \)
                     |  \! $PERLOWS (?>(?&check_expr))
                     |  $PARAMETERIZED_CHECK
        )
    )
}xms;

# General purpose failure handler (during parsing, it inserts a die into the code itself)...
sub FAIL  (@msg) { _FAIL(0, @msg) }
sub FAIL1 (@msg) { _FAIL(1, @msg) }

sub _FAIL ($uplevel, @msg) {
    # Build the message...
    my $msg = join q{}, @msg;

    # While source-filtering, just build a fatal BEGIN and return it to be interpolated into the code...
    if (${^GLOBAL_PHASE} eq 'START') {
        return qq{ do{BEGIN{die q{$msg} }}}
    }

    # Find the external caller...
    for my $level (0..1000000) {
        # If there is an external caller, it must be in some other file...
        my @caller = caller $level or last;
        next if $caller[1] eq __FILE__ || substr($caller[1],0,6) eq '(eval ';

        # Skip any extra levels that were requested...
        next if $uplevel--;

        # Discover how the failure is supposed to be handled (if at all)...
        my $mode = $caller[10]{'Data::Checks/mode'} // 'FATAL';
        return if $mode eq 'NONE';

        # Add in the location information, if it's needed...
        $msg .= " at " . join(' line ', @caller[1..2]) . "\n"
            if substr($msg,-1) ne "\n";


        # Raise an exception or warning, as appropriate...
        die  $msg if $mode eq 'FATAL';
        warn $msg;

        # And we're done...
        return;
    }

    # This shouldn't ever happen, so report a problem if it ever does...
    die "Internal error: $msg\n";
}

# Given a check specification, generate the appropriate code to test one or more variables...
sub _gen_returns_check_code ($check) {
    state %RETURNS_CHECK_CODE;  # CACHE CODE GENERATION FOR PERFORMANCE...
    return $RETURNS_CHECK_CODE{$check} //= '(' . do {
        # Replace algebraic components with standard Perl code...
        $check =~ s{
              (?<or>    \|   )
            | (?<and>   \&   )
            | $PARAMETERIZED_CHECK
            | (?<error> [^!()\s]++ )
        }{
            my $subcheck = $+{check} // q{};
              $+{or}               ? '||'
            : $+{and}              ? '&&'
            : $subcheck eq 'REP'   ? Data::Checks::FAIL "Can't specify $& here (only in a TUPLE or SEQ)"
            : $subcheck eq 'ETC'
            || $subcheck eq 'OPT'  ? Data::Checks::FAIL "Can't specify $& here (only in a TUPLE, SEQ, or DICT)"
            : $+{params}           ? _gen_parameterized_returns_check_code($subcheck, $+{params})
            : $+{error}            ? Data::Checks::FAIL "Can't specify $+{error}"
            :                        $RETURNS_CHECK{ $subcheck } // Data::Checks::FAIL "Unknown check: $subcheck\n",
        }grexmso;
    } . ')';
}

# Given a check specification, generate the appropriate code to test one or more variables...
sub _gen_of_check_code ($check, @varnames) {
    die "Call to _gen_of_check_code() in non-list context" if !wantarray;

    state %CHECK_CODE;  # CACHE CODE GENERATION FOR PERFORMANCE...
    $CHECK_CODE{$check} //= '(' . do {
        # Replace algebraic components with standard Perl code...
        $check =~ s{
              (?<or>    \|   )
            | (?<and>   \&   )
            | $PARAMETERIZED_CHECK
            | (?<error> [^!()\s]++ )
        }{
            my $subcheck = $+{check} // q{};
              $+{or}               ? '||'
            : $+{and}              ? '&&'
            : $subcheck eq 'REP'   ? Data::Checks::FAIL "Can't specify $& here (only in a TUPLE or SEQ)"
            : $subcheck eq 'ETC'
            || $subcheck eq 'OPT'  ? Data::Checks::FAIL "Can't specify $& here (only in a TUPLE, SEQ, or DICT)"
            : $+{params}           ? _gen_parameterized_of_check_code($subcheck, $+{params})
            : $+{error}            ? Data::Checks::FAIL "Can't specify $+{error}"
            :                        $CHECK{ $subcheck } // Data::Checks::FAIL "Unknown check: $subcheck\n",
        }grexmso;
    } . ')';

    # Insert the variables into the check code...
    return map { $CHECK_CODE{$check} =~ s{§}{$_}gr } @varnames;
}

# Generate (possibly recursive) parametric checks for enumerated types (INT and UINT)...
sub _gen_ranged_check ($CHECKNAME, $VAL, $DESC) {

    # Only integer ranges can start at -infinity...
    my $MIN = $CHECKNAME eq 'INT' ? '(?<from_inf>   -inf )' : '(?!)';

    # Return the check specification and the subroutine implementing it...
    $CHECKNAME => sub ($check, $params) {
        # Handy regex that matches a single parameter within a parametric check...
        state $ELEM  = qr{ (?<range> (?<from> $VAL | $MIN ) \s*+
                           \.\. \s*+ (?<to>   $VAL | (?<to_inf>   \+?inf ) ) )
                         | (?<value> $VAL        )
                         | (?<regex> $PERLREGEX  )
                         | (?<check> $CHECK_EXPR )
                         | (?<error> .+? ) (?= \s*+ , | \z )
                         }ixms;

        # Accumulate matching code for each parameter...
        my @matchers;
        while ($params =~ m{\G \s*+ $ELEM \s*+ (?: , | \z) }gxms) {
            my %match = %+;

            # Adjust range to standard Perl terms for infinity...
            $match{from} = q{-Inf}  if $match{from_inf};
            $match{to}   = q{'Inf'} if $match{to_inf};

            # Select the correct optimized code template...
            if ($match{range} && ($match{from_inf} || $match{to_inf} || $match{from} <= $match{to})) {
                push @matchers, qq(( $match{from} <= § && § <= $match{to} ));
            }
            elsif ($match{value}) {
                push @matchers, qq(( $match{value} == § ));
            }
            elsif ($match{regex}) {
                push @matchers, qq(( (0+§) =~ $match{regex} ));
            }
            elsif ($match{check}) {
                push @matchers, Data::Checks::_gen_of_check_code($match{check}, '§');
            }
            else { # We have an error: report it...
                if (${^GLOBAL_PHASE} eq 'START') {
                    push @matchers, qq{ do{BEGIN{die "$CHECKNAME\[$params] is not a valid check\\n(because $match{error} is not a valid $DESC, $DESC range, regex, or check)" }}}
                }
                else {
                    Carp::croak "$CHECKNAME\[$params] is not a valid check\\n(because $match{error} is not a valid $DESC, $DESC range, regex, or check)";
                }
            }
        }

        # Join all the components into a single check expression...
        return qq{($CHECK{$CHECKNAME} && (} . join('||', @matchers) . q{))};
    }
}

# These are the subroutines that generate code for various built-in parametric checks...
my %CHECK_GEN = (
    # Numbers...
    NUM => sub ($check, $params) {
        # Handy regexes...
        state $NUM   = qr{ [-+]?+ (?: \d++ \.? \d*+ | \. \d++ ) (?: [eE] [+-]?+ \d++)?+ }xms;
        state $RANGE = qr{(?<from>$NUM|-inf) \s*+ (?<ltfrom> \< )? \.\. (?<ltto> \< )? \s*+ (?<to>$NUM|inf) }ixms;
        state $ELEM  = qr{ (?<range> $RANGE      )
                         | (?<regex> $PERLREGEX  )
                         | (?<check> $CHECK_EXPR )
                         | (?<error> .+? ) (?= \s*+ , | \z )
                         }xms;

        # Accumlate checking code for each parameter...
        my @matchers;
        while ($params =~ m{\G \s*+ $ELEM \s*+ (?: , | \z) }gxms) {
            my %match = %+;
            # Number must be in a range...
            if ($match{range} && $match{from} < $match{to}) {
                my $ltfrom = $+{ltfrom} // '<=';
                my $ltto   = $+{ltto} // '<=';
                push @matchers, qq(( $match{from} $ltfrom § && § $ltto '$match{to}' ));
            }
            # Number must match a regex...
            elsif ($match{regex}) {
                push @matchers, qq(( (0+§) =~ $match{regex} ));
            }
            # Number must match a nested check...
            elsif ($match{check}) {
                push @matchers, Data::Checks::_gen_of_check_code($match{check}, '§');
            }
            # Something illegal in the specification...
            else {
                if (${^GLOBAL_PHASE} eq 'START') {
                    push @matchers, qq{ do{BEGIN{die "NUM[$params] is not a valid check\\n(because $match{error} is not a valid numeric range, regex, or check)" }}}
                }
                else {
                    Carp::croak "NUM[$params] is not a valid check\\n(because $match{error} is not a valid numeric range, regex, or check)";
                }
            }
        }

        # Join them up into a single checking expression...
        return qq{($CHECK{NUM} && (} . join('||', @matchers) . q{))};
    },

    # Integers and unsigned integers use the same generator...
    _gen_ranged_check(  INT => qr{ [-+]? \d++ (?: [eE] \+? \d++)?+ }xms, 'integer'),
    _gen_ranged_check( UINT => qr{  \+?  \d++ (?: [eE] \+? \d++)?+ }xms, 'unsigned integer'),

    # Strings are very similar but use string ops (eq, lt) instead of numeric ops (==, <)...
    STR => sub ($check, $params) {
        # Handy patterns...
        state $ELEM  = qr{ (?<range> (?<from> $PERLSTRING ) \s*+ \.\. \s*+ (?<to> $PERLSTRING ) )
                         | (?<value> $PERLSTRING )
                         | (?<regex> $PERLREGEX  )
                         |           $PARAMETERIZED_CHECK
                         | (?<error> .+? ) (?= \s*+ , | \z )
                         }xms;

        # Accumlate checking code for each parameter...
        my @matchers;
        while ($params =~ m{\G \s*+ $ELEM \s*+ (?: , | \z) }gxms) {
            my %match = %+;
            # String must be in a range...
            if ($match{range} && $match{from} le $match{to}) {
                push @matchers, qq(( $match{from} le § && § le $match{to} ));
            }
            # Must be a specific string...
            elsif ($match{value}) {
                push @matchers, qq(( $match{value} eq § ));
            }
            # String must match a regex...
            elsif ($match{regex}) {
                push @matchers, qq(( (§) =~ $match{regex} ));
            }
            # String must satisfy a parametric check...
            elsif ($match{params}) {
                push @matchers,
                     Data::Checks::_gen_parameterized_of_check_code(@match{'check', 'params'});
            }
            # String must satisfy a non-parametric check...
            elsif ($match{check}) {
                push @matchers, Data::Checks::_gen_of_check_code($match{check}, '§');
            }
            # Something is rotten in the state of the specification...
            else {
                push @matchers, qq{ do{BEGIN{die "STR[$params] is not a valid check\\n(because $match{error} is not a valid string, string range, regex, or check)"}} };
            }
        }

        # Join the individual components into a single checking expression...
        return qq{($CHECK{STR} && (} . join('||', @matchers) . q{))};
    },

    # A reference check dereferences the value being tested and then checks it against the param...
    REF => sub ($check, $param) {
        my ($subcheck) = _gen_of_check_code($param, '${§}');
        return qq(( $CHECK{REF} && eval { $subcheck } ));
    },

    # Array ref check...
    ARRAY => sub ($check, $param) {
        # Handy regexes...
        state $UINT     = qr{ \+? \d+ (?: E\+?\d+)? }ixms;
        state $RANGE    = qr{ (?<from> $UINT ) $PERLOWS \.\. (?> (?<to> $UINT ) | (?<toinf> inf ) ) }ixms;
        state $LENCHECK = qr{ (?<len> $RANGE | (?<exact> $UINT) )
                              $PERLOWS (?: => | , ) $PERLOWS (?<check> .* ) }xms;

        # If the check also checks length, then there are several possible optimized tests...
        if ($param =~ $LENCHECK) {
            my ($subcheck) = _gen_of_check_code($+{check}, '$_');
            my $lencheck = $+{toinf}  ? qq(( $+{from} <= \@{§} ))
                         : $+{to}     ? qq(( $+{from} <= \@{§} && \@{§} <= $+{to} ))
                         :              qq((  $+{len} == \@{§} ));

            return qq(( $CHECK{ARRAY} && $lencheck && eval { !grep{ !$subcheck } \@{§} } ));
        }
        # Otherwise we just check the parametric subcheck against each element...
        else {
            my ($subcheck) = _gen_of_check_code($param, '$_');
            return qq(( $CHECK{ARRAY} && eval { !grep{ !$subcheck } \@{§} } ));
        }
    },

    # Tuples where each element has its own check...
    TUPLE => sub ($check, $param) {
        # Handy regexes...
        state $CHECK_LIST = qr{ $CHECK_EXPR (?: $PERLOWS , $PERLOWS $CHECK_EXPR )*+ ($PERLOWS ,)?+ }xms;
        state $TUPLE_ARG  = qr{
            $PERLOWS (?<elem> (?>  (?<etc> ETC )
                                |  (?<opt> OPT \[ $PERLOWS
                                    (?<rep> REP \[ $PERLOWS (?<list> $CHECK_LIST ) $PERLOWS \] )
                                    $PERLOWS \]
                                   )
                                |  (?<rep> REP \[ $PERLOWS (?<list> $CHECK_LIST ) $PERLOWS \] )
                                |  (?<opt> OPT \[ $PERLOWS (?<check> $CHECK_EXPR ) $PERLOWS \] )
                                |  (?<check> $CHECK_EXPR )
                                ))
            $PERLOWS (?:,|\z)
        }xms;

        # Build the source for the complete check in this...
        my $check_source = q{};

        # Track progress as well as special statuses (like optionals and repeated subtuples)...
        my ($index, $opt_from, $seen_etc, $seen_rep) = 0;

        # Process each subcheck in the tuple specification...
        while ($param =~ m{ \G $TUPLE_ARG }gcxms) {
            my %match = %+;

            # ETC or REP must be last element of tuple specification...
            if ($seen_etc)   { Carp::croak "Can't specify $& after ETC in check $check"; }
            if ($seen_rep)   { Carp::croak "Can't specify $& after REP in check $check"; }

            # Handle a final ETC...
            if ($match{etc}) {
                $opt_from //= $index;
                $seen_etc = q{'Inf'};
                next;
            }

            # Handle a final REP...
            if ($match{rep}) {
                $seen_rep = 1;
                my $rep_checks_code = q{};
                my $rep_count = 0;

                # Loop through the REP's sub-subchecks and build the appropriate checking code...
                while ($match{list} =~ m{ \G $PERLOWS (?<subcheck> $CHECK_EXPR ) $PERLOWS ,? }gxms) {
                    my ($nextcheck) = _gen_of_check_code($+{subcheck}, qq{§->[\$n + $rep_count]});
                    $rep_checks_code .= qq{\$okay &&= $nextcheck or last;};
                    $rep_count++;
                }

                # Complete the rep checking code...
                my $required_rep = $match{opt} ? q{} : qq{ (\@{§} - $index) > 0 && };
                $check_source .= qq{ && ( $required_rep  (\@{§} - $index) % $rep_count == 0 && do { my \$okay = 1; for (my \$n = $index; \$n < \@{§}; \$n += $rep_count) { $rep_checks_code} \$okay; } ) };

                # Remember the tuple index we're optional from...
                $opt_from //= $index + ($match{opt} ? 0 : $rep_count);
                $seen_etc = q{'Inf'};

                next;
            }


            # Get the source for the element check...
            my ($nextcheck) = _gen_of_check_code($+{check}, qq{§->[$index]});

            # Optional elements either don't exist or satisfy the corresponding check...
            if ($match{opt}) {
                $opt_from //= $index;
                $check_source .= qq{ && eval { \@{§} <= $index || $nextcheck } };
            }

            # Required elements must exist, precede optional/slurpy elements, and satisfy the check...
            else {
                Carp::croak "Can't specify non-optional $match{elem} after OPT or ETC in check $check"
                    if defined($opt_from) || $seen_etc;
                $check_source .= qq{ && eval { \@{§} > $index && $nextcheck } };
            }

            # And then we're done with this subcheck, so move on...
            $index++;
        }

        # Anything else in the config is an error...
        Carp::croak "Unexpected trailing '$&' in TUPLE specification"
            if $param =~ m{ \G $PERLOWS \S.* }gxms;

        # Work out the length logic for verifying the tuple...
        my $mincount = $opt_from // $index;
        my $maxcount = $seen_etc // $index;
        my $count_check = $mincount eq $maxcount ? qq{\@{§} == $mincount}
                                                 : qq{\@{§} >= $mincount && \@{§} <= $maxcount};

        # Generate and return the final check (phew!)...
        return qq(( $CHECK{ARRAY} && $count_check  $check_source ));
    },

    # Hash checks, which may have both key and value subchecks...
    HASH => sub ($check, $param) {
        # If it has a key subcheck build both subchecks and return the checking code...
        if ($param =~ m{\A \s*+ (?<key> $CHECK_EXPR ) \s*+ => \s* (?<val> $CHECK_EXPR) \s*+ \z}xms) {
            my ($keycheck) = _gen_of_check_code($+{key}, '$_');
            my ($valcheck) = _gen_of_check_code($+{val}, '$_');
            return qq(( $CHECK{HASH} && eval { !grep{ !$keycheck } keys %{§} } && eval { !grep{ !$valcheck } values %{§} } ));
        }

        # Otherwise just build and return checking code for the values...
        else {
            my ($subcheck) = _gen_of_check_code($param, '$_');
            return qq(( $CHECK{HASH} && eval { !grep{ !$subcheck } values %{§} } ));
        }
    },

    # A DICT is a HASH where individual keys are specified separately...
    DICT => sub ($check, $param) {
        # Handy regex...
        state $DICT_ARG = qr{
            $PERLOWS (?<elem> (?>  (?<etc> ETC )
                                |  (?<opt> OPT \[
                                        $PERLOWS
                                        (?> (?<key> $PERLSTRING ) $PERLOWS (?: => | , )
                                        |   (?<key> \w+         ) $PERLOWS     =>
                                        )
                                        $PERLOWS (?<check> $CHECK_EXPR )
                                        $PERLOWS \]
                                   )
                                |
                                        $PERLOWS
                                        (?> (?<key> $PERLSTRING ) $PERLOWS (?: => | , )
                                        |   (?<key> \w+         ) $PERLOWS     =>
                                        )
                                        $PERLOWS (?<check> $CHECK_EXPR )
                                ))
            $PERLOWS (?:,|\z)
        }xms;

        # Accumulate checking source code in this var...
        my $check_source = q{};

        # Track important elements...
        my $seen_etc;
        my @keys;

        # Process each subcheck in the dict specification...
        while ($param =~ m{ \G $DICT_ARG }gcxms) {
            my %match = %+;

            # ETC must be last element of dict specification...
            if ($seen_etc)   { Carp::croak "Can't specify $match{elem} after ETC within a DICT check"; }
            if ($match{etc}) {
                $seen_etc = 1;
                next;
            }

            # Remember each key...
            push @keys, $match{key};

            # Get the source for the element check...
            if (substr($match{check},0,4) eq 'OPT[') {
                my $opt_value = substr($match{check},4,-1);
                Carp::croak "Invalid DICT item:      $match{key} => OPT[ $opt_value ]\n",
                      "Perhaps you meant: OPT[ $match{key} => $opt_value ]\n",
                      "or maybe you want:      $match{key} => $opt_value | UNDEF\n",
                      "(Specifying a required key but an optional value doesn't make sense.\n",
                      " If the key exists in the hash, then the value must be present too.)\n";
            }
            my ($nextcheck) = _gen_of_check_code($match{check}, qq{(§)->{$match{key}}});

            # Optional elements either don't exist or satisfy the corresponding check...
            if ($match{opt}) {
                $check_source .= qq{ && eval { !exists §->{$match{key}} || $nextcheck } };
            }

            # Required elements must exist and must satisfy the check...
            else {
                $check_source .= qq{ && eval { exists §->{$match{key}} && $nextcheck } };
            }
        }

        # The target hash must have only keys specified in the dict.
        # (The trailing => in the eval ensures that bareword keys are also interpreted correctly)...
        my $allowed_keys = join '|', map { '\\Q'. eval("$_ =>") . '\\E' } @keys;

        # Anything else in the config is an error...
        Carp::croak "Unexpected trailing '$&' in DICT specification"
              if $param =~ m{ \G $PERLOWS \S.* }gxms;

        # Work out the logic for verifying the dict...
        my $required_keys = $seen_etc ? q{} : qq{ && !grep({!/^(?:$allowed_keys)\$/} keys %{§}) };
        return qq(( $CHECK{HASH}  $required_keys  $check_source ));
    },

    # OPT can't appear as a top-level check...
    OPT => sub ($check, $param) {
        Carp::croak "Can't specify OPT[$param], except as part of a TUPLE, SEQ, or DICT"
    },

    # A parametric classname is a string that also satisfies the isa check...
    CLASS => sub ($check, $param) {
        return qq(( $CHECK{STR} && length(§) > 0 && (''.§)->isa(q{$param}) ));
    },

    # An parametric object is an object that also satisfies the isa check...
    OBJ => sub ($check, $param) {
        return qq(( $CHECK{OBJ} && (§)->isa(q{$param}) ));
    },

    # Roles (and more specifically role introspection) aren't yet integrated to Perl...
    ROLE => sub ($check, $param) {
        Carp::croak "ROLE[$param] check failed (can't yet detect roles)";
    },

    # Only objects can be checked for overloaded operators...
    OP => sub ($check, $param) {
        return qq(( $CHECK{OBJ} && overload::Method(§,q{$param}) ));
    },

    # Both objects and classes can "isa" a classname...
    ISA => sub ($check, $param) {
        return qq(( ($CHECK{OBJ} || $CHECK{CLASS}) && (§)->isa(q{$param}) ));
    },

    # Both objects and classes can "DOES" a classname (or eventually a rolename)...
    DOES => sub ($check, $param) {
        return qq(( ($CHECK{OBJ} || $CHECK{CLASS}) && (§)->DOES(q{$param}) ));
    },

    # Both objects and classes can "can" a methodname...
    CAN => sub ($check, $param) {
        return qq(( ($CHECK{OBJ} || $CHECK{CLASS}) && (§)->can(q{$param}) ));
    },

    LIST => sub ($check, $param) { return qq(do{BEGIN{die "Can't specify a LIST check in an :of"}}); },
    SEQ  => sub ($check, $param) { return qq(do{BEGIN{die "Can't specify a SEQ check in an :of"}}); },
);

my %RETURNS_CHECK_GEN = (
    %CHECK_GEN,
    LIST => sub { return $CHECK_GEN{ARRAY}->(@_) =~ s/§/¤/gr },
    SEQ  => sub { return $CHECK_GEN{TUPLE}->(@_) =~ s/§/¤/gr },
);

# Find and call the appropriate generator for a parametric :of check...
sub _gen_parameterized_of_check_code ($check, $params) {
    my $generator = $CHECK_GEN{$check}
            // return qq{(do{BEGIN{die 'Unknown check: $check\[$params]'}}};
    return $generator->($check, $params)
}

# Find and call the appropriate generator for a parametric :returns check...
sub _gen_parameterized_returns_check_code ($check, $params) {
    my $generator = $RETURNS_CHECK_GEN{$check}
        // return qq{(do{BEGIN{die 'Unknown check: $check\[$params]'}}};
    return $generator->($check, $params)
            =~ s{\A \(}{$check =~ /\A(?:LIST|SEQ)\z/ ? '(«LIST»&&' : '(«SCALAR»&&'}exmsr;
}

# Generate source code for a :returns check...
my sub _gen_returns_checks_source ($check, $subname) {
    # Do we know the name of the subroutine being modified???
    $subname = $subname ? "$subname()" : 'anonymous subroutine';

    # Some checks can be optimized...
    my %inlines = do {
        if ($check eq 'ANY') {
            ( syn_list_check => 1, syn_scalar_check => 1, syn_void_check  => 1 );
        }
        elsif ($check eq 'LIST') {
            ( syn_list_check => 1, syn_scalar_check => 1, syn_void_check => 0 );
        }
        elsif ($check eq 'VOID') {
            ( syn_list_check   => 0,  list_msg   => qq{q{Can't call $subname in list context}},
              syn_scalar_check => 0,  scalar_msg => qq{q{Can't call $subname in scalar context}},
              syn_void_check   => 1
            );
        }
        else { # It's a "complex" check...
            my $check_code = Data::Checks::_gen_returns_check_code($check);
            ( syn_list_check   => ($check_code =~ s{ «LIST»   }{ 1           }gxr
                                               =~ s{ «SCALAR» }{ \$scalar    }gxr
                                               =~ s{ «VOID»   }{ 0           }gxr
                                               =~ s{ §        }{\$result[0]}gxr
                                               =~ s{ ¤        }{(\\\@result)}gxr),
              syn_scalar_check => ($check_code =~ s{ «LIST»   }{ 1           }gxr
                                               =~ s{ «SCALAR» }{ 1           }gxr
                                               =~ s{ «VOID»   }{ 0           }gxr
                                               =~ s{ §        }{\$result}gxr
                                               =~ s{ ¤        }{[\$result]}gxr),
              syn_void_check   => ($check_code =~ s{ «LIST»   }{ 0           }gxr
                                               =~ s{ «SCALAR» }{ 0           }gxr
                                               =~ s{ «VOID»   }{ 1           }gxr
                                               =~ s{ §        }{ 0           }gxr
                                               =~ s{ ¤        }{ []          }gxr),
            );
        }
    };

    # Install default messages (if needed)...
    $inlines{syn_list_msg}
        //= qq{'List return value ' . Data::Checks::pp(\@result) . qq{ failed :returns(\Q$check\E) check in call to $subname}};
    $inlines{syn_scalar_msg}
        //= qq{'Scalar return value ' . Data::Checks::pp(\$result) . qq{ failed :returns(\Q$check\E) check in call to $subname}};
    $inlines{syn_void_msg}
        //= qq{qq{Void return from call to $subname failed :returns(\Q$check\E) check\\n(No checkable return value in void context.)}};

    return %inlines;
}

# Build a class that implements a tieclass for a specific array with specific checks...
sub _build_array_check_tieclass ($VAR_NAME, $CHECK_NAME, $uninitialized) {

    # Handle the case where a length constraint is also specified...
    state $UINT     = qr{ \+? \d+ (?: E\+?\d+)? }ixms;
    state $RANGE    = qr{ (?<from> $UINT ) $PERLOWS \.\. (?> (?<to> $UINT ) | (?<toinf> inf ) ) }ixms;
    state $LENCHECK = qr{ (?<len> $RANGE | (?<exact> $UINT) ) $PERLOWS
                          (?: => | , ) $PERLOWS (?<check> .* ) }xms;
    if ($CHECK_NAME =~ $LENCHECK) {
        return _build_array_lencheck_tieclass($VAR_NAME, $+{check}, $uninitialized, {%+});
    }

    # Build the various optimized versions of the check for different tiemethods...
    my ($CHECK_UNDERSCORE, $CHECK_2, $CHECK_UNDEF)
        = Data::Checks::_gen_of_check_code($CHECK_NAME, '$_', '$_[2]', 'undef()');

    # Each variable gets it's own optimized tieclass...
    state $ARRAY_ID = 'A0000000000001';
    my $TIE_CLASS = qq{Data::Checks::TieArray::} . $ARRAY_ID++;

    # Clean up the variable name for subsequent qq{...} interpolations...
    my $QQ_VAR_NAME = $VAR_NAME =~ m{\A \W}xms ? "\\$VAR_NAME" : $VAR_NAME;

    # Generate and install the optimized code for this tieclass...
    eval qq{
        package $TIE_CLASS;

        # This installs the magic and tests any initial values...
        sub TIEARRAY  {
            # Check that each value in the pre-tied array satisfied the array's new check...
            for (\@{\$_[1]}) {
                next if $CHECK_UNDERSCORE;
                my \$SUB_NAME = (caller 1)[3];
                Data::Checks::FAIL1
                     q{Can't pass }, Data::Checks::pp(\$_),
                    qq{ via parameter $QQ_VAR_NAME in call to \$SUB_NAME():\\n},
                     q{Value failed parameter's $CHECK_NAME check};
            }

            # Install the implementation of the tie...
            return bless [\@{\$_[1]}], \$_[0];
        }

        # These are simple pass-throughs implementing standard array behaviours...
        sub FETCHSIZE { scalar \@{\$_[0]} }
        sub FETCH     { \$_[0]->[\$_[1]] }
        sub EXISTS    { exists \$_[0]->[\$_[1]] }
        sub CLEAR     { \@{\$_[0]} = () }
        sub SHIFT     { shift(\@{\$_[0]}) }
        sub POP       { pop(\@{\$_[0]}) }
        sub EXTEND    { \$#{\$_[0]} = \$_[1] - 1 }
        sub DESTROY   {}

        # These methods all need to verify the check, because the array is being altered...
        sub STORE {
            # Fail if the new value leaves a gap of undefs and undefs aren't allowed...
            Data::Checks::FAIL
                q{Can't assign value }, Data::Checks::pp(\$_[2]), qq{ to element \$_[1] },
                q{of $VAR_NAME: autovivified undef values would fail $CHECK_NAME check}
                    if \$_[1] > \@{\$_[0]} && !$CHECK_UNDEF;

            # Fail if the new value doesn't satisfy the variable's specified check...
            Data::Checks::FAIL
                q{Can't assign value }, Data::Checks::pp(\$_[2]), qq{ to element \$_[1] },
                q{of $VAR_NAME: failed $CHECK_NAME check}
                    unless $CHECK_2;

            # Implement the op...
            \$_[0]->[\$_[1]] = \$_[2];
        }
        sub STORESIZE {
            # Fail if the new size adds a gap of undefs and undefs aren't allowed...
            Data::Checks::FAIL
                qq{Can't resize $QQ_VAR_NAME to \$_[1] elements: },
                 q{autovivified undef values would fail $CHECK_NAME check}
                    if \$_[1] > \@{\$_[0]} && !$CHECK_UNDEF;

            # Implement the op...
            \$#{\$_[0]} = \$_[1]-1;
        }
        sub DELETE {
            # Fail if the deleting the value would leave an undef, and undefs aren't allowed...
            Data::Checks::FAIL
                qq{Can't delete element \$_[1] of $QQ_VAR_NAME},
                 q{resulting undef value would fail $CHECK_NAME check}
                    if \$_[1] < \$#{\$_[0]} && !$CHECK_UNDEF;

            # Implement the op...
            delete \$_[0]->[\$_[1]];
        }
        sub PUSH {
            my \$real_array_ref = shift;

            # Fail if any of the values being appended don't satisfy the check...
            for (\@_) {
                Data::Checks::FAIL
                    qq{Can't push value }, Data::Checks::pp(\$_),
                     q{ onto $VAR_NAME: failed $CHECK_NAME check}
                        unless $CHECK_UNDERSCORE;
            }

            # Implement the op...
            push(\@{\$real_array_ref},\@_);
        }
        sub UNSHIFT {
            my \$real_array_ref = shift;

            # Fail if any of the values being prepended don't satisfy the check...
            for (\@_) {
                Data::Checks::FAIL
                    qq{Can't unshift value }, Data::Checks::pp(\$_),
                     q{ onto $VAR_NAME: failed $CHECK_NAME check}
                        unless $CHECK_UNDERSCORE;
            }

            # Implement the op...
            unshift(\@{\$real_array_ref},\@_);
        }
        sub SPLICE {
            my \$real_array_ref = shift;

            # Normalize the arguments...
            my \$sz  = \$real_array_ref->FETCHSIZE;
            my \$off = \@_ ? shift : 0;
            \$off   += \$sz if \$off < 0;
            my \$len = \@_ ? shift : \$sz-\$off;

            # Fail if any new value being added doesn't satisfy the variable's specified check...
            for (\@_) {
                Data::Checks::FAIL
                    qq{Can't splice value }, Data::Checks::pp(\$_),
                     q{ into $VAR_NAME: failed $CHECK_NAME check}
                        unless $CHECK_UNDERSCORE;
            }

            # Implement the op...
            return splice(\@{\$real_array_ref},\$off,\$len,\@_);
        }

        1; # Even here we need the stupid final true value! :-)
    } // Carp::croak $@ =~ s/ at .*|BEGIN failed--compilation aborted.*//rs;

    # Return the classname so something can be tied to it...
    return $TIE_CLASS;
}


# It's more expensive to check array lengths, so use a separate tieclass (only when needed)...
sub _build_array_lencheck_tieclass ($VAR_NAME, $CHECK_NAME, $UNINITIALIZED, $len_ref) {
    # Work out how to check lengths...
    my $MIN_LEN = ($len_ref->{exact} // $len_ref->{from});
    my $LEN_CHECK_SPEC = $len_ref->{len};
    my $LEN_CHECK_CODE = $len_ref->{toinf}  ? qq(( $len_ref->{from} <= § ))
                       : $len_ref->{to}     ? qq(( $len_ref->{from} <= § && § <= $len_ref->{to} ))
                       :                      qq((  $len_ref->{len} == § ));
    my ($LEN_CHECK_AT_UNDER1, $LEN_CHECK_1, $LEN_CHECK_1_PLUS_1, $LEN_CHECK_LAST,
        $LEN_CHECK_NEWSIZE, $LEN_CHECK_PLUS_ATUNDER, $LEN_CHECK_MINUS_1, $LEN_CHECK_PLUS_1)
            = map { $LEN_CHECK_CODE =~ s{§}{($_)}gr }
                  q{@{$_[1]}}, q{$_[1]}, q{1+$_[1]}, q{$#{$_[0]}}, q{$newsize}, 
                  q{@{$real_array_ref}+@_}, q{@{$real_array_ref} - 1}, q{@{$real_array_ref} - 1};

    # Work out how to check values...
    my ($CHECK_UNDERSCORE, $CHECK_2, $CHECK_UNDEF)
        = Data::Checks::_gen_of_check_code($CHECK_NAME, '$_', '$_[2]', 'undef()');

    # These location lookups are used in multiple places, so make them string constants...
    my $LOC0 = q{' at ' . join(' line ', (caller  )[1,2]) . "\\n"};

    # Clean up the variable name for subsequent qq{...} interpolations...
    my $QQ_VAR_NAME = $VAR_NAME =~ m{\A \W}xms ? "\\$VAR_NAME" : $VAR_NAME;

    # These are the default behaviours for length checks that allow a zero length...
    my ($CLEAR_CHECK, $CLEAR_PENDING_VAR) = (q{},q{});
    my $CLEAR_METHOD  =  q{ sub CLEAR  { @{$_[0]} = ()} };  # Just the standard ClEAR behaviour
    my $EXTEND_METHOD = qq{ sub EXTEND {
                                # Can only extend if the new size satisfies the length check...
                                unless ($LEN_CHECK_1) {
                                    Data::Checks::FAIL
                                        qq{Can't assign list of length \$_[1] to $QQ_VAR_NAME: },
                                        qq{array length must be $LEN_CHECK_SPEC, not \$_[1]};
                                }

                                # Implement the op...
                                \$#{\$_[0]} = \$_[1] - 1;
                            }
                        };

    # If the min length > 0, things get a little bit more complicated
    # (because a CLEAR isn't allowed unless immediately followed by a suitanle EXTEND)...
    if ($MIN_LEN > 0) {
        # We have to track CLEAR ops and provide a suitable failure response to them...
        $CLEAR_PENDING_VAR = qq{ my \$clear_pending;  # Track CLEAR ops

                                 # Use this to fail with suitable message if invalid CLEAR occurred...
                                 sub _fail_clear {
                                     my \$len = \$_[0] // 0;
                                     Data::Checks::FAIL
                                        qq{Can't assign list of length \$len to $QQ_VAR_NAME: },
                                        qq{array length must be $LEN_CHECK_SPEC, not \$len},
                                        \$clear_pending, "\\n";
                                 }
                             };

        # All ops have to check that they weren't preceded by an invalid CLEAR...
        $CLEAR_CHECK       = qq{ _fail_clear() if \$clear_pending; };

        # The CLEAR method has to track where it occurred
        # (it's only valid if an EXTEND occurs immediately, and on the same line)...
        $CLEAR_METHOD      = qq{ sub CLEAR {
                                    \@{\$_[0]} = ();
                                    \$clear_pending = ' at ' . join(' line ', (caller)[1,2]) . "\\n";
                                 }
                             };

        # EXTEND requests fail if not immediately after a CLEAR, or if they're of the wrong size...
        $EXTEND_METHOD     = qq{ sub EXTEND {
                                    _fail_clear() unless \$clear_pending eq $LOC0;
                                    _fail_clear(\$_[1]) unless $LEN_CHECK_1;

                                    \$clear_pending = q{};  # No need to track this now (it was okay)

                                    # Implement the op...
                                    \$#{\$_[0]} = \$_[1]-1;
                                 }
                              };
    }

    # Each variable gets it's own optimized tieclass...
    state $ARRAY_ID = 'AL0000000000001';
    my $TIE_CLASS = qq{Data::Checks::TieArray::} . $ARRAY_ID++;

    # Generate and install the optimized code for this tieclass...
    eval qq{
        package $TIE_CLASS;

        # Make sure croaks croak at the right place...
        our \@CARP_NOT = ('Data::Checks', 'attributes');

        # Install CLEAR checking, if it's needed...
        $CLEAR_PENDING_VAR;

        # This installs the magic and tests any initial values...
        sub TIEARRAY  {
            # Verify that the array length satisfies the length check...
            if ($UNINITIALIZED && !($LEN_CHECK_AT_UNDER1)) {
                Data::Checks::FAIL1
                    q{Can't initialize $VAR_NAME with a list of }, scalar(\@{\$_[1]}),
                    q{ elements: array length must be $LEN_CHECK_SPEC, not }, scalar(\@{\$_[1]});
            }

            # Verify that every initial element satisfies the value check...
            for (\@{\$_[1]}) {
                next if $CHECK_UNDERSCORE;
                my \$SUB_NAME = (caller 1)[3];
                Data::Checks::FAIL1
                     q{Can't pass }, Data::Checks::pp(\$_),
                    qq{ via parameter $QQ_VAR_NAME in call to \$SUB_NAME():\\n},
                     q{Value failed parameter's $CHECK_NAME check};
            }

            # Copy the original contents and ensure there are enough of them...
            my \@impl = \@{\$_[1]};
            \$#impl = $MIN_LEN - 1 if \@impl < $MIN_LEN;

            # Install the tie...
            return bless \\\@impl, \$_[0];
        }

        # These are (mostly) simple pass-throughs implementing standard behaviours
        # (Except that they sometimes also check for invalid CLEARs)...
        sub FETCHSIZE { $CLEAR_CHECK; scalar \@{\$_[0]} }
        sub FETCH     { $CLEAR_CHECK; \$_[0]->[\$_[1]] }
        sub EXISTS    { $CLEAR_CHECK; exists \$_[0]->[\$_[1]] }
        sub DESTROY   {}

        # These are either standard CLEAR and EXTEND, or the special ones for non-zero lengths...
        $CLEAR_METHOD
        $EXTEND_METHOD

        # These tiemethod always need to check, because the array is being altered...
        sub STORE {
            # Verify that there's no pending illegal CLEAR...
            $CLEAR_CHECK

            # Verify that storing this new element doesn't make the array too long...
            Data::Checks::FAIL
                q{Can't assign value }, Data::Checks::pp(\$_[2]), qq{ to element \$_[1] },
                q{of $VAR_NAME: array length must be $LEN_CHECK_SPEC, not }, \$_[1]+1
                    unless \$_[1] < \@{\$_[0]} || $LEN_CHECK_1_PLUS_1;

            # Verify that storing this element doesn't leave undefs (if undef isn't allowed)...
            Data::Checks::FAIL
                q{Can't assign value }, Data::Checks::pp(\$_[2]), qq{ to element \$_[1] },
                q{of $VAR_NAME: autovivified undef values would fail $CHECK_NAME check}
                    if \$_[1] > \@{\$_[0]} && !$CHECK_UNDEF;

            # Verify that this new element satisfies the array's value check...
            Data::Checks::FAIL
                q{Can't assign value }, Data::Checks::pp(\$_[2]), qq{ to element \$_[1] },
                q{of $VAR_NAME: failed $CHECK_NAME check}
                    unless $CHECK_2;

            # Implement the op...
            \$_[0]->[\$_[1]] = \$_[2];
        }
        sub STORESIZE {
            # Verify that there's no pending illegal CLEAR...
            $CLEAR_CHECK

            # The new size must satify the length check...
            Data::Checks::FAIL
                qq{Can't resize $QQ_VAR_NAME to \$_[1] elements: },
                qq{array length must be $LEN_CHECK_SPEC, not \$_[1]}
                    unless $LEN_CHECK_1;

            # The new size must not introduce new undef values (if undefs would fail the check)...
            Data::Checks::FAIL
                qq{Can't resize $QQ_VAR_NAME to \$_[1] elements: },
                 q{autovivified undef values would fail $CHECK_NAME check}
                    if \$_[1] > \@{\$_[0]} && !$CHECK_UNDEF;

            # Implement the op...
            \$#{\$_[0]} = \$_[1]-1;
        }
        sub DELETE {
            # Verify that there's no pending illegal CLEAR...
            $CLEAR_CHECK

            # Verify that deleting this element won't make the array too short for its length check...
            Data::Checks::FAIL
                qq{Can't delete element \$_[1] of $QQ_VAR_NAME: },
                 q{array length must be $LEN_CHECK_SPEC, not }, \$_[1] + 1
                    unless \$_[1] < \$#{\$_[0]} || \$_[1] == \$#{\$_[0]} && $LEN_CHECK_LAST;

            # Verify that the deletion won't introduce an (invalid) undef...
            Data::Checks::FAIL
                qq{Can't delete element \$_[1] of $QQ_VAR_NAME},
                 q{resulting undef value failed $CHECK_NAME check}
                    if \$_[1] < \$#{\$_[0]} && !$CHECK_UNDEF;
            delete \$_[0]->[\$_[1]];
        }
        sub PUSH {
            # Verify that there's no pending illegal CLEAR...
            $CLEAR_CHECK

            my \$real_array_ref = shift;

            # Verify that appending these new values won't make the array too long...
            Data::Checks::FAIL
                q{Can't push }, Data::Checks::pp(\@_),
                q{ onto $VAR_NAME: array length must be $LEN_CHECK_SPEC, not },
                \@{\$real_array_ref} + \@_
                    unless $LEN_CHECK_PLUS_ATUNDER;

            # Verify that each appended value satisfies the value check...
            for (\@_) {
                Data::Checks::FAIL
                    q{Can't push value }, Data::Checks::pp(\$_),
                    q{ onto $VAR_NAME: failed $CHECK_NAME check}
                        unless $CHECK_UNDERSCORE;
            }

            # Implement the op...
            push(\@{\$real_array_ref},\@_);
        }
        sub POP {
            # Verify that there's no pending illegal CLEAR...
            $CLEAR_CHECK

            my \$real_array_ref = shift;

            # Verify that appending these new values won't make the array too long...
            Data::Checks::FAIL
                q{Can't pop $VAR_NAME: array length must be $LEN_CHECK_SPEC, not },
                \@{\$real_array_ref} - 1
                    unless $LEN_CHECK_MINUS_1;

            # Implement the op...
            pop(\@{\$real_array_ref});
        }
        sub SHIFT {
            # Verify that there's no pending illegal CLEAR...
            $CLEAR_CHECK

            my \$real_array_ref = shift;

            # Verify that prepending these new values won't make the array too long...
            Data::Checks::FAIL
                q{Can't shift $VAR_NAME: array length must be $LEN_CHECK_SPEC, not },
                \@{\$real_array_ref} - 1
                    unless $LEN_CHECK_PLUS_1;

            # Verify that each prepended value satisfies the value check...
            for (\@_) {
                Data::Checks::FAIL
                    q{Can't unshift value }, Data::Checks::pp(\$_),
                    q{ onto $VAR_NAME: failed $CHECK_NAME check}
                        unless $CHECK_UNDERSCORE;
            }

            # Implement the op...
            unshift(\@{\$real_array_ref},\@_);
        }
        sub UNSHIFT {
            # Verify that there's no pending illegal CLEAR...
            $CLEAR_CHECK

            my \$real_array_ref = shift;

            # Verify that prepending these new values won't make the array too long...
            Data::Checks::FAIL
                q{Can't unshift }, Data::Checks::pp(\@_),
                q{ onto $VAR_NAME: array length must be $LEN_CHECK_SPEC, not },
                \@{\$real_array_ref} + \@_
                    unless $LEN_CHECK_PLUS_ATUNDER;

            # Verify that each prepended value satisfies the value check...
            for (\@_) {
                Data::Checks::FAIL
                    q{Can't unshift value }, Data::Checks::pp(\$_),
                    q{ onto $VAR_NAME: failed $CHECK_NAME check}
                        unless $CHECK_UNDERSCORE;
            }

            # Implement the op...
            unshift(\@{\$real_array_ref},\@_);
        }
        sub SPLICE {
            my \$real_array_ref = shift;

            # Normalize the arguments...
            my \$sz  = \$real_array_ref->FETCHSIZE;
            my \$off = \@_ ? shift : 0;
            \$off   += \$sz if \$off < 0;
            my \$len = \@_ ? shift : \$sz-\$off;
               \$len = \$#{\$real_array_ref} + \$len if \$len < 0;

            # Verify that the new array size after deletions and insertions is allowable...
            my \$newsize
                = \$off > \$#{\$real_array_ref} ? \$off + 1 : \@{\$real_array_ref} + \@_ - \$len;
                Data::Checks::FAIL
                    q{Can't splice }, Data::Checks::pp(\@_),
                    q{ into $VAR_NAME: array length must be $LEN_CHECK_SPEC, not }, \$newsize
                        unless $LEN_CHECK_NEWSIZE;

            # Verify that each value being inserted satisfies the array's value check...
            for (\@_) {
                Data::Checks::FAIL
                    q{Can't splice value }, Data::Checks::pp(\$_),
                    q{ into $VAR_NAME: failed $CHECK_NAME check}
                        unless $CHECK_UNDERSCORE;
            }

            # Implement the op...
            return splice(\@{\$real_array_ref},\$off,\$len,\@_);
        }

        1; # Even here we need the stupid final true value! :-)
    } // die $@; # Carp::croak $@ =~ s/ at .*|BEGIN failed--compilation aborted.*//rs;

    # Return the classname so something can be tied to it...
    return $TIE_CLASS;
}


# Constructs an optimized class for implementing checked hashes...

sub _build_hash_check_tieclass ($VAR_NAME, $CHECK_NAME) {
    # Extract the check(s) from the specification...
    my ($keycheck, $valcheck)
        = ($CHECK_NAME =~ m{\A \s*+ (?<key> $CHECK_EXPR ) \s*+ => \s* (?<val> $CHECK_EXPR) \s*+ \z}xms)
            ? @+{'key','val'}
            : (undef, $CHECK_NAME);

    # Generate specific implementations for both key and value checks...
    my ($CHECK_KEY, $CHECK_1)
        = defined $keycheck ? Data::Checks::_gen_of_check_code($keycheck, '$key', '$_[1]') : (1,1);
    my ($CHECK_VALUE, $CHECK_2)
        = Data::Checks::_gen_of_check_code($valcheck, '$value', '$_[2]');

    # Generate a unique classname for each tied hash...
    state $HASH_ID = 'H0000000000001';
    my $TIE_CLASS = qq{Data::Checks::TieHash::} . $HASH_ID++;

    # Clean up the variable name for subsequent qq{...} interpolations...
    my $QQ_VAR_NAME = $VAR_NAME =~ m{\A \W}xms ? "\\$VAR_NAME" : $VAR_NAME;

    # Generate the optimized code for that class...
    eval qq{
        package $TIE_CLASS;

        # We can mostly just reuse the standard hash behaviours provided by Tie::StdHash...
        use Tie::Hash;
        BEGIN { our \@ISA = 'Tie::StdHash' };

        # This installs the magic and tests any initial values...
        sub TIEHASH {
            # Validate every key and value in the original hash...
            while (my (\$key, \$value) = each \%{\$_[1]}) {
                next if $CHECK_KEY && $CHECK_VALUE;
                my \$SUB_NAME = (caller 1)[3];
                Data::Checks::FAIL1
                    qq{Can't pass pair '\$key' => }, Data::Checks::pp(\$value),
                    qq{ via parameter $QQ_VAR_NAME in call to \$SUB_NAME():\\n},
                     q{Value failed parameter's $CHECK_NAME check};
            }

            # Tie the hash...
            return bless {%{\$_[1]}}, \$_[0];
        }

        # This is the only tiemethod that needs to check, because only it modifies the hash...
        sub STORE {
            # Verify that any new value being stored under a key satisfies both key and value checks...
            Data::Checks::FAIL
                 q{Can't assign value }, Data::Checks::pp(\$_[2]),
                qq{ to key '\$_[1]' of $QQ_VAR_NAME: failed \Q$CHECK_NAME\E check}
                    unless $CHECK_1 && $CHECK_2;

            # Implement the op...
            \$_[0]{\$_[1]} = \$_[2];
        }

        1; # Even here we need the stupid final true value!
    } // Carp::croak $@ =~ s/ at .*|BEGIN failed--compilation aborted.*//rs;

    # Return the classname so something can be tied to it...
    return $TIE_CLASS;
}

# Rewrite a subroutine declaration to install return-value checks...
sub _rewrite_sub ($decl_ref) {
    # Some handy regexes...
    state $DECOLONIZE = qr{ \A $PERLOWS : $PERLOWS \Z }xms;
    state $EXTRACT_OF = qr{ (?<param> (?<sigil> [\$\@%] ) \w+)  $PERLOWS
                            :                                   $PERLOWS
                            of  (?<check>  \( (?&round_contents) \)  )

                            (?(DEFINE)
                                (?<round_contents>  (?: [^()]++ | \\. | \(  (?&round_contents)  \) )*+ )
                            )
                          }xms;
    state $RETURNS    = qr{ \b returns \( (?<returns> (?&quotelike_contents) ) \)
                            (?(DEFINE)
                                (?<quotelike_contents>
                                    (?: [^()\\]++
                                    |   \\.
                                    |   \( (?>(?&quotelike_contents)) \)
                                    )*+
                                )
                            )
                          }xms;

    # Extract the :returns specifier (if any)...
    my $returns_check;
    if ($decl_ref->{syn_preattrs}) {
        $decl_ref->{syn_preattrs}
            =~ s{ $RETURNS }{ q{ } x length($&) }gexms;
        $returns_check = $+{returns};
        $decl_ref->{syn_preattrs}
            =~ s{ $DECOLONIZE }{ q{ } x length($&) }gexmso;
    }
    elsif ($decl_ref->{syn_postattrs}) {
        $decl_ref->{syn_postattrs}
            =~ s{ $RETURNS }{ q{ } x length($&) }gexms;
        $returns_check = $+{returns};
        $decl_ref->{syn_postattrs}
            =~ s{ $DECOLONIZE }{ q{ } x length($&) }gexms;
    }

    # Extract parameter :of specifiers (if any)...
    my $OF_CHECKS = q{};
    if ($decl_ref->{syn_sig}) {
        while ($decl_ref->{syn_sig} =~ s{ $EXTRACT_OF }{$+{param}}xms) {
            # Extract and normalize parameter's :of check...
            my %of = %+;
            $of{check} = substr($of{check}, 1, -1);

            if ($of{sigil} eq '$') {
                # Generate and cache wizard for checking scalar parameter values...
                Data::Checks::_build_scalar_wizard_for(@of{qw< check param >});

                # Build inline check for initialization of parameter...
                my ($pass_check) = Data::Checks::_gen_of_check_code(@of{qw< check param >});

                # Install extra code at start of sub to check parameter...
                $OF_CHECKS .= qq{Data::Checks::FAIL q{Can't pass } . Data::Checks::pp($of{param}) . q{ to parameter $of{param} in call to $decl_ref->{syn_name}\() at } . join(' line ', (caller)[1,2]) . qq{:\\nValue failed parameter's \Q$of{check}\E check.\\n} if !$pass_check; Variable::Magic::cast $of{param}, \$Data::Checks::SCALAR_WIZARD_FOR{q{$of{param}/$of{check}}}; };
            }
            elsif ($of{sigil} eq '@') {
                # Generate tie class for checking array parameter values...
                my $TIECLASS = Data::Checks::_build_array_check_tieclass(@of{qw< param check >}, 1);

                # Install extra code at start of sub to check parameter...
                $OF_CHECKS .= qq{tie $of{param}, '$TIECLASS', \\$of{param}; }
            }
            else {
                # Generate tie class for checking array parameter values...
                my $TIECLASS = Data::Checks::_build_hash_check_tieclass(@of{qw< param check >});

                # Install extra code at start of sub to check parameter...
                $OF_CHECKS .= qq{tie $of{param}, '$TIECLASS', \\$of{param}; }
            }
        }
    }

    # No rewrite required if no extras specified...
    return q{} if !$returns_check && !$OF_CHECKS;

    # Make sure there's a return check...
    $returns_check //= 'ANY';

    # Update syntactic components with return-checking source code...
    %{$decl_ref} = ( %{$decl_ref}, _gen_returns_checks_source($returns_check, $decl_ref->{syn_name}) );

    # Create unique variables to check disabled sub checking...
    state $NONE_TRACKER = 'NONE0000000000';
    $NONE_TRACKER++;

    # Workaround the Perl 5.28+ bug in the compilation subs followed by vars that have attrs
    # (https://github.com/Perl/perl5/issues/19245)
    my $FIX_SUB_ATTR_BUG = $] > 5.026 ? qq{sub ___$NONE_TRACKER {}} : q{};

    # Build source code for :returns check (if any)...
    return do {
      $K_MODE eq '-K'
        # Under -K we ignore (i.e. don't implement) parameter and returns checks
        ? qq{
            «lexical»
            «ws_presub»        sub
            «ws_prename»       «name»
            «ws_prepreattrs»   «preattrs»
            «ws_presig»        «sig»
            «ws_prepostattrs»  «postattrs»
            «ws_preblock»      «block»
            $FIX_SUB_ATTR_BUG
          }

        # Otherwise, we implement all the checks...
        : qq{
            «lexical»
            «ws_presub»        sub
            «ws_prename»       «name»
            «ws_prepreattrs»   «preattrs»
            «ws_presig»        «sig»
            «ws_prepostattrs»  «postattrs»
            «ws_preblock»      {
                state sub __IMPL__ «sig» {
                    local *__ANON__ = __PACKAGE__ . q{::«name»};
                    no warnings 'once', 'redefine';
                    local *CORE::GLOBAL::caller = \\&Data::Checks::_caller;
                    «block»
                }
                BEGIN { \$Data::Checks::$NONE_TRACKER = (\$^H{'Data::Checks/mode'}//q{}) eq 'NONE'; }
                UNITCHECK { if (*«name»{CODE} && \$Data::Checks::$NONE_TRACKER) { no warnings; *«name» = \\&__IMPL__; } }

                if (((caller 0)[10]{'Data::Checks/mode'}//q{}) ne 'NONE') {$OF_CHECKS}

                use if \$] >= 5.036, experimental => 'args_array_with_signatures';

                if (wantarray) {
                    no warnings 'once';
                    my \@result = &__IMPL__;
                    my \$scalar = \@result == 1;
                    Data::Checks::FAIL1 «list_msg» . "\\nat " . join(' line ', (caller)[1,2]) . "\\n"
                        unless «list_check»;
                    return \@result;
                }
                elsif (defined wantarray) {
                    my \$result = &__IMPL__;
                    Data::Checks::FAIL1 «scalar_msg» . "\\nat " . join(' line ', (caller)[1,2]) . "\\n"
                        unless «scalar_check»;
                    return \$result;
                }
                else {
                    &__IMPL__;
                    Data::Checks::FAIL1 «void_msg» . "\\nat " . join(' line ', (caller)[1,2]) . "\\n"
                        unless «void_check»;
                    return;
                }
            }$FIX_SUB_ATTR_BUG
        }
    } =~ s/\n/ /gr =~ s{«([^»]+)»}{ $decl_ref->{"syn_$1"} // q{} }gre;  # Fill in the components
}



# (Don't try this at home, kids!)
# Add :of attribute processing (without polluting UNIVERSAL to do so)...

my %SOURCE_VARNAME;
my %SOURCE_CHECK_SPEC;
my %SOURCE_IS_INIT;

package # Hide this from CPAN
attributes {
    use attributes;
    use Variable::Magic qw< wizard cast >;

    # Let carp and croak skip this package...
    our @CARP_NOT = qw< Data::Checks Filter::Simple >;

    # Cache the original attributes loader...
    state $real_import; BEGIN { $real_import = *attributes::import{CODE}; }

    # Make a wrapper...
    no warnings 'redefine';
    *import = sub {
        # Pass anything else to the real mechanism...
        goto &{$real_import} if @_ < 4 || $_[3] !~ /\Adatachecksof\d+\z/;

        # :of is a no-op if checks are deactivated...
        return if $K_MODE eq '-K';
        my $hints = (caller 0)[10];
        return if ($hints->{'Data::Checks/mode'}//q{}) eq 'NONE';

        # Unpack the components of the :of attribute...
        my (undef, $package, $referent, $CHECK_NAME) = @_;
        my $reftype = Data::Checks::reftype($referent);

        # Extract the actual check and variable info...
        my $uninitialized = $SOURCE_IS_INIT{$CHECK_NAME} ? 0 : 1;
        my $check_spec    = $SOURCE_CHECK_SPEC{$CHECK_NAME};
        my $varname       = shift @{$SOURCE_VARNAME{$CHECK_NAME}};
        push @{$SOURCE_VARNAME{$CHECK_NAME}}, $varname;

        # Some checks are illegal in an :of attribute...
        if ($reftype ne 'code' && $check_spec =~ /\bVOID\b|\bLIST\b/) {
            die qq{Can't specify :of($check_spec) on a \L$reftype\E variable at },
                 join(' line ', (caller)[1,2]), "\n",
                qq{(The LIST and VOID checks are only valid in the :returns specifier of a subroutine)\n};
        }

        # Handle the different kinds of declarations individually...
        # 1. Implement checked scalars via Variable::Magic (for performance)...
        if ($reftype eq 'SCALAR') {
            # Uninitialized scalars can only be declared with checks that also pass for an undef...
            if ($uninitialized) {
                my ($check_undef) = Data::Checks::_gen_of_check_code($check_spec, 'undef()');
                if (!eval $check_undef) {
                    Data::Checks::FAIL
                        qq{Can't declare $varname :of($check_spec) with no initial value:\n},
                        qq{the default undef value would fail the $check_spec check};
                }
            }

            # Build the required variable magic and install it on the scalar...
            cast ${$referent}, Data::Checks::_build_scalar_wizard_for($check_spec, $varname);
        }
        # 2. Implement checked arrays via a tie (for completeness)...
        elsif ($reftype eq 'ARRAY') {
            my $tie_name = Data::Checks::_build_array_check_tieclass($varname, $check_spec, $uninitialized);
            tie @{$referent}, $tie_name, $referent;
        }
        # 3. Implement checked hashes via a tie (for convenience)...
        elsif ($reftype eq 'HASH') {
            my $tie_name = Data::Checks::_build_hash_check_tieclass($varname, $check_spec);
            tie %{$referent}, $tie_name, $referent;
        }
        # 4. Can't put an :of on a sub...
        elsif ($reftype eq 'CODE') {
            die qq{Can't specify an :of attribute on a subroutine at } . join(' line ', (caller)[1,2])
              . qq{\n(did you mean :returns($check_spec)?)};
        }
        # 5. ...or on anything else...
        else {
            Data::Checks::FAIL qq{ Can't apply a check to $reftype referent};
        }
    };
}

# This generates an optimized implementation of a checked scalar...
use Variable::Magic qw< wizard cast >;
sub _build_scalar_wizard_for ($CHECK_NAME, $VARNAME) {
    # We can cache these to optimize performance...
    our %SCALAR_WIZARD_FOR;

    # Generate, cache, and return the implementation...
    return $SCALAR_WIZARD_FOR{$VARNAME . '/' . $CHECK_NAME} //= do {
        # Exception objects need a personalized classname...
        my $EXCEPTION_CLASS = $CHECK_NAME =~ /\A[a-zA-Z]+\z/ ? $CHECK_NAME : 'EXPR';

        # Build the code that performs the check...
        my ($CHECK_EXPR) = Data::Checks::_gen_of_check_code($CHECK_NAME, '${$_[0]}');

        # Build the handler...
        wizard set => eval qq{
            sub {
                # Check the assignment and report failure...
                if (!eval{ $CHECK_EXPR }) {
                    Data::Checks::REFAIL(\$@) if \$@;
                    my \$loc = join ' line ', (caller 1)[1,2];
                    my \$desc = Data::Checks::pp(\${\$_[0]});
                    Data::Checks::FAIL
                        qq{Can't assign \$desc to \\$VARNAME: failed \Q$CHECK_NAME\E check};
                }
            }
        } // Carp::croak $@ =~ s/ at .*|BEGIN failed--compilation aborted.*//rs;
    }
}


# Utilities used by rewritten subs...

# This is used to initialize uninitialized declarations...
sub _init_var_decl { return }

# This replaces the CORE::caller() in the implementation of a subroutine with a return check...
sub _caller {
    my @caller = CORE::caller(($_[0]//0)+2);
    !wantarray ? $caller[0] : @_ ? @caller : @caller[0..2];
}

# This extracts the new syntax from the old and replaces it with an implementation in standard Perl...
state sub _FILTER {
    {
        my $caller_level = 0;
        my $caller;
        do {
            $caller = caller($caller_level);
            $caller_level++;
            if ( $caller_level > 5 || !$caller )
            {    # shouldn't be greater than 2 ...
                die
"PANIC: We could not determine calling package. Too many  levels of FILTER";
            }
          } while $caller =~ /\A (?:
                Data::Checks     # Don't apply features to ourselves
                | 
                Filter::Simple   # or to our filter
            ) /x;

        # XXX Hijacking import didn't work, so we use this. Need to apply
        # these directly here. Need to debug this later.
        strict->import::into($caller);
        warnings->import::into($caller);
        feature->import::into( $caller, ':5.22' );
        experimental->import::into( $caller, 'signatures' );
    }

    # This PPR-based grammar does all the work...
    state $EXTENDED_PERL_GRAMMAR = qr{
        (?&PerlDocument)

        (?(DEFINE)

            # Handle phantom 'use checks'/'no checks' without adding a checks.pm module...
            (?<PerlUseStatement>
                             (?{ pos() })          (?<useno> use | no )
                             (?>(?&PerlNWS))       checks \b
                         (?: (?>(?&PerlNWS))       (?&PerlPodSequence) )?+
                (?<args> (?: (?>(?&PerlOWS))       (?&PerlExpression)  )?+ )
                             (?>(?&PerlOWSOrEND))  (?> (?<semi> ; ) | (?= \} | \z ))

                                    # Save internal representation...
                                    (?{ push @Data::Checks::source_decls, {
                                            is_checks => 1,
                                            from      => $^R,
                                            len       => pos() - $^R,
                                            useno     => $+{useno},
                                            args      => $+{args},
                                            semi      => $+{semi} // q{},
                                            container => $Data::Checks::sub_container,
                                        };
                                    })

                | (?>(?&PerlStdUseStatement))
            )

            # Locate string evals (because they need recursive preprocessing with this filter)...
            (?<PerlBuiltinFunction>
                ((?>(?&PerlStdBuiltinFunction)))

                # Save internal representation...
                (?{ if ($^N eq 'eval') {
                        push @Data::Checks::source_decls, {
                            is_eval   => 1,
                            from      => pos() - 4,
                            len       => 4,
                            container => $Data::Checks::sub_container,
                        };
                    }
                })
            )

            # Add :of attributes to signature parameters...
            (?<PerlParameterDeclaration>
                (?: # Nameless optional (no checks allowed)
                        \$  (?>(?&PerlOWS))
                    (?: =   (?>(?&PerlOWS))  (?&PerlConditionalExpression)?+ (?>(?&PerlOWS)) )?+
                |
                    (?&PerlVariableScalar) (?>(?&PerlOWS))
                    (?: : (?>(?&PerlOWS))  of  (?= \( ) (?&PPR_X_quotelike_body) (?>(?&PerlOWS)) )?+  # )
                    (?: =   (?>(?&PerlOWS))  (?&PerlConditionalExpression)   (?>(?&PerlOWS)) )?+
                |
                    (?&PerlVariableArray) (?>(?&PerlOWS))
                    (?: : (?>(?&PerlOWS))  of  (?= \( ) (?&PPR_X_quotelike_body) (?>(?&PerlOWS)) )?+  # )
                |
                    (?&PerlVariableHash)  (?>(?&PerlOWS))
                    (?: : (?>(?&PerlOWS))  of  (?= \( ) (?&PPR_X_quotelike_body) (?>(?&PerlOWS)) )?+  # )
                )
                (?: , (?>(?&PerlOWS))  |  (?= \) ) )     # (
            )

            # Add :returns to named sub declarations and extract internal checked vars...
            (?<PerlSubroutineDeclaration>
                # Set up potential internal representation for this sub...
                (?{ local $Data::Checks::sub_container
                        = { from => pos(), container => $Data::Checks::sub_container };
                })

                (?>
                    (?<lexical>     (?> my\b | our\b | state\b | )       )
                        (?{ $Data::Checks::sub_container->{syn_lexical} = $^N; })
                    (?<ws_presub>   (?>(?&PerlOWS))                      )
                        (?{ $Data::Checks::sub_container->{syn_ws_presub} = $^N; })

                    sub \b

                    (?<ws_prename>  (?>(?&PerlOWS))                      )
                        (?{ $Data::Checks::sub_container->{syn_ws_prename} = $^N; })
                    (?<name>        (?>(?&PerlOldQualifiedIdentifier))   )
                        (?{ $Data::Checks::sub_container->{syn_name} = $^N; })
                |
                    (?<name>        (?> AUTOLOAD | DESTROY )             )
                        (?{ $Data::Checks::sub_container->{syn_name} = $^N; })
                )
                (?:
                    # Perl pre 5.028
                    (?<ws_presig>   (?>(?&PerlOWS))                      )
                        (?{ $Data::Checks::sub_container->{syn_ws_presig} = $^N; })
                    (?<sig>         (?> (?&PerlSignature)
                                    |   \( [^)]*+ \)                     # (
                                    |
                                    )
                    )
                        (?{ $Data::Checks::sub_container->{syn_sig} = $^N; })
                    (?<ws_prepostattrs>         (?>(?&PerlOWS))          )
                        (?{ $Data::Checks::sub_container->{syn_ws_prepostattrs} = $^N; })
                    (?<postattrs>               (?>(?&PerlAttributes)) | )
                        (?{ $Data::Checks::sub_container->{syn_postattrs} = $^N; })
                |
                    # Perl post 5.028
                    (?<ws_prepreattrs>          (?>(?&PerlOWS))          )
                        (?{ $Data::Checks::sub_container->{syn_ws_prepreattrs} = $^N; })
                    (?<preattrs>                (?>(?&PerlAttributes)) | )
                        (?{ $Data::Checks::sub_container->{syn_preattrs} = $^N; })
                    (?<ws_presig>               (?>(?&PerlOWS))          )
                        (?{ $Data::Checks::sub_container->{syn_ws_presig} = $^N; })
                    (?<sig>                     (?>(?&PerlSignature))  | )
                        (?{ $Data::Checks::sub_container->{syn_sig} = $^N; })
                )

                    (?<ws_preblock>             (?>(?&PerlOWS))          )
                        (?{ $Data::Checks::sub_container->{syn_ws_preblock} = $^N;
                            $Data::Checks::sub_container->{syn_block_from}  = pos(); })
                    (?<block>                   (?> ; | (?&PerlBlock) )  )
                        (?{ $Data::Checks::sub_container->{syn_block_len}
                                = pos() - $Data::Checks::sub_container->{syn_block_from} ; })

                # Save internal representation...
                (?{
                    $Data::Checks::sub_container->{len} = pos() - $Data::Checks::sub_container->{from};
                    push @Data::Checks::source_decls, $Data::Checks::sub_container;
                })
            )

            # Add :returns to anonymous sub declarations and extract internal checked vars...
            (?<PerlAnonymousSubroutine>
                # Set up potential internal representation for this sub...
                (?{ local $Data::Checks::sub_container
                        = { from => pos(), container => $Data::Checks::sub_container };
                })

                sub \b

                (?:
                    # Perl pre 5.028
                    (?<ws_presig>   (?>(?&PerlOWS))                      )
                        (?{ $Data::Checks::sub_container->{syn_presig} = $^N; })
                    (?<sig>         (?> (?&PerlSignature)
                                    |   \( [^)]*+ \)                     # (
                                    |
                                    )
                    )
                        (?{ $Data::Checks::sub_container->{syn_sig} = $^N; })
                    (?<ws_prepostattrs>         (?>(?&PerlOWS))          )
                        (?{ $Data::Checks::sub_container->{syn_ws_prepostattrs} = $^N; })
                    (?<postattrs>               (?>(?&PerlAttributes)) | )
                        (?{ $Data::Checks::sub_container->{syn_postattrs} = $^N; })
                |
                    # Perl post 5.028
                    (?<ws_prepreattrs>          (?>(?&PerlOWS))          )
                        (?{ $Data::Checks::sub_container->{syn_ws_prepreattrs} = $^N; })
                    (?<preattrs>                (?>(?&PerlAttributes)) | )
                        (?{ $Data::Checks::sub_container->{syn_preattrs} = $^N; })
                    (?<ws_presig>               (?>(?&PerlOWS))          )
                        (?{ $Data::Checks::sub_container->{syn_presig} = $^N; })
                    (?<sig>                     (?>(?&PerlSignature))  | )
                        (?{ $Data::Checks::sub_container->{syn_sig} = $^N; })
                )

                    (?<ws_preblock>             (?>(?&PerlOWS))          )
                        (?{ $Data::Checks::sub_container->{syn_ws_preblock} = $^N;
                            $Data::Checks::sub_container->{syn_block_from}  = pos(); })
                    (?<block>                   (?>(?&PerlBlock))        )
                        (?{ $Data::Checks::sub_container->{syn_block_len}
                                = pos() - $Data::Checks::sub_container->{syn_block_from} ; })

                # Save internal representation...
                (?{
                    $Data::Checks::sub_container->{len} = pos() - $Data::Checks::sub_container->{from};
                    push @Data::Checks::source_decls, $Data::Checks::sub_container;
                })
            )

            # Extract variable declarations (especially initialization state info)...
            (?<PerlVariableDeclaration>
                # Set up potential internal representation for this sub...
                (?> my | our | state ) \b           (?>(?&PerlOWS))
                (?: (?&PerlQualifiedIdentifier)        (?&PerlOWS))?+
                (?> (?<lvalue> (?&PerlLvalue) ) )   (?>(?&PerlOWS))

                (?{ local $Data::Checks::var_decl = {
                                                        is_var => 1,
                                                        from => pos(),
                                                        lvalue => $+{lvalue},
                                                        container => $Data::Checks::sub_container,
                                                    };
                })
                (?:
                    # We're only interested in var decls with attributes...
                    (?> (?&PerlAttributes) )

                    # Especially if they're uninitialized...
                    (?>
                        (?! (?>(?&PerlOWS)) (?>(?&PerlAssignmentOperator)))
                        (?{ $Data::Checks::var_decl->{uninit} = 1; })
                    )?+

                    # Save internal representation...
                    (?{
                        $Data::Checks::var_decl->{len} = pos() - $Data::Checks::var_decl->{from};
                        push @Data::Checks::source_decls, $Data::Checks::var_decl;
                    })
                )?+
            )
        )

        $PPR::X::GRAMMAR
    }xms;

    # Prepare to collate subroutine declarations...
    local @Data::Checks::source_decls;

    # Parse through source code...
    if ($_ =~ $EXTENDED_PERL_GRAMMAR) {
        # Plan to process declarations depth-first end-to-start...
        my @decls = sort    { $a->{container} && $a->{container} == $b ? -1
                            : $b->{container} && $b->{container} == $a ? +1
                            :                                             0 }
                    reverse @Data::Checks::source_decls;

        # Rewrite each construct (if necessary) and adjust span of its container (if any)...
        DECL:
        for my $decl_ref (@decls) {
            # Rewrite use/no checks...
            if ($decl_ref->{is_checks}) {
                my $rewritten_pragma
                    = qq{$decl_ref->{useno} Data::Checks::CheckPragmaSim $decl_ref->{args} $decl_ref->{semi}};

                # Update container's information...
                if ($decl_ref->{container}) {
                    my $delta_len = length($rewritten_pragma) - $decl_ref->{len};
                    $decl_ref->{container}{len}           += $delta_len;
                    $decl_ref->{container}{syn_block_len} += $delta_len;
                }

                # Install rewritten eval code...
                substr($_, $decl_ref->{from}, $decl_ref->{len}, $rewritten_pragma);
                next DECL;
            }


            # Rewrite string evals...
            elsif ($decl_ref->{is_eval}) {
                my $rewritten_eval = q{eval Data::Checks::_filter};
                # Update container's information...
                if ($decl_ref->{container}) {
                    my $delta_len = length($rewritten_eval) - $decl_ref->{len};
                    $decl_ref->{container}{len}           += $delta_len;
                    $decl_ref->{container}{syn_block_len} += $delta_len;
                }

                # Install rewritten eval code...
                substr($_, $decl_ref->{from}, $decl_ref->{len}, $rewritten_eval);
                next DECL;
            }

            # Rewrite and record uninitialized scalar var decls...
            if ($decl_ref->{is_var}) {
                # Use this to extract the :of attrs...
                state $ATTR_PARTS = qr{
                      :
                    | $PERLOWS
                    | (?> (?<of_attr> \bof\b ) | [^\W\d]\w*+ )              # Attr name
                      (?: \(  (?<attr_config> (?&round_contents) )  \) )?+  # Attr args (if any)

                    (?(DEFINE)
                        (?<round_contents>  (?: [^()]++ | \\. | \(  (?&round_contents)  \) )*+ )
                    )
                }xms;

                # Use this to rename and cache/retrieve details about the :of attrs...
                state $ATTR_ID = 'datachecksof00000000000000';

                # Extract the attr source code...
                my $attrs_decl = substr($_, $decl_ref->{from}, $decl_ref->{len});

                # Replace the :of attrs with unique IDs...
                $attrs_decl =~ s{ $ATTR_PARTS }{
                    # Rewrite and record details of :of attrs...
                    if ($+{of_attr}) {
                        # Generate a unique ID for this :of attr...
                        $ATTR_ID++;

                        # Record the relevant info about it...
                        $SOURCE_CHECK_SPEC{$ATTR_ID} = $+{attr_config};
                        $SOURCE_VARNAME{$ATTR_ID}    = [$decl_ref->{lvalue} =~ m{[\$\@%][^\W\d]\w*}gx];
                        $SOURCE_IS_INIT{$ATTR_ID}    = !$decl_ref->{uninit};

                        # Rewrite it...
                        $ATTR_ID
                    }

                    # Other attrs passed through unchanged...
                    else { $& }
                }gexms;

                # Install those unique IDs...
                substr($_, $decl_ref->{from}, $decl_ref->{len}, $attrs_decl);

                # Update container's information...
                if ($decl_ref->{container}) {
                    my $delta_len = length($attrs_decl) - $decl_ref->{len};
                    $decl_ref->{container}{len}           += $delta_len;
                    $decl_ref->{container}{syn_block_len} += $delta_len;
                }

                next DECL;
            }

            # Otherwise rewrite sub decls...

            # Extract current block source (may already have been rewritten from original source)...
            $decl_ref->{syn_block} = substr($_, $decl_ref->{syn_block_from}, $decl_ref->{syn_block_len});

            # Rewrite subroutine...
            my $rewritten_sub = eval { _rewrite_sub($decl_ref) } // qq{ BEGIN { die q{$@} } }
                or next;

            # Update container's information...
            if ($decl_ref->{container}) {
                my $delta_len = length($rewritten_sub) - $decl_ref->{len};
                $decl_ref->{container}{len}       += $delta_len;
                $decl_ref->{container}{syn_block_len} += $delta_len;
            }

            # Install rewritten sub code...
            substr($_, $decl_ref->{from}, $decl_ref->{len}, $rewritten_sub);
        }
    }
    else {
        die "Internal parsing error";
    }

    # Implement the default-to-warnings behaviour of -k...
    $_ = q{BEGIN { $^H{'Data::Checks/mode'} = 'NONFATAL' }} . $_
        if $K_MODE eq '-k';
}

# This sub provides recursive filtering for string evals (once they're rewritten)...
sub _filter :prototype($) {
    local $_ = shift;
    _FILTER();
    return $_;
}

# Apply the filter to any code in which this module is called...
FILTER {
    shift @_;
    my ($file, $line) = (caller 1)[1,2];
    $line--;  # ...to make the error messages work correctly
    my sub FAIL ($msg) { $_ = qq{\n#line $line\nBEGIN{die q{$msg} }} }
    for my $arg (@_) {
        if ($arg =~ m{\A -[kK] \z}xms) {
            if ($loaded_at) {
                return FAIL qq{Data::Checks was already loaded at $loaded_at.\n}
                          . qq{Too late to specify '$arg' option};
            }
            if ($K_MODE && $K_MODE ne $arg) {
                return FAIL qq{Can't specify both '$K_MODE' and '$arg' options};
            }
            $K_MODE = $arg;
        }
        else {
            return FAIL qq{Invalid argument ("$arg") to "use Data::Checks"};
        }
    }
    $loaded_at //= "$file line $line";

    # Rewrite the code...
    _FILTER();
};

1; # Magic true value required at end of module

__END__

=encoding utf8

=head1 NAME

Data::Checks - Declarative data validation for variables and subroutines


=head1 VERSION

This document describes Data::Checks version 0.002


=head1 SYNOPSIS

    use Data::Checks;

    state $count :of(UINT) = 0;
                 #########

    our $exception :of( STR | OBJ | UNDEF);
                   #######################

    my @data :of(HASH[INT => ARRAY[OBJ[Account]]]);
             #####################################

    sub get_account_data :returns(LIST[OBJ[Account]]) ($n :of(UINT)) {...}
                         ############################     #########

    $count += 1;      # Okay
    $count -= 10;     # EXCEPTION: rvalue not an unsigned integer

    $exception = [];  # EXCEPTION: rvalue not a string, object or undef

    @data = ( { 0 => [get_account_data(1)    ] } );  # Okay
    @data = ( { 0 => [get_account_data('one')] } );  # EXCEPTION: parameter not an integer
    @data = ( [ 0 => [get_account_data('one')] ] );  # EXCEPTION: rvalue not a hash


=head1 STATUS

This is very early alpha code, designed to prototype an idea that might one
day be a core feature of Perl.

Every aspect of this module is subject to sudden and radical change,
from the check syntax itself, to the names of the various checks,
to their essential behaviours, features, and limitations.

B<DO I<NOT> USE THIS MODULE IN PRODUCTION CODE.>


=head1 DESCRIPTION

This is I<B<NOT>> a type system for Perl.

The fundamental problem with type systems is that every individual programmer
knows exactly what they mean by – and want in – and need from – a I<“type system”>
...but no two programmers can ever agree precisely what that is.

What most Perl users actually need is a practical way to ensure that, when a value
that is assigned to a variable, or passed to a parameter, or returned from a
subroutine, that value conforms to the designer’s original expectations and
assumptions I<(e.g. did their subroutine get passed a positive integer and a
filehandle, and did it return a reference to a hash of strings?)>

So this is not a compile-time type-system for Perl.
It’s a runtime data-checking system for Perl.
A system of I<“checks”>.

=head2 Checks

A I<check> is an assertion about the value(s) that can be assigned to a variable,
passed to a parameter, or returned by a subroutine. This module provides
a large number of L<built-in checks|/"Built-in checks"> and will eventually also
offer a mechanism for specifying L<user-defined checks|/"User-defined checks">.

Built-in checks are all named in I<UPPERCASE>: C<INT>, C<STR>, C<HASH>, C<ARRAY>, I<etc.>
User-defined checks must be named in I<MixedCase>: C<Account>, C<ClientName>, C<PosNum>, I<etc.>
For more details on this carefully considered design decision see: L<"Why built-in checks are LOUD">.


=head2 An important note about the nature of checks

It’s important to understand that a check applied to a variable is not an
B<I<invariant>> on that variable. It is, rather, a B<I<prerequisite>> for
assignment into that variable. This is an important difference. An I<“invariant
on”> would guarantee that the contents of the variable must B<I<always>> meet a
given constraint; a I<“prerequisite into”> only guarantees that each element
must be assigned values that meet the constraint B<I<at the moment they are
assigned>>. So an array such as C<my @data :of(HASH[INT])> only requires that
each element of C<@data> must be assigned a hash whose values are integers. If
you were to subsequently modify an element like so:

    $data[$idx]{$key} = 'not an integer";

...the check on C<@data> would B<I<not>> fail at that point...because the assignment
is not modifying C<@data> directly, only retrieving a value from it and modifying
the contents of an entirely different variable I<through> that retrieved reference value.

Of course, we B<I<could>> specify that checks are invariants, instead of
prerequisites, but that would require that any reference value stored within a
checked array or hash would have to have checks automatically and recursively
applied to them as well, which would greatly increase the cost of checking, and
might also lead to unexpected action-at-a-distance, when the now-checked
references are modified through some other access mechanism. Moreover, we would
have to ensure that such auto-subchecked references were appropriately
“de-checked” if they are ever removed from the checked container. To say
nothing of how we might manage any conflict if the nested referents happened to
have their own (possibly inconsistent) checks.

So – for the time being at least – the checks provided by this module are
simply assertions on direct assignments, rather than invariants
over a variable’s entire nested data structure.


=head1 INTERFACE

=head2 Applying a check to a scalar variable

You apply a check to a variable by declaring it with an C<:of> attribute:

    my $count  :of(INT)  = 0;
    my $name   :of(STR)  = "";
    my $score  :of(NUM)  = 0.0;

Thereafter, a new value can only be assigned to that variable if the specified check
succeeds (I<i.e.> returns true) for that new value; if the check fails, an exception
is immediately thrown instead.

A check’s test is applied regardless of how the assignment is invoked:
during initialization, during an explicit assignment, or as the result of some other mutator.
Hence all of the following would throw an exception:

    my $count :of(INT);           # The implicit undef initialization does not pass the INT check

    $name = ['Kim', 'Lee'];       # An arrayref does not pass the STR check

    $score .= ' (pass)';          # "0.0 (pass)" does not pass the NUM check


=head2 Applying a check to an array variable

If a check is specified on an array, that check is applied to each S<I<element>>
of the array, every time any element is modified in any way (assigned to,
concatenated to, incremented, deleted, I<etc.>) For example:

    my @scores  :of(NUM);       # Every element must be a number
    my @data    :of(DEF);       # Every element must be defined
    my @events  :of(OBJ);       # Every element must be a object

Note that a built-in check on an array I<never> applies collectively to the entire array;
it always applies individually to each element of the array.
If you want to specify some condition to be verified across the entire array,
you need a L<user-defined check|"User-defined checks">.

Unlike checked scalars, checked arrays generally do not have to be initialized,
because every element in an empty array (all zero of them) trivially satisfies
almost any possible check.

However, you can also specify the required length of an array, or a range of acceptable lengths,
by specifying a list of two components in the array’s C<:of>. The first component must
then be an unsigned integer, or a range of unsigned integers, which indicate the
minimum/maximum number of elements the array is permitted to store. The second component
is the subcheck that will be applied to each element. Hence:

    my @scores  :of(100    => NUM) = (0) x 100;     # Must store exactly 100 elements;
                                                    # each must be a number

    my @data    :of(0..9   => DEF);                 # Must store no more than nine elements;
                                                    # each must be defined

    my @events  :of(1..inf => OBJ) = get_events();  # Must store one or more elements;
                                                    # each must be an object


Note that arrays with a specified size that doesn’t include zero
B<I<do>> have to be initialized appropriately.

To specify a size without limiting the kinds of values that the array can hold,
specify the second argument as C<ANY>:

    my @anydata :of(10 => ANY) = get_data_(10);     # Must store exactly ten elements,
                                                    # but each element can be anything


=head2 Applying a check to a hash variable

If a check is specified on a hash, that check is applied to the
value of each entry in the hash, whenever those values are assigned. For example:

    my %seen   :of(INT);       # Every value in the hash must be an integer
    my %record :of(DEF);       # Every value in the hash must be defined
    my %events :of(HASH);      # Every value in the hash must a reference to a nested hash

Like checked arrays, checked hashes generally do not have to be initialized.
Also, as with arrays, checks on hashes never apply collectively to the entire hash;
only individually to each entry of the array I<< (though you can always create a L<user-defined check|"User-defined checks"> that B<I<does>> apply to the hash as a whole). >>

You can also set up a check on a hash that verifies keys as well as (or instead of)
values...by specifying an C<:of> containing a list of two checks separated by a C<< => >>.
The first check is then applied to any key being added to the hash, and the second check
is applied to the corresponding value being added. Hence:

    my %seen    :of( INT => ANY );                # Every key in the hash must be an integer;
                                                  # Stored values can be anything

    my %record  :of( STR[/^[XYZ]\d+/] => DEF );   # Every key must match the specified pattern;
                                                  # Every value in the hash must be defined

    my %events  :of( CLASS => OBJ );              # Every key must be the name of a class;
                                                  # Every value in the hash must an object


=head2 Applying a check to a parameter variable

Subroutine parameters are just a special kind of variable, so they may also
be checked by applying an C<:of> attribute to them:

    sub enlist ($N :of(INT), $oxford :of(BOOL), @terms :of(STR))  {
                   ########          #########         ########
        my $max   = min($N, scalar @terms);
        my $comma = $oxford ? ',' : '';
        return $max < 3 ? join(' and ', @terms[0..$max-1])
                        : join(', ', @terms[0..$max-2]) . "$comma and $terms[$max-1]";
    }


Such parameter checks operate exactly like regular variable checks, and will be
applied to any subsequent modifier operation on the parameter.


=head2 Applying a check to a subroutine return value

In addition to checking the values that may be stored in a variable,
you can also check the return value of a subroutine. To do so,
declare the subroutine with a C<:returns> attribute:

    sub count_active_accts  :returns(INT)  (@acct_list) {
                            #############
        return scalar grep { $_->is_active } @acct_list;
    }


The check is applied to every return value from the subroutine,
whether it is the result of an explicit C<return> statement,
or the implicit return of its final executed expression.

The specified check is applied to calls in any context (list, scalar, or void).
In scalar context, the check is simply applied to the single return value.

In list context, the check is applied to the entire list being returned
(B<I<not>> to each list element individually).

Hence, because the vast majority of built-in checks require a single scalar value or reference to
test, most built-in checks will fail if a list-context call happens to return more than a single element.
And because a void-context return returns no value at all (not even C<undef> or an empty list),
most built-in checks will also fail in void context. For example:

    sub get_positive  :returns(INT)  (@data)  { return grep {$_ > 0} @data }
                      #############

    # Always okay in scalar context...
    $count = get_positive(-1..1);   # Okay: grep in scalar context returns an integer count
    $count = get_positive(-3..3);   # Ditto here (even though the count is now 3, not 1)

    # Only occasionally okay in list context...
    @valid = get_positive(-1..1);   # Okay: INT check passes when passed the one-element list (1)
    @valid = get_positive(-3..3);   # EXCEPTION: INT test fails when passed the list (1,2,3)

    # Never okay in void context...
             get_positive(-1..1);   # EXCEPTION: INT check fails when passed no argument
             get_positive(-3..3);   # Ditto


=head3 Contextually aware checks on return values

To better support list- and void-context returns, the built-in C<LIST> and C<VOID> checks
can be used.

Whereas every other built-in test implicitly tests a subroutine’s return value collectively,
as a single entity, a C<:returns(LIST)> tests each element of the return list individually.
Likewise, a C<:returns(VOID)> only passes when the checked subroutine returns no value whatsoever,
not even C<undef> or an empty list (I<i.e.> only when it is called in void context).

For example:

    sub generate_data  :returns(LIST)  ($n)    { return map {rand} 1..$n }
    sub count_users    :returns(INT)   ($pat)  { return scalar grep /$pat/, @USERS }
    sub clear_screen   :returns(VOID)  ()      { print "\n" x $SCREEN_HEIGHT }

    # and then...

    my @data  = generate_data(99);        # Okay: sub returned a list
    my $datum = generate_data(99);        # Okay: sub returned a single value – a one-element list
                generate_data(99);        # EXCEPTION: sub didn't return a list, not even an empty list

    my @counts = count_users(qr/^\d+$/);  # Okay: sub returned an integer – from scalar grep
    my $count  = count_users(qr/^\d+$/);  # Okay: ditto
                 count_users(qr/^\d+$/);  # EXCEPTION: sub didn't return integer...or anything else

    my @cleared = clear_screen();         # EXCEPTION: Can't call clear_screen() in list context
    my $cleared = clear_screen();         # EXCEPTION: Can't call clear_screen() in scalar context
                  clear_screen();         # Okay


The C<LIST> check optionally takes a L<parameter|"The parameterized LIST check">
that can be used to specify a subcheck on each element of the returned list.
In that case, the return-value check only passes if every element of the returned list
individually passes the specified subcheck. For example:

    # Each item of generated data must be a number in the range [0..1]
    sub generate_data  :returns(LIST[NUM])  ($n) { return map {rand} 1..$n }
                                    #####

Note that had this version of C<generate_data()> been implemented:

    sub generate_data  :returns(LIST[NUM])  ($n) { return map {('a'..'z')[rand 26]} 1..$n; }

...then the return-value check would fail because, although the subroutine still returns a list,
each element of that return list fails the C<NUM> check.

If you want to be able to call a checked subroutine in void context as well
(I<i.e.> to just silently throw away the returned value in void contexts),
you can use a L<check expression|"Check expressions"> to specify that void context
is also acceptable:

    # Subroutine returns a list of hash references in list context,
    # or just the next hash reference in scalar context,
    # but cannot be called in void context...
    sub get_events  :returns(LIST[HASH])  () { return wantarray ? splice @events : shift @events; }
                             ##########

    # Same as above, but we're also allowed to just throw away the return value in void context...
    sub get_events_maybe  :returns(LIST[HASH]|VOID)  () { get_events() }
                                   ###############


To summarize, a subroutine declared with:

=over

=item *

C<:returns(LIST)> always returns successfully in list and scalar contexts;
but always dies in void context

=item *

C<:returns(LIST[>I<subcheck>C<])> returns successfully in list and scalar
contexts B<I<if>> all return values pass the subcheck; but always dies in
void context

=item *

C<:returns(>I<check>C<)> returns successfully in scalar contexts B<I<if>> the
return value passes the check; returns successfully in list context B<I<if>> the
returned list contains exactly one element that also passes the check; but
always dies in void context

=item *

C<:returns(VOID)> always dies in list and scalar contexts;
but always returns successfully in void contexts

=back


=head2 Built-in checks

As the preceding examples imply, this module provides a considerable number of built-in
checks, which can be applied to any variable, parameter, or return value without
the need to define them first. These built-in checks are arranged in a coherent
hierarchy of increasingly stringent requirements.

When given a value C<$V> to validate, the built-in checks test it as follows:

=over

=item  C<ANY>

Always trivially passes (no actual test is applied)

=item  C<LIST>

I<< (in C<:returns> only) >> the subroutine must return a list of values

=item  C<VOID>

I<< (in C<:returns> only) >> the subroutine must return in void context

=item  C<UNDEF>

C<defined($V)> must return a false value

=item  C<DEF>

C<defined($V)> must return a true value

=item  C<NONREF>

C<builtin::reftype($V)> must return a false value

=item  C<REF>

C<builtin::reftype($V)> must return a true value

=item  C<HANDLE>

C<Scalar::Util::openhandle($V)> must return a true value

=item  C<BOOL>

C<builtin::reftype($V)> must return a false value,
or else C<$V> must be an object with a C<'bool'> overloading

=item  C<NUM>

C<Scalar::Util::looks_like_number($V)> must return true and C<$V> must be neither C<'Inf'> nor C<'NaN'>),
or else C<$V> must be an object with a C<'0+'> overloading

=item  C<INT>

C<$V> must satisify the C<NUM> check and C<$V> must not contain a <C'.'>

=item  C<STR>

C<builtin::reftype($V)> must return a false value and C<builtin::reftype(\$V)> must not return C<'GLOB'>,
or else C<$V> must be an object with a C<'""'> overloading

=item  C<GLOB>

C<builtin::reftype(\$V)> must return C<'GLOB'>

=item  C<UINT>

C<$V> must satisfy the C<INT> check and C<$V> must have no leading sign

=item  C<VSTR>

C<Scalar::Util::isvstring($V)> must return true

=item  C<CLASS>

C<$V> must be the name of a defined class

=item  C<ROLE>

B<I<(Note: This check is not currently implemented)>>

C<$V> must be the name of a defined role

=item  C<SCALAR>

C<builtin::reftype($V)> must return C<'SCALAR'>,
or else C<$V> must be an object with a C<'${}'> overloading

=item  C<REGEXP>

C<builtin::reftype($V)> must return C<'REGEXP'>,
or else C<$V> must be an object with a C<'qr'>overloading

=item  C<CODE>

C<builtin::reftype($V)> must return C<'CODE'>,
or else C<$V> must be an object with a C<'&{}'> overloading

=item  C<ARRAY>

C<builtin::reftype($V)> must return C<'ARRAY'>,
or else C<$V> must be an object with a C<'@{}'> overloading

=item  C<HASH>

C<builtin::reftype($V)> must return C<'HASH'>,
or else C<$V> must be an object with a C<'%{}'> overloading

=item  C<OBJ>

C<builtin::blessed($V)> must return a true value

=item  C<CHECK>

C<$V> must be the name of – or a reference to – a built-in or user-defined check
that is currently in lexical scope

=back


=head2 Parameterized checks

The module also supplies a number of built-in checks that can be configured via
compile-time parameters:

=over

=item C<NUM[>I<< targ_1, targ_2, etc >>C<]>

The value being checked must satisfy one of the target subchecks,
or must match one of the target regexes or ranges

=item C<INT[>I<< targ_1, targ_2, etc >>C<]>

The value being checked must satisfy one of the target subchecks,
or must match one of the target regexes, ranges, or values

=item C<UINT[>I<< targ_1, targ_2, etc >>C<]>

The value being checked must satisfy one of the target subchecks,
or must match one of the target regexes, ranges, or values

=item C<STR[>I<< targ_1, targ_2, etc >>C<]>

The value being checked must satisfy one of the target subchecks,
or must match one of the target regexes, ranges, or values

=item C<REF[>I<subcheck>C<]>

The value being checked must be a reference
to something that passes the specified subcheck

=item C<LIST[>I<valcheck>C<]>

I<< (In C<:returns> only) >> The return value must be a list
in which the value of every element passes the specified subcheck

=item C<LIST[>I<len>C<< => >>I<valcheck>C<]>

I<< (In C<:returns> only) >> The return value must be a list
whose length is the value (or range) specified, and in which the
value of every element passes the specified subcheck

=item C<SEQ[>I<< chk_1, chk_2, ... chk_N >>C<]>

I<< (In C<:returns> only) >> The return value must be a list with exactly
I<N> elements, where the value of the I<< n-th >> element passes
the I<< n-th >> subcheck

=item C<ARRAY[>I<valcheck>C<]>

The value to be checked must be a reference to an array in which
the value of every element passes the specified subcheck

=item C<ARRAY[>I<len>C<< => >>I<valcheck>C<]>

The value to be checked must be a reference to an array whose length
is the value (or range) specified, and in which the value of every element
passes the specified subcheck

=item C<TUPLE[>I<< chk_1, chk_2, ... chk_N >>C<]>

The value to be checked must be a reference to an array with exactly I<N> elements,
where the value of the I<< n-th >> element passes the I<< n-th >> subcheck

=item C<HASH[>I<valcheck>C<]>

The value to be checked must be a reference to a hash in which every value
in the hash passes the specified subcheck

=item C<HASH[>I<keycheck>C<< => >>I<valcheck>C<]>

The value to be checked must be a reference to a hash in which every key
passes the key subcheck and every value passes the value subcheck

=item C<DICT[>I<< 'k_1' >>C<< => >>I<< v_1 >>C<,>I<< 'k_2' >>C<< => >>I<etc>C<]>

The value to be checked must be a reference to a hash which has B<all> of the
specified literal keys, and where the value stored under a given key passes
the corresponding subcheck

=item C<CLASS[>I<classname>C<]>

The value to be checked must satisfy the C<STR> check and must also be
the name of a defined class for which C<< ->isa( >>I<classname>C<)> returns a true value

=item C<ROLE[>I<rolename>C<]>

B<I<(Note: This check is not currently implemented)>>

The value to be checked must satisfy the C<STR> check and must also be
the name of a defined role for which C<< ->DOES( >>I<rolename>C<)>  returns a true value

=item C<OBJ[>I<name>C<]>

The value to be checked must be an object that inherits from class I<name>,
or which composes role I<name> (I<i.e.> an object for which C<< ->DOES( >>I<name>C<)>
returns a true value)

=item C<OP[>I<op>C<]>

The value to be checked must be an object for which
C<overload::Method(>I<obj,op>C<)> returns a true value

=item C<ISA[>I<classname>C<]>

The value to be checked must be a classname or an object
for which C<< ->isa( >>I<classname>C<)>  returns a true value

=item C<DOES[>I<name>C<]>

The value to be checked must be a classname, a rolename, or an object
for which C<< ->DOES( >>I<name>C<)> returns a true value

=item C<CAN[>I<methodname>C<]>

The value to be checked must be a classname, a rolename, or an object
for which C<< ->can( >>I<methodname>C<)> returns a true value

=back

See L<"Some notes on the behaviour of specific parameterized checks">
for more details.


=head2 The full built-in check hierarchy

The full hierarchy of built-in checks is as follows:

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


=head2 Why built-in checks are I<LOUD>

The built-in checks (C<INT>, C<ARRAY>, C<CLASS>, I<etc.>) and the user-defined checks
(C<PosNum>, C<AccountObj>, C<Filter>, I<etc.>) have deliberately been kept in two completely
separate namespaces. This separation is essential as it ensures that new built-in checks
can be added in the future, without stomping on anyone’s pre-existing user-defined check.

Apart from the need to isolate the namespace of built-in checks from that of
user-defined checks, there is a deeper and more important reason for making all
built-in checks uppercase. Using STENTORIAN names for builtins ensures that
those names are B<I<ugly>>, which will make users less inclined to use them.

That might initially seem crazy and counter-productive, but we really don’t
want developers using the raw built-in checks more than is strictly necessary.
We want them defining their own checks, with more meaningful, more self-documenting,
and more L<intentional|https://en.wikipedia.org/wiki/Intentional_programming> names.
Consider the following fragment of code:

    my %key_distribution :of(TUPLE[INT, STR[/[[:alpha:]]\w*/]]);
                         ######################################

    sub get_events :returns(LIST[OBJ[Event]])  ($filter :of(CODE|REGEX)) {...}
                   ##########################           ###############


Can you tell whether those check specifications are correct? Or what kinds of data are
actually being passed, returned, or stored here? Or why?

But if the code is written as follows, with the raw built-in checks factored out
into user-defined checks with meaningful names, we get instead:

    my %key_distribution :of(KeyDist);
                         ############

    sub get_events :returns(EventList)  ($filter :of(SmartFilter) {...}
                   ###################           ################

...which is considerably more likely to be correct, and certainly more maintainable.
Especially if we later decide that a C<SmartFilters> can also be a hash, in which case
we just update the single user-defined check, rather than locating and changing ten instances
of C<:of(CODE|REGEX)> to C<:of(CODE|REGEX|HASH)> I<(only eight of which instances will
subsequently prove to have been actually related to smartfiltering!)>

In other words, the choice of uppercase names for built-ins is a deliberate syntactic
L<disaffordance|https://en.wikipedia.org/wiki/Affordance>: a carefully selected psychological
disincentive to discourage the use these low-level and uninformative checks directly,
and a subtle encouragement to compose them into well-named, self-explanatory,
and vastly more maintainable user-defined checks instead.


=head2 Some notes on the behaviour of specific parameterized checks

The following subsections discuss the particulars and subtleties
of some of the more complicated built-in parameterized checks...

=head3 The parameterized “enumerables” checks

The built-in checks C<INT>, C<UINT>, and C<STR> all have parameterized variants.
Each of them takes an enumerated list of I<target values> and succeeds if any of those values
“match” the value being tested, where the meaning of “match” is appropriate
to the kind of check and to the particular I<target value>:

=over

=item * If any I<target value> is a check, then the entire parameterized check passes
if the value being tested passes that target subcheck.

=item * If any I<target value> is a regex (specified either as C</pat/> or C<m/pat/> or C<qr/pat/>),
then the entire parameterized check passes
if the value being tested satisfies an C<=~> match on that target regex.

=item * If any I<target value> is an integer, then the entire parameterized check passes
if the value being tested satisfies a C<==> test against that target.

=item * If the I<target value> is anything else (effectively: a string),
then the entire parameterized check passes
if the value being tested passes an C<eq> test against that target.

=back

For example:

    # Can only specify text format as 'pod', 'markdown', 'HTML', or 'XHTML'...
    sub format_text_as ($text :of(STR), $format :of(STR['pod','markdown',/X?HTML/]) {...}
                                                    ##############################

     # Identify a specific Platonic solid by its number of faces...
     my $platonic_faces  :of(UINT[4,6,8,12,20])  = 4;
                             #################

     # Must return an integer in the range -100..100, inclusive...
     sub get_popularity  :returns(INT[-100..100])  {...}
                                  ##############


Note that, target lists that are specified as Perl ranges (I<e.g.> C<INT[-100..100]>
or C<STR['AAA00000'..'ZZZ99999']>) are B<I<never>> expanded into an explicit list of –
for example – 202 integers or 1037845224 strings. They are, instead, always
internally implemented as: C<< (MIN <= $testvalue <= MAX) >> or C<(MIN le $testvalue le MAX)>.

Note too that strings may be specified using the C<'...'> or C<q{...}> notations,
or using the C<"..."> or C<qq{...}> notations. However, because these strings
are being specified inside an attribute (I<i.e.> in the parens of an C<:of(...)> or C<:returns(...)>),
you B<I<cannot>> interpolate variables into the double-quoted forms.
Attributes are themselves mostly just a kind of single-quoted compile-time string,
so variables simply don’t interpolate into them at all. The same restriction applies
to regexes used in any parameterized check: they cannot include interpolated variables.

=head3 The parameterized C<NUM> check

There is no full equivalent “target-matching” parameterized version of C<NUM>
(I<i.e.> no version of C<NUM[...]> that can accept an explicit list of numbers to match).
This is because the C<==> operator is unreliable on non-integer numbers,
which would all too frequently lead to equally unreliable (I<i.e.> completely useless) checks:

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


However, there I<is> a parametric form of C<NUM> that I<does> accept
a slightly more limited list of targets, namely: ranges, regexes, or subchecks:

    my $coefficient :of(NUM[0.1..0.5])      = 0.1 + 0.2;   # Okay (value within specified range)
                            ########

    my $coefficient :of(NUM[qr/^0\.[1-4]/]) = 0.1 + 0.2;   # Okay (value matches specified regex)
                            #############

    my $coefficient :of(NUM[LessThan[1]])   = 0.1 + 0.2;   # Okay (value passes user-defined subcheck)
                            ###########


Ranges are (of course) converted to tests of the form S<< C<< MIN <= $value <= MAX >> >>,
but you can also specify numeric ranges that I<exclude> one or both of their end-points,
using a special non-standard numeric-range syntax that adds a C<< < >> to either end of
the C<..>, like so:

    my $probability :of(NUM[0 ..< 1])       = rand();        # Requires: 0 <= $probability < 1
                              ###

    my $increment   :of(NUM[0 <.. 99.9])    = get_incr();    # Requires: 0 < $increment <= 99.9
                              ###

    my $offset      :of(NUM[-100 <..< 100]) = get_offset();  # Requires: -100 < $offset < 100
                                 ####


You can also specify semi-infinite numeric ranges:

    my $chess_ranking :of(NUM[0..inf])  = 2882;       # Any number: zero or greater

    my $student_loan  :of(NUM[-inf..0]) = -1.234e56;  # Any number no greater than zero

However, if you do this, you still can’t assign actual infinite values to such variables:

    $chess_ranking = 'Inf';     # EXCEPTION, because NUM specifically excludes 'Inf' as a value

    $student_loan  = -INF;      # EXCEPTION, because NUM specifically excludes -Inf as a value too


Note that attempting to configure C<NUM[...]> with an argument that is a single number
I<< (even sneakily, via something like: C<NUM[0.3..0.3]>) >> B<always> produces a compile-time error.

Keep in mind, however, that despite the various safeguards built into this check,
C<NUM[...]> is still subject to all the limitations, unreliability, and general lack
of I<do-what-I-meanness> of regular floating-point numbers in Perl.

Even specifying a numeric check as a range will not always produce reliable outcomes,
especially for floating-point values on the boundaries of the range. For example:

    my $coefficient :of(NUM[0..0.3]) = 0.1 + 0.2;          # EXCEPTION (value NOT in specified range)

    my $summation   :of(NUM[1<..<9]) = sum((0.01) x 100);  # NO EXCEPTION (value unexpectedly in range)


In particular, don’t use numeric ranges to validate monetary amounts:

    # We only accept payment in coins for totals under €1...
    sub accept_coin_payment_for ($amount :of(NUM[0.00 .. 0.99])) {...}

    # And later...
    accept_coin_payment_for( 0.1 + 0.2 + 0.3 + 0.39 );  # EXCEPTION (value NOT in specified range)


=head3 The parameterized C<REF> check

The C<REF> check has a parameterized form that allows you to specify a check for a multi-level
reference. This is (very occasionally) needed because Perl does allow references-to-references,
references-to-references-to-references, I<etc.>, and you may need to check them.

The unparameterized C<REF> check passes when the value it is checking is a reference to anything
(including to another reference). The parameterized C<REF[>I<subcheck>C<]> check requires that
the value passed is a reference, and that its referent (the thing it is referring to)
also passes the specified subcheck.

For example:

=over

=item C<REF[STR]  > – Value must be a reference to a string

=item C<REF[GLOB] > – Value must be a reference to a typeglob

=item C<REF[VSTR] > – Value must be a reference to a vstring

=item C<REF[INT]  > – Value must be a reference to an integer

=item C<REF[ARRAY]> – Value must be a reference to an array reference

=item C<REF[REF]  > – Value must be a reference to any kind of reference

=back

Note that this also implies that the unparameterized C<REF> check is equivalent to C<REF[ANY]>.

Note too that if the subcheck is itself a referential check (e.g. C<REF[REF]>,
C<REF[ARRAY]>, C<REF[HASH]>, I<etc.>), the parameterized C<REF> check will only
succeed when the value being assessed is a “double-reference”. That is, a
check such as C<REF[ARRAY]> will pass only if the value is a B<I<reference to a
reference to>> an array (I<e.g.> C<\\@array> or C<\[1,2,3]>), but will not pass
if the value is just a B<I<reference to>> an array (I<e.g.> C<\@array> or
C<[1,2,3]>).

That’s because:

                                    REF[ ARRAY ]
                                     │     │
    Match a reference to... ─────────┘     │
    ...a reference to an array ────────────┘


=head3 The parameterized C<ARRAY> check

The C<ARRAY> check also has a parameterized form that can be configured with a single subcheck.
That subcheck is then applied to every element within the array. For example:

    # Scalar stores a reference to an array in which every element must be a number...
    my $scores_ref :of(ARRAY[NUM]) = [];
                       ##########

    # Subroutine expects an argument that is a reference to an array of hashrefs...
    sub process_records ($records_ref :of(ARRAY[HASH])) {...}
                                          ###########

A parameterized C<ARRAY> check can also be configured with two arguments, in
which case the first argument is either an unsigned integer specifying the
required length of the array, or a range of unsigned integers specifying the
allowable range of lengths. The second argument must then be a subcheck that is
(as usual) applied to every element within the array. For example:

    # Scalar stores a reference to an array of exactly 10 numbers...
    my $scores_ref :of(ARRAY[10 => NUM]) = [0..9];
                             #####

    # Subroutine expects an argument that is a reference to an array of no more than three hashrefs...
    sub process_records ($records_ref :of(ARRAY[0..3 => HASH])) {...}
                                                #######

    # Subroutine returns a reference to an array of at least 3 Event objects...
    sub get_events :returns(ARRAY[3..inf => OBJ[Event]]) () {...}
                                  #########

To specify a required length for an array reference, without constraining what kinds of values
it can hold, simply make the second argument an C<ANY>:

    # Subroutine returns a reference to an array with one or more elements of some kind...
    sub get_data :returns(ARRAY[1..inf => ANY]) () {...}
                                #########


=head3 The parameterized C<LIST> check

The C<LIST> check also has a parameterized form, which is a close analogue
of the parameterized C<ARRAY> check.

The C<LIST> check can be configured with a single subcheck,
which is then applied to every element within the return list:

    # Subroutine must return a list of numbers...
    sub get_samples  :returns(LIST[NUM])  {...}
                              #########

    # Subroutine must return a list of objects of class Event (or some subclass thereof)...
    sub get_samples  :returns(LIST[OBJ[Event]])  {...}
                              ################


Like the C<ARRAY> check, the parameterized C<LIST> check can also be configured with two arguments,
to specify both a required length (or range of acceptable lengths) and a per-element subcheck:

    # Subroutine must return a list of 13 numbers...
    sub get_samples  :returns(LIST[13 => NUM])  {...}
                                   #########

    # Subroutine must return a list of one or more objects of class Event (or some subclass thereof)...
    sub get_samples  :returns(LIST[1..inf => OBJ[Event]])  {...}
                                   ####################


Note the difference between specifying a C<LIST> check and an C<ARRAY> check
for the C<:returns> attribute of a subroutine:

    # Must return a single scalar value: a reference to an array that must contain only integers...
    sub get_next_client  :returns(ARRAY[INT])  () {...}
                                  ##########

    # Must return a list that must contain only integers...
    sub get_next_client  :returns(LIST[INT])   () {...}
                                  #########


=head3 The parameterized C<HASH> check

The C<HASH> check also has a parameterized version. It can be configured
with a single argument that’s another check. That subcheck is then
applied to every value stored in the hash reference. For example:

    # Every exam result in the hashref must be an integer between -1 and 100...
    my $exam_results_ref  :of(HASH[ INT[-1..100] ])  = {};
                              ####################

    # Sub returns a reference to a hash of objects...
    sub get_event_handlers  :returns(HASH[OBJ])  {...}
                                     #########


When the C<HASH> check is configured with two arguments, each of which is itself
a check, those subchecks are applied, respectively, to every key and every value
stored in the hash reference. For example:

    # Each key must match the specified pattern
    # and each value must be a number between 0 and 1...
    my $client_rating  :of(STR[/[XYZ]\d+/] => NUM[0..1])  = {};
                           ############################

    # Reverse look-up table for exam results
    # (each key must be a -1..100 integer;
    # each value must be a reference to an array of names)...
    my $students_ref  :of(HASH[ INT[-1..100] => ARRAY[STR] ])  = {};
                          ##################################

    # Sub returns a reference to a hash of objects,
    # where each key must be a classname...
    sub get_event_handlers  :returns(HASH[CLASS => OBJ])  {...}
                                     ##################


=head3 The parameterized C<TUPLE> check

The parameterized C<TUPLE> check requires the value it is testing to be an array reference,
and that the array should also have a specific size and structure.

When configured with zero or more subchecks, the number of subchecks specifies the exact number
of elements the arrayref must contain, and that the I<< n-th >> element in the array must
pass the I<< n-th >> subcheck. In other words, this kind of check allows you to require an
arrayref that is a I<fixed tuple> with the specified format. For example:

        # A client record is areference to an array containing a name (a string),
        # an ID number (an integer), and some data (a hashref), in that order...
        sub get_next_client  :returns(TUPLE[STR,INT,HASH])  () {...}
                                      ###################

     # Track minimum and maximum values in a single arrayref...
     my $range  :of(TUPLE[NUM,NUM])  =  [0, $MAXNUM];
                    ##############


=head3 The parameterized C<SEQ> check

The C<SEQ> check is a close analogue of the parameterized C<TUPLE> check,
but exclusively applicable to subroutine return lists, instead of arrayrefs.

When a C<SEQ> check is configured with zero or more arguments, the number of subchecks
specifies the exact number of elements the return list must contain, and that
the I<< n-th >> element in the list must pass the I<< n-th >> subcheck.
In other words, this kind of check requires a subroutine to return a I<fixed tuple list>
with the specified structure. For example:

    # Subroutine returns a list of error information: errorcode (an integer),
    # severity level (a non-negative integer < 12), and error handler (a subref)...
    sub get_error  :returns(SEQ[INT, UINT[0..11], CODE])  {...}
                            ###########################

    # Subroutine returns a list of exactly three names (family, middle, first).
    # The family name must contain at least one alphabetic character...
    sub get_name  :returns(SEQ[ STR[/[[:alpha:]]/], STR, STR ])  {...}
                           ###################################


Note the difference between specifying a C<SEQ> check and an C<TUPLE> check for
the C<:returns> attribute of a subroutine:

    # Must return a single scalar value: a reference to an array
    # with exactly three specific elements.
    sub get_next_client  :returns(TUPLE[STR,INT,HASH])  () {...}
                                  ###################

    # Must return a list with exactly three specific elements.
    # (Sub can only be called in list context as it has to return three values)...
    sub get_next_client  :returns(SEQ[STR,INT,HASH])  () {...}
                                  #################


=head3 The parameterized C<DICT> check

The parameterized C<DICT> is analogous to the C<TUPLE> and C<SEQ> checks, but for hashrefs.

When configured with a “KV” list of zero or more arguments (I<i.e.> where every odd argument is a
string and the total number of arguments is a multiple of two), then the odd configuration arguments
specify the literal keys that the hash is required to contain, and the even arguments specify a set
of subchecks to be applied to the corresponding value for each key. In other words, this configuration
specifies that the hash must act as a I<“fixed dictionary”> with an exact set of keys whose
corresponding values pass specific subchecks. The order in which the keys are specified is,
of course, irrelevant.

For example:

    # An identity must be a hash with an ID number and a challenge code...
    my $ident :of(DICT[ 'ID' => UINT, 'challenge' => STR[qr/\d{6}/] ])  = get_identity();
                  ###################################################

    # Sub must be passed a reference to a hash with required keys 'name', 'age', and 'shoesize',
    # where each key's value must pass a check appropriate to that particular entry
    # (ages in whole years, shoe sizes in EU standard)...
    sub validate ($candidate :of(DICT[name=>STR, age=>UINT[0..120], shoesize=>NUM[33.5 .. 48]])) {...}
                                 #############################################################


=head3 Optional elements in tuples, sequences, and dictionaries

The C<TUPLE>, C<SEQ>, and C<DICT> checks normally specify an exact number of elements that
must be present in an array, list, or hash. However it is possible to specify that
some of the elements you are specifying are B<I<optional>> and that the check
should still succeed if they are not present.

To specify an optional element in a C<TUPLE>, C<SEQ>, or C<DICT>, simply enclose the
specific check for that element in an C<OPT[...]>. For example:

    # Each client record is a list containing a name (a string), then an ID (an integer),
    # then some data (a hashref), and finally an optional flag (a string)...
    sub get_next_client  :returns(SEQ[STR, INT, HASH, OPT[STR]])  () {...}
                                                      ########

    # Track minimum and maximum values in a single arrayref
    # The maximum value is optional, so we can initialize with a 1-element arrayref...
    my $range  :of(TUPLE[NUM, OPT[NUM]])  =  [0];
                              ########

    # Sub must be passed a reference to a hash with required keys 'name' and 'age'.
    # The hash may also have an optional 'shoesize' entry...
    sub validate ($data :of(DICT[name=>STR, age=>UINT[0..120], OPT[shoesize=>NUM[33.5 .. 48]]])) {...}
                                                               ##############################


Note that any C<OPT[...]> subchecks must always come after all non-C<OPT> subchecks.

Note too that, when specifying optional components of a C<DICT[...]>, both the key string
B<I<and>> the value subcheck must be together inside the C<OPT[...]>. I<< (It doesn’t make
sense to specify a required key with an optional value: if the key is present in
the hash, it B<I<will>> have some value, even if that value is only C<undef>.) >>

If you specify two or more optional elements in a C<TUPLE> or C<SEQ>, they become
I<“progressively optional”> (like optional parameters in a subroutine signature).
That is, once a C<TUPLE> or C<SEQ> omits any optional subcheck, it must omit
all the following ones as well. For example:


    # The final flag, counter, and callback are progressively optional...
    # (i.e. your list can be missing the final 1, 2, or 3 elements)...
    sub get_next_client  :returns(SEQ[STR, INT, HASH, OPT[STR], OPT[INT], OPT[CODE]])  () {...}
                                                      #############################


=head3 Ignorable elements in tuples, sequences, and dictionaries

You can also specify that a C<TUPLE>, C<SEQ>, or C<DICT> may contain zero or
more extra trailing elements, which need not be checked at all (I<i.e.>
analogous to a final slurpy parameter in a subroutine signature). You do this by
adding the special subcheck C<ETC> as the final element (B<without> an
associated key, in the case of a C<DICT>). For example:

    # Takes a single parameter: a reference to a hash with (at least) 'name' and 'ID' keys...
    sub add_client( $data :of(DICT['name' => STR, 'ID' => UINT, ETC]) ) {...}
                                                                ###

    # Returns 3 (or more) elements...
    sub call_context :returns( SEQ[STR, STR, UINT, ETC] ) {...}
                                                   ###


Note that you can specify both C<OPT[...]> and C<ETC> subchecks within the same
parameterized check. In such cases, the C<ETC> must still be the final subcheck.


=head3 Repeatable elements in tuples and sequences

Provided they don’t specify optional or slurpy components, the C<TUPLE> and C<SEQ> checks
each require the array or list they are validating to have exactly I<N> elements; one for
each subcheck they specify.

A common variation on this theme is to have an array or a list that contains zero or more
consecutive subsequences, each of I<N> elements. For example, a list of I<(key, value, key, value, ...)>,
or an array containing triples of I<[name, rank, serial-number, name, rank, serial-number, ...]>.

To allow checking of such repeated tuples and sequences, the built-in C<REP> subcheck
is available. This subcheck can only be used as the final configuration argument within
a C<TUPLE> or C<SEQ> check. It takes I<N> subchecks and applies them to each successive
subsequence of I<N> elements in turn. For example:

    # The enlist() subroutine takes a reference to an array of any number of name-rank-ID triples
    # and converts those triples to a list of ID => object pairs...

    sub enlist  :returns(SEQ[REP[STR, OBJ[Soldier]]])  ($data :of(TUPLE[REP[STR, STR, UINT]]))  {...}
                             ######################                     ###################


A C<REP> subcheck does not have to be the only configuration argument of its containing
C<TUPLE> or C<SEQ> check, merely the final one. For example, you could specify a tuple
that starts with an integer, then contains an alternating sequence of strings and hashrefs:

    # An arrayref containing an initial integer, then one-or-more string-hashref pairs...
    my $data  :of(TUPLE[INT, REP[STR, HASH]])  =  get_data();
                             ##############


Note that the trailing elements of an array or list that is being checked by a C<REP>
subcheck must have in total some non-zero integer multiple of I<N> elements.
If you need to allow for the possibility that a repeated subarray or sublist
can repeat zero times, make the entire C<REP> optional:

    # An arrayref containing an initial integer, then zero-or-more string-hashref pairs...
    my $data  :of(TUPLE[INT, OPT[REP[STR, HASH]]])  =  get_data();
                             ###################


=head2 Check expressions

Two or more checks can be composed into a new check using any combination
of the following operators (listed here in order of descending precedence):

    Operator     Resulting check...
    ========     ==========================================

    ( C )        ...succeeds if check C succeeds

    ! C          ...succeeds if check C fails

    C1 & C2      ...succeeds only if both C1 and C2 succeed
                    (and short-circuits if C1 fails)

    C1 | C2      ...succeeds if either C1 or C2 succeeds
                    (and short-circuits if C1 succeeds)

Hence you can specify that a variable must store only subroutine references,
but that it can also be undefined:

    my $var :of(CODE|UNDEF);  # No need to initialize, default undef is allowed
                ##########

...or that a subroutine may return either a typeglob or an C<IO::Handle> object:

    sub get_fh :returns(GLOB | OBJ[IO::Handle]) {...}
                        ######################

...or that an array stores a list of C<Account> objects, but not if they’re implemented as
hashes or arrays:

    my @accounts :of(OBJ[Account] & !(HASH|ARRAY));
                     ############################

User-defined checks (see the next subsection) can also be used as operands
to these check operators.


=head2 User-defined checks

B<I<(Note: The mechanism described in this section is not yet implemented.
The syntax and behaviour detailed hereafter may change significantly.)>>

The built-in checks provided by this module cover a wide range of typical uses,
but are certainly not sufficient to handle every possible data-checking
requirement.

In addition, the names of the built-in checks are accurate but not very informative:
in a check such as C<TUPLE[REP[STR, STR, UINT]]> it is not obvious that each triple we
are expecting here represents a name, a rank, and an ID number.

Moreover, built-in checks like that can become unwieldy as they become more complex.
When you are attempting to check a large collection of related variables, parameters,
and/or return-values, it would be gratifying if you did I<not> have to respecify something
tedious like C<< DICT[ name => STR, age => UINT[0..120], shoesize => NUM[33.5..48] ] >>
separately on every one of them.

So it is essential to be able to define new kinds of checks, and to be able to give
long check expressions a single, much shorter name; one which is also likely to be more
intentional and informative.

New checks can be specified using the keyword C<check>:

S<    B<C<check>> I<NAME> I<ATTRS_opt>  C<(> I<CHECK_PARAMS> C<)  {> I<IMPLEMENTATION> C<}>>

And new names/aliases for existing checks can be specified using a variation of that same syntax:

S<    B<C<check>> I<NAME> C<:isa(> I<EXISTING_CHECK> C<)> I<OTHER_ATTRS_opt>  C<;>>

Whereas this module’s built-in checks are universally available, both these kinds of user-defined
checks are always B<I<lexical>> in scope, and hence only available from the first statement
after they are declared to the end of the surrounding block or file.

Specifically, checks are implemented a special kind of intangible lexical subroutine,
hidden in their own private namespace, so they are not directly callable for within
their scope (nor do they pollute that scope’s lexical subroutine namespace).
Hence you can specify a check and a subroutine with the same name;
there is no ambiguity or conflict between the two.

The I<< C<NAME> >> of a check is an unqualified Perl identifier, which must contain
at least one upper-case character and at least one lower-case character.
Checks with purely upper-case names are reserved for current and future
built-in checks. Checks with purely lower-case names are also reserved
...for unspecified future use. It is a compile-time error to declare
a user-defined check with a single-cased name.

The implementation of the check is its block of code, which will be passed
the value to be tested via the check’s single parameter. You can, of course,
name that parameter whatever you wish:

    check OddNum         ($n)     { $n % 2 != 0      }
    check LongStr        ($str)   { length($str) > 8 }
    check NonEmptyArray  ($aref)  { $aref->@* != 0   }

...but however it is declared, that parameter must accept the scalar value
that it will be passed every time the check is called upon to test a variable assignment
or a subroutine’s return value.

The check block is expected to return a boolean value indicating whether
or not the check succeeded. If the code block returns a true value,
the check is considered to have succeeded and execution continues silently.
If the code block returns false, the check is considered to have failed
and a suitable exception is automatically thrown.


=head3 Attributes for user-defined checks

User-defined check declarations may take any combination of the following four attributes,
all of which are optional:

=over

=item C<:isa>

Specifies the base check(s) that the new check is extending...and which the new check must still pass.

=item C<:params>

Specifies the list of configuration parameters for a parametric check.

=item C<:on>

Restricts the kinds of declarations to which a check may be applied.

=item C<:export>

Specifies that the check is also to be made available in any lexical scope into
which the current module is imported.

=back

The purpose and use of these attributes is described in the following subsections.

=head3 Check inheritance

The C<:isa> attribute indicates that a new check must first pass the “base” check
specified within the attribute, and must then also pass its own test (if any).
For example:

    # Value must be a number...that is also greater than zero...
    check PosNum  :isa(NUM)  ($value)  { $value > 0 }
                  #########

    # Value must be a reference to a container...that also has no elements/entries...
    check Empty   :isa(ARRAY|HASH)  ($value)  { (ref $value eq 'ARRAY' ? $value->@* : $value->%*) == 0 }
                  ################

The C<:isa> attribute is optional, in which case the code block specifies the
entire check by itself:

    # Value must be a safe password (at least one alpha, numeric, and symbol)...
    check SafePwd  ($value)  { given ($value) { /[[:alpha:]]/ && /\d/ && /[[:punct:]]/ && !/password/i } }

    # Value must not be any kind of reference...
    check NonRef   ($value)  { !defined ref $value }


Inheritance is also the mechanism by which long compound checks
can be given simpler and more meaningful names. If the block
at the end of a check definition is omitted entirely,
then the check must specify an C<:isa> and that check simply becomes an alias for
whatever its base check specifies (but under a more concise and comprehensible name).
For example:

    check IDNum          :isa( UINT );

    check MaybeCode      :isa( CODE|UNDEF );

    check Writeable      :isa( GLOB | OBJ[IO::Handle] );

    check NamesRanksIDs  :isa( TUPLE[REP[STR, STR, UINT]] );

    check ModernAccount  :isa( OBJ[Account] & !(HASH|ARRAY) );

    check ValidKeyVal    :isa( HASH[ STR['all', 'first', 'random'] => DEF ] );

    check ShoeData       :isa( DICT[name=>STR, age=>UINT[0..120], shoesize=>NUM[33.5..48]] );


With these check definitions in scope, we can then apply clearer and more meaningful
constraints to variables and subroutines:

    sub select_team :returns(NamesRanksIDs) ($selector :of(ValidKeyVal)) {...}
                             #############                 ###########

    my $shoe_spec :of(ShoeData) = get_shoe_data();
                      ########

    sub report_accounts ($to :of(Writeable), @accts :of(ModernAccount)) {...}
                                 #########              #############


=head3 Parametric user-defined checks

If a check is specified with a C<:params> attribute, the contents of that attribute are
interpreted as a I<signature> specifying the list of compile-time configuration parameters
that the check requires when it is subsequently used. These configuration arguments
are, as we have seen, passed to the check in a pair of square brackets placed
immediately after the check’s name (with no intervening space).

The arguments bound to those configuration parameters are then
available as runtime constants within the check’s body. For example:

    # Must be a number between MIN and MAX...
    check RangeNUM  :params($MIN, $MAX)  :isa(NUM)  ($value)  { $MIN <= $value <= $MAX }
                           ############                         ####              ####

    # Must be a string of at least N characters...
    check LongSTR   :params($N)          :isa(STR)  ($value)  { length $value >= $N }
                           ####                                                  ##

    # And then we can use the new parametric checks,
    # by supplying them with appropriate arguments...

    my $scale  :of(RangeNum[-1, +1]) = 0;
                           ########

    my $passwd :of(LongStr[12]) = '?' x 12;
                          ####


Note that, as illustrated in the preceding examples, it is a convention (but not a requirement)
to specify configuration parameters with upper-case names, to reflect the fact that these
parameters are bound at compile-time and effectively become constants at run-time.

Furthermore, because the configuration parameters I<are> bound at compile-time,
they can only be passed compile-time constants. Specifically, they B<I<cannot>>
be passed variables of any kind. The following will not work as desired:

    my ($from, $to) = (10,99);

    my $scale  :of(RangeNum[$from, $to]) = $to;
    my $passwd :of(LongStr[$from])        = '?' x $from;

...because the C<$MIN> and C<$MAX> configuration parameters would be passed the literal strings
C<'$from'> and C<'$to'>, rather than the contents of the variables C<$from> and C<$to>.

Instead you would need to create check aliases for the desired compile-time
minimal and maximal constants:

    check ActiveRange :isa(RangeNum[10,99]);
    check MinStrLen   :isa(LongStr[10]);

    my $scale  :of(ActiveRange) = $to;
    my $passwd :of(MinStrLen)   = '?' x $from;

...or else redesign the two checks so that you can pass them named compile-time constants
instead of literals:

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

    my $passwd :of(LongStr[FROM]) = '?' x FROM;
                          ######

This is, of course, less than ideal, but is mandated by the fundamental limitations
of Perl attributes (namely, that they are compile-time literal strings,
not run-time expressions).

The configuration parameter list is just like any regular subroutine parameter list
(except for the C<:params> prefix), so you can specify your final configuration parameter
as a slurpy array to allow parameterized checks to be configured with
an arbitrary number of positional configuration parameters. For example:

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


Likewise, you can specify a suitably checked slurpy hash as a check’s final
(or only) parameter, to indicate that the check takes alternating I<key> => I<value>
configuration arguments:

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


Like regular subroutine parameters, check-configuration parameters can also be given defaults:

    # If upper bound is omitted, there is no upper bound...
    check RangeNUM  :params($MIN, $MAX = 'Inf')  :isa(NUM)  ($value)  { $MIN <= $value <= $MAX }
                                  ############

    # Default to 10 characters, if no specific minimum length is configured...
    check LongSTR   :params($N = 10)             :isa(STR)  ($value)  { length $value >= $N }
                            #######

If all the configuration parameters are optional (or slurpy), the square brackets
also become optional when the check is used:

    my $passwd :of(LongStr[]) = 'open sesame 12345';   # Means: LongStr[10]

    my $passwd :of(LongStr)   = 'open sesame 12345';   # Means the same

In addition to specifying configuration parameters as scalars or slurpies,
you can also specify them with a C<&> sigil I<< (which is B<I<not>> possible in regular
subroutine signatures) >>. Configuration parameters specified in this way
can only be bound to some other check. They then become lexical subroutines
within the code block of the check, with those subroutines executing the
specified check test. For example:

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

As the preceding examples illustrate, when the parameters of a check are themselves other checks,
those parametric checks are passed as subroutines (because checks really are just a special kind
of auto-applied subroutine). Hence, when a check is passed as the parameter of another check,
that parametric check can be invoked directly as part of the new check’s code block.

The configuration parameters specified by a C<:param> are also immediately available
to any subsequent attributes specified in a C<check> declaration. For example:

    check Maybe   :params(&CHECK)    :isa(CHECK | UNDEF);
                          ##### --------> #####

    check Blessed :params(&REFTYPE)  :isa(REF & REFTYPE)  ($ref) { builtin::blessed $ref }
                          ######## -----------> #######


=head4 Checking the parameters of a parameterized check

Checks can be applied to B<I<any>> variable...including to the configuration parameter variables
of another check. So it’s also possible to ensure that those configuration parameters
themselves meet specific requirements. For example:

    # Must be a number between the numbers MIN and MAX...
    check RangeNum  :params($MIN :of(NUM), $MAX :of(NUM))  :isa(NUM)  ($n)  { $MIN <= $n <= $MAX }
                                 ########       ########

    # Must be a string of at least N characters, where N is a positive integer...
    check LongStr   :params($N :of(PosInt))      :isa(STR)  ($n)  { length $n >= $N }
                               ###########

    # Must be one of a particular set of specified strings...
    check MatchStr  :params(@TARGETS :of(STR))   :isa(STR)  ($s)  { grep { $_ eq $s } @TARGETS }
                                     ########


Designating that any check parameter is itself a check (by giving it a C<&> sigil)
causes the compiler to require the corresponding argument to be a named check
(or as an expression involving named checks), but you can also use the built-in
C<CHECK> check to explicitly specify that a scalar or slurpy configuration parameter
must be bound to some kind of built-in or user-defined check. For example:

    check Maybe  :params($SUBCHECK :of(CHECK))  ($value)  { !defined $value || $SUBCHECK->($value) }
                         ####################                                  #########

    my $count :of(Maybe[INT]);    # Okay
    my $count :of(Maybe[0]);      # Compile-time error: check argument (0) failed INT check


    check UnorderedTuple  :params(@ELEM_CHECKS :of(CHECK))  :isa(ARRAY)  ($aref) {...}
                                  #######################

    sub get_data :returns(UnorderedTuple[INT,  STR,    HASH  ]) {...}   # Okay
    sub get_data :returns(UnorderedTuple['ID', 'name', 'data']) {...}   # Compile-time error


=head3 Restricting checks to specific declarands

By default, a user-defined check is applicable to any kind of variable,
or to the return value of any subroutine. However, some kinds of checks can only
usefully be applied to variables, or to one particular kind of variable,
or only to subroutine return values.

The C<:on> attribute provides a means to restrict a user-defined
check to a particular kind of declarand, as follows:

=over

=item C<:on(SCALAR)>

Can only be used in an C<:of()> attached to a scalar variable declaration
(including scalar parameters)

=item C<:on(ARRAY)>

Can only be used in an C<:of()> attached to an array declaration
(including slurpy array parameters)

=item C<:on(HASH)>

Can only be used in an C<:of()> attached to a hash declaration
(including slurpy hash parameters)

=item C<:on(CODE)>

Can only be used in a C<:returns()> attached to a subroutine

=back

For example, to define a check that prevents a hash from storing values
that are references, and which, therefore, is logically only applicable to hashes:

    check NoRefVals :on(HASH) :isa(!REF);
                    #########

    my %names  :of(NoRefVals);    # Okay
    my @scores :of(NoRefVals);    # Error: Check NoRefVals can only be applied to a hash

You can also specify check expressions in an C<:on>, to allow a check to be applied
to two or more declarands. For example, to allow the C<NoRefVals> check to be applied
to both hashes and arrays:

    check NoRefVals :on(HASH|ARRAY) :isa(!REF);
                    ###############


Note that, if the check expression specified in an C<:on(...)>
involves anything other than C<SCALAR>, C<ARRAY>, C<HASH>, or C<CODE>,
the attribute is invalid and will produce a compile-time error.

People are sometimes confused between the C<:on> attribute and
the C<:isa> attribute, both of which take a subcheck as their
configuration argument. The easiest way to remember the difference
is that:

=over

=item C<:on> is an abbreviation of C<:>B<C<on>>C<ly_applicable_to>

=item C<:isa> is the same as a class’s C<:isa>: it specifies some pre-existing behaviour that the new entity must conform to

=back

To visualize the difference between C<:isa> and C<:on>, consider the check declaration:

        check RecordQueue  :on(ARRAY) :isa(HASH)  ($href) { exists $href->{recordID} }
                           #####################

We could represent the C<:isa> and C<:on> relationships of this check like so:

                                           ┏━━━━━━━━━━━━━━━┓
    $slr                                   ┃  check HASH   ┃
                                           ┗━━━━━━━╽━━━━━━━┛
    %hsh                                           ┃ :isa(X) = must also pass check X
            :on(Y) = only applies to Y   ┏━━━━━━━━━┻━━━━━━━━━┓
    @ary <┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┈┃ check RecordQueue ┃
                                         ┗━━━━━━━━━━━━━━━━━━━┛
    &sub


=head3 Contextual information for check blocks

Normally the code block of a check receives any value to be tested
(I<i.e.> any value being assigned to a checked variable or returned
from a checked subroutine) via its sole parameter variable.

However, sometimes a variable check will need more information than just
the proposed new value, in order to be able to determine if an assignment
is permitted.

For example, one could envisage a I<monotonic variable>: a C<$count> or C<$sum>, for which
assignments must never decrease the stored value. Or a I<finite array> that must never store
more than I<N> elements. Or a I<bijection>: a hash in which no two keys can store the same value.
Or a I<restricted hash> in which every key must conform to a specific pattern.

Each of these checks requires extra information to determine if an assignment
is permitted. The monotonic variable check requires access to the current value
stored in the variable; the finite array check requires access to the specific index
being updated (to ensure it’s less than I<N>); the bijective hash check requires
access to all the values of the hash (to be able to ensure they’re all distinct);
the restricted hash check requires access to the specific key under which the new value
is to be stored.

To provide access to this extra information, you can add an extra slurpy hash
after the single required check parameter. If a check is specified with this
second parameter, it no longer receives just the value to be checked. Instead,
it is also passed a key/value sequence containing additional information about
the context in which the check is being applied. That information consists of:

=over

=item C<< old => >> I<VALUE>

This pair passes a readonly copy of the old (pre-modification) value of the checked scalar,
array element, or hash value. This pair is passed to the slurpy parameter only
if the check was applied to a variable.

=item C<< key => >> I<VALUE>

This pair passes a copy of the hash key or array index within the container variable
at which the new value is supposed to be assigned. This pair is passed to the slurpy parameter
only if the check was applied to an array or hash.

=item C<< var => >> I<REFERENCE>

This pair passes a readonly reference to the entire variable to which the check was applied.
This pair is passed to the slurpy parameter only if the check is being applied to a variable.

=item C<< name => >> I<STRING>

This pair passes the name of the checked variable or subroutine.
This pair is always passed whenever the check has a slurpy parameter.

=item C<< want => >> I<STRING>

This pair passes the call context (C<'LIST'>, C<'SCALAR'>, C<'VOID'>) of the subroutine
whose return value is being checked.
This pair is only passed when the check is being applied to a subroutine return list.

=back

Hence we could implement the various non-simple-value checks
described at the start of this subsection, as follows:

    # Newly assigned values must never decrease...
    check Monotonic  :isa(NUM)  ($value, %value)  { $value >= $value{old} }
                                         ######

    my $counter :of(Monotonic) = 0;             # Okay
    $counter++;                                 # Okay
    $counter--;                                 # EXCEPTION


    # The array cannot have more than N elements...
    check MaxElems  :params($N :of(UINT))  ($, %elem)  { $elem{key} < $N }
                                               #####

    my @finalists :of(MaxElems[10]);            # Okay
    @finalists = ('a'..'j');                    # Okay
    @finalists = ('a'..'k');                    # EXCEPTION


    # The values of the hash must remain unique...
    check Bijective  :on(HASH)  ($new_value, %target)  {
                                             #######
        return $target{old} eq $new_value
               || not grep { $_ eq $new_value} } values $target{var}->%*;
    }

    my %mapping :of(Bijective);                 # Okay
    %mapping = (a=>1, b=>2, c=>3);              # Okay
    $mapping{c} = 1;                            # EXCEPTION


    # The keys of the hash must conform to a given pattern...
    check KeyPat  :params($PATTERN :of(REGEXP))  ($, %entry)  { $entry{key} =~ $PATTERN; }

    my %data :of(KeyPat[qr/[a-z]{3}\d{5}/]);    # Okay
    $data{xyz12345} = 1;                        # Okay
    $data{XYZ678}   = 1;                        # EXCEPTION


=head3 User-defined error messages

Normally, the exceptions generated by user-defined checks are in the
same format as those of the built-in checks. But this can be changed.

Instead of returning a false value to indicate that the check failed,
the code block of a user-defined check can signal failure by throwing an exception.
This allows a new check to tailor a more appropriate error message,
if the standard autogenerated one would be insufficient for some reason.

For example:

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

Note that any exception thrown inside a user-defined check is automatically adjusted
to reflect the filename and line number of the operation for which the check actually failed,
rather than the file and line of the check’s own code block:

    my @finalists :of(MaxElems[10]);

    $finalists[86] = 'Max';   # EXCEPTION: ...YOU SHALL PERISH! at demo.pl line 3
                              #       NOT: ...YOU SHALL PERISH! at ArrayChecks.pm line 157


=head3 Exporting user-defined checks

Because user-defined checks are lexically scoped, a check that
is declared in a module’s source file will only be available within
that module. This would make it difficult to create libraries
of reusable checks.

So a user-defined check can be declared with the C<:export> attribute:

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

     {
         use Checks::Integral;   # All checks marked :export now available in this scope

         sub add_odd :returns(EvenInt) ($x :of(OddInt), $y :of(OddInt)) {     # Okay
             return $x + $y;  #######          ######          ######
         }
     }

     my $result1              = add_odd(7, 35);   # Okay

     my $result2 :of(EvenInt) = add_odd(7, 35);   # Compile-time error: Unknown check EvenInt


Exported checks can also be imported individually, by name, in the usual Perl manner:

    # Import only these two checks into this lexical scope...
    use Checks::Integral  'NatInt', 'PrimeInt';


Groups of exported attributes can also be designated for collective export.
The C<:export> attribute can be given one or more arguments, which specify I<tags>.
Just as with C<Exporter> tags, these allow specific checks to be exported
either collectively (by default), individually (by name), or in groups (by tag):

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

If you I<don’t> want a particular check exported by default, you can specify
it with the special tag: C<OK>:

    # Exported only under:  use Check::Integral 'PrimeInt';
    check PrimeInt :isa(INT)  :export(OK)  ($n)  { is_prime($n) }
                              ###########

Note that this is equivalent to the C<Exporter> module’s C<@EXPORT_OK> mechanism.
You can also specify other tags along with the special C<OK> tag, to allow
not-exported-by-default checks to still be exported as part of other export groups:

    # Exported only under:  use Check::Integral 'LuckyInt';
    #                  or:  use Check::Integral ':Pred'
    check LuckyInt :export(OK, Pred)  :isa(INT[2,3,5,11,17,41]);
                   #################



=head3 Changing how checks report failure

When you apply a check to a variable or subroutine, that check becomes active
for the duration of the declarand’s existence. Any access to the variable or
call to the subroutine causes the check to execute and (potentially) an exception
to be thrown.

But over the development cycle this default behaviour may not always be optimal.
When retrofitting checks onto an existing codebase, you may want to turn checks “down”
in certain sections of the code, so that you still get the notification of a broken
expectation, but that notification doesn’t immediately terminate the program (which
may then allow you to find other problems later in the same execution). You may even want
to I<globally> downgrade checks in this way, so you can find all the problems at once,
without actually breaking a working(-ish) program at any point.

At other times you may want to turn checks off entirely, so that they are neither created,
nor attached to variables or subroutines, nor tested during execution. This would most
likely be when the code has been thoroughly tested and is about to be deployed. If it’s all
working correctly, there’s no need to activately watch for errors. At least, not all the time.
So you may either want to disable every check in the entire program, or maybe just turn off
all the “internal” checks within various software modules, leaving only the checks on
public API components active.

Downgrading checks to either warnings or no-ops is accomplished via the C<checks> pragma
(which is simulated by this module).

Like all other pragmas, the effects of C<checks> are lexical, and can therefore be used
to de-escalate or disable checking in any block or file scope...and, of course, to
re-enable or re-escalate checks in nested scopes.

You can downgrade all failed checks in a lexical scope from throwing exceptions to
merely issuing warnings like so:

    # Failed checks anywhere in the remainder of this lexical scope just issue warnings...
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


Similarly, you can completely disable checks in a given lexical scope
in precisely the way you’d expect:

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


The C<checks> pragma affects both the compile-time and runtime components of any check
within its scope. Specifically, a C<no checks> turns off compile-time check declarations,
compile-time and runtime check attributions, and runtime check testing:

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


Note that turning off checks in this way, doesn’t invalidate the check-related B<I<syntax>>
(you’d need to specify C<no feature 'checks'> to disable that). This means that you can turn off
the effects of checks without having to remove the checks themselves from your code.
That’s handy when deploying your code I<(you can leave the various check declarations
in place, but disabe their behaviour to boost performance)>, and handier still when a new bug
is discovered I<(at which point you can temporarily turn all those automatic data
validations back on to help you track down the problem).>

Note too that, because the C<checks> pragma is lexically scoped in its effect,
when your code is stable and well-tested, it is easy to switch off all run-time
checks throughout an entire module or file, but at the same time cordon off
a small subset of “API” subroutines, re-enabling just the public checks
on their parameters and return values. For example:

    package Data::Tools;

    no checks;  # The following checks are now turned off...

    state %cache :of(CLASS => OBJ);

    # Internal utility functions...
    sub _build_data  :returns(ARRAY) ($source  :of(STR)  ) {...}
    sub _validate    :returns(ARRAY) ($data    :of(ARRAY)) {...}
    sub _reduce_data :returns(ARRAY) ($reducer :of(CODE) ) {...}

    {
        # These subs constitute the API, so leave their checks active...
        use checks;

        sub get_data :returns(ARRAY) ($source :of(STR)   ) {...}
        sub set_data :returns(BOOL)  ($data   :of(ARRAY) ) {...}
        sub net_data :returns(ARRAY) ($addr   :of(URL)   ) {...}
    }


Like all pragmas, C<use checks> and C<no checks> are lexical in scope.
So you can’t use them turn checks down or off throughout your entire program
without adding the appropriate pragma at the start of every separate file and module.
Which is possible, but obviously not an ideal solution.

So, to downgrade every check throughout your source so that it merely issus warnings,
rather than throwing exceptions, you can load the Data::Checks module with the C<-k> flag:

    # Run a program with all checks issuing only warnings...
    use Data::Checks '-k';

And to completely disable every check throughout your entire source, so that check declarations
are ignored and check tests never run, you would use the C<-K> flag:

    # Run a program without any checks at all...
    use Data::Checks '-K';

I<< (The mnemonic here is that these two flags both “weaB<k>en checB<k>s”,
and that the larger letter (C<-K>) has the larger effect: the total removal of all checking.
Whereas the smaller letter (C<-k>) has the smaller effect: removing only the lethality of failed checks). >>

Note that the C<-k> and C<-K> flags also differ in the extent of their effects. The C<-k> flag merely
sets the default failed-check response to warning at the start of each file, as if every file
started with an implicit: S<C<use checks 'NONFATAL'>>. Any explicit S<C<use checks>>
or S<C<no checks>> pragma within a file will still override that default.

In contrast, the C<-K> flag universally overrides all in-code C<checks> pragmas,
irrevocably disabling checks everywhere in your program.


=head2 Coercions

B<I<(Note: The mechanism described in this section is not yet implemented.
The syntax and behaviour described hereafter may change significantly.)>>

Checks, whether built-in or user-defined, B<I<never>> modify the value that they are testing.
That is, a check verifies the value being assigned to a variable or returned from a subroutine,
but in a strictly I<either/or> way: either the value passes the check and is assigned/returned
unchanged, or else the value fails the check, a suitable exception is thrown, and so no value
at all is assigned or returned at that point.

But there is a related concept – the I<“coercion”> – which also asserts that a value
must pass some test. However, unlike a check, if the value fails the test then a coercion
can also attempt to I<convert> the value in some way, so that it does pass the test.

There are no built-in coercions, but you can define your own using the C<coercion> keyword,
which has the following syntax:

S<C<    coercion  >I<NAME>C<  :to(>I<TARGET>C<)  >I<ATTRS_opt>C< (>I<PARAMS>C<) { >I<IMPLEMENTATION>C< }>>

A coercion declaration still defines something that can be used like a check (I<i.e.> in the C<:of>
of a variable, or the C<:returns> of a subroutine). But a coercion has a slightly different
interface and different internal behaviour from a check.

Like checks, coercions receive the value they are supposed to verify as a read-only argument,
but, instead of returning true or false to indicate the outcome of the test (as a check does),
a coercion must return a value that successfully passes the target check (I<i.e.> that passes
the check specified in the coercion’s mandatory C<:to> attribute).

The value returned by the coercion can either be the original value being tested, or else
another value that is to B<I<replace>> the value being tested. Either way, this returned value
is then the value that is ultimately assigned to the coerced variable, or returned from the
coerced subroutine.

For example:

    # Must be an integer (if not, make it so)...
    coercion WholeNum  :to(INT)  ($n) {
        die "$n can't be converted to a number"  if !looks_like_number($n);
        return round($n);
    }

    # Average is rounded on assignment
    my $average_score :of(WholeNum)  =  sum(@scores) / @scores;
                      #############


    # Must be a string that's at least twelve characters long (if not, pad it)...
    coercion LongStr  :to(STR[/.{12}/])  ($value) {
        my $is_ref = reftype($value);
        die "$is_ref reference $value can't be converted to a LongStr" if $is_ref;
        return sprintf('%12s', $value) }
    }

    # $new_passwd padded with spaces, if necessary
    sub set_passwd ($new_passwd :of(LongStr)) {...}
                                ############


When a coercion is applied to the value being assigned to a variable or being returned from a subroutine,
the original value being assigned or returned is processed as follows:

=over

=item 1.

The original value is first checked against the target specified in the coercion’s C<:to> attribute.

=item 2.

If the C<:to> check passes, then the entire coercion is immediately considered
to have succeeded, and the original value is passed through – unchanged – to
the assignment or subroutine-return that the coercion is guarding. In such
cases, the coercion’s code block is not invoked at all.

=item 3.

If the C<:to> check fails, the code block of the coercion is executed and is
passed the original value as its argument. The task of the code block is then to
convert the original value into some other value; one that is acceptable to the
C<:to> check.

=item 4.

If the coercion’s code block throws an exception at any point, the coercion
immediately fails. In which case, the exception propagates as usual,
interrupting execution just like a failed check would.

=item 5.

If the coercion’s code block successfully returns a value, the C<:to> check is
then applied to that returned value.

=item 6.

If the returned value passes its C<:to> check, the coercion is considered to
have succeeded, and the new value returned by the coercion’s code block is
passed through instead of the original value.

=item 7.

If the returned value fails its C<:to> check, the entire coercion fails, and a
suitable exception is thrown.

=back

In other words, a coercion must return a value satisfying the check specified by its C<:to> attribute
(either by automatically passing though the original value being tested, or by generating a suitable
replacement value in its code block), or else the coercion must signal failure by throwing an exception.


=head3 Parametric coercions

Coercions can be parameterized in the same way as checks.
For example:

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


=head3 Preconditions on coercions

Note that, in all of the preceding examples, the coercion’s code block first had to
implement some underlying check (by throwing a suitable exception if the value
was not a number, or was a reference, or wasn’t an arrayref, respectively)
before implementing its own specific conversion of the original value.

You can avoid this tedious preliminary gate-keeping, by B<I<declaring>>
that the value passed to the coercion must first satisfy some precondition,
before its code block can be entered. Such preconditions are declared using the C<:from> attribute:

    # Must be a number in the range $MIN..$MAX (if not, make it so)...
    coercion NumBetween :params($MIN, $MAX) :to(NUM[$MIN..$MAX])  :from(NUM)  ($n) {
                                                                  ##########
        return $n < $MIN  ?  $MIN  :  $MAX;
    }

    # Must be a string at least N characters long (if not, pad it)...
    coercion LongStr :params($N :of(UINT)) :to(STR[/.{12}/])  :from(!REF)  ($value) {
                                                              ###########
        return sprintf('%*s', $N, $value);
    }


When a C<:from> is specified, if the original value fails the initial C<:to>
check but I<passes> the C<:from> check, then the code block is executed and the
value it returns is then retested against the C<:to> check. To summarize:

 [Original Value]
        ┆
   ┏━━━━V━━━━┓                                                               ┏━━━━━━━━━━┓
   ┃   :to   ┠┄┄passes┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄❯          ┃
   ┗━━━━┯━━━━┛                                                               ┃          ┃
        ┆                                                                    ┃  ENTIRE  ┃
      fails                                                                  ┃ COERCION ┃
        ┆                                                                    ┃  PASSES  ┃
   ┏━━━━V━━━━┓          ┏━━━━━━━━━━━━━━━━━┓               ┏━━━━━━━┓          ┃          ┃
   ┃  :from  ┠┄┄passes┄┄❯ code block runs ┠┈┈[New Value]┈┈❯  :to  ┠┄┄passes┄┄❯          ┃
   ┗━━━━┯━━━━┛          ┗━━━━━━━━┯━━━━━━━━┛               ┗━━━┯━━━┛          ┗━━━━━━━━━━┛
        ┆                        ┆                            ┆
      fails                  exception                      fails
        ┆                        ┆                            ┆
   ┏━━━━V━━━━━━━━━━━━━━━━━━━━━━━━V━━━━━━━━━━━━━━━━━━━━━━━━━━━━V━━━┓
   ┃                   ENTIRE COERCION FAILS                      ┃
   ┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛


=head3 Other features of coercions

A coercion behaves in almost all other respects just like a check:

=over

=item *

It may be constrained to only be applied to particular kinds of variables, or
only to subroutine return values, by giving it
L<an C<:on> attribute|"Restricting checks to specific declarands">.

=item *

It may be exported into a caller’s lexical scope via
L<an C<:export> attribute|"Exporting user defined checks">.

=item *

It may be specified with a second slurpy parameter, in which case it is passed
L<additional context information|"Contextual information for check blocks>.

=back

With those features you could, for example, create a coercion to guard
and adapt the parameters of a particular subroutine. Suppose you need a subroutine
with a single parameter that must be an C<Account> object. You could define a coercion
that verifies this constraint, but which also allows users to pass
an C<Account::ID> object instead, in which case the coercion will look up the ID
and convert it to the corresponding account object. Like so:


    # Require an Account object, or an Account::ID object (which is converted to an Account)...
    coercion CoercedAccount  :to(OBJ[Account])  :from(OBJ[Account::ID])  :export  ($obj) {
        return $account_DB->find_by_ID( $obj )
            // die "Can't locate Account object for ID: " . $obj->ID_as_str();
    }

    # and later...

    sub update_account ($acct :of(CoercedAccount)) { ... }

    update_account( Account->new(%acct_data)    );  # Okay
    update_account( Account::ID->new($valid_ID) );  # Okay

    update_account( Account::ID->new($bad_ID)   );  # EXCEPTION: Can't locate Account object...
    update_account( $bad_ID  );                     # EXCEPTION: Can't convert to OBJ[Account]
    update_account( \*STDOUT );                     # EXCEPTION: Can't convert to OBJ[Account]


=head3 (Not) disabling coercions

Coercions are like checks, but they are not checks.

In particular, because coercions can B<I<modify>> the behaviour of assignments
and subroutine returns, coercions cannot ever be disabled or downgraded without
potentially changing the behaviour of the program they are part of.

Hence coercions are “always on” constructs and are excluded from the lexical effects of any
C<checks> pragma and the global effects of the C<-k> and C<-K> flags.

This means that when you deploy your code, you can safely downgrade or deactivate all of your
internal checks, without disrupting any of your vital coercions.


=head1 DIAGNOSTICS

=head2 Module loading errors

=over

=item C<< Too late to specify '-k' option >>

=item C<< Too late to specify '-K' option >>

The C<-k> and C<-K> options can only be specified when the module
is loaded for the first time during compilation.

These errors usually occur because you’re using some other module that
also uses Data::Checks, and loading that module I<before>
you use Data::Checks in your main program.

Move the C<use Data::Checks -k> to the very start of your main code.

=item C<< Can't specify both '-k' and '-K' options >>

These two options are mutually exclusive.
In any given program, there can be only one!

=item C<< Invalid argument (<ARG>) to "use Data::Checks" >>

The only arguments that the module can be loaded with are
either a single C<-k> or else a single C<-K> option. You
attempted to pass something else. Maybe dont’t do that?

=back

=head2 Bad check specifications

=over

=item C<< Unknown check: <CHECK> >>

The check being specified was probably misspelt.

=item C<< Can't specify <SUBCHECK> after ETC in <CHECK> >>

An C<ETC> has to be the last subcheck in its C<TUPLE>, C<SEQ>, or C<DICT>,
but another subcheck was found after it. Remove or relocate the trailing subcheck.

=item C<< Can't specify <SUBCHECK> after REP in <CHECK> >>

A C<REP> has to be the last subcheck in its C<TUPLE> or C<SEQ>,
but another subcheck was found after it. Remove or relocate the trailing subcheck.

=item C<< Can't specify non-optional <SUBCHECK> after OPT or ETC in <CHECK> >>

Once you have specified an C<OPT>, you can only specify more C<OPT>s or a
final C<ETC>. Once you have specified an C<ETC>, you can’t specify anything
after it. However, you tried to specify a non-optional check after either an C<OPT>
or an C<ETC>. Eiher delete that trailing subcheck, or move it before the C<OPT> or C<ETC>.


=item C<< Can't specify OPT[<SUBCHECK>], except as part of a TUPLE, SEQ, or DICT >>

The C<OPT> subcheck is only allowed inside the square brackets of a parameterized
C<TUPLE>, C<SEQ>, or C<DICT> check. You used it somewhere else, which is not supported.

=item C<< Can't specify ETC here (only in a TUPLE, SEQ, or DICT) >>

The C<ETC> subcheck is only allowed inside the square brackets of a parameterized
C<TUPLE>, C<SEQ>, or C<DICT> check. You used it somewhere else, which is not supported.

=item C<< Invalid DICT item: <KEY> => OPT[ <SUBCHECK> ] >>

If you want to specify an optional subcheck within a parameterized C<DICT> check,
the entire I<key>C<< => >>I<value> pair of the subcheck has to be placed within
the C<OPT>, not just the I<value>.

Rewrite the subcheck as: C<< OPT[ keycheck => VALUECHECK ]> >>

Or, if you meant that the key could have C<undef> as its value,
rewrite the subcheck as: C<< keycheck => VALUECHECK | UNDEF >>

=item C<< Can't specify a LIST check in an :of >>

=item C<< Can't specify a SEQ check in an :of >>

=item C<< Can't specify a VOID check in an :of >>

These three checks are only meaningful as part of a C<:returns> attribute
and cannot be applied to the C<:of> attribute of a variable.

Did you mean C<ARRAY> instead C<LIST>, C<TUPLE> instead of C<SEQ>, or C<UNDEF> instead of C<VOID>?

=item C<< Can't specify an :of attribute on a subroutine >>

To add a check to the return value of a subroutine, use the C<:returns> attribute.
The C<:of> attribute is only applicable to variables.

=item C<< <CHECK> is not a valid check: <REASON> >>

You attempted to specify an “enumerated” parameterized check, such as an C<STR[...]>
or C<NUM[...]>, but the subchecks you put inside the square brackets were wrong.
You can only specify literal values, or ranges of literal values, or regexes, or
some other check, but you put something else there.

=item C<< Unexpected trailing <SYNTAX> in <CHECK> specification >>

Your check specification was at least partially correct, but there was
extra syntax at the end of it, which the module did not recognize.
Possibly you have a typo.

=item C<< ROLE check failed (can't yet detect roles) >>

As of Perl 5.36 there is still no official role mechanism in Perl, and certainly
no role introspection. Hence the C<ROLE> check cannot (yet) be implemented.

=item C<< Can't specify <SYNTAX> >>

The module’s parser became confused by the syntax you used.
This may be an internal bug in the module, but is more likely a typo in your code.

=back

=head2 Failed checks on scalars

=over

=item C<< Can't declare <VAR> :of(<CHECK>) with no initial value: the default undef value would fail the <CHECK> >>

The kind of check you specified on the scalar variable does not accept C<undef>,
and you didn’t initialize the variable to some other value. So the variable will
have the value C<undef> by default, and that will cause the specified check to fail.

You need to initialize your variable to something that its check will accept.


=item C<< Can't assign value <VAL> to <SCALAR>: value failed <CHECK> >>

You attempted to assign a value to the scalar variable, but the check on that
variable would not accept that value.

Either the check on your scalar variable isn’t what you actually wanted, or else
the value you were trying to assign to the variable was wrong.

=back

=head2 Failed checks on arrays

=over

=item C<< Can't assign value <VAL> to element <N> of <ARRAY>: failed <CHECK> >>

You attempted to assign a value to an element of the array, but that value
did not satisfy the check specified on the array (which is subsequently tested
whenever any array element is assigned to).

Either the check on your array variable isn’t what you actually wanted, or else
the value you were trying to assign into the array was wrong.

=item C<< Can't assign value <VAL> to element <N> of <ARRAY>: autovivified undef values would fail <CHECK> >>

=item C<< Can't resize <ARRAY>: autovivified undef values would fail <CHECK> >>

You attempted to assign a value to an element of the array that is after the end of
the array. Or you attempted to increase the size of the array (by assigning to C<$#array>).

Perl obligingly extended the array to accommodate that new element or size request,
but in doing so it created some interim elements (between the previous end of the array
and the new end of the array). Those “autovivified” interim elements will have been created
with the value C<undef>. Unfortunately the check that has been applied to the array
does not allow its elements to have the value C<undef>.

Either add the new element(s) without creating interim C<undef> elements,
or else modify the check on the array to allow C<undef> as a valid element value.

=item C<< Can't delete element <N> of <ARRAY>: resulting undef value would fail <CHECK> >>

If you delete an array element that isn’t at the end of the array, Perl simply replaces that
element’s value with C<undef>. Unfortunately the check that has been applied to the array
does not allow its elements to have the value C<undef>.

Either don’t delete “interior” elements of the array, or else modify the check on the array
to allow C<undef> as a valid element value. I<(Frankly, using C<delete> on an array isn’t a
great idea anyway.)>


=item C<< Can't push value <VAL> onto <ARRAY>: failed <CHECK> >>

=item C<< Can't unshift value <VAL> onto <ARRAY>: failed <CHECK> >>

=item C<< Can't splice value <VAL> into <ARRAY>: failed <CHECK> >>

You attempted to insert an element into the array, either at the end (C<push>),
at the beginning (C<unshift>), or somewhere in the middle (C<splice>).
Unfortunately, the value being inserted failed the check that has been applied
to the entire array.

So either the check on your array variable isn’t what you actually wanted,
or else the value you were trying to insert into the array was wrong.


=item C<< Can't initialize <ARRAY> with a list of <N> elements: array length must be <M>, not <N> >>

=item C<< Can't assign list of length <N> to <ARRAY>: array length must be <M>, not <N> >>

=item C<< Can't assign value <VAL> to element <N> of <ARRAY>: array length must be <M>, not <N> >>

=item C<< Can't push value <VAL> onto <ARRAY>: array length must be <M>, not <N> >>

=item C<< Can't unshift <VAL> onto <ARRAY>: array length must be <M>, not <N> >>

=item C<< Can't shift <ARRAY>: array length must be <M>, not <N> >>

=item C<< Can't delete element <N> of <ARRAY>: array length must be <M>, not <N> >>

=item C<< Can't pop <ARRAY>: array length must be <M>, not <N> >>

=item C<< Can't splice <VAL> into <ARRAY>: array length must be <M>, not <N> >>

You are using one of these built-in operations to modify a checked array.
However, the check specifies that the array must be of a certain length
(or within a certain range of lengths) and the operation you were attempting
would make the length of that array either too short or too long to satisfy
the check.

It's likely that the logic of your algorithm is flawed, if it’s causing your
array to overflow or underflow its length bounds. A common case here is
specifying a fixed-length array and then “rotating” its elements the wrong way:

    my @clients :of(10 => OBJ[Account]) = load_clients(10);

    # and later we want to rotate the client list...

    push @clients, shift @clients;     # EXCEPTION!

The problem is that the C<shift> is performed before the C<push>. So, after the C<shift>,
the array has only nine elements, which is a violation of its own check. The solution
is to use an algorithm that ensures the array’s length remains constant.

    @clients = @clients[1..$#clients, 0];     # Okay

=back

=head2 Failed checks on hashes

=over

=item C<< Can't assign value <VAL> to key <KEY> of <HASH>: failed <CHECK> >>

You attempted to assign a value to an entry in a hash, but that value
did not satisfy the check specified on the hash (which is subsequently tested
whenever any hash entry is assigned to).

Either the check on your hash variable isn’t what you actually wanted,
or else the value you were trying to assign into the hash was wrong.

=back

=head2 Failed subroutine calls:

=over

=item C<< Can't pass <VAL> via parameter <PARAM> in call to <SUB>: value failed parameter's <CHECK> >>

You specified a check on a particular parameter of the subroutine but, when the subroutine
was called, the corresponding argument did not satisfy that check.

So either the check on your parameter variable isn’t what you actually wanted,
or else the value you were trying to pass to that parameter was wrong.

=item C<< Can't call subroutine in <CONTEXT> >>

You specified that the subroutine should only be called in void context, by giving
it a C<:returns(VOID)> attribute. But then you called that subroutine in list
or scalar context.

Either the logic of your subroutine call is wrong, or the context is not what you
expected, or you do actually want to be able to call that subroutine in non-void contexts,
so you shouldn’t specify C<:returns(VOID)> on it.

=item C<< List return value <VAL> failed :returns(<SUBCHECK>) check in call to <SUB> >>

=item C<< Scalar return value <VAL> failed :returns(<SUBCHECK>) check in call to <SUB> >>

=item C<< Void return from call to <SUB> failed :returns(<SUBCHECK>) check >>

You specifed a check on the return value of the subroutine, but the value the
subroutine returned did not satisfy that check.

So either the C<:returns> check on your subroutine isn’t what you actually wanted,
or else the value you were trying to return was wrong.

Note that almost all C<:return> checks will fail in void context,
because there is no return value for the check to test. If you want to
allow a checked return value to be “thrown away” without complaint in void contexts,
change the check from C<:returns(WHATEVER)> to C<:returns(WHATEVER | VOID)>.

=back


=head1 CONFIGURATION AND ENVIRONMENT

Data::Checks requires no configuration files or environment variables.


=head1 DEPENDENCIES

Requires Perl 5.22 or later.

Also requires the following non-core modules:

=over

=item L<PPR>

=item L<Variable::Magic>

=back


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to C<bug-data-checks.cpan.org>,
or through the web interface at L<http://rt.cpan.org>.

This module uses the L<PPR> module to pre-parse source code and convert
C<:of> and C<:returns> attributes into the appropriate code. Hence it
inherits all the limitations of that module. It also will not handle
syntax extensions (such as L<Object::Pad> or L<Syntax::Keyword::Gather>
or L<Keyword::Declare>).

=head1 AUTHOR

Damian Conway  C<< <DCONWAY@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2023, Damian Conway. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE.
ALL SUCH WARRANTIES ARE EXPLICITLY DISCLAIMED. THE ENTIRE RISK AS TO THE
QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH YOU. SHOULD THE SOFTWARE
PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL NECESSARY SERVICING, REPAIR,
OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE LIABLE
FOR DAMAGES, INCLUDING ANY DIRECT, INDIRECT, GENERAL, SPECIAL, INCIDENTAL,
EXEMPLARY, OR CONSEQUENTIAL DAMAGES, HOWEVER CAUSED AND ON ANY THEORY OF
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
NEGLIGENCE OR OTHERWISE) ARISING OUT OF THE USE OR INABILITY TO USE THE
SOFTWARE (INCLUDING BUT NOT LIMITED TO PROCUREMENT OF SUBSTITUTE GOODS
OR SERVICES, LOSS OF DATA OR DATA BEING RENDERED INACCURATE, OR LOSSES
SUSTAINED BY YOU OR THIRD PARTIES, OR A FAILURE OF THE SOFTWARE TO
OPERATE WITH ANY OTHER SOFTWARE) EVEN IF SUCH HOLDER OR OTHER PARTY HAS
BEEN ADVISED OF THE POSSIBILITY OF SUCH DAMAGES.

