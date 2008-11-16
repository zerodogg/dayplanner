# Day Planner plugin system
# Copyright (C) Eskild Hustvedt 2006, 2007, 2008
# $Id: dayplanner 1985 2008-02-03 12:48:43Z zero_dogg $
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package DP::CoreModules::Plugin;
use strict;
use warnings;
# Useful constants for prettier code
use constant { true => 1, false => 0 };

# Purpose: Create a new plugin instance
# Usage: my $object = DP::iCalendar->new();
sub new
{
	my $name = shift;
	my $this = {};
	bless($this,$name);
	$this->{stash} = {};
	$this->{signals} = {};
	return $this;
}

sub register_signals
{
	my $this = shift;
	my @Signals = @_;
	foreach(@Signals)
	{
		$this->{signals}{$_} = [];
	}
	return true;
}

sub set_data
{
	my $this = shift;
	my $name = shift;
	my $content = shift;
	$this->{stash}{$name} = $content;
	return true;
}

sub get_data
{
	my $this = shift;
	my $name = shift;
	return $this->{stash}{$name};
}

sub signal_connect
{
	my $this = shift;
	my $signal = shift;
	my $handlerModule = shift;
	my $handlerMethod = shift;
	if(not $this->{signals}{$signal})
	{
		$this->{signals}{$signal} = [];
	}
	push(@{$this->{signals}{$signal}}, { module => $handlerModule, method => $handlerMethod });
	return true;
}

sub signal_emit
{
	my $this = shift;
	my $signal = shift;
	if ($this->{signals}{$signal})
	{
		foreach my $i (@{$this->{signals}{$signal}})
		{
			eval('$i->{module}->'.$i->{method}.'();');
			my $e = $@;
			if ($e)
			{
				main::DPIntWarn("Failure when emitting signal $signal: $e: ignoring");
			}
		}
	}
	return true;
}

sub abort
{
	my $this = shift;
	STUB();
}

# Summary: Mark something as a stub
# Usage: STUB();
sub STUB
{
    my ($stub_package, $stub_filename, $stub_line, $stub_subroutine, $stub_hasargs,
        $stub_wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
    warn "STUB: $stub_subroutine\n";
}
1;
