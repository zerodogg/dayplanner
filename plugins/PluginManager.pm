#!/usr/bin/perl
# Day Planner
# A graphical Day Planner written in perl that uses Gtk2
# Plugin manager plugin
# Copyright (C) Eskild Hustvedt 2008
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
use DP::CoreModules::PluginFunctions qw(DPIntWarn GTK_Flush DP_DestroyProgressWin DPError DPInfo DPCreateProgressWin runtime_use Assert);
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
	$info->set_size_request(-1,90);
	my $infoText = Gtk2::TextBuffer->new();
	$info->set_buffer($infoText);
	$scroll->add($info);
	$mainVBox->pack_end($scroll,0,0,0);

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
					$string = 'Author: '.$meta->{author}."\n";
					$string .= 'Version: '.$meta->{version}."\n";
					$string .= 'License: '.$meta->{license}."\n";
					$string .= 'Description: '.$meta->{description};
					$this->{pluginInfo}->{$selectedPlugin} = $string;
				}
				$infoText->set_text($string);
			}
		}
	);

	$window->show_all();
}

sub PopulateList
{
	my $this = shift;
	my $listData = shift;
	my $pluginPath = $this->{plugin}->get_var('pluginPaths');
	foreach my $d (@{$pluginPath})
	{
		foreach my $p (glob($d.'/*dpi'))
		{
			next if $p =~ m{/\*dpi$};
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

1;
