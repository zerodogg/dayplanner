#!/usr/bin/perl
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
package DP::Plugin::HelloWorld;
use strict;
use warnings;
use DP::CoreModules::PluginFunctions qw(DPInfo);

sub new_instance
{
	my $this = shift;
	$this = {};
	bless($this);
	my $plugin = shift;
	$this->{plugin} = $plugin;
	$this->{plugin}->signal_connect('INIT',$this,'helloWorld');
	$this->{meta} =
	{
		name => 'HelloWorld',
		title => '"Hello World" plugin example',
		description => 'This is an example plugin, it is meant as a short example on how to write an extremely simple plugin for Day Planner. When active it will simply display a Hello World message each time Day Planner is started.',
		version => 0.1,
		apiversion => 1,
		author => 'Eskild Hustvedt',
		license => 'GNU General Public License version 3 or later',
	};
	return $this;
}

sub helloWorld
{
	DPInfo('Hello world');
}
