#!/usr/bin/perl
# Day Planner
# A graphical Day Planner written in perl that uses Gtk2
# Plugin manager plugin
# Copyright (C) Eskild Hustvedt 2008, 2009
# $Id: dayplanner 2315 2008-11-16 15:32:45Z zero_dogg $
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
package DP::Plugin::PluginManager;
use Moo;
extends 'DP::Plugin';
use Gtk2;
use Gtk2::SimpleList;
use DP::CoreModules::PluginFunctions qw(DPIntWarn GTK_Flush DP_DestroyProgressWin DPError DPQuestion DPInfo DPCreateProgressWin Assert Gtk2_Button_SetImage QuitSub);
use DP::GeneralHelpers qw(LoadConfigFile);
use File::Basename qw(basename);
use constant { true => 1, false => 0 };

sub earlyInit
{
	my $this = shift;
	$this->{metadata} = {};
	$this->{pluginInfo} = {};

	# Register the one signal we have
	$this->register_signals(qw(SHOW_PLUGINMANAGER));
	# Connect to signals
	$this->signal_connect('CREATE_MENUITEMS' => sub { $this->mkmenu });
	$this->signal_connect('SHOW_PLUGINMANAGER' => sub { $this->ShowManager });

	$this->{i18n} = $this->get_plugin_var('i18n');
	return $this;
}

sub mkmenu
{
	my $this = shift;
	my $MenuItems = $this->get_plugin_var('menu_preferences');
	my $i18n = $this->get_plugin_var('i18n');
	# This is our menu item
	my $menu =  [ '/'.$i18n->get('_Plugins') ,undef, sub { $this->signal_emit('SHOW_PLUGINMANAGER'); },     0,  '<StockItem>',  'gtk-properties'];
	# Add the menu
	push(@{$MenuItems},$menu);
	return;
}

