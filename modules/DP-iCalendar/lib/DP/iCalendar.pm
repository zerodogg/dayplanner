#!/usr/bin/perl
# DP::iCalendar
# $Id$
# An iCalendar parser/loader.
# Copyright (C) Eskild Hustvedt 2007
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package DP::iCalendar;

use strict;
use warnings;
use Carp;
use Exporter qw(import);
use POSIX;
use Data::Dumper;

# Exported functions
our @EXPORT_OK = qw(iCal_ParseDateTime iCal_GenDateTime);

# Version number
my $VERSION;
$VERSION = 0.1;

# - Public methods

# Purpose: Create a new object, call _LoadFile and  _parse_file on it
# Usage: my $object = DP::iCalendar->new(/FILE/);
sub new {
	my $File = $_[1];
	my $self;
	if(ref($File)) {	# If we got a reference
		if(ref($File) eq "ARRAY") {
			# Do stuff
		} else {
			carp("Supplied a reference, but the reference is not a ARRAYREF.");
		}
		$self = _NewObj();
	} else {		# If we don't have a reference, treat it as a scalar
				# filepath argument
		unless(defined($File)) {
			carp("Needs an option: path to the iCalendar file");
			return(undef);
		}
		unless(-e $File) {
			carp("\"$File\": does not exist");
			return(undef);
		}
		$self = _NewObj($File);
	}
	$self->_LoadFile($File);
	return($self);
}

# Purpose: Create a new object using file
# Usage: my $object = DP::iCalendar->newfile(/FILE/);
sub newfile {
	my $File = $_[1];
	if(not defined($File)) {
		carp("Needs an option: path to the iCalendar file");
		return(undef);
	}
	if(ref($File)) {
		carp("Doesn't take a reference");
		return(undef);
	}
	return(_NewObj($File));
}

# Purpose: Get information for the supplied month (list of days there are events)
# Usage: my $TimeRef = $object->get_monthinfo(YEAR,MONTH,DAY);
sub get_monthinfo {
	my($self, $Year, $Month) = @_;	# TODO: verify that they are set
	if(not defined($self->{OrderedCalendar}{$Year})) {
		# Generate the calendar for this year
		$self->_GenerateCalendar($Year);
	}
	my @DAYS;
	if(defined($self->{OrderedCalendar}{$Year}{$Month})) {
		foreach(keys(%{$self->{OrderedCalendar}{$Year}{$Month}})) {
				push(@DAYS, $_);
		}
		return(\@DAYS) if @DAYS;
	}
	return(undef);
}

# Purpose: Get information for the supplied date (list of times in the day there are events)
# Usage: my $TimeRef = $object->get_dateinfo(YEAR,MONTH,DAY);
sub get_dateinfo {
	my($self, $Year, $Month, $Day) = @_;	# TODO: verify that they are set
	if(not defined($self->{OrderedCalendar}{$Year})) {
		# Generate the calendar for this year
		$self->_GenerateCalendar($Year);
	}
	my @TIME;
	if(defined($self->{OrderedCalendar}{$Year}{$Month}) and defined($self->{OrderedCalendar}{$Year}{$Month}{$Day})) {
		foreach(keys(%{$self->{OrderedCalendar}{$Year}{$Month}{$Day}})) {
				push(@TIME, $_);
		}
		return(\@TIME) if @TIME;
	}
	return(undef);
}

# Purpose: Get the list of UIDs for the supplied time
# Usage: my $UIDRef = $object->get_timeinfo(YEAR,MONTH,DAY,TIME);
sub get_timeinfo {
	my($self, $Year, $Month, $Day, $Time) = @_;	# TODO: verify that they are set
	if(not defined($self->{OrderedCalendar}{$Year})) {
		# Generate the calendar for this year
		$self->_GenerateCalendar($Year);
	}
	my @UIDs;
	if(defined($self->{OrderedCalendar}{$Year}{$Month}) and defined($self->{OrderedCalendar}{$Year}{$Month}{$Day}) and defined($self->{OrderedCalendar}{$Year}{$Month}{$Day}{$Time})) {
		foreach(@{$self->{OrderedCalendar}{$Year}{$Month}{$Day}{$Time}}) {
				push(@UIDs, $_);
		}
		return(\@UIDs) if @UIDs;
	}
	return(undef);
}

