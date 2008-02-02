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
	$this->{indexBy} = shift;
	$this->reindex();
	return($this);
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
	$this->{array}[$this->{index}{$indexed}] = undef;
}

# Purpose: Change an entry, using its indexed value
# Usage: $this->changeEntry(INDEXEDVALUE, NEWCONTENT);
sub changeEntry
{
	my $this = shift;
	my $indexed = shift;
	my $content = shift;
	my $ival = $this->{index}{$indexed};
	$this->{array}[$ival] = $content;
	delete($this->{index}{$indexed});
	$this->_appendToIndex($ival);
}

# Purpose: Add a new entry, automatically indexing in the process
# Usage: $this->addEntry(NEWENTRY);
sub addEntry
{
	my $this = shift;
	my $newentry = shift;
	my $i = push(@{$this->{array}},$newentry);
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
	my $var = $this->{array}[$i]->{$this->{indexBy}}[0];
	if(defined($var))
	{
		if(defined($this->{index}{$var}))
		{
			warn("DP::iCalendar::ArrayHashManager: index value $var belongs to ".$this->{index}{$var}." but $i also wants it. Duplicates. Ignoring $i\'s request\n");
		}
		else
		{
			$this->{index}{$var} = $i;
		}
	}
}
