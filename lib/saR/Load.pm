package saR::Load;

use 5.007;
use strict;
use warnings;
use Exporter qw( import );
use English qw( -no_match_vars );
use Carp;
use List::Util qw(max);
use Data::Dumper;

my $time_re = qr{ \A ( \d\d [:] \d\d [:] \d\d (?:\s*AM|\s*PM)? ) \s* (.*) }imxs;

=head1 NAME

saR::Load - Load textual sar data from a file

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=pod

my $data = (
    cols => {
        'none' => [ qw(
          proc/s
          cswch/s
          pswpin/s pswpout/s
          tps rtps wtps bread/s bwrtn/s
          kbmemfree kbmemused %memused kbbuffers kbcached kbswpfree kbswpused %swpused kbswpcad
          dentunusd file-sz inode-sz super-sz %super-sz dquot-sz %dquot-sz rtsig-sz %rtsig-sz
          totsck tcpsck udpsck rawsck ip-frag
          runq-sz plist-sz ldavg-1 ldavg-5 ldavg-15
          frmpg/s bufpg/s campg/s) ],
        CPU  => [qw( %user %nice %system %iowait %steal %idle )],
        INTR => [qw( intr/s )],
        CPU  => [
            qw(i000/s i001/s i008/s i009/s i012/s i051/s i059/s i067/s i075/s i083/s i090/s i122/s i130/s i138/s i146/s i178/s i186/s i194/s i202/s i210/s i218/s i234/s )
        ],
        TTY   => [ qw(rcvin/s xmtin/s framerr/s prtyerr/s brk/s ovrun/s) ],
        IFACE => [ qw(rxerr/s txerr/s coll/s rxdrop/s txdrop/s txcarr/s rxfram/s rxfifo/s txfifo/s) ],
        IFACE => [ qw(rxpck/s txpck/s rxbyt/s txbyt/s rxcmp/s txcmp/s rxmcst/s) ],
        DEV =>   [ qw( tps rd_sec/s wr_sec/s avgrq-sz avgqu-sz await svctm %util) ],
    }
);
=cut

=head1 SYNOPSIS

Load data from .txt files in one or multiple directory.

    use saR::Load;

    my $loader = saR::Load->new();
    ...

=head1 DESCRIPTION

This module will take care of opening a sar data file, reading from it,
whether header info or data, and closing it.

=head1 EXPORT

None.

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
    my ( $class, $file ) = @_;

    my $self = {};
    bless $self, $class;
    $self->{file} = $file;

# FIXME: this one should be global to a saR session accross multiple files, not saR::Load

    return $self;
}

=head2 open_file

Open the file for read

=cut

sub open_file {
    my ($self) = @_;

    my $fh;
    if ( !open $fh, '<', $self->{file} ) {
        croak "Couldn't open file $self->{file} $ERRNO\n";
    }
    $self->{fh} = $fh;

    return $self;
}

=head2 base_info

Actually load the data base info

=cut

sub base_info {
    my ($self) = @_;

    my %info = (
        'HW Model'     => { v => 'hwmodel', },
        'CPU Model'    => { v => 'cpumodel', },
        'Nb CPUs'      => { v => 'cpus', },
        'Nb Cores/cpu' => { v => 'cores', },
        'RAM'          => { v => 'ram', },
        'OS Level'     => { v => 'oslevel', },
        'SAN'          => { v => 'san', },
    );
    my %bi = ();

    # compile regexps
    for my $s ( keys %info ) {
        $info{$s}->{re} = qr{^$s\s*:\s*(.*)}i;
    }

    $self->open_file;

    my $nline = 0;
    my $fh    = $self->{fh};
  LOOP:
    while ( my $l = <$fh> ) {
        chomp $l;
        for my $s ( keys %info ) {
            if ( $l =~ qr{$info{$s}->{re}}imxs ) {
                $bi{ $info{$s}->{v} } = $1;
            }
        }
        last LOOP if $nline++ > 100;
    }

    $self->close_file;

    return \%bi;
}

=head2 feed_data_cols
    
    $s->feed_data_cols( \%data_cols, @cols );

Helper method to keep track of columns headers overall all files.

C<%data_cols> must be kept maintained accross all files in a session,
and usually is maintained in the calling C<saR> object.

=cut

sub feed_data_cols {
    my ( $self, $data_cols, @cols ) = @_;

    # do we have an index
    my $first = $cols[0];
    my $index = 'noidx';
    $data_cols = $$data_cols;   # get hashref from ref
    $self->debug("data_cols:", $data_cols);

    # an index column are spotted as all uppercase
    if ( $first eq uc($first) ) {

        # if one present, remove it from the list of real data cols
        $index = shift @cols;
    }
    $self->debug("index=$index, cols:", @cols);

    # take care of existence of first level in the hash (index)
    if ( !defined( $data_cols->{$index} ) ) {
        $data_cols->{$index} = {};
    }

    # loop through columns
    foreach my $c (@cols) {
        if ( !defined( $data_cols->{$index}->{$c} ) ) {
            $self->debug("new column $c: index=$index");

            # we have a new column not already registered
            # find max col index for it
            my $next = 1 + max( values %{ $data_cols->{$index} } );
            $data_cols->{$index}->{$c} = $next;
        }
    }

    return $index;
}

