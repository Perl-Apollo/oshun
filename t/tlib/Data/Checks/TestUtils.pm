package    # Protect from CPAN indexer
  Data::Checks::TestUtils 0.000001;

use 5.022;
use warnings;
use experimentals;

sub import ( $, $CHECKNAME ) {
    no strict 'refs';
    use Test::More;

    my $PACKAGE = caller;

    *{ $PACKAGE . '::OKAY' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'OKAY ' ) .= "\t[line " . (caller)[2] . ']';
        my $outcome   = eval { $code->(); 1 };
        my $exception = $@;
        ok $outcome => $msg;
        if ($exception) {
            note qq{   ...expected:  <nothing>};
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::FAIL_ON_LENGTH' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'FAIL_ON_LENGTH' ) .= "\t[line " . (caller)[2] . ']';

        my $outcome      = eval { $code->(); 1 };
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $exception =~ m{\QCan't \E(?:assign|push|pop|shift|unshift|splice|delete) .* \Qlength must be\E}xms;
        my $correct_line = $exception =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok $correct_msg  => '   ...threw correct exception';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't assign ... length must be ... at line $line};
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::FAIL_ON_LENGTH_OLD' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'FAIL_ON_LENGTH_OLD' ) .= "\t[line " . (caller)[2] . ']';

        my $outcome     = eval { $code->(); 1 };
        my $exception   = $@;
        my $correct_msg = $exception =~ m{\QCan't assign\E .* \Qlength must be\E}xms;

        ok !$outcome    => $msg;
        ok $correct_msg => '   ...threw correct exception';
        if ( !$correct_msg ) {
            note qq{   ...expected:  Can't assign ... length must be};
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::FAIL_ON_LENGTH_INIT' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'FAIL_ON_LENGTH_INIT' ) .= "\t[line " . (caller)[2] . ']';

        my $outcome     = eval { $code->(); 1 };
        my $exception   = $@;
        my $correct_msg = $exception =~ m{\QCan't initialize\E .* \Qlength must be\E}xms;

        ok !$outcome    => $msg;
        ok $correct_msg => '   ...threw correct exception';
        if ( !$correct_msg ) {
            note qq{   ...expected:  Can't assign ... length must be ... };
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::FAIL_ON_ASSIGN' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'FAIL_ON_ASSIGN' ) .= "\t[line " . (caller)[2] . ']';

        my $outcome      = eval { $code->(); 1 };
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $exception =~ m{\QCan't assign\E .* (?:\Qfailed \E|\Qwould fail \E) \Q$CHECKNAME check\E}xms;
        my $correct_line = $exception =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok $correct_msg  => '   ...threw correct exception';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't assign ... failed $CHECKNAME check ... at line $line};
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::FAIL_ON_MODIFY' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'FAIL_ON_MODIFY' ) .= "\t[line " . (caller)[2] . ']';

        my $outcome      = eval { $code->(); 1 };
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $exception =~ m{\QCan't \E .* (?:\Qfailed \E|\Qwould fail \E) \Q$CHECKNAME check\E}xms;
        my $correct_line = $exception =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok $correct_msg  => '   ...threw correct exception';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't ... failed $CHECKNAME check ... at line $line};
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::FAIL_ON_UNPACK' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'FAIL_ON_PARAM' ) .= "\t[line " . (caller)[2] . ']';

        my $outcome     = eval { $code->(); 1 };
        my $exception   = $@;
        my $correct_msg = $exception =~ m{(?:\QCan't initialize\E|\QCan't assign\E) .* (?:\Qfailed \E|\Qwould fail \E) \Q$CHECKNAME check\E}xms;

        ok !$outcome    => $msg;
        ok $correct_msg => '   ...threw correct exception';
        if ( !$correct_msg ) {
            note qq{   ...expected:  Can't assign|initialize ... failed $CHECKNAME check ... };
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::FAIL_ON_PARAM' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'FAIL_ON_PARAM' ) .= "\t[line " . (caller)[2] . ']';

        my $outcome      = eval { $code->(); 1 };
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $exception =~ m{\QCan't pass\E .* \Qfailed parameter's $CHECKNAME check\E}xms;
        my $correct_line = $exception =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok $correct_msg  => '   ...threw correct exception';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't pass ... failed parameter's $CHECKNAME check ... at line $line};
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::FAIL_ON_RETURN' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'FAIL_ON_RETURN' ) .= qq{\t[line } . (caller)[2] . ']';

        my $outcome      = eval { $code->(); 1 };
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $exception =~ m{\Qfailed :returns($CHECKNAME) check\E}xms;
        my $correct_line = $exception =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok $correct_msg  => '   ...threw correct exception';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  ... failed :returns($CHECKNAME) check ... at line $line};
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::FAIL_ON_INIT' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'FAIL_ON_INIT' ) .= qq{\t[line } . (caller)[2] . ']';

        my $outcome     = eval { $code->(); 1 };
        my $exception   = $@;
        my $line        = (caller)[2];
        my $correct_msg = $exception
          =~ m{(?:\QCan't initialize\E|\QCan't assign\E) .*? (?:\Qfailed \E|\Qwould fail \E) \Q$CHECKNAME check\E | \QCan't declare \E [\@\$%].*? \Q:of\E .*? \Qthe default undef value would fail the $CHECKNAME check\E}xms;
        my $correct_line = $exception =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok $correct_msg  => '   ...threw correct exception';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't assign|initialize|specify :of... at line $line};
            note qq{   ...but threw: $exception};
        }
    };

    *{ $PACKAGE . '::WARN_ON_LENGTH' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'WARN_ON_LENGTH' ) .= "\t[line " . (caller)[2] . ']';

        # Catch warning message...
        my $warning = q{};
        local $SIG{__WARN__} = sub { $warning = shift };

        my $outcome      = eval { $code->(); 1 } && !$warning;
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $warning =~ m{\QCan't \E(?:assign|push|pop|shift|unshift|splice|delete) .* \Qlength must be\E}xms;
        my $correct_line = $warning =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok !$exception   => '   ...did not throw exception';
        ok $correct_msg  => '   ...raised correct warning';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't assign ... length must be ... at line $line};
            note qq{   ...but got:   $warning};
        }
    };

    *{ $PACKAGE . '::WARN_ON_LENGTH_OLD' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'WARN_ON_LENGTH_OLD' ) .= "\t[line " . (caller)[2] . ']';

        # Catch warning message...
        my $warning = q{};
        local $SIG{__WARN__} = sub { $warning = shift };

        my $outcome     = eval { $code->(); 1 } && !$warning;
        my $exception   = $@;
        my $correct_msg = $warning =~ m{\QCan't assign\E .* \Qlength must be\E}xms;

        ok !$outcome    => $msg;
        ok !$exception  => '   ...did not throw exception';
        ok $correct_msg => '   ...raised correct warning';
        if ( !$correct_msg ) {
            note qq{   ...expected:  Can't assign ... length must be ... };
            note qq{   ...but got:   $warning};
        }
    };

    *{ $PACKAGE . '::WARN_ON_LENGTH_INIT' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'WARN_ON_LENGTH_INIT' ) .= "\t[line " . (caller)[2] . ']';

        # Catch warning message...
        my $warning = q{};
        local $SIG{__WARN__} = sub { $warning = shift };

        my $outcome     = eval { $code->(); 1 } && !$warning;
        my $exception   = $@;
        my $correct_msg = $warning =~ m{\QCan't initialize\E .* \Qlength must be\E}xms;

        ok !$outcome    => $msg;
        ok !$exception  => '   ...did not throw exception';
        ok $correct_msg => '   ...raised correct warning';
        if ( !$correct_msg ) {
            note qq{   ...expected:  Can't assign ... length must be ... };
            note qq{   ...but got:   $warning};
        }
    };

    *{ $PACKAGE . '::WARN_ON_ASSIGN' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'WARN_ON_ASSIGN' ) .= "\t[line " . (caller)[2] . ']';

        # Catch warning message...
        my $warning = q{};
        local $SIG{__WARN__} = sub { $warning = shift };

        my $outcome      = eval { $code->(); 1 } && !$warning;
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $warning =~ m{\QCan't assign\E .* (?:\Qfailed \E|\Qwould fail \E) \Q$CHECKNAME check\E}xms;
        my $correct_line = $warning =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok !$exception   => '   ...did not throw exception';
        ok $correct_msg  => '   ...raised correct warning';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't assign ... length must be ... at line $line};
            note qq{   ...but got:   $warning};
        }
    };

    *{ $PACKAGE . '::WARN_ON_MODIFY' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'WARN_ON_MODIFY' ) .= "\t[line " . (caller)[2] . ']';

        # Catch warning message...
        my $warning = q{};
        local $SIG{__WARN__} = sub { $warning = shift };

        my $outcome      = eval { $code->(); 1 } && !$warning;
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $warning =~ m{\QCan't \E .* (?:\Qfailed \E|\Qwould fail \E) \Q$CHECKNAME check\E}xms;
        my $correct_line = $warning =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok !$exception   => '   ...did not throw exception';
        ok $correct_msg  => '   ...raised correct warning';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't assign ... length must be ... at line $line};
            note qq{   ...but got:   $warning};
        }
    };

    *{ $PACKAGE . '::WARN_ON_UNPACK' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'WARN_ON_PARAM' ) .= "\t[line " . (caller)[2] . ']';

        # Catch warning message...
        my $warning = q{};
        local $SIG{__WARN__} = sub { $warning = shift };

        my $outcome     = eval { $code->(); 1 } && !$warning;
        my $exception   = $@;
        my $correct_msg = $warning =~ m{(?:\QCan't initialize\E|\QCan't assign\E) .* (?:\Qfailed \E|\Qwould fail \E) \Q$CHECKNAME check\E}xms;

        ok !$outcome    => $msg;
        ok !$exception  => '   ...did not throw exception';
        ok $correct_msg => '   ...raised correct warning';
        if ( !$correct_msg ) {
            note qq{   ...expected:  Can't assign ... length must be ... };
            note qq{   ...but got:   $warning};
        }
    };

    *{ $PACKAGE . '::WARN_ON_PARAM' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'WARN_ON_PARAM' ) .= "\t[line " . (caller)[2] . ']';

        # Catch warning message...
        my $warning = q{};
        local $SIG{__WARN__} = sub { $warning = shift };

        my $outcome      = eval { $code->(); 1 } && !$warning;
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $warning =~ m{\QCan't pass\E .* \Qfailed parameter's $CHECKNAME check\E}xms;
        my $correct_line = $warning =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok !$exception   => '   ...did not throw exception';
        ok $correct_msg  => '   ...raised correct warning';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't assign ... length must be ... at line $line};
            note qq{   ...but got:   $warning};
        }
    };

    *{ $PACKAGE . '::WARN_ON_RETURN' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'WARN_ON_RETURN' ) .= qq{\t[line } . (caller)[2] . ']';

        # Catch warning message...
        my $warning = q{};
        local $SIG{__WARN__} = sub { $warning = shift };

        my $outcome      = eval { $code->(); 1 } && !$warning;
        my $exception    = $@;
        my $line         = (caller)[2];
        my $correct_msg  = $warning =~ m{\Qfailed :returns($CHECKNAME) check\E}xms;
        my $correct_line = $warning =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok !$exception   => '   ...did not throw exception';
        ok $correct_msg  => '   ...raised correct warning';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't assign ... length must be ... at line $line};
            note qq{   ...but got:   $warning};
        }
    };

    *{ $PACKAGE . '::WARN_ON_INIT' } = sub : prototype(&$) {
        my ( $code, $msg ) = @_;
        ( $msg //= 'WARN_ON_INIT' ) .= qq{\t[line } . (caller)[2] . ']';

        # Catch warning message...
        my $warning = q{};
        local $SIG{__WARN__} = sub { $warning = shift };

        my $outcome     = eval { $code->(); 1 } && !$warning;
        my $exception   = $@;
        my $line        = (caller)[2];
        my $correct_msg = $warning
          =~ m{(?:\QCan't initialize\E|\QCan't assign\E) .*? (?:\Qfailed \E|\Qwould fail \E) \Q$CHECKNAME check\E | \QCan't declare \E [\@\$%].*? \Q:of\E .*? \Qthe default undef value would fail the $CHECKNAME check\E}xms;
        my $correct_line = $warning =~ m{line \s* $line\b}xms;

        ok !$outcome     => $msg;
        ok !$exception   => '   ...did not throw exception';
        ok $correct_msg  => '   ...raised correct warning';
        ok $correct_line => '   ...at correct location';
        if ( !$correct_msg || !$correct_line ) {
            note qq{   ...expected:  Can't assign ... length must be ... at line $line};
            note qq{   ...but got:   $warning};
        }
    };
}

package Class::Base {
    sub new { bless {}, shift }
}

package Class::NoOverload {
    use base 'Class::Base';
    sub report { }
}

package Class::WithOverload {
    use base 'Class::Base';
    sub report { }

    use overload (
        'bool' => sub {1},
        '""'   => sub {'string'},
        '0+'   => sub {42},
        'qr'   => sub {qr/.../},
        '${}'  => sub { my $x; \$x; },
        '@{}'  => sub { [] },
        '%{}'  => sub { {} },
        '&{}'  => sub {
            sub { }
        },
        '*{}' => sub {*STDOUT},

        fallback => 1,
    );
}

package Class::NonHash::Base {
    sub new { bless [], shift }
}

package Class::NonHash::NoOverload {
    use base 'Class::NonHash::Base';
    sub report { }
}

package Class::NonHash::WithOverload {
    use base 'Class::NonHash::Base';
    sub report { }

    use overload (
        'bool' => sub {1},
        '""'   => sub {'string'},
        '0+'   => sub {42},
        'qr'   => sub {qr/.../},
        '${}'  => sub { my $x; \$x; },
        '@{}'  => sub { [] },
        '%{}'  => sub { {} },
        '&{}'  => sub {
            sub { }
        },
        '*{}' => sub {*STDOUT},

        fallback => 1,
    );
}

1;    # Magic true value required at end of module
__END__

=head1 NAME

Data::Checks::TestUtils - «DESCRIPTION»


=head1 VERSION

This document describes Data::Checks::TestUtils version 0.000001


=head1 SYNOPSIS

    use Data::Checks::TestUtils;

=for author to fill in:
    Brief code example(s) here showing commonest usage(s).
    This section will be as far as many users bother reading
    so make it as educational and exeplary as possible.


=head1 DESCRIPTION

=for author to fill in:
    Write a full description of the module and its features here.
    Use subsections (=head2, =head3) as appropriate.


=head1 INTERFACE

=for author to fill in:
    Write a separate section listing the public components of the modules
    interface. These normally consist of either subroutines that may be
    exported, or methods that may be called on objects belonging to the
    classes provided by the module.


=head1 DIAGNOSTICS

=for author to fill in:
    List every single error and warning message that the module can
    generate (even the ones that will "never happen"), with a full
    explanation of each problem, one or more likely causes, and any
    suggested remedies.

=over

=item C<< Error message here, perhaps with %s placeholders >>

[Description of error here]

=item C<< Another error message here >>

[Description of error here]

[Et cetera, et cetera]

=back


=head1 CONFIGURATION AND ENVIRONMENT

=for author to fill in:
    A full explanation of any configuration system(s) used by the
    module, including the names and locations of any configuration
    files, and the meaning of any environment variables or properties
    that can be set. These descriptions must also include details of any
    configuration language used.

Data::Checks::TestUtils requires no configuration files or environment variables.


=head1 DEPENDENCIES

=for author to fill in:
    A list of all the other modules that this module relies upon,
    including any restrictions on versions, and an indication whether
    the module is part of the standard Perl distribution, part of the
    module's distribution, or must be installed separately. ]

None.


=head1 INCOMPATIBILITIES

=for author to fill in:
    A list of any modules that this module cannot be used in conjunction
    with. This may be due to name conflicts in the interface, or
    competition for system or program resources, or due to internal
    limitations of Perl (for example, many modules that use source code
    filters are mutually incompatible).

None reported.


=head1 BUGS AND LIMITATIONS

=for author to fill in:
    A list of known problems with the module, together with some
    indication Whether they are likely to be fixed in an upcoming
    release. Also a list of restrictions on the features the module
    does provide: data types that cannot be handled, performance issues
    and the circumstances in which they may arise, practical
    limitations on the size of data sets, special cases that are not
    (yet) handled, etc.

No bugs have been reported.

Please report any bugs or feature requests to
C<bug-data-checks-testutils@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org>.


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

