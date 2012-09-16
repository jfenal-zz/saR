package saR::Load;

use 5.006;
use strict;
use warnings;
use Exporter qw( import );
use English;
our @ISA     = qw(Exporter);
our @EXPORT  = qw(  );
our @EXPORTS = qw( $VERSION );
use Params::Validate;
use Data::Dumper;
use Carp;
use List::Util qw(max);
use vars qw( $time_re );

my $time_re = qr{ \A ( \d\d [:] \d\d [:] \d\d (?:AM|PM) ) \s (.*) }imxs;

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

=head1 EXPORT

None.

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
    my ( $class, $file ) = @_;

    my $self = {};
    bless $self, $class;
    $self->{file}      = $file;

    # FIXME: this one should be global to a saR session accross multiple files, not saR::Load
    $self->{data_cols} = {};      # empty data cols for the current file

    return $self;
}

=head2 open 

Open the file for read

=cut

sub open {
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

    $self->open;

    my $nline = 0;
    my $fh    = $self->{fh};
  LOOP:
    while ( my $l = <$fh> ) {
        chomp $l;
        for my $s ( keys %info ) {
            if ( $l =~ qr{$info{$s}->{re}} ) {
                $bi{ $info{$s}->{v} } = $1;
            }
        }
        last LOOP if $nline++ > 100;
    }

    $self->close;

    return \%bi;
}

=head2 _feed_data_cols
    
    _feed_data_cols( \%data_cols, @cols );

    Not a method, just a function.
=cut

sub _feed_data_cols {
    my ( $data_cols, @cols ) = @_;

    # do we have an index
    my $first = $cols[0];
    my $index = 'noidx';

    # an index column are spotted as all uppercase
    if ( $first eq uc($first) ) {

        # if one present, remove it from the list of real data cols
        $index = shift @cols;
    }

    foreach my $c (@cols) {
        if ( !defined( $data_cols->{$index}->{$c} ) ) {

            # we have a new column not already registered
            # find max col index for it
            my $next = 1 + max( values %{ $data_cols->{$index} } );
            $data_cols->{$index}->{$c} = $next;
        }
    }

    return $index;
}

=head2 load_data

  $hdata = $loader->load_data()

=cut

sub load_data {
    my ($self) = @_;

    my $hdata = {};

    # open file for read
    $self->open();

    my $nline = 0;
    my $fh    = $self->{fh};
  LOOP:

    my %context;         # context : OS kernelver hostname date [ arch ncpus ]
    my %read_col_pos;    # defined when finding a new data header line
                         # %col_pos = ( proc/s => 1, ...);

    #
    # data cols, as we add all data in one row per data type
    #
    my $data_cols = $self->{data_cols};

    # %data_cols = {
    #   noidx => { proc/s => 0, cswch/s => 1, pswpin/s => 2, ... },
    #   CPU => { %user => 0, %nice => 1, %system => 2, ... },
    #   INTR => { sum => 0 },
    #   IFACE => { rxpck/s => 0, txpck/s => 1, rxbyt/s => 2, ... },
    #   DEV => { tps => 0, rd_sec/s => 1, wr_sec/s => 2, ... },
    #   };
    #
    # $data_cols will be used for rendering data in the output
    #

    while ( my $l = <$fh> ) {
        chomp $l;

#
# We have a new day header
# qr[ \A (Linux) \s (.*?) \s [(] (.*?) [)] \s+ ( \d\d / \d\d / \d\d ) \s+ (.*?)* \s+ (?: [(] (\d+?) CPU [)])* ]imxs
#
        if ( $l =~ qr{ \A Linux }imxs ) {
            @context{qw(OS kernelver hostname date arch ncpus )} = split( m{\s*}imxs, $l );
            $self->_debug( "Changed context to $context{OS}"
                  . " $context{kernelver} $context{hostname}" );

            delete $context{index};    # removing index will help spot
                                       # flaws in header/data reading logic
        }    # header line

        #
        # Treat data block header line (empty line separated)
        #
        if ( $l =~ qr{ \A \z }imxs ) {

            # we got an empty line, get the header line
            $l = <$fh>;

            my ( $time, $data );
            if ( $l =~ $time_re ) {
                ( $time, $data ) = ( $1, $2 );
                my @col_headers = split qr{ \s+ }, $data;

                # first make %col_pos for this block
                my $c = 0;

                # TODO: doesn't matter if we keep the potential index
                my %read_col_pos = map { $_ => $c++ } @col_headers;
                $self->_debug( 'col pos : ' . Dumper( \%read_col_pos ) );

                # then add possible new cols to data file global
                # %data_cols, get the current context index
                $context{index} = _feed_data_cols( $data_cols, @col_headers );
            }
        }

        #
        # Treat data line
        #
        # Regexp should address both 12 AM/PM & 24 hours time format in sar
        if ( $l =~ $time_re ) {
            my ( $time, $data ) = ( $1, $2 );
            my @cols = split qr{ \s+ }, $data;

        }

        # data line
    }
}

=head2 close

Close file.

=cut

sub close {
    my ($self) = @_;

    if ( defined( $self->{fh} ) ) {
        if ( !close( $self->{fh} ) ) {
            croak "Couldn't close file $self->{file}: $ERRNO\n";
        }
    }

}

=head2 _debug

Print debug info.

=cut

sub _debug {
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
