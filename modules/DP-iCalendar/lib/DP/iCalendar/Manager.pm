# DP::iCalendar::Manager
# $Id$
# An wrapper around DP::iCalendar that allows subscriptions to iCalendar calendars
# via the internet.
# Copyright (C) Eskild Hustvedt 2007
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package DP::iCalendar::Manager;

use Carp;
use constant { true => 1, false => 0 };
use strict;
use warnings;

our $VERSION;
$VERSION = 0.1;
my @Capabilities = ('LIST_DPI','RRULE','SAVE','CHANGE','ADD','EXT_FUNCS','ICS_FILE_LOADING','RAWDATA','EXCEPTIONS');

# -- Manager stuff --
sub new
{
	my $self = {};
	bless($self);
	$self->{UID_Cache} = {};
	$self->{'PRIMARY'} = undef;
	$self->{objects} = [];
	foreach(@Capabilities) {
		$self->{$_} = [];
	}
	return($self);
}

sub add_object
{
	my $self = shift;
	my $object = shift;
	my $primary = shift;
	my $version = $object->get_manager_version();
	if(not $version eq '01_capable') {
		carp("added_object: does not support this version. Supported: $version, this version: 01_capable");
	}
	push(@{$self->{objects}},$object);
	my $capabilities = $object->get_manager_capabilities();
	if(not defined($capabilities)) {
		carp("added_object: undef returned from get_manager_capabilities()")
	}
	foreach(@{$capabilities}) {
		push(@{$self->{$_}},$object);
	}
	if($primary) {
		# TODO: Ensure that PRIMARY has *ALL* capabilities
		$self->{'PRIMARY'} = $primary;
	}
}

sub remove_object
{
	warn('remove_object: STUB');
}

sub list_objects
{
	my $self = shift;
	return($self->{objects});
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
	return($obj->get_info($self->_get_real_UID($UID)));
}

# Purpose: Get information for the supplied month (list of days there are events)
# Usage: my $TimeRef = $object->get_monthinfo(YEAR,MONTH,DAY);
sub get_monthinfo {
	my($self, $Year, $Month) = @_;	# TODO: verify that they are set
	my @OBJArray;
	foreach my $obj (@{$self->{LIST_DPI}}) {
			push(@OBJArray,$obj->get_monthinfo($Year,$Month));
	}
	return(_merge_arrays_unique(\@OBJArray));
}

# Purpose: Get information for the supplied date (list of times in the day there are events)
# Usage: my $TimeRef = $object->get_dateinfo(YEAR,MONTH,DAY);
sub get_dateinfo {
	my($self, $Year, $Month, $Day) = @_;	# TODO: verify that they are set
	my @OBJArray;
	foreach my $obj (@{$self->{LIST_DPI}}) {
			push(@OBJArray,$obj->get_dateinfo($Year,$Month,$Day));
	}
	return(_merge_arrays_unique(\@OBJArray));
}

# Purpose: Get the list of UIDs for the supplied time
# Usage: my $UIDRef = $object->get_timeinfo(YEAR,MONTH,DAY,TIME);
sub get_timeinfo {
	my($self, $Year, $Month, $Day, $Time) = @_;	# TODO: verify that they are set
	my @OBJArray;
	foreach my $obj (@{$self->{LIST_DPI}}) {
			push(@OBJArray,$obj->get_timeinfo($Year,$Month,$Day,$Time));
	}
	return(_merge_arrays_unique(\@OBJArray));
}

# Purpose: Get a list of years which have events (those with *only* recurring not counted)
# Usage: my $ArrayRef = $object->get_years();
sub get_years {
	my $self = shift;
	my @OBJArray;
	foreach my $obj (@{$self->{LIST_DPI}}) {
			push(@OBJArray,$obj->get_years());
	}
	return(_merge_arrays_unique(\@OBJArray));
}

# Purpose: Get a list of months which have events (those with *only* recurring not counted)
# Usage: my $ArrayRef = $object->get_months();
sub get_months {
	my ($self, $Year) = @_;
	warn('get_months: STUB'); return(undef);
}

# Purpose: Get a parsed RRULE for the supplied UID
# Usage: my $Info = $object->get_RRULE(UID);
sub get_RRULE {
	my ($self, $UID) = @_;
	my $obj = $self->_locate_UID($UID);
	if(not $obj) {
		warn("ERR\n"); # FIXME
		return;
	}
	if(not $self->_verify_capab($obj,'RRULE')) {
		return false;
	}
	return($obj->get_RRULE($UID));
}

