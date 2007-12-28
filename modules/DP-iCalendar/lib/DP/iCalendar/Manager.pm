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
my @Capabilities = ('LIST_DPI','RRULE','SAVE','CHANGE','ADD','EXT_FUNCS','ICS_FILE_LOADING','RAWDATA','EXCEPTIONS','DELETE','RELOAD');

# -- Manager stuff --
sub new
{
	my $this = {};
	bless($this);
	$this->{UID_Cache} = {};
	$this->{'PRIMARY'} = undef;
	$this->{objects} = [];
	$this->{ProdId} = undef;
	$this->{capab} = {};
	foreach(@Capabilities) {
		$this->{$_} = [];
		$this->{capab}{$_} = {};
	}
	return($this);
}

sub add_object
{
	my $this = shift;
	my $object = shift;
	my $primary = shift;
	my $version = $object->get_manager_version();
	if(not $version eq '01_capable') {
		carp("DP::iCalendar::Manager: added_object: does not support this version. Supported: $version, this version: 01_capable");
	}
	push(@{$this->{objects}},$object);
	my $capabilities = $object->get_manager_capabilities();
	if(not defined($capabilities)) {
		carp('added_object: undef returned from get_manager_capabilities()')
	}
	foreach(@{$capabilities}) {
		if(defined($this->{$_})) {
			push(@{$this->{$_}},$object);
			$this->{capab}{$_}{$object} = true;
		} else {
			carp('Unknown capability: '.$_);
		}
	}
	if($primary) {
		# TODO: Ensure that PRIMARY has *ALL* capabilities
		$this->{'PRIMARY'} = $object;
	}
	if($this->{ProdId}) {
		$object->set_prodid($this->{ProdId});
	}
	if(not $this->{'PRIMARY'}) {
		carp('First object not PRIMARY. This might mean trouble');
	}
}

sub remove_object
{
	warn('remove_object: STUB');
}

sub list_objects
{
	my $this = shift;
	return($this->{objects});
}

sub get_primary
{
	my $this = shift;
	return($this->{'PRIMARY'});
}

# -- DP::iCalendar API wrapper --

# Purpose: Get information for a supplied UID
# Usage: my $Info = $object->get_info(UID);
sub get_info {
	my($this,$UID) = @_;
	my $obj = $this->_locate_UID($UID);
	if(not $obj) {
		return;
	}
	if(not $this->_verify_capab($obj,'DELETE',true)) {
		my $info = $obj->get_info($UID);
		$info->{'X-DPM-NODELETE'} = 'TRUE';
		return($info);
	}
	return($obj->get_info($UID));
}

# Purpose: Get information for the supplied month (list of days there are events)
# Usage: my $TimeRef = $object->get_monthinfo(YEAR,MONTH,DAY);
sub get_monthinfo {
	my($this, $Year, $Month) = @_;	# TODO: verify that they are set
	my @OBJArray;
	foreach my $obj (@{$this->{LIST_DPI}}) {
		push(@OBJArray,$obj->get_monthinfo($Year,$Month));
	}
	return(_merge_arrays_unique(\@OBJArray));
}

# Purpose: Get information for the supplied date (list of times in the day there are events)
# Usage: my $TimeRef = $object->get_dateinfo(YEAR,MONTH,DAY);
sub get_dateinfo {
	my($this, $Year, $Month, $Day) = @_;	# TODO: verify that they are set
	my @OBJArray;
	foreach my $obj (@{$this->{LIST_DPI}}) {
		push(@OBJArray,$obj->get_dateinfo($Year,$Month,$Day));
	}
	return(_merge_arrays_unique(\@OBJArray));
}

# Purpose: Get the list of UIDs for the supplied time
# Usage: my $UIDRef = $object->get_timeinfo(YEAR,MONTH,DAY,TIME);
sub get_timeinfo {
	my($this, $Year, $Month, $Day, $Time) = @_;	# TODO: verify that they are set
	my @OBJArray;
	foreach my $obj (@{$this->{LIST_DPI}}) {
		push(@OBJArray,$obj->get_timeinfo($Year,$Month,$Day,$Time));
	}
	return(_merge_arrays_unique(\@OBJArray));
}

# Purpose: Get a list of years which have events (those with *only* recurring not counted)
# Usage: my $ArrayRef = $object->get_years();
sub get_years {
	my $this = shift;
	my @OBJArray;
	foreach my $obj (@{$this->{LIST_DPI}}) {
		push(@OBJArray,$obj->get_years());
	}
	return(_merge_arrays_unique(\@OBJArray));
}

# Purpose: Get a list of months which have events (those with *only* recurring not counted)
# Usage: my $ArrayRef = $object->get_months();
sub get_months {
	my ($this, $Year) = @_;
	my @OBJArray;
	foreach my $obj (@{$this->{LIST_DPI}}) {
		push(@OBJArray,$obj->get_months($Year));
	}
	return(_merge_arrays_unique(\@OBJArray));
}

