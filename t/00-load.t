#!perl -T

use Test::More tests => 3;

BEGIN {
    use_ok( 'saR' ) || print "Bail out!\n";
    use_ok( 'saR::Loader' ) || print "Bail out!\n";
    use_ok( 'saR::R' ) || print "Bail out!\n";
}

diag( "Testing saR $saR::VERSION, Perl $], $^X" );
