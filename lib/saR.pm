package saR;

use 5.006;
use strict;
use warnings;
use Carp;

use File::Basename;
use File::Spec;
use saR::Load;
use saR::DB;

=head1 NAME

saR - Load and feed text sar data to something able to work it out

=head1 DESCRIPTION

saR gets you base methods to deal with multiple sar data files from
multiple machines, get information from those files, and eventually dump
them.

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

    %{ $self } = @args;

    # Transform scalar values into an array
    foreach my $s2a (qw( dir ext )) {
        if ( defined( $self->{$s2a} )
            && ref( $self->{$s2a} ) ne 'ARRAY' )
        {
            my $scalar_value = $self->{$s2a};
            $self->{$s2a} = [ ($scalar_value) ];
        }
    }

    # Set default values
    if ( !defined( $self->{dir} ) ) { $self->{dir} = [] }
    if ( !defined( $self->{ext} ) ) { $self->{ext} = [ q() ];
    }

    $self->{machines} = {};
    $self->{data_cols} = {};
    $self->{data} = {};

    $self->find_machine_files;

    return $self;
}

=head2 find_machine_files

Find machines files according to dirs, extensions, and file patterns.

    $self->find_machine_files( qw(hp* ibm* dell*) );

=cut
sub find_machine_files {
    my ( $self, @args ) = @_;
    
    my @fpatterns = qw( * );

    if (scalar(@args) > 0) {
        @fpatterns = @args;
    }

    foreach my $dir ( @{ $self->{dir} } ) {
        foreach my $e ( @{ $self->{ext} } ) {
            my $end = q();

            # useless now we're using catfile
            # if ( -d $d && $d ne q() ) { $dir = $d . "/"; }

            if ( defined $e && $e ne q() ) {
                $end = q(.) . $e;
            }

            foreach my $m ( @fpatterns ) {
                $self->debug(5, "Considering dir=$dir m=$m e=$end");

                foreach my $candidate ( glob( File::Spec->catfile( $dir, $m) .  $end) ) {
                $self->debug(5, "Considering $candidate");

                if ( -r $candidate ) {
                    my ($fname, $fdir, $suffix) = fileparse($candidate, $end);
                    $self->debug(5, "Found $candidate : $fname");

                    $self->{machines}->{$fname} = $candidate;
                }
                }
            }
        }
    }

    my $mnumber = scalar keys %{ $self->{machines} };
    if ($mnumber == 0 ) {
        warn "No machine sar data file found";
    }
    return $mnumber;
}

=head2 base_info

Load one or multiple machine files.
Heuristic is to look at all stated directories and all file extensions
passed in C<new()>, and use the first filename found in the form
C<$dir/${machine}.$ext>.

  my %base_info = $s->base_info();

=cut

sub base_info {
    my ( $self, @args ) = @_;

    my %base_info;

    my @machines = keys %{$self->{machines}};
    foreach my $machine ( @machines ) {
        my $loader = saR::Load->new( $self->{machines}->{$machine}, $self->{db} );
        $base_info{$machine} = $loader->base_info; 
    }
    return %base_info;
}


=head2 headers

Read all files for headers, and returns a reference to a hash of hashes
containing the data header information.

    my %headers = %{ $s->headers() };

B<Caveat:> This data is also loaded during the C<load_data()> invocation.
If you need it along with the actual data, be sure to invoke the
C<load_data()> method first to avoid reading the files twice.

=cut

sub headers {
    my ( $self, @args ) = @_;

    my $c=1;
    my @machines = keys %{$self->{machines}};
    my $total = scalar @machines;
    foreach my $machine ( @machines ) {
        print STDERR "\nLoading header data for machine $machine ($c/$total)\n";
        my $loader = saR::Load->new( $self->{machines}->{$machine}, $self->{db} );
        $loader->load_data( \$self->{data_cols} );
        $c++;
    }

    return $self->{data_cols};
}

=head2 data

Read all files for headers, and returns a reference to a hash of hashes
containing the data header information.

    my %data = %{ $s->data() };

B<Caveat:> This data is also loaded during the C<load_data()> invocation.
If you need it along with the actual data, be sure to invoke the
C<load_data()> method first to avoid reading the files twice.

=cut

sub data {
    my ( $self, @args ) = @_;

    my $c=1;
    my @machines = keys %{$self->{machines}};
    my $total = scalar @machines;
    foreach my $machine ( @machines ) {
        print STDERR "Loading data for machine $machine ($c/$total)\n";
        my $loader = saR::Load->new( $self->{machines}->{$machine}, $self->{db} );
        $loader->load_data( \$self->{data_cols}, \$self->{data} );
        $c++;
    }

    return $self->{data};
}


=head2 debug

Print debug information on STDERR when $ENV{DEBUG} is set.

    $self->debug("Print", $this);

=cut

sub debug {
    my ( $self, $level, @args ) = @_;

    if ( defined $ENV{DEBUG} && $ENV{DEBUG} >= $level ) {
        print STDERR join( q( ), @args, "\n" );
    }

    return;
}



=head1 DIAGNOSTICS

A C<debug()> method is provided. Not much more yet.

Perl's Carp module is in use, so scripts using this library may halt.

=head1 CONFIGURATION AND ENVIRONMENT

Set C<DEBUG> environment variable to dump debug information.

=head1 DEPENDENCIES

None outside Perl's core modules.

=head1 INCOMPATIBILITIES

None known.

=head1 BUGS AND LIMITATIONS

Lots possibly.

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
