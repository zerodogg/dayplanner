#!/usr/bin/perl
# Date::HolidayParser
# $Id$
# A parser of ~/.holiday-style files.
#  The format is based off of the holiday files found bundled
#  with the plan program, not any official spec. This because no
#  official spec could be found.
# Copyright (C) Eskild Hustvedt 2006
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package Date::HolidayParser;

use strict;
use warnings;
use Carp;
use Exporter;
use POSIX;

# Exportable functions are ParseHoliday (main parser function) and EasterCalc
my @EXPORT_OK = qw(EasterCalc ParseHoliday);

# Version number
my $VERSION;
$VERSION = 0.3;

# The user should be able to tell us to be silent
our $BeSilent;

# Easter calculation using the gauss algorithm. See:
# http://en.wikipedia.org/wiki/Computus#Gauss.27s_algorithm
# Parts of the code stolen from Kenny Fowler
#
# Purpose: Calculate on which day easter occurs on in the year YEAR
# Usage: $EasterYDay = EasterCalc(YEAR);
# 
# YEAR should be absolute and not relative to 1900
sub EasterCalc {
	my $year = $_[0];

	my $c;
	my $l;
	my $k;
	my $d;
	my $r;
	my $j;
	my $NewTime;
	
	$c = int($year/100);
	
	$l = $year % 19;
	
	$k = int(($c - 17)/25);
	
	$d = (15 + $c - int($c/4) - int(($c-$k)/3) + 19*$l) % 30;
	
	$r = $d - int(($d + int($l/11))/29);
	
	$j = ($year + int($year/4) + $r + 2 - $c + int($c/4)) % 7;

	my $number = 28 + $r - $j;

	if ($number > 31)
	{
		$number = $number - 31;
		$year = $year - 1900;
		$NewTime = POSIX::mktime(0, 0, 0, $number, 3, $year);
	} else {
		$year = $year - 1900;
		$NewTime = POSIX::mktime(0, 0, 0, $number, 2, $year);
	}
	my ($easter_sec,$easter_min,$easter_hour,$easter_mday,$easter_mon,$easter_year,$easter_wday,$easter_yday,$easter_isdst) = localtime($NewTime);
	return($easter_yday);
}

# Purpose: Calculate a NumericYDay
# Usage: $CreativeParser{FinalYDay} = _HCalc_NumericYDay($CreativeParser{NumericYDay}, $CreativeParser{AddDays}, $CreativeParser{SubtDays});
sub _HCalc_NumericYDay {
	my ($DAY, $ADD_DAYS, $SUBTRACT_DAYS) = @_;
	if(defined($ADD_DAYS)) {
		$DAY += $ADD_DAYS;
	}
	if(defined($SUBTRACT_DAYS)) {
		$DAY -= $SUBTRACT_DAYS;
	}
	# mday begins on 1 not 0 - we use mday for all calculations, thus
	# make the day 1-365 instead of 0-364 here
	$DAY++;
	return($DAY);
}

# Purpose: Return the English day name of the year day supplied
# Usage: $DayName = _Holiday_DayName(INTEGER_NUMBER, YEAR);
sub _Holiday_DayName {
	my $year = $_[1];
	$year -= 1900;
	
	my $PosixTime = POSIX::mktime(0, 0, 0, $_[0], 0, $year);
	die("*** _Holiday_DayName: For some reason mktime returned undef!. Was running: \"POSIX::mktime(0, 0, 0, $_[0], 0, $year)\".\nYou've probably got a loop that has started looping eternally. This error is fatal") unless(defined($PosixTime));
	my %NumToDayHash = (
		0 => 'sunday',
		1 => 'monday',
		2 => 'tuesday',
		3 => 'wednesday',
		4 => 'thursday',
		5 => 'friday',
		6 => 'saturday',
		7 => 'sunday',
	);
	my ($DayName_sec,$DayName_min,$DayName_hour,$DayName_mday,$DayName_mon,$DayName_year,$DayName_wday,$DayName_yday,$DayName_isdst) = localtime($PosixTime);
	return($NumToDayHash{$DayName_wday});
}

