# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#########################

use Test::More;
use FindBin;
use strict;

# Tests run before the loop
my $pretests = 6;
# Tests run after the loop
my $maintests = 69;
# Times we pass through the loop
my $looptimes = 3;

# Plan it.
plan tests => ($maintests*$looptimes)+$pretests;

# This is useful for diagnosing issues.
# Only /really/ used during writing of the tests, but won't hurt to
# have it here permanently.
use Data::Dumper;
$Data::Dumper::Sortkeys = 1;

#########################

use_ok('DP::iCalendar');
use_ok('DP::iCalendar::Manager');

my ($date_sec,$date_min,$date_hour,$date_mday,$date_mon,$date_year,$date_wday,$date_yday,$date_isdst) = localtime();
$date_year += 1900;
$date_mon++;

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
	my @Methods = ('exists','get_info','get_RRULE','get_monthinfo','get_timeinfo','get_dateinfo','get_exceptions','get_info','get_rawdata','UID_exists_at','add','change');
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
	ok($d->delete('dayplanner-117045552311276773'),'Deleting event for '.ref($d));
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

	# Now, add a new event, without a UID.
	my %NewEvent = (
		DTEND => '20080819T214400',
		DTSTART => '20080819T214400',
		RRULE => 'FREQ=YEARLY',
		SUMMARY => 'Newevent',
	);
	my $UID = $d->add(%NewEvent);
	ok($UID,'Add new event for '.ref($d));
	ok($d->exists($UID),'UID existance after add for '.ref($d));
	is_deeply($d->get_monthinfo(2008,8),['19'],'Month info 2008 for '.ref($d));
	is_deeply($d->get_dateinfo(2028,8,19),['21:44'],'Date info 2008 for '.ref($d));
	is_deeply($d->get_timeinfo(2008,8,19,'21:44'),[$UID],'Time info 2008 for '.ref($d));

	my $uid_obj = $d->get_info($UID);
	ok($uid_obj,'Returned uid object from get_info for '.ref($d));

	# Verify contents
	foreach my $part (keys(%NewEvent))
	{
		is($uid_obj->{$part},$NewEvent{$part},'Part of UID object from get_info ('.$part.')'.' for '.ref($d));
	}
	# Make sure we have a CREATED and LAST-MODIFIED entry that matches today.
	like($uid_obj->{'CREATED'},qr/^${date_year}0?${date_mon}0?$date_mday/,'Creation date of uid for '.ref($d));
	like($uid_obj->{'LAST-MODIFIED'},qr/^${date_year}0?${date_mon}0?$date_mday/,'Last modification date of uid for '.ref($d));

	# Now, change the event.
	my %ChangedEvent = (
		DTEND => '20080919T214500',
		DTSTART => '20080919T214500',
		RRULE => 'FREQ=YEARLY',
		SUMMARY => 'Changed',
	);
	ok($d->change($UID,%ChangedEvent));
	is_deeply($d->get_monthinfo(2008,8),[],'Month info 2008 for '.ref($d));
	is_deeply($d->get_dateinfo(2028,8,19),[],'Date info 2008 for '.ref($d));
	is_deeply($d->get_timeinfo(2008,8,19,'21:44'),[],'Time info 2008 for '.ref($d));
	is_deeply($d->get_monthinfo(2008,9),['19'],'Month info 2008 for '.ref($d));
	is_deeply($d->get_dateinfo(2028,9,19),['21:45'],'Date info 2008 for '.ref($d));
	is_deeply($d->get_timeinfo(2008,9,19,'21:45'),[$UID],'Time info 2008 for '.ref($d));
	is_deeply($d->get_timeinfo(2008,9,19,'21:44'),[],'Time info 2008 for '.ref($d));
	# Verify contents
	$uid_obj = $d->get_info($UID);
	ok($uid_obj,'Returned uid object from get_info for '.ref($d));
	foreach my $part (keys(%NewEvent))
	{
		is($uid_obj->{$part},$ChangedEvent{$part},'Part of UID object from get_info ('.$part.')'.' for '.ref($d));
	}

	ok($d->delete($UID));
	ok(!$d->exists($UID),'UID non-existance after add for '.ref($d));

	$d->addfile($f);
	my $rd3 = $d->get_rawdata();
	$rd3 =~ s/\r\n/\n/g;
	# Now it is equal again, because we just imported it.
	is($rd3,$rawdata,'Raw data after delete for '.ref($d));
}
