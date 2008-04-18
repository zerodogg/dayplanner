# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#########################

use Test::More;
use FindBin;

my $pretests = 6;
my $maintests = 40;
plan tests => ($maintests*3)+$pretests;

# This is useful for diagnosing issues.
# Only /really/ used during writing of the tests, but won't hurt to
# have it here permanently.
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

#########################

use_ok('DP::iCalendar');
use_ok('DP::iCalendar::Manager');

my $f = $FindBin::RealBin.'/calendar.ics';
if(not -e $f)
{
	BAIL_OUT('Calendar file "'.$f.'": did not exist');
}

my $dpi = DP::iCalendar->new($f);
isa_ok($dpi,'DP::iCalendar','Object type');
my $dpi_mgr = DP::iCalendar::Manager->new();
isa_ok($dpi_mgr,'DP::iCalendar::Manager','Object type');
my $dpi_mg = DP::iCalendar->new($f);
$dpi_mgr->add_object($dpi_mg,1);

# Fetch the raw iCalendar file
my $rawdata;
open(my $i,'<',$f);
my $oslash = $/;
$/ = undef;
$rawdata = <$i>;
$/ = $oslash;
close($i);
# Convert to unix format
$rawdata =~ s/\r\n/\n/g;
# Make sure it's not undef or empty.
ok($rawdata);

# Now do one object that is created from the scalar
my $dp_s = DP::iCalendar->new(\$rawdata);
isa_ok($dp_s,'DP::iCalendar');

