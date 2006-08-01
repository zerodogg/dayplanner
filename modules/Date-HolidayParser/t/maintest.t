#!perl -T
use strict;
use warnings;
use Test::More 'no_plan';
use Cwd;
use File::Basename;
use Date::HolidayParser;

my $MyPath = dirname(Cwd::realpath($0));

my $parser = Date::HolidayParser->new("$MyPath/testholiday");

ok(defined $parser, "->new returned something usable");
ok($parser->isa('Date::HolidayParser'), "->new returned the right class");

my %YearTests = (
	2006 => {
		3 => {
			13 => {
				'Monday' => undef,
			},
			27 => {
				'Monday' => undef,
			},
		},
		4 => {
			2 => {
				"First sunday in april" => "red",
			},
			16 => {
				"Easter" => undef,
			},
			30 => {
				"Last sunday in april" => "red",
			},

		},
		5 => {
			17 => {
				'17th of may' => undef,
				'Also 17th of may' => undef,
				'Again the 17th of may' => undef
			},
			21 => {
				'Easter plus 35' => undef,
				'Easter plus 35 - formatted' => 'red',
			}
		},
		12 => {
			 '17' => {
				 'Sunday before 25th minus 7 days' => undef
			 }
		 },
	},
);

foreach my $year (sort(keys(%YearTests))) {
		my $YearP = $parser->get($year);
		ok(defined $YearP, "->get($year) returned something usable");
		foreach my $month (sort(keys(%{$YearTests{$year}}))) {
					ok(defined $YearP->{$month}, "->get->month($month) defined");
					foreach my $day (sort(keys(%{$YearTests{$year}{$month}}))) {
						ok(defined $YearP->{$month}{$day}, "->get->month($month)->day($day) defined");
						foreach my $name (sort(keys(%{$YearP->{$month}{$day}}))) {
							if(defined($YearTests{$year}{$month}{$day}{$name})) {
								ok($YearP->{$month}{$day}{$name} eq $YearTests{$year}{$month}{$day}{$name}, "->get->month($month)->day($day)->name($name) eq $YearTests{$year}{$month}{$day}{$name}");
							} else {
								ok(! defined($YearP->{$month}{$day}{$name}), "->get->month($month)->day($day)->name($name) eq undef");
								}
						}
					}
				}
	}
