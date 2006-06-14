#!perl -T

use Test::More tests => 1;

BEGIN {
	use_ok( 'Date::HolidayParser' );
}

diag( "Testing Date::HolidayParser $Date::HolidayParser::VERSION, Perl $], $^X" );
