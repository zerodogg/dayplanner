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
# Usage: my $object = DP::iCalendar->new(\%ConfRef);
sub new
{
	my $name = shift;
	my $this = {};
	bless($this,$name);
	$this->{config} = shift;
	$this->{stash} = {};
	$this->{signals} = {};
	$this->{currPlugin} = undef;
	$this->{abortCurrent} = false;
	$this->{tempVars} = [];
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

sub set_tempvar
{
	my $this = shift;
	my $name = shift;
	my $content = shift;
	push(@{$this->{tempVars}},$name);
	return $this->set_var($name,$content);
}

sub set_var
{
	my $this = shift;
	my $name = shift;
	my $content = shift;
	$this->{stash}{$name} = $content;
	if(not defined $content)
	{
		$this->_warn('set_var('.$name.',undef) called, did you mean to use ->delete_var()?');
	}
	return true;
}

sub delete_var
{
	my $this = shift;
	my $name = shift;
	delete($this->{stash}->{$name});
}

sub get_var
{
	my $this = shift;
	my $name = shift;
	return $this->{stash}{$name};
}

sub set_confval
{
	my $this = shift;
	my $name = shift;
	my $value = shift;
	$name = $this->_get_currName().'_'.$name;
	return $this->{config}{$name} = $value;
}

sub get_confval
{
	my $this = shift;
	my $name = shift;
	$name = $this->_get_currName().'_'.$name;
	return $this->{config}->{$name};
}

sub signal_connect
{
	my $this = shift;
	my $signal = shift;
	my $handlerModule = shift;
	my $handlerMethod = shift;
	if(not $this->{signals}{$signal})
	{
		$this->_warn('Plugin '.ref($handlerModule).' connected to unregistered signal: '.$signal);
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
			$this->{currPlugin} = $i->{module};
			eval('$i->{module}->'.$i->{method}.'($this);');
			my $e = $@;
			if ($e)
			{
				chomp($e);
				$this->_warn("Failure when emitting signal $signal: $e: ignoring");
			}
			$this->{currPlugin} = undef;
		}
	}
	else
	{
		$this->_warn('Emitted unregistered signal: '.$signal);
	}
	# Delete temporary variables
	foreach my $var(@{$this->{tempVars}})
	{
		$this->delete_var($var);
	}

	if ($this->{abortCurrent})
	{
		$this->{abortCurrent} = false;
		return true;
	}
	return false;
}

sub abort
{
	my $this = shift;
	$this->{abortCurrent} = true;
	return true;
}

# Summary: Mark something as a stub
# Usage: STUB();
sub STUB
{
    my ($stub_package, $stub_filename, $stub_line, $stub_subroutine, $stub_hasargs,
        $stub_wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
    warn "STUB: $stub_subroutine\n";
}

sub _warn
{
	shift;
	warn('*** Day Planner Plugins: '.shift(@_)."\n");
}

sub _get_currName
{
	my $this = shift;
	my $base;
	if(ref($this->{currPlugin}))
	{
		$base = ref($this->{currPlugin});
	}
	elsif ($this->{currPlugin})
	{
		$base = $this->{currPlugin};
	}
	else
	{
		my ($name_package, $name_filename, $name_line, $name_subroutine, $name_hasargs,
			$name_wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
		$base = $name_package;
	}
	$base =~ s/DP::Plugin:://g;
	$base =~ s/::/_/g;
	return $base;
}
1;
