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
    my $plugin = shift;
	my $name = shift;
	my $value = shift;
	$name = $this->_get_plugName($plugin).'_'.$name;
	return $this->{config}{$name} = $value;
}

sub get_confval
{
	my $this = shift;
    my $plugin = shift;
	my $name = shift;
	$name = $this->_get_plugName($plugin).'_'.$name;
	return $this->{config}->{$name};
}

sub signal_connect
{
	my $this = shift;
	my $handlerModule = shift;
	my $signal = shift;
    my $codeRef = shift;
	if(not $this->{signals}{$signal})
	{
		$this->_warn('Plugin '.ref($handlerModule).' connected to unregistered signal: '.$signal);
		$this->{signals}{$signal} = [];
	}
	push(@{$this->{signals}{$signal}}, { module => $handlerModule, codeRef => $codeRef});
	return true;
}

sub signal_connect_ifavailable
{
	my $this = shift;
	my $handlerModule = shift;
	my $signal = shift;
	if(not $this->{signals}{$signal})
	{
		return false;
	}
	return $this->signal_connect($handlerModule,$signal,@_);
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
    my $meta = eval('return DP::Plugin::'.$pluginName.'->metainfo;');
    if ( !$meta || !ref($meta) || ($meta->{apiversion} != 2) )
    {
        $this->_warn('The plugin '.$pluginName.' is not compatible with this version of the Day Planner plugin API');
        return;
    }
	eval('$plugin = DP::Plugin::'.$pluginName.'->new(__plugin => $this);');
	$e = $@;
	if ($e)
	{
		$e =~ s/\n$//;
		$this->_warn('Construction of plugin "'.$pluginName.'" failed: '.$e);
		return;
	}
    eval
    {
        if ($plugin->can('earlyInit'))
        {
            $plugin->earlyInit();
        }
        1;
    };
	$e = $@;
	if ($e)
	{
		$e =~ s/\n$//;
		$this->_warn('earlyInit of plugin "'.$pluginName.'" failed: '.$e);
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
            eval
            {
                $i->{codeRef}->();
            };
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
	shift(@{$this->{runningSignals}});
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

sub _get_plugName
{
	my $this = shift;
    my $plugin = shift;
	my $base = ref($plugin);
    if (!$base)
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

=head1 DAY PLANNER PLUGINS

See L<DP::Plugin> for the Day Planner plugin documentation