# Purpose: Get information for a supplied UID
# Usage: my $Info = $object->get_info(UID);
sub get_info {
	my($self,$UID) = @_;
	if(defined($self->{RawCalendar}{$UID})) {
		return($self->{RawCalendar}{$UID});
	}
	carp("get_info got invalid UID");
	return(undef);
}

# Purpose: Write the data to a file.
# Usage: $object->write(FILE?);
sub write {
	my ($self, $file) = @_;
	if(not defined($file)) {
		if($self->{FILETYPE} eq "ref") {
			carp("write called on object created from array ref");
			return(undef);
		}
		$file = $self->{FILE};
	}
	my $iCalendar = $self->get_rawdata($self->{FILE},0,0);
	if($iCalendar) {
		open(my $TARGET, ">", $file) or do {
			_OutWarn("Unable to open $file for writing: $!");
			return(undef);
		};
		print $TARGET $iCalendar;
		close($TARGET);
		return(1);
	} else {
		_OutWarn("Unknown error ocurred, get_rawdata returned false. Attempt to write data from uninitialized object?");
		return(undef);
	}
}

# Purpose: Get raw iCalendar data
# Usage: my $Data = $object->get_rawdata();
sub get_rawdata {
	my ($self) = @_;
	my $iCalendar;
	# Print initial info. The prodid could probably be changed to something mroe suitable.
	$iCalendar .= "BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:$self->{PRODID}\r\nCALSCALE:GREGORIAN\r\n";

	foreach my $UID (keys(%{$self->{RawCalendar}})) {
		$iCalendar .= "BEGIN:VEVENT\r\n";
		$iCalendar .= "UID:$UID\r\n";
		foreach my $setting (keys(%{$self->{RawCalendar}{$UID}})) {
			$iCalendar .= "$setting:" . _GetSafe(${$self->{RawCalendar}}{$UID}{$setting}) . "\r\n";
		}
		$iCalendar .= "END:VEVENT\r\n";
	}
	$iCalendar .= "END:VCALENDAR\r\n";
	return($iCalendar);
}

# Purpose: Delete an iCalendar entry
# Usage: $object->delete(UID);
sub delete {
	my ($self, $UID) = @_;	# TODO verify UID
	if(defined($self->{RawCalendar}{$UID})) {
		delete($self->{RawCalendar}{$UID});
		# FIXME: There are much more efficient ways to do this.
		$self->{OrderedCalendar} = {};
		return(1);
	} else {
		carp("delete called without a valid UID");
		return(undef);
	}
}

# Purpose: Add an iCalendar entry
# Usage: $object->add(%EntryHash);
sub add {
	my ($self, %Hash) = @_;
	unless(defined($Hash{DTSTART})) {
		carp("Refusing to add a iCalendar entry without a DTSTART.");
		return(undef);
	}
	my $UID = _UID($Hash{DTSTART});
	# FIXME: There are much more efficient ways to do this.
	$self->{OrderedCalendar} = {};
	$self->_ChangeEntry($UID,%Hash);
	return(1);
}

# Purpose: Change an iCalendar entry
# Usage: $object->change(%EntryHash);
sub change {
	my ($self, $UID, %Hash) = @_;
	unless(defined($Hash{DTSTART})) {
		carp("Refusing to change a iCalendar entry without a DTSTART.");
		return(undef);
	}
	$self->_ChangeEntry($UID,%Hash);
	return(1);
}

# Purpose: Check if an UID exists
# Usage: $object->exists($UID);
sub exists {
	my($self,$UID) = @_;
	if(defined($self->{RawCalendar}{$UID})) {
		return(1);
	}
	delete($self->{RawCalendar}{$UID});
	return(0);
}

# Purpose: Add another file
# Usage: $object->addfile(FILE);
sub addfile {
	my ($self,$File) = @_;
	if(ref($File)) {	# If we got a reference
		if(not ref($File) eq "ARRAY") {
			carp("Supplied a reference, but the reference is not a ARRAYREF.");
		}
	} else {		# If we don't have a reference, treat it as a scalar
				# filepath argument
		unless(defined($File)) {
			carp("Needs an option: path to the iCalendar file");
			return(undef);
		}
		unless(-e $File) {
			carp("\"$File\": does not exist");
			return(undef);
		}
	}
	return($self->_LoadFile($File));
}

