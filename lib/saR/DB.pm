package saR::DB;

use strict;
use warnings;
use English qw( -no_match_vars );
use Carp;
use Time::HiRes qw( time ) ;
use DBI;
use List::Util qw(max);
use Data::Dumper;
#use Date::Parse;

my $time_re =
  qr{ \A ( \d\d [:] \d\d [:] \d\d (?: \s* AM | \s* PM )? ) \s* (.*) }imxs;

=head1 NAME

saR::DB - Manage DB connexion for saR

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

=head1 SYNOPSIS

Create DB connexion for saR, provide methods to add columns or massively
add data.

    use saR::DB;

    my $saRdbh = saR::DB->new();
    ...

=head1 DESCRIPTION

Create DB connexion for saR, provide methods to add columns or massively
add data.


=head1 EXPORT

None.

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
    my ( $class, $dsn, $u, $p ) = @_;

    my $self = {};
    bless $self, $class;

    $self->{db} = DBI->connect($dsn, $u, $p) or die $DBI::errstr;

    return $self;
}


=head2 db

Return DBI db handler.

  my $dbh = $self->db;

=cut

sub db {
    my ( $self ) = @_;

    return $self->{db};
}

=head2 metric_ids

Add metrics to list of know metrics, return ids for metrics passed.

  $db->metric_ids(

=cut

sub metric_ids {
    my ( $self, $index, @metrics ) = @_;

    $self->debug(5, "In metric_ids", @metrics);
    my %col2id=();
    my $dbh =  $self->db;

    my $rhr = $dbh->selectall_hashref( q{ select * from metrics; }, 'metricname') or carp "Unable to get metrics " . $dbh->errstr;
    
    #insert into metrics (metricid, metricname, index) values (NULL, ?, ?);
    my $q =  q{
    INSERT INTO `sar`.`metrics` ( `metricid` , `metricname` , `index`) VALUES ( NULL , ?, ?);
    };

    my $sth = $self->db->prepare($q) or carp "Unable to prepare $q " . $dbh->errstr;

    my $updated = 0;
    foreach my $c (@metrics) {
        if ( ! defined $rhr->{$c} ) {
            $updated++;
            $self->debug(5, "Adding metric $c to database ($index)");
            $sth->bind_param(1, $c);
            $sth->bind_param(2, $index);
            $sth->execute or $self->debug(1, DBI::dump_results($sth));
        }
    }

    $sth->finish;

    # refresh from table if updated
    if ($updated) {
        $self->debug(2, "updating metrics from table");
        $rhr = $dbh->selectall_hashref( q{ select * from metrics; }, 'metricname');
    }
    
    %col2id = map { $_ => $rhr->{$_}->{metricid} } keys %$rhr;

    # cache it
    $self->{c2i} = \%col2id;

    $self->debug(5, "metric_ids", Dumper \%col2id);

    return %col2id;
}

=head2 server_id

Add server to database if unknown, return its id

  $id = $db->server_id( 'hostname' );

=cut

sub server_id {
    my ( $self, $hostname ) = @_;

    $self->debug(5, "In server_ids", $hostname );
    my %hostname2id=();

    if (! defined $self->{servers}->{$hostname} ) {
    my $dbh =  $self->db;

    my $rhr = $dbh->selectall_hashref( qq{ select * from servers where servername="$hostname" ; }, 'servername') or carp "Unable to select serverid " . $dbh->errstr;
    
    if (! defined( $rhr->{$hostname} ) ) {
        my $q =  q{ INSERT INTO `sar`.`servers` ( `servername` ) VALUES ( ? ); };

        my $sth = $dbh->prepare($q) or carp "Unable to prepare $q " . $dbh->errstr;
        $sth->execute( $hostname )
            or $self->debug(1, DBI::dump_results($sth));
        $sth->finish();

        $rhr = $dbh->selectall_hashref( qq{ select * from servers where servername="$hostname" ; }, 'servername') or carp "Unable to select serverid " . $dbh->errstr;

        }

        $self->{servers}->{$hostname} = $rhr->{$hostname}->{serverid}
    }
    return $self->{servers}->{$hostname};
}


=head2 prepare_insert_data

  $db->prepare_insert_data( \%read_col_pos, $hostname );

=cut

sub prepare_insert_data {
    my ( $self, $read_col_pos, $hostname ) = @_;
    my $serverid = $self->server_id($hostname);

    my $q = q{ INSERT INTO `sar`.`data` ( `tstamp`, `serverid`, `dataindex`, `metricid`, `value`) VALUES };
    foreach my $col (sort { $read_col_pos->{$a} <=> $read_col_pos->{$b} } keys %{$read_col_pos} ) {
        $q .= "( ?, $serverid, ?, ?, ?),";
    }
    chop $q; # remove trailing C<,>

    my $sth = $self->db->prepare($q);
    $self->{sth} = $sth;
    $self->{time} = time();
    return $sth;
}

=head2 insert_data

Insert line of data into the data table

  $db->insert_data( \%read_col_pos, $tstamp, $index, @data );

TODO: Other options would be to read data blocks in memory, then dump
entire columns in the database

=cut

sub insert_data {
    my ( $self, $read_col_pos, $tstamp, $index, @data ) = @_;

    my $q = q{ INSERT INTO `sar`.`data` ( `tstamp`, `serverid`, `dataindex`, `metricid`, `value`) VALUES };

    my $col=0;
    my @qvalues = ();
    foreach my $col (sort { $read_col_pos->{$a} <=> $read_col_pos->{$b} } keys %{$read_col_pos} ) {
        my $d = shift @data;
        push @qvalues, ($tstamp, $index, $self->{c2i}->{$col}, $d);
    }

    $self->{sth}->execute(@qvalues) or carp "Unable to insert data $q";
    
    return;
}

=head2 finish_insert_data

Finish the statement handler used for a data block.

=cut
sub finish_insert_data {
    my ( $self, $lines ) = @_;

    if (defined $self->{sth} && defined $lines) {
        $self->{sth}->finish();
        delete $self->{sth};
    }

    $self->debug(1, "\nLoaded $lines lines in ", time() - $self->{time}, " seconds");
    return;
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


In Perl's core: L<POSIX>, L<Carp>, L<English>, L<Data::Dumper>,
C<List::Util> (shipped in Core starting with Perl 5.7.3).

Outside: L<DBI>.

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

    perldoc saR::DB


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

1;    # End of saR::DB
