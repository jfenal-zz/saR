package saR;

use 5.006;
use strict;
use warnings;
use Carp;

use File::Basename;
use File::Spec;
use saR::Load;

=head1 NAME

saR - Load and feed text sar data to something able to work it out

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

saR's ultimate goal is to load text sar data and make available to an
analysis system, which could be R (L<http://www.r-project.org/>).

    use saR;

    my $foo = saR->new( dir => qw( dev prod test) );
    ...

=head1 EXPORT

None. Use the OO interface.

=head1 SUBROUTINES/METHODS

=head2 new

Create a new saR object. 

  $s = saR->new( dir => [ qw( . data )], ext => 'txt' );


Valid parameters: 

=over 4

=item * dir

Pass either a scalar or an array of directories where to search for
files to read from.
If no directory is specified, then only the current directory will be
searched.

=item * ext

Pass either a scalar or an array of possible extensions for files to
read data from.
If no extension is specified, then only files with no extension matching
the machine name will be considered.

=back

=cut

sub new {
    my ( $class, @args ) = @_;
    $class = ref($class) || $class;

    my $self = {};

    bless $self, $class;

    %{ $self->{_config} } = @args;

    # Transform scalar values into an array
    foreach my $s2a (qw( dir ext )) {
        if ( defined( $self->{_config}->{$s2a} )
            && ref( $self->{_config}->{$s2a} ) ne 'ARRAY' )
        {
            my $scalar_value = $self->{_config}->{$s2a};
            @{ $self->{_config}->{$s2a} } = ($scalar_value);
        }
    }

    # Set default values
    if ( !defined( $self->{_config}->{dir} ) ) { $self->{_config}->{dir} = [] }
    if ( !defined( $self->{_config}->{ext} ) ) {
        $self->{_config}->{ext} = [q()];
    }

    $self->{machines} = {};

    $self->find_machine_files;

    return $self;
}

=head2 find_machine_files

Find machines files according to dirs, extensions, and file patterns.

    $self->find_machine_files( qw(hp* ibm* dell*) );

=cut
sub find_machine_files {
    my ( $self, @args ) = @_;
    
    my @fpatterns = ('*');

    if (scalar(@args) > 0) {
        @fpatterns = @args;
    }

    foreach my $dir ( @{ $self->{_config}->{dir} } ) {
        foreach my $e ( @{ $self->{_config}->{ext} } ) {
            my $end = q();

            # useless now we're using catfile
            # if ( -d $d && $d ne q() ) { $dir = $d . "/"; }

            if ( defined $e && $e ne q() ) {
                $end = '.' . $e;
            }

            foreach my $m ( @fpatterns ) {
                $self->debug("Considering dir=$dir m=$m e=$end");

                foreach my $candidate ( glob( File::Spec->catfile( $dir, $m) .  $end) ) {
                $self->debug("Considering $candidate");

                if ( -r $candidate ) {
                    my ($fname, $fdir, $suffix) = fileparse($candidate, $end);
                    $self->debug("Found $candidate : $fname");

                    $self->{machines}->{$fname} = $candidate;
                }
                }
            }
        }
    }

    my $mnumber = scalar keys %{ $self->{machines} };
    if ($mnumber == 0 ) {
        $self->debug("No machine sar data file found");
    }
    return $mnumber;
}

=cut


=head2 base_info

Load one or multiple machine files.
Heuristic is to look at all stated directories and all file extensions
passed in C<new()>, and use the first filename found in the form
C<$dir/${machine}.$ext>.

  $s->base_info();

=cut

sub base_info {
    my ( $self, @args ) = @_;

    my %base_info;

    foreach my $machine ( keys %{$self->{machines}} ) {
        my $loader = saR::Load->new( $self->{machines}->{$machine} );
        $base_info{$machine} = $loader->base_info; 
    }
    return %base_info;
}

sub debug {
    my ( $self, @args ) = @_;

    if ( defined $ENV{DEBUG} ) {
        print STDERR join( q( ), @args, "\n" );
    }
}

=head1 AUTHOR

Jérôme Fenal, C<< <jfenal at redhat.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-sar at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=saR>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc saR


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=saR>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/saR>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/saR>

=item * Search CPAN

L<http://search.cpan.org/dist/saR/>

=back


=head1 ACKNOWLEDGEMENTS

Michael Tieman for suggesting using R to analyse S<14 GiB> of machine
sar data.

=head1 LICENSE AND COPYRIGHT

Copyright 2012 Jérôme Fenal.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of saR
