# Day Planner plugin system
# Copyright (C) Eskild Hustvedt 2012
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

package DP::Plugin;
use Carp qw(croak);
use Moo;

our @CARP_NOT = ('DP::CoreModules::Plugin');

has '__plugin' => (
    is => 'ro',
    required => 1,
);

sub p_register_events
{
    my $this = shift;
    return $this->__plugin->register_events(@_);
}

sub p_set_var
{
    my $this = shift;
    return $this->__plugin->set_var(@_);
}

sub p_get_var
{
    my $this = shift;
    return $this->__plugin->get_var(@_);
}

sub p_delete_var
{
    my $this = shift;
    return $this->__plugin->delete_plugin_var(@_);
}

sub p_get_confval
{
    my $this = shift;
    return $this->__plugin->get_confval($this,@_);
}

sub p_set_confval
{
    my $this = shift;
    return $this->__plugin->set_confval($this,@_);
}

sub p_subscribe
{
    my $this = shift;
    my $event = shift;
    my $codeRef = shift;
    if (!ref($codeRef) || ref($codeRef) ne 'CODE')
    {
        $this->__croak('Invalid usage of p_subscribe(): Second parameter is not a coderef');
    }
    return $this->__plugin->subscribe($this,$event,$codeRef,@_);
}

sub p_subscribe_ifavailable
{
    my $this = shift;
    my $event = shift;
    my $codeRef = shift;
    if (!ref($codeRef) || ref($codeRef) ne 'CODE')
    {
        $this->__croak('Invalid usage of p_subscribe_ifavailable(): Second parameter is not a coderef');
    }
    return $this->__plugin->subscribe_ifavailable($this,$event,$codeRef,@_);
}

sub p_publish
{
    my $this = shift;
    return $this->__plugin->publish(@_);
}

sub p_get_plugin_object
{
    my $this = shift;
    return $this->__plugin;
}

