# Day Planner plugin system
# Copyright (C) Eskild Hustvedt 2008, 2009
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
use File::Temp qw(tempdir);
use File::Copy qw(copy);
use Cwd qw(getcwd realpath);
use DP::GeneralHelpers qw(LoadConfigFile);

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
	$this->{loadedPlugins} = {};
	$this->{tempVars} = [];
	$this->{runningSignals} = [];
	$this->{signalRunning} = {};
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

sub signal_connect_ifavailable
{
	my $this = shift;
	my $signal = shift;
	if(not $this->{signals}{$signal})
	{
		return false;
	}
	return $this->signal_connect($signal,@_);
}

sub set_searchpath
{
	my $this = shift;
	my $searchPath = shift;
	$this->{searchPaths} = $searchPath;
}

sub load_plugin
{
	my $this = shift;
	my $pluginName = shift;
	my $paths = shift;
	if (not $paths)
	{
		if(not $this->{searchPaths})
		{
			$this->_warn("load_plugin($pluginName): failed: no search path set anywhere");
			return;
		}
		$paths = $this->{searchPaths};
	}
	elsif ($this->{searchPaths})
	{
		push(@{$paths},@{$this->{searchPaths}});
	}
	my $pluginPath;
	if ($this->{loadedPlugins}->{$pluginName})
	{
		$this->_warn('Plugin '.$pluginName.' is being reloaded');
	}
	foreach my $path (@{$paths})
	{
		if (-e $path.'/'.$pluginName.'.pm')
		{
			$pluginPath = $path.'/'.$pluginName.'.pm';
			last;
		}
	}
	if(not $pluginPath)
	{
		$this->_warn('Failed to locate the plugin "'.$pluginName.'": ignoring');
		return;
	}

	my $e;
	eval
	{
		package DP::Plugin::Loader;
		do($pluginPath) or $e = $@;
	};
	if ($e)
	{
		$e =~ s/\n$//;
		$this->_warn('Failed to load the plugin "'.$pluginName.'": '.$e);
		return;
	}
	my $plugin;
	eval('$plugin = DP::Plugin::'.$pluginName.'->new_instance($this);');
	$e = $@;
	if ($e)
	{
		$e =~ s/\n$//;
		$this->_warn('Init of plugin "'.$pluginName.'" failed: '.$e);
		return;
	}
	$this->{loadedPlugins}->{$pluginName} = 1;
	if(not $plugin)
	{
		$this->_warn("Plugin $pluginName appears not to have returned itself");
		return true;
	}
	return $plugin;
}

sub load_plugin_if_missing
{
	my $this = shift;
	my $pluginName = shift;
	my $paths = shift;
	if (not $this->plugin_loaded($pluginName))
	{
		return $this->load_plugin($pluginName,$paths);
	}
	return true;
}

sub plugin_loaded
{
	my $this = shift;
	my $pluginName = shift;
	if ($this->{loadedPlugins}->{$pluginName})
	{
		return true;
	}
	return false;
}

sub signal_emit
{
	my $this = shift;
	my $signal = shift;
	my $multi = false;

	if ($this->{signalRunning}->{$signal})
	{
		$multi = true;
		$this->_warn("Signal \"$signal\" emitted before another instance of the same signal has finished, tempvar and aborts will not work properly at all");
	}

	$this->{signalRunning}->{$signal} = {
		tempVars => $this->{tempVars} ? $this->{tempVars} : [],
		abort => 0
	};
	$this->{tempVars} = [];

	push(@{$this->{runningSignals}},$signal);
	my $info = $this->{signalRunning}->{$signal};

	if ($this->{signals}{$signal})
	{
		my $repairIt = false;
		foreach my $i (@{$this->{signals}{$signal}})
		{
			$this->{currPlugin} = $i->{module};
			eval('$i->{module}->'.$i->{method}.'($this);');
			$this->{currPlugin} = undef;
			my $e = $@;
			if ($e)
			{
				chomp($e);
				$this->_warn("Failure when emitting signal $signal: $e: ignoring and attempting to repair main app state");
				$repairIt = true;
			}
		}

		# Try to make sure the app itself is in a usable state
		if ($repairIt)
		{
			my $w = $this->get_var('MainWindow');
			if ($w)
			{
				$w->set_modal(false);
				$w->set_sensitive(true);
			}
		}
	}
	else
	{
		$this->_warn('Attempted to emit unregistered signal (request refused): '.$signal);
	}

	# Delete temporary variables
	foreach my $var(@{$info->{tempVars}})
	{
		$this->delete_var($var);
	}

	my $return = false;

	if ($info->{abort})
	{
		$return = true;
	}
	if(not $multi)
	{
		delete($this->{signalRunning}->{$signal});
	}
	return $return;
}