# Purpose: Return the yday of the supplied unix time
# Usage: $YDay = _Get_YDay(UNIX_TIME);
sub _Get_YDay {
	my $Unix_Time = $_[0];
	warn("_Get_YDay: Invalid usage: must be numeric. Got \"$Unix_Time\"") and return(undef) if $Unix_Time =~ /\D/;
	my ($get_sec,$get_min,$get_hour,$get_mday,$get_mon,$get_year,$get_wday,$get_yday,$get_isdst) = localtime($Unix_Time);
	return($get_yday);
}

# Purpose: Print a warning about some error during the holiday parsing
# Usage: _HolidayError(LINE_NO, FILENAME, ERROR, ACTION_TAKEN);
sub _HolidayError {
	_PrintError("*** Holiday parser error: $_[2] on line $_[0] in $_[1]. $_[3]\n");
}

# Purpose: Print a syntax error in a holiday file
# Usage: _SyntaxError(LINE_NO, FILENAME, ERROR, ACTION_TAKEN);
sub _SyntaxError {
	_PrintError("*** Holiday parser: Syntax error: $_[2] on line $_[0] in $_[1]. $_[3]\n");
}

# Purpose. Actually print the error (obeying $BeSilent)
# Usage: _PrintError(ERROR);
sub _PrintError($) {
	unless($BeSilent) {
		warn $_[0];
	}
}

# Purpose: Emulate the legacy syntax using the new OO-syntax
# Usage: Parse(FILE, YEAR);
sub Parse {
	my ($File, $Year) = @_;
	carp("$File does not exist") and return(undef) unless -e $File;
	carp("$File is not readable") and return(undef) unless -r $File;
	carp("$Year is not numeric") and return(undef) if $Year =~ /\D/;

	# Validate year
	if($Year > 2037) {
		carp("The holiday parser can't count longer than 2037 due to imitations with the 32bit posix time functions. Ignoring request for paring of $File for the year $Year");
		return(undef);
	}
	my $Object = Date::HolidayParser->new($File);
	return($Object->parse($Year));
}