sub __croak
{
    my $this = shift;
    my $message = shift;
    my ($croak_package, $croak_filename, $croak_line, $croak_subroutine, $croak_hasargs,
        $croak_wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
    die($message.' at '.$croak_filename.' '.$croak_line."\n");

}

1;
__END__
=head1 INTRODUCTION

Day Planner offers a plugin system that lets you hook into most parts of the
program.

All plugins are perl objects. These objects communicate with Day Planner
via a special plugin object that it gets supplied. This plugin object gives
access to internal data, and handles event passing.

Day Planner comes with various plugins by default, ranging from the
basic hello world to synchronization. Take a look at the source code
of these plugins to get a feel for it.

=head1 THE BASIC PLUGIN LAYOUT

Day Planner plugins are L<Moo>-objects that extend DP::Plugin.

A plugin can have an earlyInit method. This is run immediately after
construction. In this method you should only do initialization that
is required for your plugin to be operation before the INIT event is
emitted and it can finalize its initialization.  See the builtin events
section for more information about the INIT event.

=head1 THE PLUGIN METHODS

Extending DP::Plugin grants you a number of methods that allows you to interact
with Day Planner. All of these methods are available on your object (ie. from $self).

Note that all methods are prefixed by either p_ (for public plugin methods) or
__ (for private data), so you may name your methods any way you want as long as
they don't crash with these two namespaces.

The following methods are made available:

=over

=item p_register(B<ARRAY>)

This method takes an array of zero or more elements as its parameter.
It is used to register a event (not a handler) for use. You should
call this if your plugin will emit events. The plugin handler ignores
all emitted events that has not been previously registered.

=item p_event_emit(B<STRING> event)

Emits the event supplied, calling all listeners in turn.

=item p_subscribe(B<STRING> event, B<CODEREF> callback)

Subscribes to the supplied event. Whenever that event is emitted, the
supplied coderef will be done.

Callbacks are called inside of an eval, so any die()s or crashes will be
caught by the plugin handler.

=item p_subscribe_ifavailable(B<STRING> event, B<CODEREF> callback)

The same as p_subscribe, but this will not attach to (or warn about)
unregistered events, instead it will silently ignore the request.

Its primary use is connecting to events that belong to another plugin,
and it should not be used within the constructor, but within the INIT
event (see the I<BUILTIN EVENTS> section).

If there's any data that is provided by the emitter, it is provided
to callback as a hashref. See the BUILTIN EVENTS section for information
about what data each event gives you.

=item p_set_var(B<STRING> variable name, B<VARIABLE> content)

This is used for sharing data. Sets the variable supplied to the content
supplied.

=item p_get_var(B<STRING> variable name)

Gets the contents of the shared variable supplied.

=item delete_plugin_var(B<STRING> variable name)

Deletes the variable supplied. You should never use this to delete
content that is shared by anything other than your plugin.

=item p_set_confval(B<STRING> name, B<STRING> value)

Sets the configuration value name to value for THIS plugin. The plugin object
automatically handles making it unique for your plugin, so you do not need to
ensure that the name is unique for the entire program, only for your plugin.
The configuration values are automatically saved and loaded by Day Planner.

=item p_get_confval(B<STRING> name)

Gets the configuration value supplied. This retrieves settings set using
p_set_confval()

=back

=head1 USEFUL DAY PLANNER FUNCTIONS

Day Planner has many useful functions that you can import from various sources.
The most common ones are found in L<DP::CoreModules::PluginFunctions>, and allow
access to such things as telling Day Planner that data has been updated, and
displaying simple dialog boxes, as well as an Assert() function. See the
documentation for that module for more information.

The calendar interface is provided by L<DP::iCalendar>, and you can find
various generic helpers in L<DP::GeneralHelpers>.

=head1 GLOBALLY SHARED VARIABLES

These variables are available with p_get_var() throughout the lifetime of the
application. Some of these variables are however not available before after the
INIT event has been emitted.

=over

=item MainWindow

This is the main L<Gtk2::Window> for Day Planner. Not available
before the INIT event.

=item CalendarWidget

This is the main L<Gtk2::Calendar> widget displayed in the main
Day Planner window. Not available before the INIT event.

NOTE: If you switch the date, you have to remember to call:
I<$object->p_event_emit('day-selected')> after you have switched it.
Day Planner will not redraw the list of events until you do.

=item calendar

The L<DP::iCalendar::Manager> object.

=item state

A hashref to the state.conf configuration hash. You should not modify
this, but use set/p_get_confval() instead.

=item config

A hashref to the dayplanner.conf configuration hash. This can not hold
any configuration values other than those predefined. If you make changes
make sure that they are valid.

=item Gtk2Init

Boolean, true if gtk2 has been initialized.

=item i18n

The L<DP::GeneralHelpers::i18n> object.

=item version

The Day Planner version number.

=item confdir

The path to the Day Planner configuration directory.

=back

=head1 BUILTIN EVENTS

=over

=item CREATE_MENUITEMS

NOTE: This event is emitted BEFORE the INIT event.

This lets you modify the Day Planner menus.
It gives a hashref with the following keys to the callbacks:

=over

=item menu_importExport, menu_addRemove menu_preferences 

Arreyrefs to an array containing elements for a L<Gtk2::ItemFactory>.
You can push additional items that you wish added to the menu onto these
variables. Each correspond to a single section in the menu (importExport
at the top, addRemove in the middle, and preferences at the bottom).

=back

=item BUILD_TOOLBAR

NOTE: This event is emitted BEFORE the INIT event.

This lets you add buttons to the Day Planner toolbar at the top of
the main window. It gives a hashref with the following keys to the
callbacks:

=over 

=item toolbar

The L<Gtk2::Toolbar> object that represents the Day Planner toolbar widget.

=item tooltips

The L<Gtk2::Tooltips> object used for the toolbar. Use this to add tooltips
to any button you add, like this:

	$myButton->set_tooltip($TooltipsObj,'My tooltip','');
	$TooltipsObj->set_tip($myButton,'My tooltip');

=back

=item INIT

This is the initialization event. If your module needs to perform some initial tasks,
this is where it should be done.

For instance, a synchronization plugin will want to do its initial synchronization
in this event.

=item IPC_IN

Emitted when an IPC call is received, before it is processed. It gives a hashref
with the following keys to the callbacks:

=over

=item message

The IPC message received

=item aborted

Always 0 by default. You can set this key to 1 to abort Day Planner's handling
of the IPC request (ie. to indicate that it was mean for you, and you have
handled it).

=item reply

If you set aborted to 1, then you will also need to set reply to the reply
you want Day Planner to send. If you don't set reply, then Day Planner's
internal handling will not be aborted.

=back

=item SAVEDATA

Emitted right before Day Planner writes iCalendar data to disk.

=item SHUTDOWN

Emitted right before Day Planner is about to exit (before the gtk2 main loop
is exited, and before writing state and iCalendar files).

=back

=head1 SEE ALSO

For program documentation: 
L<dayplanner> L<dayplanner-daemon(1)> L<dayplanner-notifier(1)>

For API documentation see:
L<DP::iCalendar> L<DP::iCalendar::Manager> L<Date::HolidayParser>
L<DP::GeneralHelpers> L<DP::CoreModules::PluginFunctions>

=head1 LICENSE AND COPYRIGHT

Copyright (C) Eskild Hustvedt 2006, 2007, 2008, 2009

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with this program.  If not, see L<http://www.gnu.org/licenses/>.