# Purpose: Remove all loaded data
# Usage: $object->clean()
sub clean {
	my $self = shift;
	$self->{RawCalendar} = {};
	$self->{OrderedCalendar} = {};
	return(1);
}

# Purpose: Enable a feature
# Usage: $object->enable(FEATURE);
sub enable {
	my($self, $feature) = @_;
	foreach(qw(SMART_MERGE)) {
		next unless($feature eq $_);
		$self->{FEATURE}{$_} = 1;
		return(1);
	}
	carp("Attempted to enable unknown feature: $feature");
	return(undef);
}

# Purpose: Disable a feature
# Usage: $object->disable(FEATURE);
sub disable {
	my($self, $feature) = @_;
	foreach(qw(SMART_MERGE)) {
		next unless($feature eq $_);
		$self->{FEATURE}{$_} = 0;
		return(1);
	}
	carp("Attempted to disable unknown feature: $feature");
	return(undef);
}

# Purpose: Reload the data
# Usage: $object->reload();
sub reload {
	my $self = shift;
	if($self->{FILETYPE} eq "ref") {
		carp("reload called on object created from array ref");
		return(undef);
	}
	$self->clean();
	return($self->addfile($self->{FILE}));
}

# Purpose: Set the prodid
# Usage: $object->set_prodid(PRODID);
sub set_prodid {
	my($self, $ProdId) = @_;
	if(not defined($ProdId) or not length($ProdId)) {
		croak("Emtpy/undef ProdId used in ->set_prodid");
		return(undef);
	}
	# Warn about excessively long prodids
	if(length($ProdId) > 100) {
		croak("ProdId is over 100 characters long (in ->set_prodid). Consider slimming it down.");
	}
	# Verify that it is nicely formatted
	unless($ProdId =~ m#^-//.+//NONSGML\s.+//EN$#) {
		croak("ProdId is not nicely formatted, see the DP::iCalendar documentation.");
	}
	# Set the prodid
	$self->{PRODID} = $ProdId;
	return(1);
}

# - Public functions

# Purpose: Generate an iCalendar date-time from multiple values
# Usage: my $iCalDateTime = iCal_GenDateTime(YEAR, MONTH, DAY, TIME);
sub iCal_GenDateTime {
	my ($Year, $Month, $Day, $Time) = @_;
	# Fix the month and day
	my $iCalMonth = _AppendZero($Month);
	my $iCalDay = _AppendZero($Day);
	if($Time) {
		# Get the time
		my $Hour = $Time;
		my $Minute = $Time;
		$Hour =~ s/^(\d+):\d+$/$1/;
		$Minute =~ s/^\d+:(\d+)$/$1/;
		return("$Year$iCalMonth${iCalDay}T$Hour${Minute}00");
	} else {
		# FIXME: This might not be fully valid. Needs to be checked with the spec.
		# Might need to be VALUE=DATE:$Year$iCalMonth$iCalDay
		return("$Year$iCalMonth$iCalDay");
	}
}

# Purpose: Parse an iCalendar date-time
# Usage: my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime(DATE-TIME_ENTRY);
sub iCal_ParseDateTime {
	my $Value = shift;

	# Handling of VALUE=DATE:YYYYMMDD
	if($Value =~ /^VALUE/) {
		# Alternate value definition. Processing here can
		# probably be improved.
		if(not $Value =~ s/^VALUE=DATE://) {
			_ErrOut("Unhandled value in iCal_ParseDateTime(): $Value. This is a bug!");
			_WarnOut("Returning 2000,01,01,00:00");
			# We don't return undef in order to not break programs that expect
			# this function to return something usable.
			return(2000,"01","01","00:00");
		}
	}

	my $Year = $Value;
	my $Month = $Value;
	my $Day = $Value;
	my $Hour = $Value;
	my $Minutes = $Value;
	my $Time;

	$Year =~ s/^(\d\d\d\d).*$/$1/;
	$Month =~ s/^\d\d\d\d(\d\d).*$/$1/;
	$Day =~ s/^\d\d\d\d\d\d(\d\d).*$/$1/;

	# Test if the time is set, if it is then process it.
	if($Hour =~ s/^.+T//) {
		$Hour =~ s/^(\d\d).*$/$1/;
		$Minutes =~ s/^.+T//;
		$Minutes =~ s/^\d\d(\d\d).*$/$1/;
		$Time = _AppendZero($Hour) . ":" . _AppendZero($Minutes);
	}
	return($Year,$Month,$Day,$Time);
}