# Purpose: Interperate and calculate the holiday file
# Usage: $self->_interperate_year(YEAR);
sub _interperate_year {
	my $self = $_[0];
	my $Year = $_[1];
	my $PosixYear = $Year - 1900;
	my $FinalParsing = {};
	foreach my $LineNo (keys(%{$self->{parsed}})) {
		my ($FinalYDay, $NumericYDay);
		my $CreativeParser = $self->{parsed}->{$LineNo};
		my $HolidayName = $self->{parsed}->{$LineNo}{name};
		my $File = $self->{FILE};
		my %MonthMapping = (
			'january' => 0,
			'february' => 1,
			'march' => 2,
			'april' => 3,
			'may' => 4,
			'june' => 5,
			'july' => 6,
			'august' => 7,
			'september' => 8,
			'october' => 9,
			'november' => 10,
			'december' => 11,
		);	# Hash mapping the month name to a numeric
	
		if(defined($CreativeParser->{AddEaster})) {
			$NumericYDay = EasterCalc($Year);
		}
		if(defined($CreativeParser->{MonthDay})) {
			my $month = $CreativeParser->{MonthDay};
			my $day = $CreativeParser->{MonthDay};
			$month =~ s/^(\d+)-(\d+)$/$1/;
			$day =~ s/^(\d+)-(\d+)$/$2/;
			my $PosixTime = POSIX::mktime(0, 0, 0, $day, $month, $PosixYear);
			$NumericYDay = _Get_YDay($PosixTime);
		}
		
		unless(defined($CreativeParser->{IsMonth}) or defined($NumericYDay)) {
			_SyntaxError($LineNo, $File, "I had no day-of-the-year nor a month defined after parsing", "Ignoring this line");
			next;
		}

		if(defined($CreativeParser->{MustBeDay})) {
	
			# If IsMonth is defined then find a NumericYDay that we can use so that
			# the NumericYDay parsing below can do all of the heavy lifting
			if (defined($CreativeParser->{IsMonth}) and defined($CreativeParser->{Number})) {
				my $PosixYear = $Year - 1900;
				my $PosixTime = POSIX::mktime(0, 0, 0, 1, $MonthMapping{$CreativeParser->{IsMonth}}, $PosixYear);
				my $proper_yday = _Get_YDay($PosixTime);
				unless(defined($CreativeParser->{Number})) {
					_HolidayError($LineNo, $File, "\$CreativeParser->{Number} is undef", "Skipping this line. This is probably a bug in the parser");
					next;
				}
				if($CreativeParser->{Number} eq 'last') {
					# Find the first of the set day
					while(1) {
						if(_Holiday_DayName($proper_yday, $Year) eq $CreativeParser->{MustBeDay}) {
							last;
						}
						$proper_yday++;
					}
	
					# Find the last of the set day
					my $Last_YDay = $proper_yday;
					while(1) {
						if(_Holiday_DayName($proper_yday, $Year) eq $CreativeParser->{MustBeDay}) {
							$proper_yday += 7;
						}
						my $MKTime = POSIX::mktime(0, 0, 0, $proper_yday, 0, $PosixYear);
						my ($detect_sec,$detect_min,$detect_hour,$detect_mday,$detect_mon,$detect_year,$detect_wday,$detect_yday,$detect_isdst) = localtime($MKTime);
						# If $detect_mon is not equal to $MonthMapping{$CreativeParser->{IsMonth}} then
						# we're now on the next month and have found the last of the day
						unless($detect_mon eq $MonthMapping{$CreativeParser->{IsMonth}}) {
							last;
						}
						$Last_YDay = $proper_yday;
					}
					$NumericYDay = $Last_YDay;
					$CreativeParser->{BeforeOrAfter} = 'before';
				} else {
					# Parse the final
					$NumericYDay = $proper_yday;
					if($CreativeParser->{Number} eq 'first') {
						$CreativeParser->{BeforeOrAfter} = 'after';
					} elsif($CreativeParser->{Number} eq 'second') {
						$CreativeParser->{BeforeOrAfter} = 'after';
						$CreativeParser->{AddDays} = 7;
					} elsif($CreativeParser->{Number} eq 'third') {
						$CreativeParser->{BeforeOrAfter} = 'after';
						$CreativeParser->{AddDays} = 14;
					} elsif($CreativeParser->{Number} eq 'fourth') {
						$CreativeParser->{BeforeOrAfter} = 'after';
						$CreativeParser->{AddDays} = 21;
					} else {
						_HolidayError($LineNo, $File, "\$CreativeParer->{Number} is \"$CreativeParser->{Number}\"", "This is a bug in the parser. This line will be ignored") and next unless $CreativeParser->{Number} eq 'null';
					}
				}
			} elsif (defined($CreativeParser->{IsMonth}) and defined($CreativeParser->{DateNumeric})) {
				my $PosixYear = $Year - 1900;
				my $PosixTime = POSIX::mktime(0, 0, 0, $CreativeParser->{DateNumeric}, $MonthMapping{$CreativeParser->{IsMonth}}, $PosixYear);
				$NumericYDay = _Get_YDay($PosixTime);
			} elsif (defined($CreativeParser->{IsMonth})) {
				_SynaxError($LineNo, $File, "There is a month defined but no way to find out which day of the month it is referring to", "Ignoring this line.");
				next;
			}
	
	
	
			if(defined($NumericYDay)) {
				# Parse the main NumericYDay
				$FinalYDay = _HCalc_NumericYDay($NumericYDay, $CreativeParser->{AddDays}, $CreativeParser->{SubtDays});
				unless(defined($CreativeParser->{BeforeOrAfter})) {
					_SyntaxError($LineNo, $File, "It was not defined if the day should be before or after", "Defaulting to before. This is likely to cause calculation mistakes.");
					$CreativeParser->{BeforeOrAfter} = 'before';
				}
				if($CreativeParser->{BeforeOrAfter} eq 'before') {
					# Before parsing
					# Okay, we need to find the closest $CreativeParser{MustBeDay} before $CreativeParser{FinalYDay}
					while (1) {
						if(_Holiday_DayName($FinalYDay, $Year) eq $CreativeParser->{MustBeDay}) {
							last;
						}
						$FinalYDay = $FinalYDay - 1;
					}
				} elsif ($CreativeParser->{BeforeOrAfter} eq 'after') {
					# After parsing
					# Okay, we need to find the closest $CreativeParser{MustBeDay} after $CreativeParser{FinalYDay}
					while (1) {
						if(_Holiday_DayName($FinalYDay, $Year) eq $CreativeParser->{MustBeDay}) {
							last;
						}
						$FinalYDay = $FinalYDay + 1;
					}
				} else {
					_HolidayError($LineNo, $File, "BeforeOrAfter was set to an invalid value ($CreativeParser->{BeforeOrAfter})", "This is a bug in the parser. This line will be ignored.");
					return(undef);
				}
			} else {
				_SyntaxError($LineNo, $File, "A day is defined but no other way to find out when the day is could be found", "Ignoring this line");
				next;
			}
		} 
		# Calculate the yday of that day-of-the-month
		elsif(defined($CreativeParser->{IsMonth})) {
			unless(defined($CreativeParser->{DateNumeric})) {
					_SyntaxError($LineNo, $File, "It was set which month the day should be on but no information about the day itself ", "Ignoring this line");
					next;
			}
			my $PosixYear = $Year - 1900;
			my $PosixTime = POSIX::mktime(0, 0, 0, $CreativeParser->{DateNumeric}, $MonthMapping{$CreativeParser->{IsMonth}}, $PosixYear);
			my $proper_yday = _Get_YDay($PosixTime);
			$FinalYDay = _HCalc_NumericYDay($proper_yday, $CreativeParser->{AddDays}, $CreativeParser->{SubtDays});
		}	 
		# NumericYDay-only parsing is the simplest solution. This is pure and simple maths
		elsif(defined($NumericYDay)) {
			# NumericYDay-only parsing is the simplest solution. This is pure and simple maths
			if(defined($CreativeParser->{MustBeDay})) {
				_SyntaxError($LineNo, $File, "It was set exactly which day the holiday should occur on and also that it should occur on $CreativeParser->{MustBeDay}", "Ignoring the day requirement");
	
			}
			$FinalYDay = _HCalc_NumericYDay($NumericYDay, $CreativeParser->{AddDays}, $CreativeParser->{SubtDays});
		}
	
		# Verify the use of the "every" keyword
		if(defined($CreativeParser->{Every}) and not defined($CreativeParser->{Number})) {
			_SyntaxError($LineNo, $File, "Use of the \"every\" keyword without any trailing month", "Ignoring the \"every\" keyword.");
		}
		if(defined($CreativeParser->{Every}) and defined($CreativeParser->{Length})) {
			_SyntaxError($LineNo, $File, "Use of both \"every\" and \"length", "This might give unpredictable results.");
		}
		# Do the final parsing and add it to the hash
		if(defined($FinalYDay) and $FinalYDay =~ /^\d+$/) {
			while(1) {
				if(defined($FinalYDay)) {
					my $PosixYear = $Year - 1900;
					my ($final_sec,$final_min,$final_hour,$final_mday,$final_mon,$final_year,$final_wday,$final_yday,$final_isdst) = localtime(POSIX::mktime(0, 0, 0, $FinalYDay, 0, $PosixYear));
					$final_mon++;
					$FinalParsing->{$final_mon}{$final_mday}{$HolidayName} = $CreativeParser->{HolidayType};
				} 
				if(defined($CreativeParser->{Every}) and defined($CreativeParser->{Number})) {
					delete($CreativeParser->{Every});
					if($CreativeParser->{Number} ne "second") {
						_SyntaxError($LineNo, $File, "Nonsense use of $CreativeParser->{Number} along with \"every\"","Ignoring the \"every\" keyword.");
					} else {
						# Add 14 days 
						$FinalYDay += 14;
					}
				}elsif(defined($CreativeParser->{Length}) and $CreativeParser->{Length} > 0) {
					$CreativeParser->{Length}-- or die("FATAL: attempted to reduce (--) length but it failed! This is a bug.");
					$FinalYDay++;
				} else {
					last;
				}
			}
		} elsif(defined($FinalYDay)) {
			_HolidayError($LineNo, $File, "Invalid FinalYDay ($FinalYDay) after finished parsing", "This is a bug in the parser!");
		} else {
			_HolidayError($LineNo, $File, "No FinalYDay after finished parsing", "This is a bug in the parser!");
		}
	}
	return($FinalParsing);
}

