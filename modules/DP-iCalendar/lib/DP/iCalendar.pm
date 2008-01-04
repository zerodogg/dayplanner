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
use Sys::Hostname;
use constant { true => 1, false => 0 };

# Exported functions
our @EXPORT_OK = qw(iCal_ParseDateTime iCal_GenDateTime iCal_ConvertFromUnixTime iCal_ConvertToUnixTime);

# Version number
our $VERSION;
$VERSION = 0.3.1;

# - Public methods

# Purpose: Create a new object, call _LoadFile and  _parse_file on it
# Usage: my $object = DP::iCalendar->new(/FILE/);
sub new {
	my $File = $_[1];
	my $self;
	if(ref($File)) {	# If we got a reference
		if(ref($File) eq 'ARRAY') {
			# Do stuff
		} else {
			carp('Supplied a reference, but the reference is not a ARRAYREF.');
		}
		$self = _NewObj();
	} else {		# If we don't have a reference, treat it as a scalar
				# filepath argument
		unless(defined($File)) {
			carp('Needs an option: path to the iCalendar file');
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
		carp('Needs an option: path to the iCalendar file');
		return(undef);
	}
	if(ref($File)) {
		carp('Doesn\'t take a reference');
		return(undef);
	}
	return(_NewObj($File));
}

# Purpose: Get information for the supplied month (list of days there are events)
# Usage: my $TimeRef = $object->get_monthinfo(YEAR,MONTH,DAY);
sub get_monthinfo {
	my($self, $Year, $Month) = @_;	# TODO: verify that they are set
	$self->_GenerateCalendar($Year);
	my @DAYS;
	if(defined($self->{OrderedCalendar}{$Year}{$Month})) {
		foreach(keys(%{$self->{OrderedCalendar}{$Year}{$Month}})) {
				push(@DAYS, $_);
		}
	}
	return(\@DAYS);
}

# Purpose: Get information for the supplied date (list of times in the day there are events)
# Usage: my $TimeRef = $object->get_dateinfo(YEAR,MONTH,DAY);
sub get_dateinfo {
	my($self, $Year, $Month, $Day) = @_;	# TODO: verify that they are set
	
	$self->_GenerateCalendar($Year);
	
	my @TIME;
	if(defined($self->{OrderedCalendar}{$Year}{$Month}) and defined($self->{OrderedCalendar}{$Year}{$Month}{$Day})) {
		foreach(keys(%{$self->{OrderedCalendar}{$Year}{$Month}{$Day}})) {
				push(@TIME, $_);
		}
	}
	return(\@TIME);
}

# Purpose: Get the list of UIDs for the supplied time
# Usage: my $UIDRef = $object->get_timeinfo(YEAR,MONTH,DAY,TIME);
sub get_timeinfo {
	my($self, $Year, $Month, $Day, $Time) = @_;	# TODO: verify that they are set
	$self->_GenerateCalendar($Year);
	my @UIDs;
	if(defined($self->{OrderedCalendar}{$Year}{$Month}) and defined($self->{OrderedCalendar}{$Year}{$Month}{$Day}) and defined($self->{OrderedCalendar}{$Year}{$Month}{$Day}{$Time})) {
		foreach(@{$self->{OrderedCalendar}{$Year}{$Month}{$Day}{$Time}}) {
				push(@UIDs, $_);
		}
	}
	return(\@UIDs);
}

# Purpose: Get a list of years which have events (those with *only* recurring not counted)
# Usage: my $ArrayRef = $object->get_years();
sub get_years {
	my $self = shift;
	my @Years = sort keys(%{$self->{OrderedCalendar}});
	# Yes this will call _GenerateCalendar when it is not needed (that is,
	# when there are NO events) - but still, that will be very rare.
	if(not @Years) {
		my ($currsec,$currmin,$currhour,$currmday,$currmonth,$curryear,$currwday,$curryday,$currisdst) = localtime(time);
		$curryear += 1900;
		# Generate the calendar for the current year so that we return something useable.
		$self->_GenerateCalendar($curryear);
		@Years = sort keys(%{$self->{OrderedCalendar}});
	}
	return(\@Years);
}

# Purpose: Get a list of months which have events (those with *only* recurring not counted)
# Usage: my $ArrayRef = $object->get_months();
sub get_months {
	my ($self, $Year) = @_;
	$self->_GenerateCalendar($Year);
	my @Months = sort keys(%{$self->{OrderedCalendar}{$Year}});
	return(\@Months);
}

# Purpose: Get information for a supplied UID
# Usage: my $Info = $object->get_info(UID);
sub get_info {
	my($self,$UID) = @_;
	if(defined($self->{RawCalendar}{$UID})) {
		return($self->{RawCalendar}{$UID});
	}
	carp('get_info got invalid UID');
	return(undef);
}

# Purpose: Get a parsed RRULE for the supplied UID
# Usage: my $Info = $object->get_RRULE(UID);
sub get_RRULE {
	my ($self, $UID) = @_;
	if(defined($self->{RawCalendar}{$UID})) {
		if(defined($self->{RawCalendar}{$UID}{RRULE})) {
			return(_RRULE_Parser($self->{RawCalendar}{$UID}{RRULE}));
		} else {
			return(undef);
		}
	} else {
		carp('get_RRULE got invalid UID');
		return(undef);
	}
}

# Purpose: Find out if an UID exists at a given date
# Usage: true/false = $object->UID_exists_at(UID, YEAR,MONTH,DAY,TIME);
#   Time is optional.
sub UID_exists_at
{
	my $this = shift;
	my $CheckUID = shift;
	my $year = shift;
	my $month = shift;
	my $day = shift;
	my $time = shift;

	my $TimeRef;

	if($time)
	{
		$TimeRef = [$time];
	}
	else
	{
		$TimeRef = $this->get_dateinfo($year,$month,$day);
	}
	foreach my $time (@{$TimeRef})
	{
		my $UIDRef = $this->get_timeinfo($year,$month,$day,$time);
		foreach my $UID (@{$UIDRef})
		{
			if($UID eq $CheckUID)
			{
				return(true);
			}
		}
	}
	return(false);
}

# Purpose: Get a list of dates which are excepted from recurrance for the supplied UID
# Usage: my $List = $object->get_exceptions(UID);
sub get_exceptions {
	my ($self, $UID) = @_;
	if(defined($self->{RawCalendar}{$UID})) {
		if(defined($self->{RawCalendar}{$UID}{EXDATE})) {
			return($self->{RawCalendar}{$UID}{EXDATE});
		} else {
			return([]);
		}
	} else {
		carp('get_exceptions got an invalid UID');
		return([]);
	}
}

# Purpose: Set the EXDATEs for the supplied UID
# Usage: $object->set_exceptions(UID, EXCEPTIONS_ARRAY);
sub set_exceptions {
	my $self = shift;
	my $UID = shift;
	my $Exceptions = shift;
	# First, clean the current one.
	delete($self->{RawCalendar}{$UID}{EXDATE});
	# If Exceptions is undef then just return.
	return(true) if not defined($Exceptions);
	# Create the array
	$self->{RawCalendar}{$UID}{EXDATE} = [];
	foreach(@{$Exceptions}) {
		# This doesn't do any syntax checking. We (stupidly) assume the caller
		# did the proper thing(tm)
		push(@{$self->{RawCalendar}{$UID}{EXDATE}},$_);
	}
	return(true);
}

# Purpose: Write the data to a file.
# Usage: $object->write(FILE?);
sub write {
	my ($self, $file) = @_;
	if(not defined($file)) {
		if($self->{FILETYPE} eq 'ref') {
			carp('write called on object created from array ref');
			return(undef);
		}
		$file = $self->{FILE};
	}
	my $iCalendar = $self->get_rawdata($self->{FILE},0,0);
	if($iCalendar) {
		open(my $TARGET, '>', $file) or do {
			_OutWarn("Unable to open $file for writing: $!");
			return(undef);
		};
		print $TARGET $iCalendar;
		close($TARGET);
		chmod($self->{FILEPERMS},$file);
		return(true);
	} else {
		_OutWarn('Unknown error ocurred, get_rawdata returned false. Attempt to write data from uninitialized object?');
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

	foreach my $UID (sort keys(%{$self->{RawCalendar}})) {
		$iCalendar .= "BEGIN:VEVENT\r\n";
		$iCalendar .= "UID:$UID\r\n";
		foreach my $setting (sort keys(%{$self->{RawCalendar}{$UID}})) {
			my $value = ${$self->{RawCalendar}}{$UID}{$setting};
			if(ref($value)) {
				foreach my $TrueValue (@{$value}) {
					$TrueValue = _GetSafe($TrueValue);
					$iCalendar .= "$setting:$TrueValue";
					$iCalendar .= "\r\n";
				}
			} else {
				$value = _GetSafe($value);
				# Check if value should be written with a ;
				# FIXME: There are more cases than these
				if($value =~ /^(TZID=\D+:|CN=|ROLE=|CUTYPE=|PARTSTAT=).*:.*/) {
					$iCalendar .= "$setting;$value";
				} else {
					$iCalendar .= "$setting:$value";
				}
				$iCalendar .= "\r\n";
			}
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
		$self->_ClearCalculated();
		return(true);
	} else {
		carp('delete called without a valid UID');
		return(undef);
	}
}

# Purpose: Add an iCalendar entry
# Usage: $object->add(%EntryHash);
sub add {
	my ($self, %Hash) = @_;
	unless(defined($Hash{DTSTART})) {
		carp('Refusing to add a iCalendar entry without a DTSTART.');
		return(undef);
	}
	my $UID;
	if(not ($Hash{UID}) or not length($Hash{UID})) {
		$UID = $self->_UID($Hash{DTSTART});
	} else {
		$UID = $Hash{UID};
	}
	$self->_ClearCalculated();
	$self->_ChangeEntry($UID,%Hash);
	if(not $Hash{CREATED}) {
		my ($currsec,$currmin,$currhour,$currmday,$currmonth,$curryear,$currwday,$curryday,$currisdst) = gmtime(time);
		$curryear += 1900;
		$self->{RawCalendar}{$UID}{CREATED} = iCal_GenDateTime($curryear, $currmonth, $currmday, _AppendZero($currhour) . ':' . _AppendZero($currmin));
	}
	return(true);
}

# Purpose: Change an iCalendar entry
# Usage: $object->change(%EntryHash);
sub change {
	my ($self, $UID, %Hash) = @_;
	unless(defined($UID)) {
		carp('Refusing to change a iCalendar entry without a UID to change.');
		return(undef);
	}
	unless(defined($Hash{DTSTART})) {
		carp('Refusing to change a iCalendar entry without a DTSTART.');
		return(undef);
	}
	$self->_ChangeEntry($UID,%Hash);
	return(true);
}

# Purpose: Check if an UID exists
# Usage: $object->exists($UID);
sub exists {
	my($self,$UID) = @_;
	if(defined($self->{RawCalendar}{$UID})) {
		return(true);
	}
	delete($self->{RawCalendar}{$UID});
	return(false);
}

# Purpose: Add another file
# Usage: $object->addfile(FILE);
sub addfile {
	my ($self,$File) = @_;
	if(ref($File)) {	# If we got a reference
		if(not ref($File) eq 'ARRAY') {
			carp('Supplied a reference, but the reference is not a ARRAYREF.');
			return(undef);
		}
	} else {		# If we don't have a reference, treat it as a scalar
				# filepath argument
		unless(defined($File)) {
			carp('Needs an option: path to the iCalendar file');
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
	$self->_ClearCalculated();
	return(true);
}

# Purpose: Enable a feature
# Usage: $object->enable(FEATURE);
sub enable {
	my($self, $feature) = @_;
	foreach(qw(SMART_MERGE)) {
		next unless($feature eq $_);
		$self->{FEATURE}{$_} = 1;
		return(true);
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
		return(true);
	}
	carp("Attempted to disable unknown feature: $feature");
	return(undef);
}

# Purpose: Reload the data
# Usage: $object->reload();
sub reload {
	my $self = shift;
	if($self->{FILETYPE} eq 'ref') {
		carp('reload called on object created from array ref');
		return(undef);
	}
	$self->clean();
	return($self->addfile($self->{FILE}));
}

# Purpose: Find duplicate events
# Usage: $object->locateDupes();
sub locateDupes
{
	# The object
	my $this = shift;
	# List of all UIDs
	my @keyList = keys %{$this->{RawCalendar}};
	# The total number of UIDs - cached so we don't have to evaluate the array every turn through the loop
	my $total = @keyList;
	# List of processed files - so that no events gets tested twice
	my %Processed;
	# List of identical event -> UID pairs
	my %Identical;
	# This is a helper hash for creating Identical.
	# It contains UID -> array pairs, one for each event.
	my %IdenticalArrayHelper;
	# Go through everything in the array, saving the info to $i
	for(my $i=0; $i < $total; $i++)
	{
		# Get the keys from the current array
		my $thiskeys = join(' ',sort keys %{$this->{RawCalendar}{$keyList[$i]}});
		# Mark this one as processed for future use
		$Processed{$keyList[$i]} = true;
		# Now go through every other event
		foreach my $key (@keyList)
		{
			# If this has already been processed then skip forwards
			next if $Processed{$key};
			# Will contain a list of possible keys to perform an array check on
			my @ArrayChecks;
			# A sorted list of all of the events keys - events which doesn't have all
			# the same keys can't be identical.
			my $uidkeys = join(' ',sort keys %{$this->{RawCalendar}{$key}});
			# If they don't have the same keys skip forwards
			next if not $uidkeys eq $thiskeys;

			my $notEq;
			my $equals;
			# Now go through every iCalendar entry
			foreach my $mkey (sort keys %{$this->{RawCalendar}{$keyList[$i]}})
			{
				# Skip tags that doesn't define anything useful and that often changes.
				# Events are considered dupes even if these are not identical
				next if($mkey =~ /^(UID|CREATED|LAST-MODIFIED)$/);
				# Make sure it isn't an array
				if(ref($this->{RawCalendar}{$key}{$mkey}) eq 'ARRAY') {
					# The array check is slower than the simple string check we otherwise use.
					# Therefore we only do array checks if everything else is identical
					push(@ArrayChecks,$mkey);
				}
				# If the two strings aren't equal then the events can't be dupes
				elsif(not $this->{RawCalendar}{$key}{$mkey} eq $this->{RawCalendar}{$keyList[$i]}{$mkey})
				{
					$notEq = 1;
					last;
				}
				# If the two strings are identical then the events *can* be dupes.
				# This must happen for each event for them to be considered dupes.
				else
				{
					$equals = 1;
				}
			}
			# If two strings in the event wasn't equal then skip forward to the next one
			next if $notEq;
			# If no two strings in the event was equal then skip forward to the next one
			next if not $equals;
			# Okay we got so far - do array checks before we say for sure they are identical
			# - most that get this far will be, but better safe than sorry
			my $ArrayEqual = 1;
			# Go through each key marked as an array
			foreach my $arrayKey(@ArrayChecks)
			{
				# This hash will contain everything in the array being processed
				my %ArrayContents;
				# Go through each key in the array and add it to $ArrayContents
				foreach my $arrayElement (@{$this->{RawCalendar}{$key}{$arrayKey}})
				{
					$ArrayContents{$arrayElement} = true;
				}
				# Go through each key in THIS array and make sure it is in $ArrayContents
				foreach my $arrayElement (@{$this->{RawCalendar}{$key}{$keyList[$i]}})
				{
					# If it isn't then they can't be equal
					if(not $ArrayContents{$arrayElement})
					{
						$ArrayEqual = 0;
						last;
					}
					# If it is then remove it from the hash so we can make sure that all
					# values have been checked later
					else
					{
						delete($ArrayContents{$arrayElement});
					}
				}
				# If ArrayEqual is not true then it means something wasn't identical, so the
				# events can't be equal
				last if not $ArrayEqual;
				# If ArrayContents contain one or more keys now, then some keys where present
				# in only one of the arrays, so the events can't be equal.
				last if keys(%ArrayContents);
			}
			# If ArrayEqual is not true then these two events can't be equal. Skip forwards to the
			# next one.
			next if not $ArrayEqual;
			# They're equal!
			# Now we do some black magic involving a load of references
			#
			# If there is already an IdenticalArrayHelper entry for either $keyList[$i] or 
			if(not defined($IdenticalArrayHelper{$keyList[$i]}) and not defined($IdenticalArrayHelper{$key}))
			{
				# If there is an entry in Identical for key then use that
				if(defined($Identical{$key}))
				{
					$IdenticalArrayHelper{$key} = $Identical{$key};
				}
				else
				{
					# If there isn't an entry in Identical for $keyList[$i] create one
					if(not defined($Identical{$keyList[$i]}))
					{
						$Identical{$keyList[$i]} = [];
					}
					# And in any case - use it.
					$IdenticalArrayHelper{$keyList[$i]} = $Identical{$keyList[$i]};
				}
			}
			# Now use the values generated above.
			#
			# If keyList is in there push key into that
			if($IdenticalArrayHelper{$keyList[$i]})
			{
				push(@{$IdenticalArrayHelper{$keyList[$i]}},$key);
				$IdenticalArrayHelper{$key} = $IdenticalArrayHelper{$keyList[$i]};
			}
			# If key is there push keyList into that
			elsif($IdenticalArrayHelper{$key})
			{
				push(@{$IdenticalArrayHelper{$key}},$keyList[$i]);
				$IdenticalArrayHelper{$keyList[$i]} = $IdenticalArrayHelper{$key};
			}
			else
			{
				# If we reach this, then there is some bug in the above logic
				warn('Bug: no IdenticalArrayHelper array to push key into. Events: '.$key.' '.$keyList[$i]);
			}
			# Mark key as processed too. It has found its dupe. More dupes will be
			# found by the current loop and running it again for this key won't find anything
			# new - it will just waste processing time and add the key to the list more than once.
			$Processed{$key} = true;
		}
	}
	# Return the hash of duplicate events
	return(\%Identical);
}

# Purpose: Set the prodid
# Usage: $object->set_prodid(PRODID);
sub set_prodid {
	my($self, $ProdId) = @_;
	if(not defined($ProdId) or not length($ProdId)) {
		croak('Emtpy/undef ProdId used in ->set_prodid');
	}
	# Warn about excessively long prodids
	if(length($ProdId) > 100) {
		carp('ProdId is over 100 characters long (in ->set_prodid). Consider slimming it down.');
	}
	# Verify that it is nicely formatted
	unless($ProdId =~ m#^-//.+//NONSGML\s.+//EN$#) {
		croak('ProdId is not nicely formatted, see the DP::iCalendar documentation.');
	}
	# Set the prodid
	$self->{PRODID} = $ProdId;
	return(true);
}

# Purpose: Set the file permission
# Usage: $object->set_file_perms(PERM);
sub set_file_perms
{
	my $self = shift;
	$self->{FILEPERMS} = shift;
}

# - Public methods for use by DP::iCalendar::Manager

# Purpose: Return manager information
# Usage: get_manager_version();
sub get_manager_version
{
	return('01_capable');
}

# Purpose: Return manager capability information
# Usage: get_manager_capabilities
sub get_manager_capabilities
{
	# All capabilites as of 01_capable
	return(['LIST_DPI','RRULE','SAVE','CHANGE','ADD','EXT_FUNCS','ICS_FILE_LOADING','RAWDATA','EXCEPTIONS','DELETE','RELOAD'])
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
		return("$Year$iCalMonth$iCalDay");
	}
}

# Purpose: Generate an iCalendar date-time string from a UNIX time string
# Usage: my $iCalDateTime = iCal_ConvertFromUnixTime(UNIX TIME);
sub iCal_ConvertFromUnixTime {
	my $UnixTime = shift;
	my ($realsec,$realmin,$realhour,$realmday,$realmonth,$realyear,$realwday,$realyday,$realisdst) = localtime($UnixTime);
	$realyear += 1900;	# Fix the year
	$realmonth++;		# Fix the month
	# Return data from iCal_GenDateTime
	return(iCal_GenDateTime($realyear,$realmonth,$realmday,"$realhour:$realmin"));
}

# Purpose: Generate a UNIX time string from an iCalendar date-time string
# Usage: my $UnixTime = iCal_ConvertToUnixTime(DATE-TIME_ENTRY);
sub iCal_ConvertToUnixTime {
	my $Value = shift;
	my($Year,$Month,$Day,$Time) = iCal_ParseDateTime($Value);

	$Year -= 1900;
	$Month--;
	my ($Hour,$Minute) = (0,0);
	if($Time) {
		($Hour,$Minute) = split(/:/,$Time,2);
	}
	
	return(mktime(0,$Minute,$Hour,$Day,$Month,$Year));
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
			_WarnOut('Returning 2000,01,01,00:00');
			# We don't return undef in order to not break programs that expect
			# this function to return something usable.
			return(2000,'01','01','00:00');
		}
	}
	# Stripping of TZID
	$Value =~ s/^(DTSTART)?;?TZID=\D+://;

	my $Hour;
	my $Minutes;
	my $Time;

	my $Year = substr($Value, 0,4);
	my $Month = substr($Value, 4, 2);
	my $Day = substr($Value, 6, 2);

	# Test if the time is set, if it is then process it.
	if($Value =~ s/^.+T//) {
		$Hour = substr($Value,0,2);
		$Minutes = substr($Value,2,2);
		$Time = _AppendZero($Hour) . ':' . _AppendZero($Minutes);
	}
	return($Year,$Month,$Day,$Time);
}

# - Internal functions
# WARNING: Do NOT call ANY of the below functions from within programs using
# 	DP::iCalendar. They are only meant for internal use and are subject to
# 	radical API changes, or just disappearing.
# 	If there is a feature provided below that you need in your program,
# 	submit a bug report requesting a function with similar functionality to
# 	be added to the public methods.

# Purpose: Create a new object.
# Usage: my $object = _NewObj(FILE?);
#  FILE is the path to a file or undef. undef if working in ref mode.
sub _NewObj {
	my $File = shift;
	my $self = {};
	bless($self);
	$self->{RawCalendar} = {};
	$self->{OrderedCalendar} = {};
	$self->{AlreadyCalculated} = {};
	$self->{PRODID} = "-//EskildHustvedt//NONSGML DP::iCalendar $VERSION//EN";
	# Default file permissions set during ->write();
	# Can be overridden by ->set_file_perms();
	$self->{FILEPERMS} = oct(600);
	if($File) {
		$self->{FILETYPE} = 'file';
		$self->{FILE} = $File;
	} else {
		$self->{FILETYPE} = 'ref';
	}
	return($self);
}

# Purpose: Make changes to the raw calendar (append or change)
# Usage: $self->_ChangeEntry(UID,%Hash);
sub _ChangeEntry {
	my($self,$UID,%Hash) = @_;
	foreach my $key (keys(%Hash)) {
		# If the key isn't defined that means we should remove the key if it
		# exists.
		if(defined($Hash{$key})) {
			$self->{RawCalendar}{$UID}{$key} = $Hash{$key};
		} else {
			if(defined($self->{RawCalendar}{$UID}{$key})) {
				delete($self->{RawCalendar}{$UID}{$key});
			}
		}
	}
	my ($currsec,$currmin,$currhour,$currmday,$currmonth,$curryear,$currwday,$curryday,$currisdst) = gmtime(time);
	$curryear += 1900;
	$self->{RawCalendar}{$UID}{'LAST-MODIFIED'} = iCal_GenDateTime($curryear, $currmonth, $currmday, _AppendZero($currhour) . ':' . _AppendZero($currmin));
	$self->_ClearCalculated();
	return(true);
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

# Purpose: Loads iCalendar data
# Usage: $self->_LoadFile(FILE OR ARRAYREF);
sub _LoadFile {
	# TODO: Create a iCalendar error logfile with dumps of data and errors.
	my $self = shift;
	my $Data = _ParseData($_[0]);
	return(undef) unless(defined($Data));
	$self->_ClearCalculated();
	foreach(0..scalar(@{$Data})) {
		my $Current = $Data->[$_];
		my ($Summary, $Fulltext, $UID);
		# First make sure we've got everything we need. Skip entries
		# missing some things.
		next unless(defined($Current->{'X-PARSER_ENTRYTYPE'}));
		next unless($Current->{'X-PARSER_ENTRYTYPE'} eq 'VEVENT');
		unless(defined($Current->{'DTSTART'})) {
			# Detect an alternate dstart
			foreach(keys(%{$Current})) {
				if(/^DTSTART/) {
					$Current->{'DTSTART'} = $Current->{$_};
					last;
				}
			}
			unless(defined($Current->{'DTSTART'})) {
				_ErrOout('DTSTART missing from iCalendar file. Dumping data:');
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
			$UID = $self->_UID($Year.$Month.$Day);
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
							$Reassign = 1;
							last;
						}
					}
				}
				$UID = $self->_UID($Current->{DTSTART}) if($Reassign);
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
			_WarnOut('Dangerous: SUMMARY missing from iCalendar import. Dumping data:');
			print Dumper(\$Current);
		}
		foreach(keys(%{$Current})) {
				if(not /^X-PARSER/) {
					$self->{RawCalendar}{$UID}{$_} = _UnSafe($Current->{$_});
			}
		}
	}
	$Data = undef;
	return(true);
}

# Purpose: Parses a single iCalendar line into the data hash supplied
# Usage: _ParseiCalLine(DATA_HASHREF);
# 
# 	DATA_HASHREF is a ref of the hash declared at the beginning of _ParseData();
sub _ParseiCalLine {
	my $DataHash = shift;
	chomp($DataHash->{Line});
	if ($DataHash->{Line} =~ s/^\s//) {
		if($DataHash->{ArrayFields}->{$DataHash->{LastName}}) {
			my $LastArrayField = scalar(@{$DataHash->{iCalendarStructures}[$DataHash->{CurrentStructure}]{$DataHash->{LastName}}});
			$DataHash->{iCalendarStructures}[$DataHash->{CurrentStructure}]{$DataHash->{LastName}}->[$LastArrayField] .= _UnSafe($DataHash->{Line});
		} else {
			$DataHash->{iCalendarStructures}[$DataHash->{CurrentStructure}]{$DataHash->{LastName}} .= _UnSafe($DataHash->{Line});
		}
	} elsif($DataHash->{Line} =~ /^END/) {
		return;
	} else {
		my($Name,$Value) = split(/:/,$DataHash->{Line}, 2);
		if($Name =~ /^BEGIN/) {
			if($Value eq 'VCALENDAR') {
				$DataHash->{FileBegun} = 1;
				$DataHash->{iCalendarStructures} = [];
				return();
			}
			$DataHash->{CurrentStructure}++;
			$Name = 'X-PARSER_ENTRYTYPE';
		}
		$DataHash->{LastName} = $Name;
		if($DataHash->{ArrayFields}->{$Name}) {
			if(not $DataHash->{iCalendarStructures}[$DataHash->{CurrentStructure}]{$Name}) {
				$DataHash->{iCalendarStructures}[$DataHash->{CurrentStructure}]{$Name} = [];
			}
			push(@{$DataHash->{iCalendarStructures}[$DataHash->{CurrentStructure}]{$Name}}, _UnSafe($Value));
		} else {
			if($DataHash->{iCalendarStructures}[$DataHash->{CurrentStructure}]{$Name}) {
				_WarnOut("Multiple entries of $Name found, but field isn't classified as an array field. Expect trouble");
			}
			$DataHash->{iCalendarStructures}[$DataHash->{CurrentStructure}]{$Name} = _UnSafe($Value);
		}
	}
	return();
}

# Purpose: Loads an iCalendar file and returns a simple data structure. Returns
# 	undef on failure.
# Usage: my $iCalendar = _ParseData(FILE);
sub _ParseData {
	my $File = shift;
	my %DataHash = (
		iCalendarStructures => [],
		LastStructure => '',
		LastName => '',
		CurrentStructure => 0,
		FileBegun => '',
		ArrayFields => {
			EXDATE => 1,
		},
		Line => '',
	);
	my @FileContents;
	my $Type;
	# If $File is a ref...
	if(ref($File)) {
		$Type = 'ref';
		if(ref($File) eq 'ARRAY') {
			# All is well.
			@FileContents = @{$File};
		} else {
			# Nothing is well, bug!
			_WarnOut('iCal_ParseData: supplied reference is not an ARRAYREF!');
			# Return an empty anonymous array
			return([]);
		}
		foreach (@FileContents) {
			$DataHash{Line} = $_;
			_ParseiCalLine(\%DataHash);
		}
	}
	# It isn't
	else {
		$Type = "file ($File)";
		open(my $ICALENDAR, '<', $File) or do {
			_WarnOut("iCal_ParseData: Unable to open $File for reading: $!");
			# Return an empty anonymous array
			return([]);
		};
		# Seperator is \r\n
		$/ = "\r\n";
		while($DataHash{Line} = <$ICALENDAR>) {
			_ParseiCalLine(\%DataHash);
		}
		close($ICALENDAR);
		# Reset seperator
		$/ = "\n";
	}

	unless($DataHash{FileBegun}) {
		_WarnOut("FATAL: The supplied iCalendar data never had BEGIN:VCALENDAR ($Type). Failed to load the data.");
	}
	return($DataHash{iCalendarStructures});
}

# Purpose: Escape certain characters that are special in iCalendar
# Usage: my $SafeData = iCal_GetSafe($Data);
sub _GetSafe {
	$_[0] =~ s/\\/\\\\/g;
	$_[0] =~ s/,/\,/g;
	$_[0] =~ s/;/\;/g;
	$_[0] =~ s/\n/\\n/g;
	return($_[0]);
}

# Purpose: Removes escaping of iCalendar entries
# Usage: my $UnsafeEntry = iCal_UnSafe($DATA);
sub _UnSafe {
	$_[0] =~ s/\\n/\n/g;
	$_[0] =~ s/\\,/,/g;
	$_[0] =~ s/\\;/;/g;
	$_[0] =~ s/\\\\/\\/g;
	return($_[0]);
}

# Purpose: Get a unique ID for an event
# Usage: $iCalendar .= $self->_UID(NONRANDOM?);
# 	NONRANDOM is a non random string to be included into
# 	the UID. It should usually be something like $Year$Month$Day$Hour$Minute
# 	or similar. NONRANDOM *can* be omitted, if it is then it will be replaced
# 	by a random numerical string.
sub _UID {
	my $self = shift;
	my $NonRandom = shift;
	chomp($NonRandom);
	if($NonRandom) {
		$NonRandom =~ s/\D//g;
	} else {
		$NonRandom = int(rand(10000));
	}
	while(1) {
		my $UID = 'dp-' . time() . $NonRandom . int(rand(10000)) . '-' . scalar(getpwuid($<)) . '@' . hostname();
		if(not defined($self->{RawCalendar}{$UID})) {
			return($UID);
		}
	}
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
# Usage: $self->_GenerateCalendar(YEAR);
#  Note: This will generate the calendar including recurring stuff for YEAR.
#  It will create the normal calendar for all events.
sub _GenerateCalendar {
	my $self = shift;
	my $EventYear = shift;
	return if defined($self->{AlreadyCalculated}{$EventYear});
	$self->{OrderedCalendar}{$EventYear} = {};
	foreach my $UID (keys(%{$self->{RawCalendar}})) {
		my $Current = $self->{RawCalendar}{$UID};
		my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime($Current->{'DTSTART'});
		$Year =~ s/^0*//;
		$Month =~ s/^0*//;
		$Day =~ s/^0*//;
		# Recurring?
		if($Current->{RRULE}) {
			$self->_RRULE_Handler($UID,$EventYear);
		} else {
			# Not recurring
			if(not $Time) {
				$Time = 'DAY';
			}
			push(@{$self->{OrderedCalendar}{$Year}{$Month}{$Day}{$Time}}, $UID);
		}
	}
	$self->{AlreadyCalculated}{$EventYear} = 1;
	return(true);
}

# Purpose: Clear any calculated event data
# Usage: $self->_ClearCalculated();
sub _ClearCalculated {
	# TODO: At one point we might want to do additional processing depending on the UID supplied (if any)
	
	my $self = shift;
	$self->{OrderedCalendar} = {};
	$self->{AlreadyCalculated} = {};
	return(true);
}

# --- Internal RRULE calculation functions ---

# Purpose: Parse an RRULE
# Usage: _RRULE_Parser(UID);
# Returns a hash containing the RRULE fields parsed.
# Caller is expected to check EXRULE and EXDATE themselves.
# 	(ie. we don't support that yet)
# See _RRULE_Handler.
sub _RRULE_Parser {
	my $PureLine = shift;
	$_ = $PureLine;
	my %ReturnHash;
	if(not /FREQ=/) {
		_WarnOut("RRULE Parser: Unable to handle line (no FREQ): $PureLine");
		return(\%ReturnHash);
	}
	# NOTE: There are loads of settings we do not know how to handle.
	# 	These are deliberately not here so that they cause errors to be
	# 	displayed. We also need to allow the underlying user program
	# 	know that something has gone wrong and give the ability rectify it.
	# 	This could be done by a ->was_rrule_exception command which returns
	# 	true if an rrule exception occurred. Then the user could opt in to chose
	# 	what to do. Either allow the errors to pass and the module just to continue
	# 	to read the file, or discard the event in question.
	# The settings we know how to handle
	# 	Some of the descriptions are taken directly from the RFC
	my %Settings = (
		# The BYDAY rule part specifies a COMMA character (US-ASCII decimal 44)
		# separated list of days of the week; MO indicates Monday; TU indicates
		# Tuesday; WE indicates Wednesday; TH indicates Thursday; FR indicates
		# Friday; SA indicates Saturday; SU indicates Sunday.
		BYDAY => 1,

		# The WKST rule part specifies the day on which the workweek starts.
		# Valid values are MO, TU, WE, TH, FR, SA and SU. This is significant
		# when a WEEKLY RRULE has an interval greater than 1, and a BYDAY rule
		# part is specified. This is also significant when in a YEARLY RRULE
		# when a BYWEEKNO rule part is specified. The default value is MO.
		WKST => 1,
	
		# FREQ defines how often it should repeat. This can be for instance DAILY
		# MONTHLY WEEKLY YEARLY
		FREQ => 1,

		# The INTERVAL rule part contains a positive integer representing how
		# often the recurrence rule repeats. The default value is "1", meaning
		# every second for a SECONDLY rule, or every minute for a MINUTELY
		# rule, every hour for an HOURLY rule, every day for a DAILY rule,
		# every week for a WEEKLY rule, every month for a MONTHLY rule and
		# every year for a YEARLY rule.
		INTERVAL => 1,

		# UNTIL defines until when the event should repeat. It contains a standard
		# iCalendar datetime string
		UNTIL => 1,
	);
	# Check if it has multiple settings
	if(/;/) {
		# It does, process individually
		foreach my $Setting (split(/;/)) {
			my $Opt = $Setting;
			my $Val = $Setting;
			$Opt =~ s/^(\w+)=.*$/$1/;
			$Val =~ s/^\w+=(.*)$/$1/;
			if(not $Settings{$Opt}) {
				_WarnOut("RRULE Parser: $Opt is an unkown/unhandled setting in RRULE:. Expect trouble.");
			}
			if($ReturnHash{$Opt}) {
				_WarnOut("RRULE Parser: $Opt occurs multiple times in RRULE:. Can only handle one. Expect trouble.");
			}
			$ReturnHash{$Opt} = $Val;
		}
	} else {
		# It doesn't. Process the single line
			my $Opt = $_;
			my $Val = $_;
			$Opt =~ s/^(\w+)=.*$/$1/;
			$Val =~ s/^\w+=(.*)$/$1/;
			if(not $Settings{$Opt}) {
				_WarnOut("RRULE Parser: $Opt is an unkown/unhandled setting in RRULE:. Expect trouble.");
			}
			$ReturnHash{$Opt} = $Val;
	}
	return(\%ReturnHash);
}

# Purpose: Parse an RRULE and add to the hash
# Usage: _RRULE_Handler(UID,YEAR);
sub _RRULE_Handler {
	my $self = shift;
	my $UID = shift;
	my $YEAR = shift;
	if($YEAR > 2037 or $YEAR < 1970) {
		if(not $self->{Settings}{UnixTimeLimitWarned}) {
			$self->{Settings}{UnixTimeLimitWarned} = 1;
			_WarnOut('Can\'t handle RRULEs for years below 1970 or above 2037');
		}
		return(undef);
	}
	# Don't bother doing anything if DTSTART is older than YEAR
	my ($CalcYear,$CalcMonth,$CalcDay) = iCal_ParseDateTime($self->{RawCalendar}{$UID}{DTSTART});
	return(undef) if $CalcYear > $YEAR;

	my $RRULE = _RRULE_Parser($self->{RawCalendar}{$UID}{RRULE});
	my $AddDates;
	if	($RRULE->{FREQ} eq 'DAILY') {
		$AddDates = $self->_RRULE_DAILY($RRULE,$UID,$YEAR);
	} elsif ($RRULE->{FREQ} eq 'WEEKLY') {
		$AddDates = $self->_RRULE_WEEKLY($RRULE,$UID,$YEAR);
	} elsif ($RRULE->{FREQ} eq 'MONTHLY') {
		$AddDates = $self->_RRULE_MONTHLY($RRULE,$UID,$YEAR);
	} elsif ($RRULE->{FREQ} eq 'YEARLY') {
		$AddDates = $self->_RRULE_YEARLY($RRULE,$UID,$YEAR);
	} else {
		_WarnOut("STUB: _RRULE_Handler is unable to handle $self->{RawCalendar}{$UID}{RRULE} at this time.");
	}
	if($AddDates) {
		$self->_RRULE_AddDates($AddDates,$UID,$YEAR,$RRULE);
	}
}

# Purpose: Get a parsed list of EXDATES
# Usage: $self->_Get_EXDATES_Parsed(UID);
sub _Get_EXDATES_Parsed {
	my $self = shift;
	my $UID = shift;

	my %ExDates;
	foreach my $ExDate (@{$self->get_exceptions($UID)}) {
		# We merely discard Time
		my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime($ExDate);
		$Year =~ s/^0*//;
		$Month =~ s/^0*//;
		$Day =~ s/^0*//;
		$ExDates{$Year}{$Month}{$Day} = 1;
	}
	return(\%ExDates);
}

# Purpose: Add the supplied DATETIMEs to the sorted hash for the supplied UID.
# 		Also fetches the TIME from the UIDs DTSTART.
# 	This is the function that _RRULE_Handler() uses to add the dates that it has
# 	calculated from the RRULE to the internal sorted hash.
# 	This function also takes care of killing off entries matched by EXDATE entries,
# 	and entries not matched by BYDAY
# Usage: $self->_RRULE_AddDates(HASHREF, $UID, YEAR, PARSED_RRULE);
sub _RRULE_AddDates {
	my $self = shift;
	my $AddDates = shift;
	my $UID = shift;
	my $GenYear = shift;
	my $RRULE = shift;
	my $Exceptions = $self->_Get_EXDATES_Parsed($UID);
	my $BYDAY = $self->_Get_BYDAY_Parsed($RRULE,$UID);

	my ($UID_Year,$UID_Month,$UID_Day,$UID_Time) = iCal_ParseDateTime($self->{RawCalendar}{$UID}{DTSTART});
	if (not defined($UID_Time) or not length($UID_Time)) {
		$UID_Time = 'DAY';
	} elsif($UID_Time eq '00:00') {
		# NOTE: This is for the deprecated and old X-DP-BIRTHDAY syntax
		# in some iCalendar files. It should probably be removed soon and replaced by some
		# upgrade function.
		if(defined($self->{RawCalendar}{$UID}{'X-DP-BIRTHDAY'})) {
			$UID_Time = 'DAY';
		}
	}

	foreach my $DateTimeString (keys(%{$AddDates})) {
		my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime($DateTimeString);
		if($Year ne $GenYear) {
			_ErrOut("Wanted to add $Day.$Month.$Year, but we're generating $GenYear! This is a bug!");
			next;
		}
		# Test for BYDAY
		if($BYDAY and not $self->_BYDAY_Test($RRULE,$BYDAY,$UID,$DateTimeString)) {
			next;
		}

		$Year =~ s/^0*//;
		$Month =~ s/^0*//;
		$Day =~ s/^0*//;
		if(not $Exceptions->{$Year}{$Month}{$Day}) {
			push(@{$self->{OrderedCalendar}{$Year}{$Month}{$Day}{$UID_Time}},$UID);
		}
	}
}

# Purpose: Evalute an WEEKLY RRULE
# Usage: _RRULE_WEEKLY(RRULE,UID,YEAR);
sub _RRULE_DAILY {
	my $self = shift;
	my $RRULE = shift;
	my $UID = shift;
	my $YEAR = shift;
	my $UNTIL;
	my $StartsAt = $self->{RawCalendar}{$UID}{DTSTART};
	my %Dates;
	
	# Check all values in RRULE, if it has values we don't know about then don't calculate.
	foreach(keys(%{$RRULE})) {
		if(not /^(FREQ|WKST|BYDAY|UNTIL|INTERVAL)/) {
			if(/^X-/) {
				_WarnOut("Unkown X- setting in RRULE ($_): $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID.");
			} else {
				_ErrOut("RRULE too advanced for current parser: $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID. Report this to the developers.");
				return(undef);
			}
		}
	}
	# Verify INTERVAL
	if(defined($RRULE->{INTERVAL}) and $RRULE->{INTERVAL} != 1) {
			_ErrOut("RRULE too advanced for current parser: $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID. Report this to the developers.");
			return(undef);
	}
	
	# Fetch UNTIL first if it is set
	if($RRULE->{UNTIL}) {
		$UNTIL = iCal_ConvertToUnixTime($RRULE->{UNTIL});
	}

	my %StartDate = (
		Month => undef,
		Day => undef,
	);
	
	# First, start by finding out which day we're starting.
	my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime($StartsAt);
	# If YEAR is less than year then stop processing
	if($Year > $YEAR) {
		return({});
	}
	# Okay, we, sadly, need to process. So, first check if Year equals YEAR.
	# If it does then we need to start at the date specified. If not, we start
	# at the 1st of january.
	if($Year eq $YEAR) {
		$StartDate{Month} = $Month;
		$StartDate{Day} = $Day;
		$StartDate{Month}--;
	} else {
		$StartDate{Month} = 0;
		$StartDate{Day} = 1;
	}
	my $UnixYear = $YEAR - 1900;
	# Good, let's process.
	# First get the UNIX time string for the said date.
	# We use it to calculate.
	my $TimeString = mktime(0,0,0, $StartDate{Day},$StartDate{Month},$UnixYear);
	# Okay, now loop through /all/ possible dates
	my $LoopYear = $YEAR;
	while($LoopYear eq $YEAR) {
		my $iCalTime = iCal_ConvertFromUnixTime($TimeString);
		$Dates{$iCalTime} = 1;
		
		# One day is 86400
		$TimeString += 86400;
		my $NextiCalTime = iCal_ConvertFromUnixTime($TimeString);
		my ($evYear, $evMonth, $evDay, $evTime) = iCal_ParseDateTime($NextiCalTime);
		$LoopYear = $evYear;
		# Handle UNTIL.
		if($UNTIL) {
			if($TimeString > $UNTIL) {
				last;
			}
		}
	
	}
	# The loop has enedd and we've done all required calculations for BYDAY.
	return(\%Dates);
}

# Purpose: Evalute an WEEKLY RRULE
# Usage: _RRULE_WEEKLY(RRULE,UID,YEAR);
sub _RRULE_WEEKLY {
	my $self = shift;
	my $RRULE = shift;
	my $UID = shift;
	my $YEAR = shift;
	my $UNTIL;
	my $StartsAt = $self->{RawCalendar}{$UID}{DTSTART};
	my %Dates;
	
	# Check all values in RRULE, if it has values we don't know about then don't calculate.
	foreach(keys(%{$RRULE})) {
		if(not /^(UNTIL|BYDAY|FREQ|WKST|INTERVAL)/) {
			if(/^X-/) {
				_WarnOut("Unkown X- setting in RRULE ($_): $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID.");
			} else {
				_ErrOut("RRULE too advanced for current parser: $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID. Report this to the developers.");
				return(undef);
			}
		}
	}
	# Verify INTERVAL
	if(defined($RRULE->{INTERVAL}) and $RRULE->{INTERVAL} != 1) {
			_ErrOut("RRULE too advanced for current parser: $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID. Report this to the developers.");
			return(undef);
	}
	
	# We will add and eliminate dates as we go. This is inefficient, but functional.
	# Right now we just know about one date+time, so let's add that.
	#
	# Ideas on how to solve the inefficiency:
	# - Create a "recurrence" cache. Dump all recurrence information into a file.
	#   The file bases itself upon UIDs and MD5 sums. If an UID is found in the loaded
	#   iCalendar file and the UID object has the same MD5 sum as the one in the file
	#   then just use the recurrence information in the cache file, if not, recalculate it
	#   and then write out the new information to the cache file when told to do so.
	# - Another recurrence cache option:
	#    Create a directory tree consisting of a DP directory with subfiles named
	#    after UIDs. The files contain the cached recurrence information for *that*
	#    one UID. When the UID changes the new cache is written out. So it can be written
	#    and loaded on the fly without having to write out massive amounts of data.
	#    Again it should have an MD5 sum field which can be used for verification.
	#    Then when an UID is removed the file is removed.
	#    This would require us to have some sort of cleanup function in order to be able
	#    to remove old UID caches.
	# It could have:
	#  MD5SUM=THE MD5SUM
	#  RECUR_ON=space seperated list of iCalendar DATETIME strings
	#  CALCULATED_FOR=space seperated list of years which the recurrance has been calculated for
	# The file would grow as the cache grows. Years won't be removed or replaced, just appended.
	# This could result in very efficient calculations, assuming that calculating a single
	# MD5 and checking it up against another MD5 will be quicker than our hard number-crunching
	# calculations.
	#
	# The cache would not need to be written out for simple strings that only have a single
	# FREQ (and INTERVAL=1), but for more advanced strings that require a lot of calculation,
	# this would be useful. HD space is more plentyful than CPU power.

	# What do we know so far?
	# - It is an event that occurs more than once
	# - It is an event that occurs on a weekly basis
	
	# Fetch UNTIL first if it is set
	if($RRULE->{UNTIL}) {
		$UNTIL = iCal_ConvertToUnixTime($RRULE->{UNTIL});
	}

	# FIXME: Add BYDAY support.
	my %StartDate = (
		Month => undef,
		Day => undef,
	);
	# Great, we have a BYDAY. Add all of them to \%Dates
	
	# First, start by finding out which day we're starting.
	my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime($StartsAt);
	# If YEAR is less than year then stop processing
	if($Year > $YEAR) {
		return({});
	}
	# Okay, we, sadly, need to process. So, first check if Year equals YEAR.
	# If it does then we need to start at the date specified. If not, we start
	# at the 1st of january.
	if($Year eq $YEAR) {
		$StartDate{Month} = $Month;
		$StartDate{Day} = $Day;
		$StartDate{Month}--;
	} else {
		# Okay, now we need to figure out which day we're suppose to start on
		# This is a lot slower

		# The original unix time (start time)
		my $UnixOrigStart = iCal_ConvertToUnixTime($StartsAt);
		# Human-readable-ish versions of the above
		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($UnixOrigStart);
		# The wday we want it to occur on
		my $trueWday = $wday;
		# The unix year
		my $nixYear = $YEAR - 1900;
		# The date to begin processing on (1/1/year)
		my $mktYearFirst = mktime(5,0,0,1,0,$nixYear);
		# Start looping
		while(true)
		{
			# Get the time
			my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime($mktYearFirst);
			# If wday is trueWday then this is the one
			if ($wday == $trueWday)
			{
				$StartDate{Month} = 0;
				$StartDate{Day} = $mday;
				last;
			}
			# If not, + one day
			$mktYearFirst += 86400;
		}
	}
	my $UnixYear = $YEAR - 1900;
	# Good, let's process.
	# First get the UNIX time string for the said date.
	# We use it to calculate.
	my $TimeString = mktime(0,0,0, $StartDate{Day},$StartDate{Month},$UnixYear);
	# Okay, now loop through /all/ possible dates
	my $LoopYear = $YEAR;
	while($LoopYear eq $YEAR) {
		my $iCalTime = iCal_ConvertFromUnixTime($TimeString);
		$Dates{$iCalTime} = 1;
		
		# One day is 86400, thus one week is 86400 * 7 = 604800.
		$TimeString += 604800;
		my $NextiCalTime = iCal_ConvertFromUnixTime($TimeString);
		my ($evYear, $evMonth, $evDay, $evTime) = iCal_ParseDateTime($NextiCalTime);
		$LoopYear = $evYear;
			# Handle UNTIL.
		if($UNTIL) {
			if($TimeString > $UNTIL) {
				last;
			}
		}
	
	}
	# The loop has ended and we've done all required calculations
	return(\%Dates);
}

# Purpose: Evalute an MONTHLY RRULE
# Usage: _RRULE_MONTHLY(RRULE,UID,YEAR);
sub _RRULE_MONTHLY {
	my $self = shift;
	my $RRULE = shift;
	my $UID = shift;
	my $YEAR = shift;
	my $UNTIL;
	my $StartsAt = $self->{RawCalendar}{$UID}{DTSTART};
	my %Dates;
	
	# Check all values in RRULE, if it has values we don't know about then don't calculate.
	foreach(keys(%{$RRULE})) {
		if(not /^(FREQ|WKST|BYDAY|UNTIL|INTERVAL)/) {
			if(/^X-/) {
				_WarnOut("Unkown X- setting in RRULE ($_): $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID.");
			} else {
				_ErrOut("RRULE too advanced for current parser: $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID. Report this to the developers.");
				return(undef);
			}
		}
	}
	# Verify INTERVAL
	if(defined($RRULE->{INTERVAL}) and $RRULE->{INTERVAL} != 1) {
			_ErrOut("RRULE too advanced for current parser: $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID. Report this to the developers.");
			return(undef);
	}
	
	# Fetch UNTIL first if it is set
	if($RRULE->{UNTIL}) {
		$UNTIL = iCal_ConvertToUnixTime($RRULE->{UNTIL});
	}

	my %StartDate = (
		Month => undef,
		Day => undef,
	);
	# Great, we have a BYDAY. Add all of them to \%Dates
	
	# First, start by finding out which day we're starting.
	my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime($StartsAt);
	# If YEAR is less than year then stop processing
	if($Year > $YEAR) {
		return({});
	}
	# Okay, we, sadly, need to process. So, first check if Year equals YEAR.
	# If it does then we need to start at the date specified. If not, we start
	# at the 1st of january.
	if($Year eq $YEAR) {
		$StartDate{Month} = $Month;
	} else {
		$StartDate{Month} = 1;
	}
	$StartDate{Day} = $Day;
	
	my $UnixYear = $YEAR - 1900;
	# Good, let's process.
	# First get the UNIX time string for the said date.
	# We use it to calculate.
	my $TimeString = mktime(0,0,0, $StartDate{Day},$StartDate{Month},$UnixYear);
	# Okay, now loop through /all/ possible dates
	my $LoopYear = $YEAR;
	while(1) {
		my $iCalTime = iCal_GenDateTime($YEAR, $StartDate{Month}, $StartDate{Day});
		$Dates{$iCalTime} = 1;
		
		# Bump month
		$StartDate{Month}++;
		if($StartDate{Month} > 12) {
			last;
		}
		# Handle UNTIL.
		if($UNTIL) {
			my $NextiCalTime = iCal_GenDateTime($YEAR, $StartDate{Month}, $StartDate{Day});
			$NextiCalTime = iCal_ConvertToUnixTime($NextiCalTime);
			if($NextiCalTime > $UNTIL) {
				last;
			}
		}
	
	}
	# The loop has ended and we've done all required calculations
	return(\%Dates);
}

# Purpose: Evaluate an YEARLY RRULE
# Usage: RRULE_YEARLY(RRULE,UID,YEAR);
sub _RRULE_YEARLY {
	my $self = shift;
	my $RRULE = shift;
	my $UID = shift;
	my $YEAR = shift;
	my $Date = $self->{RawCalendar}{$UID}{DTSTART};
	my $TheRRULE= $self->{RawCalendar}{$UID}{RRULE};
	my $UNTIL;
	my %Dates;
	# Check all values in RRULE, if it has values we don't know about then don't calculate.
	foreach(keys(%{$RRULE})) {
		if(not /^(FREQ|WKST|INTERVAL|BYDAY|UNTIL)/) {
			if(/^X-/) {
				_WarnOut("Unkown X- setting in RRULE ($_): $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID.");
			} else {
				_ErrOut("RRULE too advanced for current parser: $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID. Report this to the developers.");
				return(undef);
			}
		}
	}
	# Verify INTERVAL
	if(defined($RRULE->{INTERVAL}) and $RRULE->{INTERVAL} != 1) {
			_ErrOut("RRULE too advanced for current parser: $self->{RawCalendar}{$UID}{RRULE}. Found in event $UID. Report this to the developers.");
			return(undef);
	}
	# Fetch UNTIL first if it is set
	if($RRULE->{UNTIL}) {
		$UNTIL = iCal_ConvertToUnixTime($RRULE->{UNTIL});
	}

	my ($Year, $Month, $Day, $Time) = iCal_ParseDateTime($Date);
	my $NewDate = iCal_GenDateTime($YEAR,$Month,$Day,$Time);
	if(not $UNTIL or not iCal_ConvertToUnixTime($NewDate) > $UNTIL) {
		$Dates{$NewDate} = 1;
	}
	return(\%Dates);
}

# Purpose: Returns a parsed map of localtime() values => byday values
# 	as specified in the RRULE.
# Usage: _RRULE_BYDAY_Parsed(RRULE,UID);
# 	It returns a hashref. The hashref has one key per wday as of localtime().
# 	Those matching the rule is true, those not, false.
# 	If a BYDAY rule is not present then it returns false.
sub _Get_BYDAY_Parsed {
	my $self = shift;
	my $RRULE = shift;
	my $UID = shift;

	# The returned map
	my %ReturnMap;

	# If there is no BYDAY rule, return undef
	if(not $RRULE->{BYDAY}) {
		return(false);
	}

	# BYDAY value -> localtime() mapping
	my %BydayMap = (
		SU => 0,
		MO => 1,
		TU => 2,
		WE => 3,
		TH => 4,
		FR => 5,
		SA => 6
	);

	foreach my $WD (split(/,/, $RRULE->{BYDAY})) {
		if(defined($BydayMap{$WD})) {
			$ReturnMap{$BydayMap{$WD}} = true;
		} else {
			_WarnOut("RRULE for UID $UID has an invalid day specified in BYDAY: $WD");
		}
	}

	return(\%ReturnMap);
}

# Purpose: Test if a date matches a preparsed BYDAY rule
# Usage: $self->_BYDAY_Test(RRULE, BYDAY, UID, DATETIME);
sub _BYDAY_Test {
	my $self = shift;
	my $RRULE = shift;
	my $BYDAY = shift;
	my $UID = shift;
	my $DateTime = shift;

	# Create the UNIX time for said day
	my $UnixTime = iCal_ConvertToUnixTime($DateTime);
	my ($testsec,$testmin,$testhour,$testmday,$testmonth,$testyear,$testwday,$testyday,$testisdst) = localtime($UnixTime);
	if($BYDAY->{$testwday}) {
		return(true);
	} else {
		return(false);
	}
}

# Purpose: Strip the time part of a DateTime string
# Usage: _DT_StripTime
sub _DT_StripTime {
	my $DT = shift;
	$DT =~ s/Z.+$//i;
	return($DT);
}

# End of DP::iCalendar
1;
__END__

=pod

=head1 NAME

DP::iCalendar - Parser for iCalendar files

=head1 VERSION

0.3.1

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
You can tell it to export the iCal_ParseDateTime, iCal_GenDateTime,
iCal_ConvertFromUnixTime and iCal_ConvertToUnixTime functions.

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

=head2 $YearArray = $object->get_years();

Returns an array reference containing a sorted list of which years
contain events.

=head2 $MonthArray = $object->get_months(YEAR);

Returns an array reference containing a sorted list of which months
in YEaR contain events.

=head2 $DayArray = $object->get_monthinfo(YEAR,MONTH);

Returns a reference to an array containing a list of days in this
month that contains events, or an empty arrayref if there are no events.

=head2 $TimeArray = $object->get_dateinfo(YEAR,MONTH,DAY);

Returns a reference to an array containing a list of times on this day
that contains events or an empty arrayref if there are no events.
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

=head2 $RRULE_Info = $object->get_RRULE(UID);

Returns a hash reference containing the information found in the RRULE
as key=value pairs (like ->get_info()). Returns undef when the UID
doesn't have an RRULE.

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

=head2 my $ArrayRef = $object->get_exceptions(UID);

This function gets you an arrayref containing a list of dates which are to be
excepted from RRULEs. DP::iCalendar already takes these into account when
calculating RRULEs, but this is provided for your convinience when you need
the information. The information is also included in ->get_info() like everything
else (but unlike everything else, it is provided in the form of an arrayref
instead of a key=value hash entry.)

=head2 $object->set_exceptions(UID, ARRAYREF);

This function sets the EXDATE entries that ->get_exceptions returns.
Again this is provided for your convinience. It is also taken into
account when present in ->change();

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

=head2 my $UnixTime = iCal_ConvertToUnixTime(DATE TIME);

The same as iCal_ParseDateTime but returns unix time instead.

=head2 my $DATETIME = iCal_ConvertFromUnixTime(UNIX TIME);

The same as iCal_GenDateTime but takes a unix time as parameter
instead.

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

Return values of keys might seem inconsistent. Most values are returned in the
form of key => value pairs inside the hash, however certain values can be included
more than once. These values are returned as arrays. So it becomes key => arrayref.
Currently this is limited to the EXDATE entry, but this /might/
change in the future if it is required.

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