# - Internal functions

# Purpose: Create a new object.
# Usage: my $object = _NewObj(FILE?);
#  FILE is the path to a file or undef. undef if working in ref mode.
sub _NewObj {
	my $File = shift;
	my $self = {};
	bless($self);
	$self->{RawCalendar} = {};
	$self->{OrderedCalendar} = {};
	# FIXME: $VERSION doesn't output nicely
	$self->{PRODID} = "-//EskildHustvedt//NONSGML DP::iCalendar $VERSION//EN";
	if($File) {
		$self->{FILETYPE} = "file";
		$self->{FILE} = $File;
	} else {
		$self->{FILETYPE} = "ref";
	}
	return($self);
}

# Purpose: Make changes to the raw calendar (append or change)
# Usage: $self->_ChangeEntry(UID,%Hash);
sub _ChangeEntry {
	my($self,$UID,%Hash) = @_;
	foreach my $key (keys(%Hash)) {
		$self->{RawCalendar}{$UID}{$key} = _GetSafe($Hash{$key});
	}
	return(1);
}

# Purpose: Output warning
# Usage: _WarnOut(MESSAGE)
sub _WarnOut {
	warn("DP::iCalendar: WARNING: $_[0]\n");
}

# Purpose: Output error
# Usage: _ErrOut(MESSAGE)
sub _ErrOut {
	warn("DP::iCalendar: ERROR: $_[0]\n");
}

# Purpose: Imports data in the iCalendar format into day planner
# Usage: _LoadFile(FILE OR ARRAYREF);
sub _LoadFile {
	# TODO: Create a iCalendar error logfile with dumps of data and errors.
	my $self = shift;
	my $Data = _ParseData($_[0]);
	return(undef) unless(defined($Data));
	foreach(0..scalar(@{$Data})) {
		my $Current = $Data->[$_];
		my ($Summary, $Fulltext, $UID);
		# First make sure we've got everything we need. Skip entries
		# missing some things.
		next unless(defined($Current->{"X-PARSER_ENTRYTYPE"}));
		next unless($Current->{"X-PARSER_ENTRYTYPE"} eq 'VEVENT');
		unless(defined($Current->{'DTSTART'})) {
			# Detect an alternate dstart
			foreach(keys(%{$Current})) {
				if(/^DTSTART/) {
					$Current->{'DTSTART'} = $Current->{$_};
					last;
				}
			}
			unless(defined($Current->{'DTSTART'})) {
				main::DPIntWarn("DTSTART missing from iCalendar file. Dumping data:");
				print Dumper(\$Current);
				next
			}
		}
		# FIXME: Don't blindly assume $Time is set.
		# Assign an UID if it is missing
		unless($Current->{UID}) {
			my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime($Current->{'DTSTART'});
			$Year =~ s/^0*//;
			$Month =~ s/^0*//;
			$Day =~ s/^0*//;
			$UID = _UID($Year.$Month.$Day);
		} else {
			$UID = $Current->{UID};
		}
		delete($Current->{UID});
		if(defined($self->{RawCalendar}{$UID})) {
			# If SMART_MERGE is enabled run a set of tests
			if($self->{FEATURE}{SMART_MERGE}) {
				my $Reassign = 0;
				# Verify that DTSTART and DTEND are set and identical.
				# If not then assign a new UID.
				foreach my $check(qw(DTSTART DTEND)) {
					if($self->{RawCalendar}{$UID}{$check} or $Current->{$check}) {
						if($self->{RawCalendar}{$UID}{$check} and $Current->{$check}) {
							if(not $self->{RawCalendar}{$UID}{$check} eq $Current->{$check}) {
								$Reassign = 1;
								last;
							}
						} else {
							last;
							$Reassign = 1;
						}
					}
				}
				$UID = _UID($Current->{DTSTART}) if($Reassign);
			} else {
				# Just overwrite it with this one
				$self->{RawCalendar}{$UID} = {};
			}
		}
		# Unsafe various values if needed
		foreach(qw(X-DP-BIRTHDAYNAME SUMMARY DESCRIPTION)) {
			if(defined($Current->{$_})) {
				$Current->{$_} = _UnSafe($Current->{$_});
			}
		}
		unless(defined($Current->{SUMMARY})) {
			_WarnOut("Dangerous: SUMMARY missing from iCalendar import. Dumping data:");
			print Dumper(\$Current);
		}
		foreach(keys(%{$Current})) {
				if(not /^X-PARSER/) {
					$self->{RawCalendar}{$UID}{$_} = _UnSafe($Current->{$_});
			}
		}
	}
	$Data = undef;
	return(1);
}

