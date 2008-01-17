# DP::iCalendar::StructLoad
# $Id$
# An iCalendar structure loader
# Copyright (C) Eskild Hustvedt 2008
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# This module is capable of loading any file conforming to some simple rules.
# BEGIN: denotes a new tree level
# END:   denotes the end of the current level
# KEY:VALUE sets KEY in the current level to VALUE. You may have multiple KEY:VALUE pairs.
# A line beginning with a space (or any whitespace char) denotes a continuation of the previous KEY:VALUE pair

# TODO: Add writing
# TODO: Make it properly object-oriented
# TODO: Replace iCalendar.pm's current loading routine with this

use strict;
use warnings;
package DP::iCalendar::StructLoad;

sub new
{
}
sub load
{
	my $file = shift;
	my $sLevel = 0;
	my %Struct;
	my @Nest;
	my $CurrRef = \%Struct;
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
			# Check that it is a hash
			if(not ref($CurrRef) eq 'HASH')
			{
				# It wasn't, work hard to get a useful error message
				if(not ref($CurrRef))
				{
					if(defined($CurrRef))
					{
						die("FATAL: \$CurrRef turned out to NOT be a hashref, was an unknown var: $CurrRef");
					}
					else
					{
						die("FATAL: \$CurrRef turned out to NOT be a hashref, was UNDEF!");
					}
				}
				else
				{
					die("FATAL: \$CurrRef turned out to NOT be a hash, was a: ".ref($CurrRef));
				}
			}
			if (not defined $CurrRef->{$value})
			{
				$CurrRef->{$value} = [];
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
	#print Dumper(\%Struct);
}
sub _parseWarn
{
	warn($_[0]);
}
#use Data::Dumper;
#$Data::Dumper::Sortkeys=1;
load($ARGV[0]);
