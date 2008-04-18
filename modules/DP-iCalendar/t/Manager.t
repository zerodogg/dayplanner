# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
#########################

use Test::More;
use FindBin;

plan tests => 10;

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

my $m = DP::iCalendar::Manager->new();
isa_ok($m,'DP::iCalendar::Manager');

my $i1 = DP::iCalendar->new($f);
my $i2 = DP::iCalendar->new($f);
my $prim = DP::iCalendar->new($f);
isa_ok($i1, 'DP::iCalendar');
isa_ok($i2, 'DP::iCalendar');
isa_ok($prim, 'DP::iCalendar');

$m->add_object($prim,1);

is_deeply($m->list_objects(),[$prim]);
is($m->get_primary(),$prim);

$m->add_object($i1);
$m->add_object($i2);
is_deeply($m->list_objects(),[$prim,$i1,$i2]);
is($m->get_primary(),$prim);