# Purpose: Loads an iCalendar file and returns a simple data structure. Returns
# 	undef on failure.
# Usage: my $iCalendar = _ParseData(FILE);
sub _ParseData {
	my $File = $_[0];
	my @iCalendarStructures;
	my $LastStructure;
	my $LastName;
	my $CurrentStructure;
	my @FileContents;
	my $FileBegun;
	my $Type;
	# If $File is a ref...
	if(ref($File)) {
		$Type = "ref";
		if(ref($File) eq "ARRAY") {
			# All is well.
			@FileContents = @{$File};
		} else {
			# Nothing is well, bug!
			_WarnOut("iCal_ParseData: supplied reference is not an ARRAYREF!");
			# Return an empty anonymous array
			return([]);
		}
	}
	# It isn't
	else {
		$Type = "file ($File)";
		open(my $ICALENDAR, "<", $File) or do {
			_WarnOut("iCal_ParseData: Unable to open $File for reading: $!");
			# Return an empty anonymous array
			return([]);
		};
		@FileContents = <$ICALENDAR>;
		close($ICALENDAR);
	}

	foreach(@FileContents) {
		s/\r//g;
		chomp;
		unless($FileBegun) {
			if (/^BEGIN:VCALENDAR/) {
				$FileBegun = 1;
			} else {
				next;
			}
		}
		if (s/^\s//) {
			$iCalendarStructures[$CurrentStructure]{$LastName} .= $_;
		} elsif(/^END/) {
			next;
		} else {
			my $Name = $_;
			my $Value = $_;
			$Name =~ s/^(\S+):(.*)$/$1/;
			$Value =~ s/^(\S+):(.*)$/$2/;
			if($Name =~ /^BEGIN/) {
				$CurrentStructure++;
				$Name = "X-PARSER_ENTRYTYPE";
			}
			$LastName = $Name;
			$iCalendarStructures[$CurrentStructure]{$Name} = _UnSafe($Value);
		}
	}
	unless($FileBegun) {
		_WarnOut("FATAL: The supplied iCalendar data never had BEGIN:VCALENDAR ($Type). Failed to load the data.");
		# TODO: DROP
		print Dumper(\@FileContents);
	}
	return(\@iCalendarStructures);
}

# Purpose: Escape certain characters that are special in iCalendar
# Usage: my $SafeData = iCal_GetSafe($Data);
sub _GetSafe {
	my $Data = $_[0];
	$Data =~ s/\\/\\\\/g;
	$Data =~ s/,/\,/g;
	$Data =~ s/;/\;/g;
	$Data =~ s/\n/\\n/g;
	return($Data);
}

# Purpose: Removes escaping of iCalendar entries
# Usage: my $UnsafeEntry = iCal_UnSafe($DATA);
sub _UnSafe {
	my $Data = $_[0];
	$Data =~ s/\\\\/\\/g;
	$Data =~ s/\\,/,/g;
	$Data =~ s/\\;/;/g;
	$Data =~ s/\\n/\n/g;
	return($Data);
}