sub ShowManager
{
	my $this = shift;

	my $i18n = $this->get_plugin_var('i18n');
	my $MainWindow = $this->get_plugin_var('MainWindow');
	my $window = Gtk2::Window->new();
	$window->set_title($i18n->get('Day Planner plugins'));
	$window->set_modal(true);
	$window->set_default_size(500,300); # FIXME
	$window->set_transient_for($MainWindow) if $MainWindow;
	$window->set_position('center-on-parent');
	$window->set_type_hint('dialog');

	my $containerWindow = Gtk2::ScrolledWindow->new();
	$containerWindow->set_policy('automatic', 'automatic');

	# The main hbox
	my $mainVBox = Gtk2::VBox->new();
	$window->add($mainVBox);

	# The list
	my $pluginList = Gtk2::SimpleList->new(
		'name' => 'hidden',
		# TRANSLATORS: The title of the column with the checkbox to activate/deactiate a plugin
		$i18n->get('Active') => 'bool',
		$i18n->get('Plugin') => 'text',
	);
	$this->PopulateList($pluginList->{data});
	$containerWindow->add($pluginList);
	$mainVBox->pack_start($containerWindow,1,1,0);

	# The info field
	my $scroll = Gtk2::ScrolledWindow->new();
	$scroll->set_policy('automatic','automatic');
	my $info = Gtk2::TextView->new();
	$info->set_editable(false);
	$info->set_cursor_visible(false);
	$info->set_wrap_mode('word');
	$info->set_size_request(-1,100);
	my $infoText = Gtk2::TextBuffer->new();
	$info->set_buffer($infoText);
	$scroll->add($info);
	$mainVBox->pack_start($scroll,0,0,0);

	# Add the buttons
	my $ButtonHBox = Gtk2::HBox->new();
	$ButtonHBox->show();
	$mainVBox->pack_end($ButtonHBox,0,0,0);

	my $CloseButton = Gtk2::Button->new_from_stock('gtk-close');
	$CloseButton->show();
	$ButtonHBox->pack_end($CloseButton,0,0,0);
	# TRANSLATORS: This would pop up a window where one can select a plugin package file to install
	my $InstallButton = Gtk2::Button->new($i18n->get('_Install a plugin'));
	my $icon = Gtk2::Image->new_from_stock('gtk-harddisk','button');
	Gtk2_Button_SetImage($InstallButton,$icon,'_Install a new plugin');
	$InstallButton->show();
	$ButtonHBox->pack_end($InstallButton,0,0,0);
	# TRANSLATORS: As in uninstall the currently selected plugin in the list of plugins
	my $RemoveButton = Gtk2::Button->new($i18n->get('_Uninstall plugin'));
	my $removeIcon = Gtk2::Image->new_from_stock('gtk-remove','button');
	Gtk2_Button_SetImage($RemoveButton,$removeIcon,'_Uninstall plugin');
	$RemoveButton->set_sensitive(false);
	$RemoveButton->show();
	$ButtonHBox->pack_end($RemoveButton,0,0,0);

	my $ClosePerform = sub {
		$window->destroy();
		my %plugins = (
			PluginManager => 1,
		);
		my $needsReload = 0;
		foreach my $i (@{$pluginList->{data}})
		{
			if ($i->[1])
			{
				$plugins{$i->[0]} = 1;
				if(not $this->get_plugin_object->plugin_loaded($i->[0]))
				{
					$needsReload = 1;
				}
			}
			else
			{
				if($this->get_plugin_object->plugin_loaded($i->[0]))
				{
					$needsReload = 2 if not $needsReload;
				}
			}
		}
		my $newPlugins = join(' ',keys %plugins);
		my $InternalConfig = $this->get_plugin_var('state');
		$InternalConfig->{plugins_enabled} = $newPlugins;
		if ($needsReload)
		{
			my $question = $i18n->get("You have enabled new plugins. Day Planner needs to be restarted before they become activated.\n\nDo you want to restart Day Planner now?");
			$question = $i18n->get("You have disabled some plugins. Day Planner needs to be restarted before they become deactivated.\n\nDo you want to restart Day Planner now?") if $needsReload == 2;
			if(DPQuestion($question))
			{
				QuitSub('RESTART');
			}
		}
	};

	$CloseButton->signal_connect('clicked' => $ClosePerform);
	$InstallButton->signal_connect('clicked' => sub {
			my $r = $this->InstallPlugin;
			if (not $r)
			{
				$window->destroy();
				$this->ShowManager();
			}
		});
	$RemoveButton->signal_connect('clicked' => sub {
			my $Selected = [$pluginList->get_selected_indices]->[0];
			if(defined $Selected)
			{
				my $selectedPlugin = $pluginList->{data}[$Selected][0];
				if(DPQuestion($i18n->get_advanced('Are you sure you want to uninstall the plugin "%(PLUGIN)"?', { PLUGIN => $selectedPlugin })))
				{
					my $ppath = $this->get_plugin_var('confdir').'/plugins/';
					if(not -e $ppath.$selectedPlugin.'.pm')
					{
						DPIntWarn('Failed to locate plugin at '.$ppath.$selectedPlugin.'.pm: '.$!);
						DPError($i18n->get('Failed to locate the plugin files, unable to uninstall'));
					}
					else
					{
						unlink($ppath.$selectedPlugin.'.pm');
						unlink($ppath.$selectedPlugin.'.dpi');
					}
					$window->destroy();
					$this->ShowManager();
				}
			}
		});

	# Handler for a user selecting an entry
	$pluginList->signal_connect('cursor-changed' => sub {
			my $Selected = [$pluginList->get_selected_indices]->[0];
			# TODO: This could perhaps use some optimizing
			if(defined $Selected)
			{
				my $selectedPlugin = $pluginList->{data}[$Selected][0];
				my $string;
				my $meta = $this->{metadata}->{$selectedPlugin};
				if ($this->{pluginInfo}->{$selectedPlugin})
				{
					$string = $this->{pluginInfo}->{$selectedPlugin};
				}
				else
				{
					$string = $this->generateInfoString($meta);
					$this->{pluginInfo}->{$selectedPlugin} = $string;
				}
				$infoText->set_text($string);
				if (-e $this->get_plugin_var('confdir').'/plugins/'.$selectedPlugin.'.pm')
				{
					$RemoveButton->set_sensitive(true);
				}
				else
				{
					$RemoveButton->set_sensitive(false);
				}
				if ($pluginList->{data}[$Selected][1])
				{
					if ($meta->{needs_modules})
					{
						foreach my $module (split(/\s+/,$meta->{needs_modules}))
						{
							if(not eval('use '.$module.'; 1;'))
							{
								$pluginList->{data}[$Selected][1] = 0;
								my @names;

								my $name = $module;
								$name =~ s/::/-/g;
								$name =~ tr[A-Z][a-z];
								$name = 'lib'.$name.'-perl';
								$name =~ s/-+/-/g;
								push(@names,$name);

								$name = $module;
								$name =~ s/::/-/g;
								$name = 'perl-'.$name;
								push(@names,$name);

								DPError($i18n->get_advanced("The plugin \"%(PLUGIN)\" needs the perl module \"%(MODULE)\", but that module is not installed on your system.\n\nYou will have to install this module before you can install this plugin. Consult your distribution documentation for instructions on how to do that.\n\nThe package might be called something like the following: %(PACKAGE)", {
											PLUGIN => $selectedPlugin,
											MODULE => $module,
											# TRANSLATORS: This word appears in the 'the plugin ... needs the perl module...' message, at the end.
											# 	%(PACKAGE) is a list of packages, and in English it might end up as something like:
											# 	"libsomething-perl or perl-something", the ' or ' string acts as glue.
											PACKAGE => join($i18n->get(' or '),@names),
										}));
								return;
							}
						}
					}
				}
			}
		}
	);
	$window->signal_connect('destroy' => $ClosePerform);
	$window->signal_connect('delete-event' => $ClosePerform);
	$window->show_all();
}