=head2 load_data

Load data from the current file in the loader.

The optional argument specifies whether to actually load the data or
not. If not, only headers from data blocks will be loaded and kept.

  $hdata = $loader->load_data( \%data_cols );    # load data
  $hdata = $loader->load_data( \%data_cols, 0 );   # load only headers

=cut

sub load_data {
    my ( $self, @args ) = @_;

    my $data_cols = shift @args;

    $self->debug( "data_cols=", Dumper($data_cols) );

    # %data_cols = {
    #   noidx => { proc/s => 0, cswch/s => 1, pswpin/s => 2, ... },
    #   CPU => { %user => 0, %nice => 1, %system => 2, ... },
    #   INTR => { sum => 0 },
    #   IFACE => { rxpck/s => 0, txpck/s => 1, rxbyt/s => 2, ... },
    #   DEV => { tps => 0, rd_sec/s => 1, wr_sec/s => 2, ... },
    #   };
    #
    # $data_cols will be used for rendering data in the output and
    # has to be maintained globally for all sar files to read.
    #

    my $doload = 1;

    if ( defined $args[0] ) {
        $doload = shift @args;
    }

    my $hdata = {};

    # open file for read
    $self->open_file;

    my $nline = 0;
    my $fh    = $self->{fh};
  LOOP:

    my %context;         # context : OS kernelver hostname date [ arch ncpus ]
    my %read_col_pos;    # defined when finding a new data header line
                         # %col_pos = ( proc/s => 1, ...);

    while ( my $l = <$fh> ) {
        chomp $l;

#
# We have a new day header
# qr[ \A (Linux) \s (.*?) \s [(] (.*?) [)] \s+ ( \d\d / \d\d / \d\d ) \s+ (.*?)* \s+ (?: [(] (\d+?) CPU [)])* ]imxs
#
        if ( $l =~ qr{ \A Linux }imxs ) {
            @context{qw(OS kernelver hostname date arch ncpus )} =
              split( m{\s+}imxs, $l );

            # remove () in hostname
            $context{hostname} =~ s/[()]//g;

            $self->debug( "Changed context to ",
                @context{qw(OS kernelver hostname date)} );

            delete $context{index};    # removing index will help spot
                                       # flaws in header/data reading logic
        }    # header line

        #
        # Treat data block header line (empty line separated)
        #
        if ( $l =~ m/^\s*$/ ) {
            $self->debug("Entering new data block following an empty line");

            # we got an empty line, get the header line
            $l = <$fh>;
    
            my ( $time, $data );
            if ( $l =~ $time_re ) {
                ( $time, $data ) = ( $1, $2 );
                my @col_headers = split qr{ \s+ }imxs, $data;
                $self->debug("time=$time, col headers: ", @col_headers);

                # first make %col_pos for this block
                my $c = 0;

                # TODO: doesn't matter if we keep the potential index
                %read_col_pos = map { $_ => $c++ } @col_headers;
                $self->debug( '%read_col_pos : ' . Dumper( \%read_col_pos ) );

                # then add possible new cols to data file global
                # %data_cols, get the current context index
                $context{index} =
                  $self->feed_data_cols( $data_cols, @col_headers );
            }
        }

        #
        # Treat data line
        #
        # Regexp should address both 12 AM/PM & 24 hours time format in sar
        if ( $doload && $l =~ $time_re ) {
            my ( $time, $data ) = ( $1, $2 );
            my @cols = split qr{ \s+ }mxs, $data;

            $self->debug("Splitted new data line: ", @cols);

            # do something with this data. Later.
        }

        # data line
    }

    $self->close_file;
    return $hdata;
}

=head2 close_file

Close file.

=cut

sub close_file {
    my ($self) = @_;

    if ( defined( $self->{fh} ) ) {
        if ( !close( $self->{fh} ) ) {
            croak "Couldn't close file $self->{file}: $ERRNO\n";
        }
    }

}

=head2 debug

Print debug info.

=cut

sub debug {
    my ( $self, @args ) = @_;

    if ( defined $ENV{DEBUG} ) {
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

C<List::Util> is used, in Core starting with Perl 5.7.3.

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

    perldoc saR::Load


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


=head1 LICENSE AND COPYRIGHT

Copyright 2012 Jérôme Fenal.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of saR::Load
