package saR::Load;

use 5.006;
use strict;
use warnings;
use Exporter qw( import );
use English;
our @ISA = qw(Exporter);
our @EXPORT = qw(  );
our @EXPORTS = qw( $VERSION );
use Params::Validate;
use Data::Dumper;
use Carp;


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

    my $foo = saR::Load->new();
    ...

=head1 EXPORT

TODO: not yet.

=head1 SUBROUTINES/METHODS

=head2 new

=cut

sub new {
    my ($class, $file) = @_;

    my $self = {};
    bless $self, $class;
    $self->{file} = $file;

    return $self;
}

=head2 open 

Open the file for read

=cut

sub open {
    my ($self) = @_;

    my $fh;
    if ( !open $fh, '<', $self->{file} ) {
        croak "Couldn't open file $self->{file} $ERRNO\n";    }
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

    my $nline=0;
    my $fh = $self->{fh};
    LOOP:
    while ( my $l = <$fh> ) {
        chomp $l;
        for my $s ( keys %info ) {
            if ( $l =~ qr{$info{$s}->{re}} ) {
                $bi{$info{$s}->{v}} = $1;
            }
        }
        last LOOP if $nline++ > 100;
    }
    
    $self->close;

    return \%bi;
}

=head2 close

Close file.

=cut


sub close {
    my ($self) = @_;

    if ( defined( $self->{fh} ) ) {
        if ( ! close($self->{fh}) ) {
            croak "Couldn't close file $self->{file}: $ERRNO\n";
        }
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

1; # End of saR::Load