# Purpose: Get a list of dates which are excepted from recurrance for the supplied UID
# Usage: my $List = $object->get_exceptions(UID);
sub get_exceptions {
	my ($self, $UID) = @_;
	my $obj = $self->_locate_UID($UID);
	if(not $obj) {
		warn("ERR\n"); # FIXME
		return;
	}
	if(not $self->_verify_capab($obj,'exceptions')) {
		return false;
	}
	return($obj->get_exceptions($UID));
}

# Purpose: Set the EXDATEs for the supplied UID
# Usage: $object->set_exceptions(UID, EXCEPTIONS_ARRAY);
sub set_exceptions {
	my $self = shift;
	my $UID = shift;
	my $Exceptions = shift;
	my $obj = $self->_locate_UID($UID);
	if(not $obj) {
		warn("ERR\n"); # FIXME
		return;
	}
	if(not $self->_verify_capab($obj,'exceptions')) {
		return false;
	}
	return($obj->set_exceptions($UID,$Exceptions));
}

# Purpose: Write the data to a file.
# Usage: $object->write(FILE?);
sub write {
	my ($self, $file) = @_;
	warn('write: STUB'); return(undef);
}

# Purpose: Get raw iCalendar data
# Usage: my $Data = $object->get_rawdata();
# 	NOTE: WORKS ONLY ON PRIMARY
sub get_rawdata {
	my ($self) = @_;
	return($self->{PRIMARY}->get_rawdata());
}

# Purpose: Delete an iCalendar entry
# Usage: $object->delete(UID);
sub delete {
	my ($self, $UID) = @_;	# TODO verify UID
	my $obj = $self->_locate_UID($UID);
	if(not $obj) {
		warn("ERR\n"); # FIXME
		return;
	}
	return($obj->delete($UID));
}

# Purpose: Add an iCalendar entry
# Usage: $object->add(%EntryHash);
# 	NOTE: WORKS ONLY ON PRIMARY
sub add {
	my ($self, %Hash) = @_;
	return($self->{PRIMARY}->add(%Hash));
}

# Purpose: Change an iCalendar entry
# Usage: $object->change(%EntryHash);
sub change {
	my ($self, $UID, %Hash) = @_;
	my $obj = $self->_locate_UID($UID);
	if(not $obj) {
		warn("ERR\n"); # FIXME
		return;
	}
	return($obj->change($UID,%Hash));
}

# Purpose: Check if an UID exists
# Usage: $object->exists($UID);
sub exists {
	my($self,$UID) = @_;
	my $obj = $self->_locate_UID($UID);
	if($obj) {
		return(true);
	} else {
		return(false);
	}
}

# Purpose: Add another file
# Usage: $object->addfile(FILE);
sub addfile {
	my ($self,$File) = @_;
	warn('addfile: STUB'); return(undef);
}

# Purpose: Remove all loaded data
# Usage: $object->clean()
sub clean {
	my $self = shift;
	foreach my $obj (@{$self->{objects}}) {
		$obj->clean();
	}
}

# Purpose: Enable a feature
# Usage: $object->enable(FEATURE);
sub enable {
	my($self, $feature) = @_;
	foreach my $obj (@{$self->{objects}}) {
		$obj->enable($feature);
	}
}

# Purpose: Disable a feature
# Usage: $object->disable(FEATURE);
sub disable {
	my($self, $feature) = @_;
	foreach my $obj (@{$self->{objects}}) {
		$obj->disable($feature);
	}
}

# Purpose: Reload the data
# Usage: $object->reload();
sub reload {
	my $self = shift;
	foreach my $obj (@{$self->{objects}}) {
		$obj->reload();
	}
}

# Purpose: Set the prodid
# Usage: $object->set_prodid(PRODID);
sub set_prodid {
	my($self, $ProdId) = @_;
	foreach my $obj (@{$self->{objects}}) {
		$obj->set_prodid($ProdId);
	}
}

# -- Internal methods --
sub _locate_UID
{
	my $self = shift;
	my $UID = shift;
	foreach my $obj (@{$self->{objects}}) {
			if($obj->exists($UID)) {
				return($obj);
			}
	}
	return(undef);
}

sub _convert_UID
{
	warn('_convert_UID: STUB');
}

sub _get_real_UID
{
	my $self = shift;
	my $UID = shift;
	return($UID);
}

sub _verify_capab
{
	my $self = shift;
	my $object = shift;
	my $capab = shift;
	if(grep($object,$self->{$capab})) {
		return true;
	} else {
		return false;
	}
}

# -- Internal functions --

sub _merge_arrays_unique
{
	my $array = shift;
	if(not ref($array) or not ref($array) eq 'ARRAY') {
		warn("_merge_arrays_unique: Didn't get an arrayref :'( - got: ". ref($array));
		return(undef);
	}
	my @NewArray;
	foreach(@{$array}) {
		push(@NewArray,@{$_});
	}
	return(\@NewArray);
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
