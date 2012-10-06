package saR::Load;

use strict;
use warnings;
use English qw( -no_match_vars );
use Carp;

use POSIX;
use POSIX::strptime;
use List::Util qw(max);
use Data::Dumper;
#use Date::Parse;

my $time_re =
  qr{ \A \s* ( \d\d [:] \d\d [:] \d\d (?: \s* AM | \s* PM )? ) \s+ (.*)}imxs;

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
    my ( $class, $file, $db ) = @_;

    my $self = {};
    bless $self, $class;
    $self->{file} = $file;
    $self->{db} = $db;

    return $self;
}

=head2 open_file

Open the file for read

Returns the size of the file.

=cut

sub open_file {
    my ($self) = @_;

    my $fh;
    if ( !open $fh, '<', $self->{file} ) {
        croak "Couldn't open file $self->{file} $ERRNO\n";
    }
    $self->{fh} = $fh;

    my $size;

    seek $fh, 0, POSIX::SEEK_END;
    $size = tell $fh;
    seek $fh, 0, POSIX::SEEK_SET;
    

    return $size;
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
    
    $s->feed_data_cols( \%data_cols, $index, $tstamp, $hostname, @cols );

Helper method to keep track of columns headers overall all files.

C<%data_cols> must be kept maintained accross all files in a session,
and usually is maintained in the calling C<saR> object.

=cut

sub feed_data_cols {
    my ( $self, $data_cols, $index, $tstamp, $hostname, @cols ) = @_;

    $self->debug(2, "data_cols:", $data_cols );

    # loop through columns
    foreach my $c (@cols) {
        if ( !defined( $data_cols->{$index}->{$c} ) ) {
            $self->debug(5, "new column $c: index=$index");

            # we have a new column not already registered
            # find max col index for it
            my $themax = max( values %{ $data_cols->{$index} } );
            my $next   = 0;
            if ( defined $themax ) {
                $next = 1 + $themax;
            }
            $data_cols->{$index}->{$c}->{rank} = $next;
            $data_cols->{$index}->{$c}->{start} = $tstamp;
            $data_cols->{$index}->{$c}->{period} = undef;
            $data_cols->{$index}->{$c}->{last} = undef;
        }
    }
    return $self->{db}->metric_ids($index, @cols);
}

=head2 load_data

Load data from the current file in the loader.

The optional argument specifies whether to actually load the data or
not. If not, only headers from data blocks will be loaded and kept.

  # load data
  $loader->load_data( \%data_cols, \%data );

  # load only headers
  $loader->load_data( \%data_cols );

Return value: none yet.

=cut

sub load_data {
    my ( $self, @args ) = @_;

    my ( $data_cols, $hdata ) = @args;

    $self->debug(2, "data_cols=", Dumper($data_cols) );
    $self->debug(5, "hdata=", Dumper($hdata) );

    # %data_cols = {
    #   NOIDX => { proc/s => 0, cswch/s => 1, pswpin/s => 2, ... },
    #   CPU => { %user => 0, %nice => 1, %system => 2, ... },
    #   INTR => { sum => 0 },
    #   IFACE => { rxpck/s => 0, txpck/s => 1, rxbyt/s => 2, ... },
    #   DEV => { tps => 0, rd_sec/s => 1, wr_sec/s => 2, ... },
    #   };

    #   %data_cols = {
    #       NOIDX => {
    #           'proc/s' => {
    #               rank   => 0,
    #               start  => $tstamp,
    #               period => undef,
    #               last   => undef,
    #           },
    #           'cswch/s' => {
    #               rank   => 0,
    #               start  => $tstamp,
    #               period => undef,
    #               last   => undef,
    #           },
    #       },
    #       CPU => {
    #           '%user' => {
    #               rank   => 0,
    #               start  => $tstamp,
    #               period => undef,
    #               last   => undef,
    #           },
    #           '%nice' => {
    #               rank   => 0,
    #               start  => $tstamp,
    #               period => undef,
    #           }
    #       }
    #   };
    #
    # $data_cols will be used for rendering data in the output and
    # has to be maintained globally for all sar files to read.
    #

    # flag: should we load data or not?
    my $doload = 0;

    $data_cols = $$data_cols;   # get hashref from ref

    # load actual data (e.g. not only headers) if we have a hash ref to
    # store data passed as an argument
    if ( defined $hdata ) {
        $doload = 1;
        $hdata=$$hdata;         # get hashref from ref
        $self->debug(1, "Initial data=", Dumper($hdata) );
    }

    # open file for read
    my $size = $self->open_file;

    my $nline = 0;
    my $fh    = $self->{fh};

    my %context;         # context : OS kernelver hostname date [ arch ncpus ]
    my %read_col_pos;    # defined when finding a new data header line
                         # %read_col_pos = ( proc/s => 1, ...);

    my %c2i;             # could also be named as data_col_pos
                         # addresses data in the columns in data output

    my $position_in_file;
    my $advance_incr = $size / 200;
    my $current_advance=0;
    my $line_count = 0;
    $context{date} = 'unknown';

  LOOP:
    while ( my $l = <$fh> ) {
        chomp $l;
        # Print advance in file read.
        $position_in_file = tell $fh;
        if ($position_in_file > $current_advance) {
            print STDERR "\r=== File: $self->{file} ($context{date}): " . int(100 * $position_in_file / $size) . "%";
            $current_advance += $advance_incr;
        }
#        else { print STDERR '.'; }

#
# We have a new day header
# qr[ \A (Linux) \s (.*?) \s [(] (.*?) [)] \s+ ( \d\d / \d\d / \d\d ) \s+ (.*?)* \s+ (?: [(] (\d+?) CPU [)])* ]imxs
#
        if ( $l =~ qr{ \A Linux }imxs ) {
            @context{qw(OS kernelver hostname date arch ncpus )} =
              split( m{\s+}imxs, $l );

            # remove () in hostname
            $context{hostname} =~ s/[()]//g;

            $self->debug(5, "\nChanged context to ",
                @context{qw(OS kernelver hostname date)} );

            $context{index} = 'NOIDX'; # defaumlt value.
               # delete $context{index};    # TODO: removing index will help spot
                                       # flaws in header/data reading logic

            if (length($context{date}) == 8) {
                my @d = split(qr{/}, $context{date});
                # FIXME: dirty hack to cope sar output mixing years on 2
                # or 4 positions
                if ($d[2] > 70) { $d[2] += 1900; } else { $d[2] += 2000; }
                $context{date} = join( '/', @d);
            }
        }    # header line

        #
        # Treat data block header line (empty line separated)
        #
        if ( $l =~ m/^\s*$/ ) {
            $self->debug(5, "\nEntering new data block following an empty line");

            # first of all, finish a potentially active statement handler
            $self->{db}->finish_insert_data($line_count);

            # reset data block line count
            $line_count = 0;
            # we got an empty line, get the header line
            $l = <$fh>;
            chomp $l;

            $self->debug(5, "Header line: $l");

            my ( $time, $data );

            if ( $l =~ $time_re ) {
                ( $time, $data ) = ( $1, $2 );

                $self->debug(5, "date: <$context{date}>");
                $self->debug(5, "time: <$time>");
                $self->debug(5, "data: <$data>");
                carp "Missing date" if not defined $context{date};
                carp "Missing time $time" if not defined $time;
                # compute time in secs from epoch
                # TODO: define a timezone per machine and use it here.
                my @ptime = 
                    POSIX::strptime( "$context{date} $time", "%m/%d/%Y %H:%M:%S %p");
                $self->debug(5, "ptime: ", Dumper \@ptime);
                my $tstamp = POSIX::mktime( @ptime );

                my @col_headers = split qr{ \s+ }imxs, $data;
                $self->debug(2, "time=$time, col headers: ", @col_headers );

                # first make %col_pos for this block
                my $c = 0;

                # Do we have an index ?
                if ($col_headers[0] eq uc($col_headers[0])) {
                    $context{index} = $col_headers[0];
                    shift @col_headers;
                }
                else {
                    $context{index} = 'NOIDX';
                }

                # reset data period to 0
                $context{period} = 0;

                %read_col_pos = map { $_ => $c++ } @col_headers;
                $self->debug(3, '%read_col_pos : ' . Dumper( \%read_col_pos ) );

                # then add possible new cols to data file global
                # %data_cols, get the current context index
                # get index for column header right away
                %c2i = $self->feed_data_cols( $data_cols, $context{index}, $tstamp, $context{hostname}, @col_headers );

                # and now open a new insert statement handler
                $self->{db}->prepare_insert_data( \%read_col_pos, $context{hostname});

                # TODO, if needed
                # new kind of storage
                # 1. if period not defined, then compute it, else check it.
                # 2. add data to each storage
                # 3. store last tstamp for all data cols

                # QUESTIONS:
                # - how to store data:
                #   - per machine, per col --> start/period
                #   - per col, per machine --> start/period
                #   or
                #   - per col/period -> machine -> start / data

            }

            # do not try to analyze data which are not there
            next LOOP;
        }

        #
        # Treat data line
        #
        # Regexp should address both 12 AM/PM & 24 hours time format in sar
        if ( $doload && $l =~ $time_re ) {
            my ( $time, $data ) = ( $1, $2 );
            $line_count++;

            my @data = split qr{ \s+ }mxs, $data;
            $self->debug(2, "Splitted new data line: ", Dumper \@data );

            # if in the context, we are supposed to have an index, set
            # it, otherwise, use 'NOIDX'
            my $index = 'NOIDX';
            if ( $context{index} ne 'NOIDX' ) {
                $index = shift @data;
            }
            $self->debug(2, "index=$index");
            # should never be the case
            if (! defined $context{index}) {
                carp "New data line without index: ", Dumper \@data 
            }

            # compute time in secs from epoch
            # TODO: define a timezone per machine and use it here.
            my $tstamp = POSIX::mktime(
                POSIX::strptime(
                    $context{date} . q( ) . $time,
                    "%m/%d/%Y %H:%M:%S %p"
                )
            );
            my $hostname = $context{hostname};

            # feed metrics loaded in the current line into db
            # all at once
            $self->{db}->insert_data( \%read_col_pos, $tstamp, $index, @data);
        }
    }

    $self->close_file;
    return;
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
    my ( $self, $level, @args ) = @_;

    if ( defined $ENV{DEBUG} && $ENV{DEBUG} >= $level) {
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

In Perl's core modules used (L<POSIX>, L<Carp>, L<English>,
L<Data::Dumper>), C<List::Util> is also used (shipped in Core starting
with Perl 5.7.3).

Outside: L<Date::Parse>.

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