sub InstallPlugin
{
	my $this = shift;
	my $i18n = $this->get_plugin_var('i18n');
	my $InstallWindow = Gtk2::FileChooserDialog->new($i18n->get('Install Day Planner plugin package'), undef, 'open',
		'gtk-cancel' => 'reject',
		'gtk-open' => 'accept',);
	$InstallWindow->set_local_only(1);
	$InstallWindow->set_default_response('accept');
	my $filter = Gtk2::FileFilter->new;
	$filter->add_pattern('*.dpp');
	$filter->set_name($i18n->get('Day Planner plugin packages'));
	$InstallWindow->add_filter($filter);
	my $Response = $InstallWindow->run();
	my $return = true;
	if($Response eq 'accept') {
		my $Filename = $InstallWindow->get_filename();
		if($Filename =~ /\.(dpp)$/i) {
			my $meta = $this->get_plugin_object->get_info_from_package($Filename);
			if(not $meta)
			{
				DPError($i18n->get('This file does not appear to be a Day Planner plugin package'));
			}
			else
			{
				my $ppath = $this->get_plugin_var('confdir').'/plugins/';
				if (-e $ppath.'/'.$meta->{shortPluginName}.'.pm')
				{
					DPInfo($i18n->get('This plugin is already installed, if you want to re-install or upgrade it you will need to uninstall the one that is already installed first'));
				}
				else
				{
					if ($meta->{apiversion} == 1)
					{
						DPInfo($i18n->get('This plugin is written for an older version of Day Planner and is incompatible with your version.'));
					}
					if ($meta->{apiversion} > 2)
					{
						DPInfo($i18n->get('This plugin is written for a later version of Day Planner. You need to upgrade Day Planner before you can use it'));
					}
					else
					{
						my $string = $this->generateInfoString($meta);
						if(DPQuestion($i18n->get('Are you sure you wish to install this package? You should only install plugins from sources you trust, unsafe plugins can damage your system and files.')."\n\nPlugin information:\n".$string))
						{
							if(not $this->get_plugin_object->install_plugin($Filename))
							{
								DPError($i18n->get('Installation failed, this file does not appear to be a Day Planner plugin package'));
							}
							else
							{
								$return = false;
							}
						}
					}
				}
			}
		} else {
			DPIntWarn("Unknown filetype: $Filename");
		}
	}
	$InstallWindow->destroy();
	return $return;
}

sub PopulateList
{
	my $this = shift;
	my $listData = shift;
	my $pluginPath = $this->get_plugin_var('pluginPaths');
	my %plugins;
	foreach my $d (@{$pluginPath})
	{
		foreach my $p (glob($d.'/*dpi'))
		{
			my $e = basename($p);
			next if $p =~ m{/\*dpi$};
			next if $plugins{$e};
			$plugins{$e} = 1;
			my $info = $this->LoadPluginMetadataFromFile($p);
			next if not $info;
            if ($info && $info->{apiversion} != 2)
            {
                next;
            }
			$this->{metadata}{$info->{name}} = $info;
			# TODO: Some way to do i18n
			my $active = $this->get_plugin_object->plugin_loaded($info->{name}) ? true : false;
			push(@{$listData},[$info->{name},$active,$info->{title}]);
		}
	}
}

sub LoadPluginMetadataFromFile
{
	my $this = shift;
	my $file = shift;
	my %Info;
	LoadConfigFile($file,\%Info);
	if (keys %Info)
	{
		return \%Info;
	}
	else
	{
		return;
	}
}

sub generateInfoString
{
	my $this = shift;
	my $meta = shift;
	my $string = '';
	my $i18n = $this->get_plugin_var('i18n');
	if ($meta->{author})
	{
		$string = $i18n->get('Author:').' '.$meta->{author}."\n";
	}
	if ($meta->{version})
	{
		$string .= $i18n->get('Version:').' '.$meta->{version}."\n";
	}
	if ($meta->{license})
	{
		$string .= $i18n->get('License:').' '.$meta->{license}."\n";
	}
	if ($meta->{description})
	{
		$string .= $i18n->get('Description:').' '.$meta->{description}."\n";
	}
	if ($meta->{website})
	{
		$string .= $i18n->get('Website:').' '.$meta->{website}."\n";
	}
	$string =~ s/\n$//;
	return $string;
}

# Plugin metadata
sub metainfo
{
	# NOTE: Although this is a plugin, it does not have any ->{meta} info, because
	# 	it isn't suppose to be displayed in itself.
    return
    {
		apiversion => 2,
    };
}

1;