# Now, why do we run tests on so many objects?
# Simple. We need to verify that all instances yield the same data, and accept the same
# parameters.
foreach my $d($dpi,$dp_s,$dpi_mgr)
{
	my @Methods = ('exists','get_info','get_RRULE','get_monthinfo','get_timeinfo','get_dateinfo','get_exceptions','get_info','get_rawdata','UID_exists_at');
	can_ok($d,@Methods) or BAIL_OUT('Required methods not present in object of type '.ref($d).'!');

	ok($d->exists('dayplanner-117045552311276773'),'UID existance for '.ref($d));

	my %BDayResult = (
		DTEND => '19881127',
		DTSTART => '19881127',
		'LAST-MODIFIED' => '20070505T214400',
		RRULE => 'FREQ=YEARLY',
		SUMMARY => "Foo's birthday",
		UID => 'dayplanner-117045552311276773',
		'X-DP-BIRTHDAY' => 'TRUE',
		'X-DP-BORNATDTSTART' => 'TRUE',
		'X-DP-BIRTHDAYNAME' => 'Foo',
	);

	is_deeply($d->get_info('dayplanner-117045552311276773'),\%BDayResult,'Returned hash for '.ref($d));

	ok($d->UID_exists_at('dayplanner-117045552311276773',2008,11,27,),'UID Existance on datetime, 2008 for '.ref($d));
	ok($d->UID_exists_at('dayplanner-117045552311276773',2006,11,27,),'UID Existance on datetime, 2006 for '.ref($d));
	ok($d->UID_exists_at('dayplanner-117045552311276773',2028,11,27,),'UID Existance on datetime, 2028 for '.ref($d));
	ok($d->UID_exists_at('dayplanner-117045552311276773',1988,11,27,),'UID Existance on datetime, 1988 for '.ref($d));
	ok(!$d->UID_exists_at('dayplanner-117045552311276773',1987,11,27),'UID non-existance on datetime, 1987 for '.ref($d));

	is_deeply($d->get_RRULE('dayplanner-117045552311276773'),{ 'FREQ' => 'YEARLY' },'RRULE for '.ref($d));

	is_deeply($d->get_monthinfo(2008,11),[27],'Month info 2008 for '.ref($d));
	is_deeply($d->get_monthinfo(1988,11),[27],'Month info 1988 for '.ref($d));
	is_deeply($d->get_monthinfo(2028,11),[27],'Month info 2028 for '.ref($d));
	is_deeply($d->get_monthinfo(1987,11),[],'Month info 1987 for '.ref($d));

	is_deeply($d->get_dateinfo(2008,11,27),['DAY'],'Date info 2008 for '.ref($d));
	is_deeply($d->get_dateinfo(1988,11,27),['DAY'],'Date info 1988 for '.ref($d));
	is_deeply($d->get_dateinfo(2028,11,27),['DAY'],'Date info 2028 for '.ref($d));
	is_deeply($d->get_dateinfo(1987,11,27),[],'Date info 1987 for '.ref($d));

	is_deeply($d->get_timeinfo(2028,11,27,'DAY'),['dayplanner-117045552311276773'],'Time info 2028 for '.ref($d));
	is_deeply($d->get_timeinfo(1988,11,27,'DAY'),['dayplanner-117045552311276773'],'Time info 1988 for '.ref($d));
	is_deeply($d->get_timeinfo(2008,11,27,'DAY'),['dayplanner-117045552311276773'],'Time info 2008 for '.ref($d));
	is_deeply($d->get_timeinfo(1987,11,27,'DAY'),[],'Time info 1987 for '.ref($d));

	is_deeply($d->get_timeinfo(2008,11,27,'00:00'),[],'Timeinfo, 00:00 for '.ref($d));

	is_deeply($d->get_exceptions('dayplanner-117045552311276773'),[],'No exceptions for '.ref($d));
	
	# Get raw data, ensure it is in unix format, and compare them
	my $rd = $d->get_rawdata();
	$rd =~ s/\r\n/\n/g;
	is($rd,$rawdata,'Raw data for '.ref($d));

	# Now we do a load of the tests over again after deleting the event
	$d->delete('dayplanner-117045552311276773');
	ok(!$d->exists('dayplanner-117045552311276773'),'UID non-existance for '.ref($d));

	ok(!$d->UID_exists_at('dayplanner-117045552311276773',2008,11,27,),'UID non-existance after delete on datetime, 2008 for '.ref($d));
	ok(!$d->UID_exists_at('dayplanner-117045552311276773',2006,11,27,),'UID non-existance after delete on datetime, 2006 for '.ref($d));
	ok(!$d->UID_exists_at('dayplanner-117045552311276773',2028,11,27,),'UID non-existance after delete on datetime, 2028 for '.ref($d));
	ok(!$d->UID_exists_at('dayplanner-117045552311276773',1988,11,27,),'UID non-existance after delete on datetime, 1988 for '.ref($d));

	is_deeply($d->get_monthinfo(2008,11),[],'Month info 2008 for '.ref($d));
	is_deeply($d->get_monthinfo(1988,11),[],'Month info 1988 for '.ref($d));
	is_deeply($d->get_monthinfo(2028,11),[],'Month info 2028 for '.ref($d));

	is_deeply($d->get_dateinfo(2008,11,27),[],'Date info 2008 for '.ref($d));
	is_deeply($d->get_dateinfo(1988,11,27),[],'Date info 1988 for '.ref($d));
	is_deeply($d->get_dateinfo(2028,11,27),[],'Date info 2028 for '.ref($d));
	is_deeply($d->get_dateinfo(1987,11,27),[],'Date info 1987 for '.ref($d));

	is_deeply($d->get_timeinfo(2028,11,27,'DAY'),[],'Time info 2028 for '.ref($d));
	is_deeply($d->get_timeinfo(1988,11,27,'DAY'),[],'Time info 1988 for '.ref($d));
	is_deeply($d->get_timeinfo(2008,11,27,'DAY'),[],'Time info 2008 for '.ref($d));

	# Get raw data, ensure it is in unix format, and compare them. This time it wouldn't match.
	my $rd2 = $d->get_rawdata();
	$rd2 =~ s/\r\n/\n/g;
	isnt($rd2,$rawdata,'Raw data for '.ref($d));
}