# Purpose: Get a unique ID for an event
# Usage: $iCalendar .= iCal_UID($Year?$Month$Day$Hour?$Minute, $Summary);
# TODO: Make sure it is unique!
sub _UID {
	my $NonRandom = shift;
	chomp($NonRandom);
	if($NonRandom) {
		$NonRandom =~ s/\D//g;
	} else {
		$NonRandom = int(rand(10000));
	}
	return("dayplanner-" . time() . $NonRandom . int(rand(10000)));
}

# Purpose: Append a "0" to a number if it is only one digit.
# Usage: my $NewNumber = AppendZero(NUMBER);
sub _AppendZero {
	if ($_[0] =~ /^\d$/) {
		return("0$_[0]");
	}
	return($_[0]);
}

# Purpose: Generate the formatted calendar from the raw calendar
# Usage: _GenerateCalendar(YEAR);
sub _GenerateCalendar {
	my $self = shift;
	my $EventYear = $_[0];
	return if defined($self->{OrderedCalendar}{$EventYear});
	$self->{OrderedCalendar}{$EventYear} = {};
	foreach my $UID (keys(%{$self->{RawCalendar}})) {
		my $Current = $self->{RawCalendar}{$UID};
		my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime($Current->{'DTSTART'});
		$Year =~ s/^0*//;
		$Month =~ s/^0*//;
		$Day =~ s/^0*//;
		# Recurring?
		if($Current->{RRULE}) {
			if($Current->{RRULE} =~ /YEARLY/) {
				push(@{$self->{OrderedCalendar}{$EventYear}{$Month}{$Day}{DAY}},$UID);
				next unless defined($Current->{DESCRIPTION});
			} else {
				_WarnOut("Unhandled RRULE: $Current->{RRULE}");
				next unless defined($Current->{DESCRIPTION});
			}
		} else {
			# Not recurring
			if(not $Time) {
				$Time = 'DAY';
			}
			push(@{$self->{OrderedCalendar}{$Year}{$Month}{$Day}{$Time}}, $UID);
		}
	}
}

# End of DP::iCalendar
1;
__END__

=pod

=head1 NAME

DP::iCalendar - Parser for iCalendar files

=head1 VERSION

0.1

=head1 SYNOPSIS

This module parses iCalendar files.

	use DP::iCalendar;

	my $iCalendar = DP::iCalendar->new("$ENV{HOME}/.dayplanner/calendar.ics");
	...

=head1 DESCRIPTION

DP::iCalendar is a module that parses files in the iCalendar format, version 2.0.
It loads the files into internal data structures and is able to return simple
date/time hashes and arrays to the caller, which can then do whatever is needed
with the data. It seemlessly handles the addition and removal of quoting as required
by the iCalendar standard.

The main functions are accessed through the object-oriented interface.
It can also export two helper functions which can be helpful in making use
of the returned iCalendar data.

=head1 EXPORT

This module doesn't export anything by default.
You can tell it to export the iCal_ParseDateTime and iCal_GenDateTime functions.

=head1 METHODS

=head2 $object = DP::iCalendar->new(FILE OR REF);

This is the main function. It creates a new DP::iCalendar object.
The function requires exactly one parameter, which is either the
path to a file containing iCalendar data, or an arrayref containing
iCalendar data (one line per entry in the array). If it is the path
to a file it must be a fully qualified path.

=head2 $object = DP::iCalendar->newfile(FILE);

This is an alternative for ->new();. It creates a new DP::iCalendar object.
It takes exactly one parameter, which is the path to the file you wish
to write the iCalendar data to. The difference from ->new is that it does
not load nor parse FILE. So FILE may or may not exist. If it exists and you
call ->write then it will overwrite it.

=head2 $DayArray = $object->get_monthinfo(YEAR,MONTH);

Returns a reference to an array containing a list of days in this
month that contains events, or undef if there are no events.

=head2 $TimeArray = $object->get_dateinfo(YEAR,MONTH,DAY);

Returns a reference to an array containing a list of times on this day
that contains events or undef if there are no events.
Note that the time can also be "DAY". If a time is DAY then it means
that the event doesn't have a time set but lasts that entire day.

=head2 $UID_List = $object->get_timeinfo(YEAR,MONTH,DAY,TIME);

