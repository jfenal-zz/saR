#!perl -T

use Test::More tests => 2;

BEGIN {
    use_ok( 'saR' ) || print "Bail out!\n";
    use_ok( 'saR::Load' ) || print "Bail out!\n";
}

diag( "Testing saR $saR::VERSION, Perl $], $^X" );