sub abort
{
	my $this = shift;
	my $sig = $this->get_current_signal();
	$this->{signalRunning}->{$sig}->{abort} = 1;
	return true;
}

sub install_plugin
{
	my $this = shift;
	my $file = shift;
	my $currDir = getcwd();
	my ($dir,$conf) = $this->_extractPluginPackage($file);
	if(not $dir)
	{
		return false;
	}
	my $name = $conf->{pluginName};
	my $target = $this->get_var('confdir').'/plugins/';
	if(not -e $target)
	{
		mkdir($target) or $this->_warn('FATAL: failed to mkdir('.$target.'): '.$!);
	}
	copy('./'.$name.'.pm',$target) or $this->_warn('FATAL: Failed to copy(./'.$name.'.pm,'.$target.'): '.$!);
	copy('./'.$name.'.dpi',$target) or $this->_warn('FATAL: Failed to copy(./'.$name.'.dpi,'.$target.'): '.$!);
	chdir($currDir);
	return true;
}

sub get_info_from_package
{
	my $this = shift;
	my $file = shift;
	my $currDir = getcwd();
	my ($dir,$conf) = $this->_extractPluginPackage($file);
	if(not $dir)
	{
		return false;
	}

	my $name = $conf->{pluginName};
	my %pluginInfo;
	my $meta = LoadConfigFile('./'.$name.'.dpi',\%pluginInfo);
	$pluginInfo{shortPluginName} = $name;
	chdir($currDir);
	return \%pluginInfo;
}