Returns a reference to an array containing a list of iCalendar UIDs
that appear at this time on said date. You can use the UIDs to get event
information from the $object->get_info() function.

=head2 $UID_Info = $object->get_info(UID);

Returns an iCalendar hash reference for the supplied UID or undef if
the UID doesn't exist. See the section ICALENDAR HASH for information
on the syntax of the returned reference.

=head2 $object->write(FILE?);

Writes the iCalendar data. If no argument is supplied it writes to the file
you supplied to ->new() (doesn't work if you supplied an array reference).

=head2 $RawData = $object->get_rawdata();

Returns the raw iCalendar data as a scalar (the full contents of a fully
qualified iCalendar file).

=head2 $object->delete(UID);

Delete the UID supplied from the calendar. Returns true on success.

=head2 $object->add(ICALENDAR HASH);

Add the contents of the ICALENDAR HASH to the calendar. See the section
ICALENDAR HASH for information on the syntax. An UID is automagically
assigned.

=head2 $object->change(UID, ICALENDAR HASH);

The same as ->add, except this takes an additional UID argument
and makes changes to an existing entry instead of adding a new one.

=head2 $object->exists(UID);

Returns 1 if the supplied UID exists. 0 if it doesn't.

=head2 $object->addfile(FILE);

Just like ->new except it adds the data to the current object
instead of creating a new one. This does NOT change the file used
for functions such as ->write();.

=head2 $object->clean();

Removes loaded data from the object, while still retaining a working
object and working metadata (the metadata being information such as
the filename used in ->write()). Use $object->addfile() to add data
to it again.

=head2 $object->reload();

The same as $object->clean(); $object->addfile(FILE); where FILE is
the filename you called ->new with. Only works when ->new was called
with a filename, not a reference. Same return values as ->addfile();

=head2 $object->enable(FEATURE); $object->disable(FEATURE);

Enables or disables a specific feature. Read the section OPTIONAL
FEATURES for more information on the features available.

=head2 $object->set_prodid(PRODID);

Sets the PRODID: used in the iCalendar file (a DP::iCalendar
PRODID is used by default). It should be formatted like this:
-//Perlfoo Software//NONSGML Foo Calendar 1.0//EN

It is used for identifying the program that created the
iCalendar file. See the iCalendar RFC for more information.

=head1 FUNCTIONS

=head2 my($Year,$Month,$Day,$Time) = iCal_ParseDateTime(DATE TIME);

Parses the DATETIME value supplied. Can be used for parsing entries
such as DTSTART.

=head2 my $DATETIME = iCal_GenDateTime(Year,Month,Day,Time);

Generates an iCalendar DATETIME value from the date supplied.
Can be used for creating entries such as DTSTART.

=head1 OPTIONAL FEATURES

All of these features are DISABLED by default. You use the
->enable and ->disable methods to enable/disable them.

=head2 SMART_MERGE

When this feature is enabled, already existing UIDs will not
be replaced when adding files containing the same UIDs.
It is first checked if the DTSTART and DTEND are identical,
if they are then it will be replaced, if not the UID will be
reassigned and the existing one not replaced.

=head1 ICALENDAR HASH

The hash referred to as the ICALENDAR HASH in the above documentation
is structured like this:

	%Hash = (
		ICAL_ENTRY => "ENTRY_VALUE",
		ANOTHER_ENTRY => "ANOTHER_VALUE",
	);

An example might look like this:

	%Hash = (
		DTSTART => "20060301T130000",
		DTEND => "20060301T130059",
		SUMMARY => "Call Lisbeth",
	);

That's a simple event on the 1st of March 2006 at 13:00 reminding
you to call Lisbeth.

=head1 EXAMPLE

See DP::iCalendar::Example

=head1 AUTHOR

Eskild Hustvedt - C<< <zerodogg@cpan.org> >>

=head1 BUGS AND LIMITATIONS

The iCalendar support of this module is a little bit limited. It
has the following limitations:

=over

=item

It does not support recurring appointments, unless they recur once
each year.

=item 

It does not support VTODO.

=item

It does not support VJOURNAL.

=item

It does not support VFREEBUSY.

=item

It ignores VTIMEZONE.

=back

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2007 Eskild Hustvedt, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. There is NO warranty;
not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
