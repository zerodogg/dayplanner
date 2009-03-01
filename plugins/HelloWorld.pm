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

# This plugin is meant as a short tutorial and example on how to write
# a Day Planner plugin.

# First, the namespace must be DP::Plugin::YourPluginName
package DP::Plugin::HelloWorld;
use strict;
use warnings;

# DP::CoreModules::PluginFunctions exports several useful functions form
# the core of DP
use DP::CoreModules::PluginFunctions qw(DPInfo UpdatedData);
# DP::iCalendar is the iCalendar parser used in DP, most of the time
# you'll use the internal object that DP uses already, so you won't have to
# load it, but it does have some useful functions.
use DP::iCalendar qw(iCal_ConvertFromUnixTime iCal_ParseDateTime iCal_GenDateTime);

# This is the constructor for the plugin, if it is not present, your plugin will not
# load. Its parameter is the internal plugin object, that you can
# hook into as a signal handler, and you can register new signals.
sub new_instance
{
	# Bless ourselves
	my $this = shift;
	$this = {};
	bless($this);
	# Get the plugin object, and stash it in ourself so that we can use it later
	my $plugin = shift;
	$this->{plugin} = $plugin;
	# Connect to the init sinal, this one will display a "Hello World" dialog box,
	# as well as adding a temporary "Hello World" event.
	$this->{plugin}->signal_connect('INIT',$this,'helloWorld');
	# Note that you can connect to a signal as many times as you'd like. This time
	# we're connecting using init_plugin_handlers. This method initializes signals
	# that are expored by other plugins.
	$this->{plugin}->signal_connect('INIT',$this,'init_plugin_handlers');
	# And, when DP is shutting down, clean up after us.
	$this->{plugin}->signal_connect('SHUTDOWN',$this,'cleanWorld');

	# This is the metadata for this plugin. It is used when installing, resolving dependencies
	# (if any), letting DP know which API version this plugin is using as well as other
	# random metadata used by the plugin system. Not all are represented here, see other
	# plugins for some more advanced metadata
	$this->{meta} =
	{
		# The short name of the plugin, as used in the namespace and filename.
		name => 'HelloWorld',
		# The real name of the plugin, this can be longer
		title => '"Hello World" plugin example',
		# The full description of the plugin
		description => 'This is an example plugin, it is meant as a short example on how to write an extremely simple plugin for Day Planner. When active it will display a Hello World message each time Day Planner is started, and add a temporary "hello world" event on the current date.',
		# The version of the plugin
		version => 0.1,
		# The Day Planner plugin API version we're using
		apiversion => 1,
		# The author of the plugin
		author => 'Eskild Hustvedt',
		# And finally, the license of the plugin
		license => 'GNU General Public License version 3 or later',
	};
	# Now, return ourself
	return $this;
}

# This is the method that we're using to initialize some additional signal handlers
# for signals that might not be available until after we have been initialized,
# ie. signals that are emitted by plugins.
sub init_plugin_handlers
{
	my $this = shift;
	# Clean up before a DPS sync
	# This is a signal emitted by the ServicesSync plugin before it performs the
	# sync. We use signal_connect_ifavailable because this is a signal emitted by a plugin,
	# so its presence depends on if the plugin is loaded or not, and when we use ifavailable
	# the plugin handler will do all the heavylifting of checking for its presence for us,
	# and if it's not there then it will simply ignore the connection.
	#
	# We do this so that the user does not get our hello world event synchronized upstream,
	# we remove the event before the sync is performed.
	$this->{plugin}->signal_connect_ifavailable('DPS_PRE_SYNCHRONIZE',$this,'cleanWorld');
	# And after the sync has finished, we re-add it.
	$this->{plugin}->signal_connect_ifavailable('DPS_POST_SYNCHRONIZE',$this,'helloWorldMkEvent');
}

# this is our hello world handler, it runs helloWorldMkEvent and displays a simple
# hello world dialog box.
sub helloWorld
{
	my $this = shift;
	$this->helloWorldMkEvent();
	DPInfo('Hello world');
}

# This creates our temporary event.
sub helloWorldMkEvent
{
	my $this = shift;
	# Get the DP::iCalendar object
	my $ical = $this->{plugin}->get_var('calendar');
	# Ensure that tehre isn't an event like this already
	$this->cleanWorld;
	# Get the current year, month, day and time. This would be just as well
	# if we would have just used localtime(), but this here shows how you can use
	# the various iCal_*Time functions
	my ($year,$month,$day,$time) = iCal_ParseDateTime(iCal_ConvertFromUnixTime(time));
	#Get the dtstart, which is today.
	my $dtstart = iCal_GenDateTime($year,$month,$day);
	# The event hash, these are iCalendar KEY => VALUE pairs.
	my %event = (
		UID => 'DP-HelloWorldPluginString',
		DTSTART => $dtstart,
		SUMMARY => 'Hello world',
	);
	# Add the event.
	$ical->add(%event);
	# Let Day Planner know we added an event, and tell it not to think too much about it,
	# by giving the first argument as true (see the day planner source for the internals on this).
	#
	# If we don't let DP know then the UI will not get refreshed and the user won't
	# see the event until she switches back and forth to this date.
	UpdatedData(1);
}

# Our cleanup handler
sub cleanWorld
{
	my $this = shift;
	# Get the iCalendar object
	my $ical = $this->{plugin}->get_var('calendar');
	# Check if our event exists
	if ($ical->exists('DP-HelloWorldPluginString'))
	{
		# It existed, so delete it.
		$ical->delete('DP-HelloWorldPluginString');
	}
}

# We should return true like a good module
1;
