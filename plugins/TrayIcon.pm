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
use Moo;
extends 'DP::Plugin';
use Gtk2::TrayIcon;
use DP::CoreModules::PluginFunctions qw(DPError DetectImage QuitSub);

sub earlyInit
{
    my $this = shift;
	$this->register_signals(qw(MINIMIZE_TO_TRAY SHOW_FROM_TRAY));
	$this->signal_connect('INIT' => sub { $this->initTrayIcon });
	$this->signal_connect('IPC_IN' => sub { $this->handleIPC });
	$this->{mainwin_x} = undef;
	$this->{mainwin_y} = undef;
	return $this;
}

sub handleIPC
{
	my $this = shift;
	my $request = $this->get_plugin_var('IPC_REQUEST');
	return if not $request =~ s/^ALIVE\s+//;
	$request =~ s/\s+//g;
	if (not $request eq $ENV{DISPLAY})
	{
		return;
	}
	my $mainWin = $this->get_plugin_var('MainWindow');
	if ($mainWin->visible)
	{
		return;
	}
	# Ok, we're going to assume handling of this signal, so abort the rest
	$this->set_plugin_var('IPC_REPLY','ALIVE_ONDISPLAY');
	$this->toggleMainWinVisibility();
	$this->abort();
}

sub toggleMainWinVisibility
{
	my $this = shift;
	my $mainWin = $this->get_plugin_var('MainWindow');
	if ($mainWin->visible)
	{
		$this->signal_emit('MINIMIZE_TO_TRAY');
		($this->{mainwin_x}, $this->{mainwin_y}) = $mainWin->get_position();
		$mainWin->hide;
	}
	else
	{
		$this->signal_emit('SHOW_FROM_TRAY');
		$mainWin->show;
		if(defined $this->{mainwin_x} and defined $this->{mainwin_y})
		{
			$mainWin->move($this->{mainwin_x}, $this->{mainwin_y});
		}
	}
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
	my $mainWin = $this->get_plugin_var('MainWindow');
	$eventbox->signal_connect('button_press_event' => sub { 
			if ( $_[ 1 ]->button == 3 ) {
				$this->rightClickMenu($_[1])
			}
			else
			{
				$this->toggleMainWinVisibility();
			}
		});
	$icon->show_all;
	$mainWin->signal_handlers_disconnect_by_func(\&main::QuitSub);
	$mainWin->signal_connect('destroy' => sub {
			$this->toggleMainWinVisibility();
			return 1;
		});
	$mainWin->signal_connect('delete-event' => sub {
			$this->toggleMainWinVisibility();
			return 1;
		});
}

sub rightClickMenu
{
	my($self,$event) = @_;
	my $i18n = $self->get_plugin_var('i18n');
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

# Plugin metadata
sub metainfo
{
    return
	{
		name => 'TrayIcon',
		title => 'System tray icon',
		description => 'This is a simple icon that sits in your system tray. When clicked, it will toggle the visibility of the Day Planner window.',
		version => '0.1.1',
		# TODO: bump apiversion when it has been done in dayplanner
		apiversion => 2,
		needs_modules => 'Gtk2::TrayIcon',
		author => 'Eskild Hustvedt',
		license => 'GNU General Public License version 3 or later',
	};
}

1;
