package DP::Plugin;
use Carp qw(croak);
use Moo;

our @CARP_NOT = ('DP::CoreModules::Plugin');

has '__plugin' => (
    is => 'ro',
    required => 1,
);

sub register_signals
{
    my $this = shift;
    return $this->__plugin->register_signals(@_);
}

sub set_plugin_var
{
    my $this = shift;
    return $this->__plugin->set_var(@_);
}

sub set_plugin_tempvar
{
    my $this = shift;
    return $this->__plugin->set_tempvar(@_);
}

sub get_plugin_var
{
    my $this = shift;
    return $this->__plugin->get_var(@_);
}

sub delete_plugin_var
{
    my $this = shift;
    return $this->__plugin->delete_plugin_var(@_);
}

sub get_confval
{
    my $this = shift;
    return $this->__plugin->get_confval($this,@_);
}

sub set_confval
{
    my $this = shift;
    return $this->__plugin->set_confval($this,@_);
}

sub signal_connect
{
    my $this = shift;
    my $signal = shift;
    my $codeRef = shift;
    if (!ref($codeRef) || ref($codeRef) ne 'CODE')
    {
        $this->__croak('Invalid usage of signal_connect(): Second parameter is not a coderef');
    }
    return $this->__plugin->signal_connect($this,$signal,$codeRef,@_);
}

sub signal_connect_ifavailable
{
    my $this = shift;
    my $signal = shift;
    my $codeRef = shift;
    if (!ref($codeRef) || ref($codeRef) ne 'CODE')
    {
        $this->__croak('Invalid usage of signal_connect_ifavailable(): Second parameter is not a coderef');
    }
    return $this->__plugin->signal_connect_ifavailable($this,$signal,$codeRef,@_);
}

sub signal_emit
{
    my $this = shift;
    return $this->__plugin->signal_emit(@_);
}

sub get_plugin_object
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
program. The basic syntax is inspired from Gtk2's signals.

All plugins are perl objects. These objects communicate with Day Planner
via a special plugin object that it gets supplied. This plugin object gives
access to internal data, and handles signal passing.

Day Planner comes with various plugins by default, ranging from the
basic hello world to synchronization. Take a look at the source code
of these plugins to get a feel for it.

=head1 THE BASIC PLUGIN LAYOUT

Day Planner plugins are L<Moo>-objects that extend DP::Plugin.

A plugin can have an earlyInit method. This is run immediately after
construction. In this method you should only do initialization that
is required for your plugin to be operation before the INIT signal is
emitted and it can finalize its initialization.  See the builtin signals
section for more information about the INIT signal.

=head1 THE PLUGIN METHODS

Extending DP::Plugin grants you a number of methods that allows you to interact
with Day Planner. All of these methods are available on your object (ie. from $self).

The following methods are made available:

=over

=item register_signals(B<ARRAY>)

This method takes an array of zero or more elements as its parameter.
It is used to register a signal (not a handler) for use. You should
call this if your plugin will emit signals. The plugin handler ignores
all emitted signals that has not been previously registered.

=item signal_emit(B<STRING> signal)

Emits the signal supplied, calling all listeners in turn.

=item signal_connect(B<STRING> signal, B<CODEREF> callback)

Connects to the supplied signal. Whenever that signal is emitted, the
supplied coderef will be done.

Callbacks are called inside of an eval, so any die()s or crashes will be
caught by the plugin handler.

=item signal_connect_ifavailable(B<STRING> signal, B<CODEREF> callback)

The same as signal_connect, but this will not attach to (or warn about)
unregistered signals, instead it will silently ignore the request.

Its primary use is connecting to signals that belong to another plugin,
and it should not be used within the constructor, but within the INIT
signal (see the I<BUILTIN SIGNALS> section).

=item set_plugin_var(B<STRING> variable name, B<VARIABLE> content)

This is used for sharing data. Sets the variable supplied to the content
supplied.

=item get_plugin_var(B<STRING> variable name)

Gets the contents of the shared variable supplied. Various signals
can offer temporary access to various data structures. These are outlined
in the documentation for the signal in question.

=item delete_plugin_var(B<STRING> variable name)

Deletes the variable supplied. You should never use this to delete
content that is shared by anything other than your plugin.

=item set_plugin_tempvar(B<STRING> variable name, B<VARIABLE> content)

This is the same as set_var() except that this version delete_var()s the
variable after the next signal has been emitted, sharing the data only
througout a single signal.

=item set_confval(B<STRING> name, B<STRING> value)

Sets the configuration value name to value for THIS plugin. The plugin object
automatically handles making it unique for your plugin, so you do not need to
ensure that the name is unique for the entire program, only for your plugin.
The configuration values are automatically saved and loaded by Day Planner.

=item get_confval(B<STRING> name)

Gets the configuration value supplied. This retrieves settings set using
set_confval()

=item abort()

Tells the plugin handler that the action that triggered the signal should stop
processing after the signal has finished. Use with care. Note that not all signals
will honor an abort() call (ie. you can't abort for instance SHUTDOWN and SAVEDATA).

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

These variables are available with get_plugin_var() throughout the lifetime of the
application. Some of these variables are however not available before after the
INIT signal has been emitted.

=over

=item MainWindow

This is the main L<Gtk2::Window> for Day Planner. Not available
before the INIT signal.

=item CalendarWidget

This is the main L<Gtk2::Calendar> widget displayed in the main
Day Planner window. Not available before the INIT signal.

NOTE: If you switch the date, you have to remember to call:
I<$object->signal_emit('day-selected')> after you have switched it.
Day Planner will not redraw the list of events until you do.

=item calendar

The L<DP::iCalendar::Manager> object.

=item state

A hashref to the state.conf configuration hash. You should not modify
this, but use set/get_confval() instead.

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

=head1 BUILTIN SIGNALS

=over

=item CREATE_MENUITEMS

NOTE: This signal is emitted BEFORE the INIT signal.

This lets you modify the Day Planner menus. It shares the following
temporary variables:

=over

=item menu_importExport, menu_addRemove menu_preferences 

Arreyrefs to an array containing elements for a L<Gtk2::ItemFactory>.
You can push additional items that you wish added to the menu onto these
variables. Each correspond to a single section in the menu (importExport
at the top, addRemove in the middle, and preferences at the bottom).

=back

=item BUILD_TOOLBAR

NOTE: This signal is emitted BEFORE the INIT signal.

This lets you add buttons to the Day Planner toolbar at the top of
the main window. It shares the following temporary variables

=over 

=item Toolbar

The L<Gtk2::Toolbar> object that represents the Day Planner toolbar widget.

=item Tooltips

The L<Gtk2::Tooltips> object used for the toolbar. Use this to add tooltips
to any button you add, like this:

	$myButton->set_tooltip($TooltipsObj,'My tooltip','');
	$TooltipsObj->set_tip($myButton,'My tooltip');

=back

=item INIT

This is the initialization signal. If your module needs to perform some initial tasks,
this is where it should be done.

For instance, a synchronization plugin will want to do its initial synchronization
in this signal.

=item SAVEDATA

Emitted right before Day Planner writes iCalendar data to disk. Cannot
be aborted.

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