# Purpose: Load and parse the holiday file
# Usage: $self->_load_and_parse(FILE);
sub _load_and_parse {
	my $self = $_[0];
	my $File = $_[1];

	carp("$File does not exist") and return(undef) unless -e $File;
	carp("$File is not readable") and return(undef) unless -r $File;

	my %FinalParsing;
	open(HOLIDAYFILE, "<$File") or croak("Unable to open $File for reading");
	my $LineNo;
	foreach my $Line (<HOLIDAYFILE>) {
		$LineNo++;
		next if $Line =~ /^\s*[:;#]/;# Ignore these lines
		next if $Line =~ /^\s*$/;# Ignore lines with only whitespace
		my $OrigLine = $Line;
		my $HolidayType;	# red or none (see above)
		
		my $LineMode;		# Is either PreDec or PostDec
					#  PreDec means that the holiday "mode" is declared before the name of
					#  the holiday.
					#
					#  PostDec means that the holiday "mode" is declared after the name
					#  of the holiday.
					#
					#  Note that PreDec incorporated the functions of PostDec aswell, but
					#  not the other way around
		if($Line =~ /^\s*\"/) {
			$LineMode = 'PostDec';
		} else {
			$LineMode = 'PreDec';
		}
	
		# Parse PreDec
		if($LineMode eq 'PreDec') {
			while(not $Line =~ /^\"/) {
				my $PreDec = $Line;
				$PreDec =~ s/^\s*(\w+)\s+.*$/$1/;
				chomp($PreDec);
				$Line =~ s/^\s*$PreDec\s+//;
				unless(length($PreDec)) {
						_HolidayError($LineNo, $File, "LineMode=PreDec, but the predec parser recieved \"$PreDec\" as PreDec", "Ignoring this predec");
					} else {
						if($PreDec =~ /^(weekend|red)$/) {
							$HolidayType = 'red';
						} elsif ($PreDec =~ /^(black|small|blue|green|cyan|magenta|yellow)$/) {
							# These are often just "formatting" declerations, and thus ignored by the day planner
							# parser. In these cases PostDec usually declares more valid stuff
							$HolidayType = 'none';
						} else {
							$HolidayType = 'none';
							_SyntaxError($LineNo, $File, "Unrecognized holiday type: \"$PreDec\".", "Defaulting to 'none'");
						}
				}
			}
		}
	
		# Get the holiday name
		my $HolidayName = $Line;
		chomp($HolidayName);
		$HolidayName =~ s/^\s*\"(.*)\".*$/$1/;
		$Line =~ s/^\s*\".*\"//;
		if ($HolidayName =~ /^\"*$/) {
			_SyntaxError($LineNo, $File, "The name of the holiday was not defined", "Ignoring this line.");
			next;
		}
	
		if ($Line =~ /^\s*(weekend|red|black|small|blue|green|cyan|magenta|yellow)/) {
			my $HolidayDec = $Line;
			$HolidayDec =~ s/^\s*(\w+)\s+.*$/$1/;
			chomp($HolidayDec);
			$Line =~ s/^\s*$HolidayDec\s+//;
			
			if($HolidayDec =~ /^(weekend|red)$/) {
				$HolidayType = 'red';
			} elsif ($HolidayDec =~ /^(black|small|blue|green|cyan|magenta|yellow)$/) {
				# These are just "formatting" keywords, so we ignore them here.
				unless(defined($HolidayType) and $HolidayType eq 'red') {
					$HolidayType = 'none';
				}
			} else {
				$HolidayType = 'none';
				_SyntaxError($LineNo, $File, "Unrecognized holiday type: \"$HolidayDec\".", "Defaulting to 'none'");
			}
		}
		unless($Line =~ /^\s*on/) {
			_SyntaxError($LineNo, $File, "Missing \"on\" keyword", "Pretending it's there. This might give weird effects");
		} else {
			$Line =~ s/^\s*on\*//;
		}

		# ==================================================================
		# Parse main keywords
		# ==================================================================
		
		# This is the hardest part of the parser, now we get creative. We read each word
		# and run it through the parser
		my %CreativeParser;
		foreach (split(/\s+/, $Line)) {
			next if /^\s*$/;
			if(/^(last|first|second|third|fourth)$/) {	# This is a number defining when a day should occur, usually used along with
									# MustBeDay (below)
				$CreativeParser{Number} = $_;
				next;
			} elsif (/^(monday|tuesday|wednesday|thursday|friday|saturday|sunday)$/) {	# This defines which day the holiday should occur on
				$CreativeParser{MustBeDay} = $_;
			} elsif (m#^\d+[/\.]\d+\.?$#) {		# This regexp gets numbers in the format XX/YY X/Y, XX.YY and X.Y
								# With an optional trailing .
				s/\.$//;
				my $day = $_;
				my $month = $_;
				if(m#^\d+\.\d+$#) {		# XX.YY and X.Y is in the format day.month
					$day =~ s/(\d+).*/$1/;
					$month =~ s#^\d+\.(\d+)\.?$#$1#;
				} elsif (m#^\d+/\d+$#) {	# XX/YY and X/Y is in the format month/day
					$month =~ s/(\d+).*/$1/;
					$day =~ s#^\d+/(\d+)\.?$#$1#;
				}
				$month--;	# The month in the holiday file is 1-12, we use 0-11
				$CreativeParser{MonthDay} = "$month-$day";
			} elsif (/^(january|february|march|april|may|june|july|august|september|october|november|december)$/) {	# Which month it occurs in
				$CreativeParser{IsMonth} = $_;
			} elsif (/^plus$/) {			# If the next number should be added to a NumericYDay value
				$CreativeParser{NextIs} = 'add';
			} elsif (/^minus$/) {			# If the next number should be subtracted to a NumericYDay value
				$CreativeParser{NextIs} = 'sub';
			} elsif (/^length$/) {			# How long (in days) it lasts. FIXME: is currently ignored
				$CreativeParser{NextIs} = 'length';
			} elsif (/^easter$/) {			# The day of easter
				$CreativeParser{AddEaster} = 1;
			} elsif (/^weekend$/) {			# Malplaced weekend keyword
				$HolidayType = 'red';
			} elsif (/^\d+$/) {			# Any other number, see below for parsing
				_SyntaxError($LineNo, $File, "Unreasonably high number", "Ignoring the number. This might give weird results") and next if $_ > 365;
				# If NextIs is not defined then it's a DateNumeric
				unless(defined($CreativeParser{NextIs}) and $CreativeParser{NextIs}) {
					$CreativeParser{DateNumeric} = $_;
					next;
				}
	
				# Add to
				if($CreativeParser{NextIs} eq 'add') {
					if(defined($CreativeParser{AddDays})) {
						$CreativeParser{AddDays} = $CreativeParser{AddDays} + $_;
					} else {
						$CreativeParser{AddDays} = $_;
					}
				# Subtract from
				} elsif ($CreativeParser{NextIs} eq 'sub') {
					if(defined($CreativeParser{SubtDays})) {
						$CreativeParser{SubtDays} = $CreativeParser{SubtDays} + $_;
					} else {
						$CreativeParser{SubtDays} = $_;
					}
				# How long should it last?
				} elsif ($CreativeParser{NextIs} eq 'length') {
					if(defined($CreativeParser{Length})) {
						_SyntaxError($LineNo, $File, "Multiple length statements", "Ignoring \"$_\"");
					} else {
						$CreativeParser{Length} = $_;
					}
				}
				
			} elsif (/^(before|after)$/) {	# If a day should be before or after a certain day/date
				$CreativeParser{BeforeOrAfter} = $_;
			} elsif (/^every$/) {
				$CreativeParser{Every} = 1;
			} elsif (/^(in|on|days|day)$/) {	# Ignored, just keywords for easier human parsing
				next;
			} else {
				_SyntaxError($LineNo, $File, "Unrecognized keyword \"$_\"", "Ignoring it. This might cause calculation mistakes! Consider using a combination of other keywords or report this as a bug to the author of this parser if you're certain the keyword should be supported");
			}
		}
		
		# TODO: This isn't an error with the OO interface, but rather the desired behaviour


		# ==================================================================
		# Finalize the interpretation and add it to $self
		# ==================================================================

		$CreativeParser{HolidayType} = $HolidayType;
		$CreativeParser{name} = $HolidayName;
		$self->{parsed}{$LineNo} = \%CreativeParser;
	}
}

# Purpose: Create a new object and call _load_and_parse on it
# Usage: my $object = Date::HolidayParser->new(/FILE/);
sub new {
	unless(defined($_[1])) {
		carp("Needs an option: path to the holiday file");
		return(undef);
	}
	unless(-e $_[1]) {
		carp("\"$_[1]\": does not exist");
		return(undef);
	}
	my $self = {};
	bless($self);
	$self->{FILE} = $_[1];
	$self->_load_and_parse($self->{FILE});
	return($self);
}

# Purpose: Get the holiday information for YEAR
# Usage: my $HashRef = $object->get(YEAR);
sub get {
	my $self = $_[0];
	carp("Date::HolidayParser->get needs an parameter: The year to parse") and return(undef) unless(defined($_[1]));
	my $Year = $_[1];
	carp("Date::HolidayParser: The year must be a digit") and return(undef) if $Year =~ /\D/;
	carp("Date::HolidayParser: Can't parse years lower than 1971") and return(undef) if $Year < 1971;
	carp("Date::HolidayParser: Can't parse years higher than 2037") and return(undef) if $Year > 2037;
	return($self->_interperate_year($Year));
}
# End of Date::HolidayParser
1;

=head1 NAME

Date::HolidayParser - Parser for .holiday-files

=head1 VERSION

0.1

=head1 SYNOPSIS

This module parses .holiday files. These are files that define holidays in various parts
of the world in an easy to read and easy to write (but hard to parse due to its very flexible
syntax) format.

This module returns a hash that you can read and use within your program.

	use Date::HolidayParser;

	my $Holidays = Date::HolidayParser->new("$ENV{HOME}/.holiday");
	my $Holidays_2006 = $Holidays->get(2006);
	
	...

=head1 DESCRIPTION

This is a module that parses .holiday-style files. These are files that define
holidays in various parts of the world. The files are easy to write and easy for
humans to read, but can be hard to parse because the format allows many different
ways to write it.

This module parses the files for you and returns a hash reference that you can use
within your perl program in whatever way you wish.

=head1 EXPORT

This module doesn't export anything by default. You're encouraged to use the object
oriented interface. It can however export the Parse and EasterCalc functions upon
request by issuing

	use Date::HolidayParser qw(EasterCalc Parse);
	...

=head1 FUNCTIONS

=head2 $object = Date::HolidayParser->new(FILE);

This is the main function. It creates a new Date::HolidayParser object for FILE and
parses the file.

FILE must be the full path to the holiday file you want to parse.

=head2 $object->get(YEAR);

This gets the holidays for YEAR. It uses the already parsed FILE and calculates the
holidays in YEAR and returns a hashref with the parsed data or undef on failure.

YEAR must be a full year (ie. 2006) not a year relative to 1900 (ie. 106).

See the section HASH SYNTAX below for the syntax of the returned hashref.

=head2 Date::HolidayParser::EasterCalc

This is an addition to the real functions that Date::HolidayParser provides.
It's needed inside of the module but might also be useful for others and
thus made available.

	use Date::HolidayParser;
	my $Easter = Date::HolidayParser::EasterCalc(YEAR);

YEAR must be a full year (ie. 2006) not a year relative to 1900 (ie. 106).

It returns the day of easter of the year supplied.

NOTE: The day returned begins on 0. This means that the days returns
are 0-364 instead of 1-365.

=head2 Date::HolidayParser::Parse

This is the legacy syntax of Date::HolidayParser. You're strongly encouraged to use
the object oriented interface. This function is slower than the OO-interface if you
need to interperate more than one year.

	use Date::HolidayParser;

	my $Holidays = Date::HolidayParser::Parse("/path/to/holiday.file", "YEAR");

YEAR must be a full year (ie. 2006) not a year relative to 1900 (ie. 106).
The path must be the full path to the holiday file you want to parse.

It returns a hashref with the parsed data or undef on failure.
See the section HASH SYNTAX below for the syntax of the returned hashref.

=head1 HASH SYNTAX

The returned hash is in the following format:

	\%HasRef = (
	 'MONTH (1-12)' => {
	   'DAY OF THE MONTH (1-31)' => {
	     'NAME OF THE HOLIDAY' => 'TYPE OF HOLIDAY'
	    }
	   }
	  );

MONTH is a numeric month in the range 1-12.

DAY OF THE MONTH is a numeric day relative to the month in the range
1-31 (max).

NAME OF THE HOLIDAY is the name of the holiday as set by the .holiday-file.

TYPE OF HOLIDAY is the type of holiday it is. It is one of the following:

=over

=item *

"none" means that it is a normal day.

=item *

"red" means that it is a "red" day (ie. public holiday/day off).

=back

=head1 EXAMPLE

Here is an example of the module in use.
The UK holiday file was chosen because it is rather small and simple.

=head2 The holiday file

	:
	: UK holiday file. Copy to ~/.holiday
	:
	: Author: Peter Lord <plord@uel.co.uk>
	:
	"New Years Day" red on 1/1
	"Easter Sunday" red on easter
	"Good Friday" red on easter minus 2
	"Easter Monday" red on easter plus 1
	"May Day" red on first monday in may
	"Spring Bank Holiday" red on last monday in may
	"Summer Bank Holiday" red on last monday in august
	"Christmas Day" red on 12/25
	"Boxing Day" red on 12/26

=head2 The program

	#!/usr/bin/perl
	use warnings;
	use strict;
	use Data::Dumper;
	use Date::HolidayParser;
	
	# Call Date::HolidayParser to parse the file
	my $Holidays = Date::HolidayParser->new();
	my $Holidays_2006 = $Holidays->get(2006);

	# Set a proper Data::Dumper format and dump the data returned by Date::HolidayParser to STDOUT
	$Data::Dumper::Purity = 1; $Data::Dumper::Sortkeys = 1; $Data::Dumper::Indent = 1;
	print Data::Dumper->Dump([$Holidays_2006], ["*Holidays_2006"]);

=head2 The output

	%Holidays_2006 = (
	  '1' => {
	    '1' => {
	      'New Years Day' => 'red'
	    }
	  },
	  '12' => {
	    '25' => {
	      'Christmas Day' => 'red'
	    },
	    '26' => {
	      'Boxing Day' => 'red'
	    }
	  },
	  '4' => {
	    '14' => {
	      'Good Friday' => 'red'
	    },
	    '16' => {
	      'Easter Sunday' => 'red'
	    },
	    '17' => {
	      'Easter Monday' => 'red'
	    }
	  },
	  '5' => {
	    '1' => {
	      'May Day' => 'red'
	    },
	    '29' => {
	      'Spring Bank Holiday' => 'red'
	    }
	  },
	  '8' => {
	    '28' => {
	      'Summer Bank Holiday' => 'red'
	    }
	  }
	);


=head2 Explenation

This is a very simple example. It first creates a $Holidays Date::HolidayParser object,
then tells it to get the holidays for the year 2006 ($Holidays->get(2006);) and saves
the information to $Holidays_2006. Then it tells Data::Dumper to dump
a visual (perl-usable) representation of the hash to stdout.

=head1 SETTINGS

=head2 $Date::HolidayParser::BeSilent

If this is set to any true value then the holiday parser will not output any
errors (syntax or internal) unless they are fatal (causing the module to
die()) or invalid usage of one or more of the functions.

=head1 AUTHOR

Eskild Hustvedt - C<< <zerodogg@cpan.org> >>

=head1 BUGS

Please report any bugs or feature requests to
C<bug-date-holidayparser@rt.cpan.org>, or through the web interface at
L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=Date-HolidayParser>.
I will be notified, and then you'll automatically be notified of progress on
your bug as I make changes.

=head1 COPYRIGHT & LICENSE

Copyright (C) 2006 Eskild Hustvedt, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. There is NO warranty;
not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
