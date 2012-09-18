#!/usr/bin/perl
#
use strict;
use warnings;
use Benchmark qw(:all);
use POSIX qw( mktime );
use POSIX::strptime;
use Data::Dumper;
use Date::Parse;

my $str   = "09/09/12 12:00:01 PM";
my $count = 200000;
my ( $res1, $res2 );
timethese(
    $count,
    {
        'POSIX::strptime' => sub {
            $res1 = POSIX::mktime( POSIX::strptime( $str, "%d/%m/%y
            %H:%M:%S %p" ) );
        },
        'Date::Parse' => sub { $res2 = str2time($str); },
    }
);

#print "res1 = " . Dumper(\@res1) . "\n";
print "res1 = $res1\n";
print "res2 = $res2\n";
