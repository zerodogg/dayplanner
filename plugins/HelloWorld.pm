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
use DP::CoreModules::PluginFunctions qw(DPInfo UpdatedData);
use DP::iCalendar qw(iCal_ConvertFromUnixTime iCal_ParseDateTime iCal_GenDateTime);

sub new_instance
{
	my $this = shift;
	$this = {};
	bless($this);
	my $plugin = shift;
	$this->{plugin} = $plugin;
	$this->{plugin}->signal_connect('INIT',$this,'helloWorld');
	$this->{plugin}->signal_connect('POST_INIT',$this,'init_plugin_handlers');
	# Clean up on exit
	$this->{plugin}->signal_connect('SHUTDOWN',$this,'cleanWorld');

	$this->{meta} =
	{
		name => 'HelloWorld',
		title => '"Hello World" plugin example',
		description => 'This is an example plugin, it is meant as a short example on how to write an extremely simple plugin for Day Planner. When active it will display a Hello World message each time Day Planner is started, and add a temporary "hello world" event on the current date.',
		version => 0.1,
		apiversion => 1,
		author => 'Eskild Hustvedt',
		license => 'GNU General Public License version 3 or later',
	};
	return $this;
}

sub init_plugin_handlers
{
	my $this = shift;
	# Clean up before a DPS sync
	$this->{plugin}->signal_connect_ifavailable('DPS_PRE_SYNCHRONIZE',$this,'cleanWorld');
	# Restart self after a sync
	$this->{plugin}->signal_connect_ifavailable('DPS_POST_SYNCHRONIZE',$this,'helloWorldMkEvent');
}

sub helloWorld
{
	my $this = shift;
	$this->helloWorldMkEvent();
	DPInfo('Hello world');
}

sub helloWorldMkEvent
{
	my $this = shift;
	my $ical = $this->{plugin}->get_var('calendar');
	$this->cleanWorld;
	my ($year,$month,$day,$time) = iCal_ParseDateTime(iCal_ConvertFromUnixTime(time));
	my $dtstart = iCal_GenDateTime($year,$month,$day);
	my %event = (
		UID => 'DP-HelloWorldPluginString',
		DTSTART => $dtstart,
		SUMMARY => 'Hello world',
	);
	$ical->add(%event);
	UpdatedData(1);
}

sub cleanWorld
{
	my $this = shift;
	my $ical = $this->{plugin}->get_var('calendar');
	if ($ical->exists('DP-HelloWorldPluginString'))
	{
		$ical->delete('DP-HelloWorldPluginString');
	}
}
