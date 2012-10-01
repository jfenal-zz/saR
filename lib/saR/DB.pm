package saR::DB;

use 5.007003;
use strict;
use warnings;
use English qw( -no_match_vars );
use Carp;

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

    $self->{dbh} = DBI->connect($dsn, $u, $p) or die $DBI::errstr;

    return $self;
}


=head2 dbh

Return dbh.

=cut

sub dbh {
    my ( $self ) = @_;

    return $self->{dbh};
}

=head2 metric_ids

Add metrics to list of know metrics, return ids for metrics passed.

=cut

sub metric_ids {
    my ( $self, $hasindex, @metrics ) = @_;

    %col2id=();

    my $rhr = $self->dbh->selectrow_hashref( qq{
    select * from metrics;
    } );

    %col2id = map { $rhr->{metric} => $rhr->{ 


    return %col2id;
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