# Purpose: Get a parsed RRULE for the supplied UID
# Usage: my $Info = $object->get_RRULE(UID);
sub get_RRULE {
	my ($this, $UID) = @_;
	my $obj = $this->_locate_UID($UID);
	if(not $obj) {
		return;
	}
	if(not $this->_verify_capab($obj,'RRULE',true)) {
		return false;
	}
	return($obj->get_RRULE($UID));
}

# Purpose: Get a list of dates which are excepted from recurrance for the supplied UID
# Usage: my $List = $object->get_exceptions(UID);
sub get_exceptions {
	my ($this, $UID) = @_;
	my $obj = $this->_locate_UID($UID);
	if(not $obj) {
		return;
	}
	if(not $this->_verify_capab($obj,'EXCEPTIONS',true)) {
		return false;
	}
	return($obj->get_exceptions($UID));
}

# Purpose: Set the EXDATEs for the supplied UID
# Usage: $object->set_exceptions(UID, EXCEPTIONS_ARRAY);
sub set_exceptions {
	my $this = shift;
	my $UID = shift;
	my $Exceptions = shift;
	my $obj = $this->_locate_UID($UID);
	if(not $obj) {
		return;
	}
	if(not $this->_verify_capab($obj,'EXCEPTIONS')) {
		return false;
	}
	return($obj->set_exceptions($UID,$Exceptions));
}

# Purpose: Write the data to a file.
# Usage: $object->write(FILE?);
sub write {
	my ($this, $file) = @_;
	if(not $this->_verify_capab($this->{'PRIMARY'},'SAVE')) {
		return false;
	}
	if($file) {
		if(not $this->{'PRIMARY'}) {
			carp('No primary set - unable to '."write($file)");
			return(undef);
		}
		return $this->{'PRIMARY'}->write($file);
	} else {
		foreach my $obj(@{$this->{'SAVE'}}) {
			$obj->write();
		}
	}
}

# Purpose: Get raw iCalendar data
# Usage: my $Data = $object->get_rawdata();
# 	NOTE: WORKS ONLY ON PRIMARY
sub get_rawdata {
	my ($this) = @_;
	return($this->{PRIMARY}->get_rawdata());
}

# Purpose: Delete an iCalendar entry
# Usage: $object->delete(UID);
sub delete {
	my ($this, $UID) = @_;	# TODO verify UID
	my $obj = $this->_locate_UID($UID);
	if(not $obj) {
		return;
	}
	if(not $this->_verify_capab($obj,'DELETE')) {
		return;
	}
	return($obj->delete($UID));
}

# Purpose: Add an iCalendar entry
# Usage: $object->add(%EntryHash);
# 	NOTE: WORKS ONLY ON PRIMARY
sub add {
	my ($this, %Hash) = @_;
	return($this->{PRIMARY}->add(%Hash));
}

# Purpose: Change an iCalendar entry
# Usage: $object->change(%EntryHash);
sub change {
	my ($this, $UID, %Hash) = @_;
	my $obj = $this->_locate_UID($UID);
	if(not $obj) {
		return;
	}
	# Check if we can call obj->change() - if we can't then we ->add it to PRIMARY
	if (not $this->_verify_capab($obj,'CHANGE',true)) {
		return($this->_move_UID_to_PRIMARY($UID,$obj,%Hash));
	}

	return($obj->change($UID,%Hash));
}

# Purpose: Check if an UID exists
# Usage: $object->exists($UID);
sub exists {
	my($this,$UID) = @_;
	my $obj = $this->_locate_UID($UID,true);
	if($obj) {
		return(true);
	} else {
		return(false);
	}
}

# Purpose: Add another file
# Usage: $object->addfile(FILE);
sub addfile {
	my ($this,$File) = @_;
	return($this->{PRIMARY}->addfile($File));
}

# Purpose: Remove all loaded data
# Usage: $object->clean()
sub clean {
	my $this = shift;
	foreach my $obj (@{$this->{objects}}) {
		$obj->clean();
	}
}

# Purpose: Enable a feature
# Usage: $object->enable(FEATURE);
sub enable {
	my($this, $feature) = @_;
	foreach my $obj (@{$this->{objects}}) {
		$obj->enable($feature);
	}
}

# Purpose: Disable a feature
# Usage: $object->disable(FEATURE);
sub disable {
	my($this, $feature) = @_;
	foreach my $obj (@{$this->{objects}}) {
		$obj->disable($feature);
	}
}

# Purpose: Reload the data
# Usage: $object->reload();
sub reload {
	my $this = shift;
	foreach my $obj (@{$this->{RELOAD}}) {
		$obj->reload();
	}
}

# Purpose: Set the prodid
# Usage: $object->set_prodid(PRODID);
sub set_prodid {
	my($this, $ProdId) = @_;
	$this->{ProdId} = $ProdId;
	foreach my $obj (@{$this->{objects}}) {
		$obj->set_prodid($ProdId);
	}
}