# Summary: Mark something as a stub
# Usage: STUB();
sub STUB
{
    my ($stub_package, $stub_filename, $stub_line, $stub_subroutine, $stub_hasargs,
        $stub_wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
    warn "STUB: $stub_subroutine\n";
}

sub get_current_signal
{
	my $this = shift;
	if (@{$this->{runningSignals}})
	{
		return $this->{runningSignals}->[-1];
	}
	return undef;
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

sub _extractPluginPackage
{
	my $this = shift;
	my $file = shift;

	if(not -e $file)
	{
		$this->_warn($file.': does not exist');
	}

	my $currDir = getcwd();
	my $tempDir = tempdir( 'dayplannerPluginInstall-XXXXXX', CLEANUP => 1, TMPDIR => 1);

	chdir($tempDir);
	if(not -e $file)
	{
		$file = $currDir.'/'.$file;
	}
	$file = realpath($file);
	my $ret;
	{
		open(my $stdout, '>&',\*STDOUT);
		open(my $stderr, '>&',\*STDOUT);
		open(STDOUT,'>','/dev/null');
		open(STDERR,'>','/dev/null');
		$ret = system('tar','-jxf',$file);
		open(STDOUT,'>&',$stdout);
		open(STDERR,'>&',$stderr);
	}
	if ($ret != 0)
	{
		$this->_warn($file.': failed to extract');
		chdir($currDir); return false;
	}
	if(not -d './DP_pluginData')
	{
		$this->_warn($file.': did not contain the DP_pluginData directory');
		chdir($currDir); return false;
	}
	chdir('DP_pluginData');
	if(not -e './pluginInfo.conf')
	{
		$this->_warn($file.': did not contain a pluginInfo.conf');
		chdir($currDir); return false;
	}
	my %conf;
	LoadConfigFile('./pluginInfo.conf',\%conf);
	my $name = $conf{pluginName};
	if(not -e './'.$name.'.dpi')
	{
		$this->_warn($file.': did not contain '.$name.'.dpi');
		chdir($currDir); return false;
	}
	if(not -e './'.$name.'.pm')
	{
		$this->_warn($file.': did not contain '.$name.'.pm');
		chdir($currDir); return false;
	}
	return ($tempDir,\%conf);
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

A plugin should have a new_instance method. This instance gets the
plugin handler object supplied as its sole parameter.

It should create the plugin's object and return it. It should only do
signal connecting and the initialization that is required for it to be
operational until the INIT signal is issued and it can finalize its
initialization. See the builtin signals section for more information about
the INIT signal.

=head1 THE PLUGIN HANDLER OBJECT

The plugin handler object is the main controller that handles all I/O
between the main application and the plugin. It allows you to request
data, set configuration parameters and hook into signals.

It has the following methods:

=over

=item register_signals(B<ARRAY>)

This method takes an array of zero or more elements as its parameter.
It is used to register a signal (not a handler) for use. You should
call this if your plugin will emit signals.

=item signal_emit(B<STRING> signal)

Emits the signal supplied, calling all listeners.

=item signal_connect(B<STRING> signal, B<OBJECT> plugin, B<STRING> method)

Connects the method on the plugin object supplied to the signal supplied.
The method will then be called whenever the signal is emitted.

=item signal_connect_ifavailable(B<STRING> signal, B<OBJECT> plugin, B<STRING> method)

The same as signal_connect, but this will not attach to (or warn about)
unregistered signals, instead it will silently ignore the request.

Its primary use is connecting to signals that belong to another plugin,
and it should not be used within the constructor, but within the INIT
signal (see the I<BUILTIN SIGNALS> section).

=item set_var(B<STRING> variable name, B<VARIABLE> content)

This is used for sharing data. Sets the variable supplied to the content
supplied.

=item get_var(B<STRING> variable name)

Gets the contents of the shared variable supplied. Various signals
can offer temporary access to various data structures. These are outlined
in the documentation for the signal in question.

=item delete_var(B<STRING> variable name)

Deletes the variable supplied. You should never use this to delete
content that is shared by anthing other than your plugin.

=item set_tempvar(B<STRING> variable name, B<VARIABLE> content)

This is the same as set_var() except that this version delete_var()s the
variable after the next signal has been emitted, sharing the data only
througout a single signal.

=item set_confval(B<STRING> name, B<STRING> value)

Sets the configuration value name to value for THIS plugin. The plugin
object automatically handles making it unique for your plugin, so you do
not need to ensure that the name is unique for the entire program, only
for your plugin. The configuration values are automatically saved by
Day Planner.

=item get_confval(B<STRING> name)

Gets the configuration value supplied.

=item abort()

Tells the plugin handler that the action that triggered the signal
should stop processing after the signal has finished. Use with care.

=back

=head1 GLOBALLY SHARED VARIABLES

=over

=item MainWindow

This is the main Gtk2::Window for Day Planner. Not available
before the INIT signal.

=item calendar

The DP::iCalendar::Manager object.

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

The DP::GeneralHelpers::i18n object.

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

=item MenuItems

An arrayref to an array containing elements for a Gtk2::ItemFactory.
You can push additional items that you wish added to the menu onto this
variable.

=item HelpName

The localized name of the help menu.

=item EditName

The localized name of the edit menu.

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
is exited, and before writing state and iCalendar files.

=back

=head1 SEE ALSO

For program documentation: 
L<dayplanner> L<dayplanner-daemon(1)> L<dayplanner-notifier(1)>

For API documentation:
L<DP::iCalendar> L<DP::iCalendar::Manager> L<Date::HolidayParser>

=head1 LICENSE AND COPYRIGHT

Copyright (C) Eskild Hustvedt 2006, 2007, 2008

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
