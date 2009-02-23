#!/usr/bin/perl
# Day Planner
# A graphical Day Planner written in perl that uses Gtk2
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

package DP::Plugin::TrayIcon;
use strict;
use warnings;
use Gtk2::TrayIcon;
use DP::CoreModules::PluginFunctions qw(DPError DetectImage QuitSub);

sub new_instance
{
	my $this = shift;
	$this = {};
	bless($this);
	my $plugin = shift;
	$this->{plugin} = $plugin;
	$this->{plugin}->signal_connect('INIT',$this,'initTrayIcon');
	$this->{meta} =
	{
		name => 'TrayIcon',
		title => 'System tray icon',
		description => 'This a simple icon that sits in your system tray. When clicked it will hide the Day Planner window if it is visible, and show it if it is not.',
		version => 0.1,
		apiversion => 1,
		needs_modules => 'Gtk2::TrayIcon',
		author => 'Eskild Hustvedt',
		license => 'GNU General Public License version 3 or later',
	};
	return $this;
}

sub initTrayIcon
{
	my $this = shift;
	my $icon = Gtk2::TrayIcon->new('DPTray');
	my $image = DetectImage('dayplanner-16x16.png','dayplanner-24x24.png','dayplanner-32x32.png','dayplanner-48x48.png','dayplanner.png');
	if(not $image)
	{
		DPError("Failed to init TrayIcon, image not found");
		return;
	}
	$image = Gtk2::Image->new_from_file($image);
	my $eventbox = Gtk2::EventBox->new;
	$eventbox->add( $image );
	$icon->add($eventbox);
	my $mainWin = $this->{plugin}->get_var('MainWindow');
	$eventbox->signal_connect('button_press_event' => sub { 
			if ( $_[ 1 ]->button == 3 ) {
				$this->rightClickMenu($_[1])
			}
			else
			{
				if ($mainWin->visible)
				{
					$mainWin->hide;
				}
				else
				{
					$mainWin->show;
				}
			}
		});
	$icon->show_all;
	$mainWin->signal_handlers_disconnect_by_func(\&main::QuitSub);
	$mainWin->signal_connect('destroy' => sub {
			$mainWin->hide();
			return 1;
		});
	$mainWin->signal_connect('delete-event' => sub {
			$mainWin->hide();
			return 1;
		});
}

sub rightClickMenu
{
	my($self,$event) = @_;
	my $i18n = $self->{plugin}->get_var('i18n');
	my $PopupWidget = Gtk2::Menu->new();
	my $quit = Gtk2::ImageMenuItem->new_from_stock('gtk-quit');
	$quit->show();
	$quit->signal_connect('activate' => \&QuitSub);
	my $add = Gtk2::ImageMenuItem->new($i18n->get('_Add an Event...'));
	$add->show();
	my $addIcon = Gtk2::Image->new_from_stock('gtk-add','menu');
	$add->signal_connect('activate' => \&main::AddEvent);
	$add->set_image($addIcon);
	$PopupWidget->append($add);
	$PopupWidget->append($quit);
	$PopupWidget->show();
	$PopupWidget->popup(undef, undef, undef, undef, 0, $event->time);
}