# -- Internal methods --
sub _locate_UID
{
	my $this = shift;
	my $UID = shift;
	my $silent = shift;
	if($this->{UID_Cache}{$UID}) {
		return($this->{UID_Cache}{$UID});
	}
	foreach my $obj (@{$this->{objects}}) {
		if($obj->exists($UID)) {
			$this->{UID_Cache}{$UID} = $obj;
			return($obj);
		}
	}
	carp("DP::iCalendar::Manager: Unable to locate owner of $UID: invalid UID") if not $silent;
	return(undef);
}

sub _verify_capab
{
	my $this = shift;
	my $object = shift;
	my $capab = shift;
	my $silent = shift;
	if($this->{capab}{$capab}{$object}) {
		return true;
	} else {
		carp("DP::iCalendar::Manager: Can't perform requested action: owner (".ref($object).") doesn't support capability $capab") if not $silent;
		return false;
	}
}

# -- Internal functions --

sub _move_UID_to_PRIMARY
{
	my $this = shift;
	my $UID = shift;
	my $CurrentOwner = shift;
	my (%Hash) = @_;
	if($this->_verify_capab($CurrentOwner,'DELETE',true)) {
		$CurrentOwner->delete($UID);
	}
	$Hash{UID} = $UID;
	$this->{UID_Cache}{$UID} = $this->{PRIMARY};
	return($this->add(%Hash));
}

sub _merge_arrays_unique
{
	my $array = shift;
	if(not ref($array) or not ref($array) eq 'ARRAY') {
		warn("_merge_arrays_unique: Didn't get an arrayref :'( - got: ". ref($array));
		return(undef);
	}
	my %Aindex;
	my @NewArray;
	foreach(@{$array}) {
		if(ref($_) eq 'ARRAY') {
			foreach my $val (@{$_})
			{
				if(not $Aindex{$val})
				{
					$Aindex{$val} = true;
					push(@NewArray,$val);
				}
			}
		}
		else
		{
			warn("_merge_arrays_unique: Array of arrays included nonarray value: ".ref($_).'='.$_);
		}
	}
	undef %Aindex;
	return(\@NewArray);
}

__END__

=pod

=head1 NAME

DP::iCalendar::Manager - Manager of multiple DP::iCalendar-compatible objects

=head1 VERSION

0.1

=head1 SYNOPSIS

This module gives you a unified interface to multiple DP::iCalendar-compatible
objects and handles special cases such as moving an event to the local ("primary")
calendar.

	use DP::iCalendar;

	my $Manager = DP::iCalendar::Manager->new();
	$Manager->add_object($iCalendar,true);
	$Manager->add_object($onlineSubscription,false);
	...

=head1 DESCRIPTION

DP::iCalendar::Manager handles the case where you want to have multiple
DP::iCalendar-compatible objects. It merges them into a single interface and
handles special cases such as calendars that can't be changed (online subscriptions
for instance). For those calendars it seemlessly adds support for changing them,
it implements this by copying the UID to the local primary calendar and
letting the changes be there.

=head1 METHODS

DP::iCalendar::Manager supports the same interface as DP::iCalendar.
See the DP::iCalendar module for more information.

The following are methods specific to DP::iCalendar::Manager:

=head2 my $object = DP::iCalendar::Manager->new();

Creates a new DP::iCalendar::Manager object.

=head2 $object->add_object(OBJECT, PRIMARY?)

Adds a new object to the manager. The second parameter
sets if the object is a primary object or not.
The primary object of the manager will be the one new entries
are added to and moved to.

=head2 $list = $object->list_objects();

Returns an arrayref containing all the objects in the manager.

=head2 $object->remove_object(OBJ);

Removes an object from the manager.

=head1 API

This section explains how the API works. This is information for developers
of modules that should be managed by the DP::iCalendar::Manager. This is not the
public interface. For information about the public end-user API. See DP::iCalendar

=head2 Essentials

First of all your objhect must be able to generate iCalendar events.
It does NOT have to generate full iCalendar files, nor be able to read
iCalendar information (although the manager can handle that aswell).

Secondly there are two methods which must be available in the object.
These are:

=head3 object->get_manager_version()

This should return a string containing the manager API version that
the object implements.

=head3 object->get_managar_capabilities()

This should return an arrayref of supported capabilities. See the capabilites
section for more information.

=head2 Capabilities

DP::iCalendar::Manager works on a set of capabilities which defines
what each of the managed modules support. And attempts to emulate
functionality not available.

The essential functionality which MUST be available is the get_uid() and
exists() methods. See DP::iCalendar for information about what they
are suppose to do.

The following is a list of capabilities and the DP::iCalendar methods
required for them to be supported.

Capability:                Methods:
LIST_DPI                   get_monthinfo() get_dateinfo() get_timeinfo() get_years() get_months()
RRULE                      get_RRULE()
SAVE                       write()
RAWDATA                    get_rawdata()
CHANGE                     add() change()
DELETE                     delete()
EXCEPTIONS                 get_exceptions() set_exceptions()
EXT_FUNCS                  enable() disable()

See DP::iCalendar for documentation on parameters and
return values from these methods.

If DELETE is missing the DP::iCalendar::Manager will tell the user that
it can't be deleted.

If CHANGE is missing then DP::iCalendar will move the event to the PRIMARY
object.
