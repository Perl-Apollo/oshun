package Data::Checks::Parser::CheckPragmaSim 0.000001;

# ABSTRACT: For internal use only.

use 5.022;
use strict;
use warnings;

our $VERSION = '0.00001';

sub import {
    # Determine the mode being requested...
    my $mode;
    for my $arg (@_[1..$#_]) {
        if ($arg =~ m{\A (?:NON)? FATAL \Z}xms) {
            if (defined $mode && $mode ne $arg) {
                die qq{Can't specify both '$mode' and '$arg' in the same "use checks" at }
                . join(' line ', (caller)[1,2]) . "\n";
            }
            $mode = $arg;
        }
        else {
            die qq{Invalid argument ('$arg') passed to "use checks" at }
            . join(' line ', (caller)[1,2]) . "\n";
        }
    }

    # Install the checking mode (defaulting to exceptions)...
    $^H{'Data::Checks::Parser/mode'} = $mode // 'FATAL';
}

sub unimport {
    if (@_ > 1) {
        die q{The "no checks" pragma doesn't take arguments at } . join(' line ', (caller)[1,2]) . "\n";
    }
    $^H{'Data::Checks::Parser/mode'} = 'NONE';
}


1; # Magic true value required at end of module
__END__


=head1 DESCRIPTION

Internal tool used by L<Data::Checks> to validate import() arguments.
