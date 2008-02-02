#!/usr/bin/perl
# DP::iCalendar::ArrayHashManager
# $Id$
# A manager and lookup indexer of arrays of hashes
# Copyright (C) Eskild Hustvedt 2008
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itthis. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
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
	$this->{index} = {};
	$this->_createIndex();
	return($this);
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

# Purpose: Create an index
# Usage: $this->_createIndex();
sub _createIndex
{
	my $this = shift;
	for(my $i = 0; $i <= scalar(@{$this->{array}}); $i++)
	{
		if(defined($this->{array}[$i]))
		{
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
	}
}
