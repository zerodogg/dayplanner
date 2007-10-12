# DP::iCalendar::Manager
# $Id: iCalendar.pm 1615 2007-08-10 17:58:24Z zero_dogg $
# An wrapper around DP::iCalendar that allows subscriptions to iCalendar calendars
# via the internet.
# Copyright (C) Eskild Hustvedt 2007
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package DP::iCalendar::Manager;

# -- Manager stuff --
sub new
{
	my $self = {};
	bless($self);
	$self->{objects} = {};
	$self->{UID_Cache} = {};
	$self->{'PRIMARY'} = undef;
	return($self);
}

sub add_object
{
	my $self = shift;
	my $object = shift;
	my $primary = shift;
	my $version = $object->get_manager_version();
	if(not $version eq '01_capable') {
		warn("ERR\n"); # FIXME
	}
	$self->{objects}->{$object} = $object->get_manager_capabilities();
	if($primary) {
		# TODO: Ensure that PRIMARY has *ALL* capabilities
		$self->{'PRIMARY'} = $primary;
	}
}
}

sub remove_object
{
	warn('STUB');
}

sub list_objects
{
	warn('STUB');
}

# -- DP::iCalendar API wrapper --

# Purpose: Get information for a supplied UID
# Usage: my $Info = $object->get_info(UID);
sub get_info {
	my($self,$UID) = @_;
	my $obj = $self->_locate_UID($UID);
	if(not $obj) {
		warn("ERR\n"); # FIXME
		return;
	}
	return($self->get_info($self->_get_real_UID($UID)));
}

# Purpose: Get information for the supplied date (list of times in the day there are events)
# Usage: my $TimeRef = $object->get_dateinfo(YEAR,MONTH,DAY);
sub get_dateinfo {
	my($self, $Year, $Month, $Day) = @_;	# TODO: verify that they are set
	warn('STUB'); return(undef);
}

# Purpose: Get the list of UIDs for the supplied time
# Usage: my $UIDRef = $object->get_timeinfo(YEAR,MONTH,DAY,TIME);
sub get_timeinfo {
	my($self, $Year, $Month, $Day, $Time) = @_;	# TODO: verify that they are set
	warn('STUB'); return(undef);
}

# Purpose: Get a list of years which have events (those with *only* recurring not counted)
# Usage: my $ArrayRef = $object->get_years();
sub get_years {
	my $self = shift;
	warn('STUB'); return(undef);
}

# Purpose: Get a list of months which have events (those with *only* recurring not counted)
# Usage: my $ArrayRef = $object->get_months();
sub get_months {
	my ($self, $Year) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Get a parsed RRULE for the supplied UID
# Usage: my $Info = $object->get_RRULE(UID);
sub get_RRULE {
	my ($self, $UID) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Get a list of dates which are excepted from recurrance for the supplied UID
# Usage: my $List = $object->get_exceptions(UID);
sub get_exceptions {
	my ($self, $UID) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Set the EXDATEs for the supplied UID
# Usage: $object->set_exceptions(UID, EXCEPTIONS_ARRAY);
sub set_exceptions {
	my $self = shift;
	my $UID = shift;
	my $Exceptions = shift;
	warn('STUB'); return(undef);
}

# Purpose: Write the data to a file.
# Usage: $object->write(FILE?);
sub write {
	my ($self, $file) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Get raw iCalendar data
# Usage: my $Data = $object->get_rawdata();
sub get_rawdata {
	my ($self) = @_;
	my $iCalendar;
	warn('STUB'); return(undef);
}

# Purpose: Delete an iCalendar entry
# Usage: $object->delete(UID);
sub delete {
	my ($self, $UID) = @_;	# TODO verify UID
	warn('STUB'); return(undef);
}

# Purpose: Add an iCalendar entry
# Usage: $object->add(%EntryHash);
sub add {
	my ($self, %Hash) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Change an iCalendar entry
# Usage: $object->change(%EntryHash);
sub change {
	my ($self, $UID, %Hash) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Check if an UID exists
# Usage: $object->exists($UID);
sub exists {
	my($self,$UID) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Add another file
# Usage: $object->addfile(FILE);
sub addfile {
	my ($self,$File) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Remove all loaded data
# Usage: $object->clean()
sub clean {
	my $self = shift;
	warn('STUB'); return(undef);
}

# Purpose: Enable a feature
# Usage: $object->enable(FEATURE);
sub enable {
	my($self, $feature) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Disable a feature
# Usage: $object->disable(FEATURE);
sub disable {
	my($self, $feature) = @_;
	warn('STUB'); return(undef);
}

# Purpose: Reload the data
# Usage: $object->reload();
sub reload {
	my $self = shift;
	warn('STUB'); return(undef);
}

# Purpose: Set the prodid
# Usage: $object->set_prodid(PRODID);
sub set_prodid {
	my($self, $ProdId) = @_;
	warn('STUB'); return(undef);
}

# -- Internal functions --
sub _locate_UID
{
}

sub _merge_arrays_unique
{
	warn('STUB');
}

sub _convert_UID
{
	warn('STUB');
}

sub _get_real_UID
{
	warn('STUB');
}
__END__

Capabilities:

All the following capabilities are OPTIONAL:
LIST_DPI		- Fetching UIDs by month, day, time and such
RRULE			- RRULE support
SAVE			- Save support
CHANGE			- Changes support
ADD				- Adding support
EXT_FUNCS		- Support for extended features that can be enabled and disable
ICS_FILE_LOADING - Support for loading iCalendar files into the object
RAWDATA			- Support for getting a raw iCalendar data file in a scalar
EXCEPTIONS		- Support for setting and getting date exceptions

All the following methods are REQUIRED:
get_uid() - gets a iCalendar UID with all info
exists() - checks if a iCalendar UID exists
