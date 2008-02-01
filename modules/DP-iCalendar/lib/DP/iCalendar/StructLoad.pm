#!/usr/bin/perl
# DP::iCalendar::StructLoad
# $Id$
# An iCalendar structure loader
# Copyright (C) Eskild Hustvedt 2008
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itthis. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# This module is capable of loading any file conforming to some simple rules.
# BEGIN: denotes a new tree level
# END:   denotes the end of the current level
# KEY:VALUE sets KEY in the current level to VALUE. You may have multiple KEY:VALUE pairs.
# A line beginning with a space (or any whitespace char) denotes a continuation of the previous KEY:VALUE pair

# TODO: Add writing
# TODO: Replace iCalendar.pm's current loading routine with this

use strict;
use warnings;
package DP::iCalendar::StructLoad;
use constant { true => 1, false => 0 };

our $VERSION;
$VERSION = 0.1;

# Purpose: Initialize a new object
# Usage: object = DP::iCalendar::StructLoad->new();
sub new
{
	my $class = shift;
	my $this = {};
	bless($this,$class);
	# The data structure will be saved here
	$this->{data} = {};
	$this->{ignoreAssertions} = false;
	return $this;
}

# Purpose: Load a new file
# Usage: $object->loadFile(path_to_file);
sub loadFile
{
	my $this = shift;
	my $file = shift;
	my $sLevel = 0;
	my %Struct;
	my @Nest;
	my $CurrRef = $this->{data};
	my $PrevValue;
	open(my $infile, '<',$file);
	while($_ = <$infile>)
	{
		s/[\r\n]+//;
		# If it's only whitespace, ignore it
		next if not /\S/;
		# First parse the contents, that is X:Y
		my $key = $_;
		$key =~ s/^([^:]+):.*$/$1/;
		my $value = $_;
		$value =~ s/^([^:]+):(.*)$/$2/;
		if ($key =~ /\s/ and not $key =~ /^\s/)
		{
			_parseWarn("key ($key:$value) contains whitespace! This is bad, other parsers might get very confused by that");
		}

		if (s/^\s//)
		{
			# Append to PrevValue
			my $prevLen = scalar(@{$PrevValue});
			$prevLen--;
			$PrevValue->[$prevLen] .= $_;
		}
		elsif ($key eq 'BEGIN')
		{
			# Check that it is a hash - the assert function dies if it isn't
			$this->_assertMustBeRef('HASH',$CurrRef,'CurrRef',true);

			if (not defined $CurrRef->{$value})
			{
				$CurrRef->{$value} = [];
			}
			else
			{
				$this->_assertMustBeRef('ARRAY',$CurrRef,'CurrRef',true);
			}
			my $pushNo = push(@{$CurrRef->{$value}}, {});
			$pushNo--;
			$CurrRef = $CurrRef->{$value}[$pushNo];
			push(@Nest,$CurrRef);
		}
		elsif ($key eq 'END')
		{
			pop(@Nest);
			my $nestSize = @Nest;
			$nestSize--;
			$CurrRef = $Nest[$nestSize];
		}
		elsif (defined($key) and defined($value))
		{
			if(not defined($CurrRef->{$key}))
			{
				$CurrRef->{$key} = [];
			}
			push(@{$CurrRef->{$key}},$value);
			$PrevValue = $CurrRef->{$key};
		}
		else
		{
			_parseWarn("Line unparseable: $_");
		}
	}
}

# Purpose: Write the file
# Usage: $object->writeFile();
sub writeFile
{
	my $this = shift;
}

# Purpose: Output a parser warning
# Usage: _parseWarn(message);
sub _parseWarn
{
	warn($_[0]);
}

# Purpose: Assert if a variable is what we want it to be and display useful errors if it isn't
# Usage: $this->_assertMustBeRef(refName,ref,varname,fatal);
# 	refName = the reference type expected, ie. HASH or ARRAY
# 	ref		= the variable that should be holding the reference
# 	varname = the name of the variable that is passed as ref, this is used for printing useful messages
# 	fatal	= true if we should die(), false if not
# Returns true if it suceeds, false if not (and fatal=false)
# NOTE that it can be turned completely off with $this->{ignoreAssertions} = true; - so do not
# DEPEND upon its return value.
sub _assertMustBeRef
{
	my $this = shift;
	# Allow this to be disabled
	if ($this->{ignoreAssertions})
	{
		return true;
	}

	my $refName = shift;
	my $ref = shift;
	if(not ref($ref) eq $refName)
	{
		my $varname = shift;
		my $fatal = shift;

		my $errMsg;
		# It wasn't, work hard to get a useful error message
		if(not ref($ref))
		{
			if(defined($ref))
			{
				$errMsg = "\$$varname turned out to NOT be a reference of type $refName, was an unknown var: $ref";
			}
			else
			{
				$errMsg = "\$$varname turned out to NOT be a reference of type $refName, was UNDEF!";
			}
		}
		else
		{
			$errMsg = "\$$varname turned out to NOT be a reference of type $refName, was a: ".ref($ref);
		}
		my ($caller_package, $caller_filename, $caller_line) = caller;
		$errMsg .= " on line $caller_line in $caller_filename";
		if ($fatal)
		{
			$errMsg = "FATAL: ".$errMsg;
			die($errMsg."\n");
		}
		else
		{
			warn("WARNING: ".$errMsg." - expect trouble\n");
			return false;
		}
	}
}
