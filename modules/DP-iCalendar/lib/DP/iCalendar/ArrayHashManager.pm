#!/usr/bin/perl
# DP::iCalendar::ArrayHashManager
# $Id$
# A manager and lookup indexer of arrays of hashes
# Copyright (C) Eskild Hustvedt 2008
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itthis. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# This module manages an arrayref (array of hashes)
# and indexes the array by one of the hash values.
# Allows simple editing of the array without having to do all sort
# of dirty stuff manually.

use strict;
use warnings;
package DP::iCalendar::ArrayHashManager;
use constant { true => 1, false => 0 };

our $VERSION;
$VERSION = 0.1;

# Purpose: Create a new manager object
# Usage: DP::iCalendar::ArrayHashManager->new(arrayref,indexby)
sub new
{
	my $class = shift;
	my $this = {};
	bless($this,$class);
	$this->{array} = shift;
	if(not ref($this->{array}))
	{
		die("DP::iCalendar::ArrayHasManager: FATAL, I don't have a reference");
	}
	$this->{indexBy} = shift;
	$this->reindex();
	return($this);
}

# Purpose: Check if an indexed value exists or not
# Usage: bool = $this->exists(INDEXVALUE);
sub exists
{
	my $this = shift;
	my $indexval = shift;
	if(defined($this->{index}{$indexval}))
	{
		return true;
	}
	return false;
}

# Purpose: List all values available (all indexed values)
# Usage: $valuelist = $this->listvalues();
sub listvalues
{
	my $this = shift;
	return keys(%{$this->{index}});
}

# Purpose: Reindex the entire array
# Usage: $object->reindex();
sub reindex
{
	my $this = shift;
	$this->{index} = {};
	$this->_createIndex();
}

# Purpose: Access an entry by its indexed value
# Usage: $this->getEntry(VALUE);
sub getEntry
{
	my $this = shift;
	my $getval = shift;
	if(defined($this->{index}{$getval}))
	{
		return($this->{array}[$this->{index}{$getval}]);
	}
	else
	{
		return undef;
	}
}

# Purpose: Delete an entry, using its indexed value
# Usage: $this->deleteEntry(VALUE);
sub deleteEntry
{
	my $this = shift;
	my $indexed = shift;
	# Forget it
	$this->{array}[$this->{index}{$indexed}] = undef;
	delete($this->{index}{$indexed});
	return true;
}

# Purpose: Change an entry, using its indexed value
# Usage: $this->changeEntry(INDEXEDVALUE, NEWCONTENT);
sub changeEntry
{
	my $this = shift;
	my $indexed = shift;
	my $content = shift;
	my $ival = $this->{index}{$indexed};
	if(defined($ival))
	{
		$this->{array}[$ival] = $content;
		delete($this->{index}{$indexed});
		return $this->_appendToIndex($ival);
	}
	else
	{
		return $this->addEntry($content);
	}
}

# Purpose: Add a new entry, automatically indexing in the process
# Usage: $this->addEntry(NEWENTRY);
sub addEntry
{
	my $this = shift;
	my $newentry = shift;
	my $i = push(@{$this->{array}},$newentry);
	$i--;
	$this->_appendToIndex($i);
}

# Purpose: Create an index
# Usage: $this->_createIndex();
sub _createIndex
{
	my $this = shift;
	for(my $i = 0; $i <= scalar(@{$this->{array}}); $i++)
	{
		if(defined($this->{array}[$i]))
		{
			$this->_appendToIndex($i);
		}
	}
}

# Purpose: Append something to the index if possible
# Usage: $this->_appendToIndex(arrayIndexNo);
sub _appendToIndex
{
	my $this = shift;
	my $i = shift;
	if(not ref($this->{array}[$i]))
	{
		if(defined($this->{array}[$i]))
		{
			warn("DP::iCalendar::ArrayHashManager: Array entry $i was not a reference. Colour me confused. Ignoring it. It was: '$this->{array}[$i]'\n");
		}
		else
		{
			warn("DP::iCalendar::ArrayHashManager: Array entry $i was not a reference. Colour me confused. Ignoring it. It was undef\n");
		}
		return;
	}
	my $var = $this->{array}[$i]->{$this->{indexBy}}[0];
	if(not defined($var) or not length($var))
	{
		my $rndString = 'DP-NIDX-'.time().rand(1000).rand(1000);
		$var = $rndString;
		$this->{array}[$i]->{$this->{indexBy}}[0] = $rndString;
		# Uh oh. No value to index by. Now what do we do.
		warn("DP::iCalendar::ArrayHashManager: Array entry $i did not have an ".$this->{indexBy}."! This is bad. Generated random string '$rndString', using that instead");
	}
	if(defined($var))
	{
		if(defined($this->{index}{$var}))
		{
			my $IsEQ = true;
			# Okay, it seems we've got a problem. The index value already exists.
			# So either we've got a dupe on our hands, or a broken file with multiple entries with the defined index value.
			# Now we iterate through the two events, comparing the first value of each entry. If they are not
			# equal then it means the two events are not equal either. Thus we create a new unique index value.
			foreach my $k (keys(%{$this->{array}[$this->{index}{$var}]}))
			{
				if (not $this->{array}[$i]{$k}[0] eq $this->{array}[$this->{index}{$var}]{$k}[0])
				{
					$IsEQ = false;
					last;
				}
			}
			# Is it equal?
			if ($IsEQ)
			{
				# If so, dupe. Don't bother doing anything more.
				if(defined($ENV{DP_AHM_DeleteDupes}) and $ENV{DP_AHM_DeleteDupes} eq '1')
				{
					warn("DP::iCalendar::ArrayHashManager: ".$this->{indexBy}." '$var' belongs to ".$this->{index}{$var}." but $i also wants it. Duplicates. Deleting $i as requested in the environment variable DP_AHM_DeleteDupes\n");
					$this->{array}[$i] = undef;
				}
				else
				{
					warn("DP::iCalendar::ArrayHashManager: ".$this->{indexBy}." '$var' belongs to ".$this->{index}{$var}." but $i also wants it. Duplicates. Ignoring $i\'s request\n");
				}
				return false;
			}
			else
			{
				# It's not, generate a new index value by appending some random numbers to it.
				my $newIdx = $var;
				while(defined($this->{index}{$newIdx}))
				{
					$newIdx.= int(rand(10000));
				}
				# Warn about the condition, the file is cleary broken (even though we have now fixed it)
				warn("DP::iCalendar::ArrayHashManager: ".$this->{indexBy}." '$var' belongs to ".$this->{index}{$var}." but $i also wants it and is not a duplicate. Renamed $i\'s ".$this->{indexBy}." to '$newIdx'.\n");
				# Set the new index value
				$this->{array}[$i]{$this->{indexBy}}[0] = $newIdx;
				# And finally, append this to our index. Our job is done.
				$this->{index}{$newIdx} = $i;
				return true;
			}
		}
		else
		{
			$this->{index}{$var} = $i;
			return true;
		}
	}
}
1;
