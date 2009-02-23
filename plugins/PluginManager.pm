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
use strict;
use warnings;
use Gtk2;
use Gtk2::SimpleList;
use DP::CoreModules::PluginFunctions qw(DPIntWarn GTK_Flush DP_DestroyProgressWin DPError DPQuestion DPInfo DPCreateProgressWin runtime_use Assert Gtk2_Button_SetImage);
use DP::GeneralHelpers qw(LoadConfigFile);
use constant { true => 1, false => 0 };

sub new_instance
{
	my $this = shift;
	$this = {};
	bless($this);
	my $plugin = shift;
	$this->{plugin} = $plugin;
	$this->{metadata} = {};
	$this->{pluginInfo} = {};

	# Register the one signal we have
	$plugin->register_signals(qw(SHOW_PLUGINMANAGER));
	# Connect to signals
	$plugin->signal_connect('CREATE_MENUITEMS',$this,'mkmenu');
	$plugin->signal_connect('SHOW_PLUGINMANAGER',$this,'ShowManager');

	$this->{i18n} = $plugin->get_var('i18n');
	# NOTE: Although this is a plugin, it does not have any ->{meta} info, because
	# 	it isn't suppose to be displayed in itself.
	return $this;
}

sub mkmenu
{
	my $this = shift;
	my $plugin = shift;
	my $MenuItems = $plugin->get_var('MenuItems');
	my $EditName = $plugin->get_var('EditName');
	my $i18n = $plugin->get_var('i18n');
	# This is our menu item
	my $menu =  [ '/'.$EditName.'/'.$i18n->get('_Plugins') ,undef, sub { $plugin->signal_emit('SHOW_PLUGINMANAGER'); },     0,  '<StockItem>',  'gtk-properties'];
	# Add the menu
	push(@{$MenuItems},$menu);
	return;
}

sub ShowManager
{
	my $this = shift;
	my $plugin = shift;

	my $i18n = $plugin->get_var('i18n');
	my $MainWindow = $plugin->get_var('MainWindow');
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
	my $InstallButton = Gtk2::Button->new($i18n->get('_Install a plugin'));
	my $icon = Gtk2::Image->new_from_stock('gtk-harddisk','button');
	Gtk2_Button_SetImage($InstallButton,$icon,'_Install a new plugin');
	$InstallButton->show();
	$ButtonHBox->pack_end($InstallButton,0,0,0);
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
		foreach my $i (@{$pluginList->{data}})
		{
			if ($i->[1])
			{
				$plugins{$i->[0]} = 1;
				$this->{plugin}->load_plugin_if_missing($i->[0]);
			}
		}
		my $newPlugins = join(' ',keys %plugins);
		my $InternalConfig = $this->{plugin}->get_var('state');
		$InternalConfig->{plugins_enabled} = $newPlugins;
	};

	$CloseButton->signal_connect('clicked' => $ClosePerform);
	$InstallButton->signal_connect('clicked' => sub {
			my $r = $this->InstallPlugin;
			if (not $r)
			{
				$window->destroy();
				$this->ShowManager($this->{plugin});
			}
		});
	$RemoveButton->signal_connect('clicked' => sub {
			my $Selected = [$pluginList->get_selected_indices]->[0];
			if(defined $Selected)
			{
				my $selectedPlugin = $pluginList->{data}[$Selected][0];
				if(DPQuestion($i18n->get('Are you sure you want to uninstall the plugin "'.$selectedPlugin.'"?')))
				{
					my $ppath = $this->{plugin}->get_var('confdir').'/plugins/';
					if(not -e $ppath.$selectedPlugin.'.pm')
					{
						DPError("Failed to locate plugin");
					}
					else
					{
						unlink($ppath.$selectedPlugin.'.pm');
						unlink($ppath.$selectedPlugin.'.dpi');
					}
					$window->destroy();
					$this->ShowManager($this->{plugin});
				}
			}
		});

	# Handler for a user selecting an entry
	$pluginList->signal_connect('cursor-changed' => sub {
			my $Selected = [$pluginList->get_selected_indices]->[0];
			if(defined $Selected)
			{
				my $selectedPlugin = $pluginList->{data}[$Selected][0];
				my $string;
				if ($this->{pluginInfo}->{$selectedPlugin})
				{
					$string = $this->{pluginInfo}->{$selectedPlugin};
				}
				else
				{
					my $meta = $this->{metadata}->{$selectedPlugin};
					$string = $this->generateInfoString($meta);
					$this->{pluginInfo}->{$selectedPlugin} = $string;
				}
				$infoText->set_text($string);
				if (-e $this->{plugin}->get_var('confdir').'/plugins/'.$selectedPlugin.'.pm')
				{
					$RemoveButton->set_sensitive(true);
				}
				else
				{
					$RemoveButton->set_sensitive(false);
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
	my $i18n = $this->{plugin}->get_var('i18n');
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
			my $meta = $this->{plugin}->get_info_from_package($Filename);
			if(not $meta)
			{
				DPError($i18n->get('This file does not appear to be a Day Planner plugin package'));
			}
			else
			{
				my $ppath = $this->{plugin}->get_var('confdir').'/plugins/';
				if (-e $ppath.'/'.$meta->{shortPluginName}.'.pm')
				{
					DPInfo($i18n->get('This plugin is already installed, if you want to re-install or upgrade it you will need to uninstall the one that is already installed first'));
				}
				else
				{
					if ($meta->{apiversion} != 1)
					{
						DPInfo($i18n->get('This plugin is written for a later version of Day Planner. You need to upgrade Day Planner before you can use it'));
					}
					else
					{
						my $string = $this->generateInfoString($meta);
						if(DPQuestion($i18n->get('Are you sure you wish to install this package? You should only install plugins from sources you trust, unsafe plugins can damage your system and files.')."\n\nPlugin information:\n".$string))
						{
							if(not $this->{plugin}->install_plugin($Filename))
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
	my $pluginPath = $this->{plugin}->get_var('pluginPaths');
	my %plugins;
	foreach my $d (@{$pluginPath})
	{
		foreach my $p (glob($d.'/*dpi'))
		{
			next if $p =~ m{/\*dpi$};
			next if $plugins{$p};
			$plugins{$p} = 1;
			my $info = $this->LoadPluginMetadataFromFile($p);
			next if not $info;
			$this->{metadata}{$info->{name}} = $info;
			# TODO: Some way to do i18n
			my $active = $this->{plugin}->plugin_loaded($info->{name}) ? true : false;
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
	my $string = 'Author: '.$meta->{author}."\n";
	$string .= 'Version: '.$meta->{version}."\n";
	$string .= 'License: '.$meta->{license}."\n";
	$string .= 'Description: '.$meta->{description};
	return $string;
}

1;
