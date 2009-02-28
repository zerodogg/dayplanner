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

package DP::Plugin::ServicesSync;
use strict;
use warnings;
use IO::Socket::SSL;
use MIME::Base64;
use Digest::MD5 qw(md5_base64);
use DP::CoreModules::PluginFunctions qw(DPIntWarn GTK_Flush DP_DestroyProgressWin DPError DPCreateProgressWin Assert UpdatedData);
# Useful constants for prettier code
use constant { true => 1, false => 0 };
my $DPS_APILevel = '06';			# The DPS API level used/supported

sub new_instance
{
	my $this = shift;
	$this = {};
	bless($this);
	my $plugin = shift;
	$this->{plugin} = $plugin;

	# Check if the user wants to temporarily disable DPS
	if(defined $ENV{DP_DISABLE_SERVICES} and $ENV{DP_DISABLE_SERVICES} eq '1')
	{
		warn('Day Planner plugin ServicesSync has been disabled by the DP_DISABLE_SERVICES environment variable'."\n");
		return;
	}

	# Register our signals
	$plugin->register_signals(qw(DPS_ENTERPREFS DPS_PRE_SYNCHRONIZE DPS_POST_SYNCHRONIZE));
	# Connect to signals
	#$plugin->signal_connect('SAVEDATA',$this,'synchronize');
	$plugin->signal_connect('INIT',$this,'synchronize');
	$plugin->signal_connect('SHUTDOWN',$this,'synchronize');
	$plugin->signal_connect('CREATE_MENUITEMS',$this,'mkmenu');
	$plugin->signal_connect('DPS_ENTERPREFS',$this,'PreferencesWindow');

	$this->{i18n} = $plugin->get_var('i18n');

	# Metadata
	$this->{meta} =
	{
		name => 'ServicesSync',
		title => 'Calendar synchronization through Day Planner services',
		description => 'Synchronizes your Day Planner calendar with a Day Planner services synchronization server',
		version => 0.1,
		apiversion => 1,
		author => 'Eskild Hustvedt',
		license => 'GNU General Public License version 3 or later',
		needs_modules => 'IO::Socket::SSL',
	};
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
	my $menu =  [ '/'.$EditName.'/'.$i18n->get('_Synchronization') ,undef, sub { $plugin->signal_emit('DPS_ENTERPREFS'); },     0,  '<StockItem>',  'gtk-network'];
	# Add the menu
	push(@{$MenuItems},$menu);
	return;
}

sub synchronize
{
	my $this = shift;
	# Make sure that DPS is enabled in the config
	if(not (defined($this->{plugin}->get_confval('DPS_enable')) and $this->{plugin}->get_confval('DPS_enable') eq "1"))
	{
		return;
	}
	$this->{plugin}->signal_emit('DPS_PRE_SYNCHRONIZE');
	$this->DPS_Perform('SYNC');
	$this->{plugin}->signal_emit('DPS_POST_SYNCHRONIZE');
}

sub PreferencesWindow
{
	my $this = shift;
	my $plugin = shift;
	my $i18n = $plugin->get_var('i18n');
	my $MainWindow = $plugin->get_var('MainWindow');
	$MainWindow->set_sensitive(0);
	my $PreferencesWindow = Gtk2::Window->new();
	$PreferencesWindow->set_modal(1);
	$PreferencesWindow->set_transient_for($MainWindow);
	$PreferencesWindow->set_position('center-on-parent');
	$PreferencesWindow->set_title($i18n->get('Synchronization'));
	$PreferencesWindow->set_resizable(0);
	$PreferencesWindow->set_border_width(5);
	$PreferencesWindow->set_skip_taskbar_hint(1);
	$PreferencesWindow->set_skip_pager_hint(1);
	$PreferencesWindow->set_type_hint('dialog');
	my $Tooltips = Gtk2::Tooltips->new();
	$Tooltips->enable();

	# ==================================================================
	# ==================================================================
	# SYNCHRONIZATION TAB
	# ==================================================================
	# ==================================================================
	
	# Get and set the values we're going to use
	my $Host = $plugin->get_confval('DPS_host') ? $plugin->get_confval('DPS_host') : '';
	my $Port = $plugin->get_confval('DPS_port') ? $plugin->get_confval('DPS_port') : 4435;
	my $Username = $plugin->get_confval('DPS_user') ? $plugin->get_confval('DPS_user') : '';
	my $Password = $plugin->get_confval('DPS_pass') ? $plugin->get_confval('DPS_pass') : '';
	my $DPSWasStatus = $plugin->get_confval('DPS_enable');

	# Create the vbox
	my $Sync_VBox = Gtk2::VBox->new();
	$Sync_VBox->show();
	$PreferencesWindow->add($Sync_VBox);

	# Create the table
	my $Config_Table = Gtk2::Table->new(3,4);
	$Config_Table->show();

	# Enable/disable evolution checkbox
#	my $EnableDisableEButton = Gtk2::CheckButton->new($i18n->get('Enable GNOME integration'));
#	$Sync_VBox->pack_start($EnableDisableEButton,0,0,0);
#	if(EvoCompat_GetMode())
#	{
#		$EnableDisableEButton->set_active(true);
#	}
#	else
#	{
#		$EnableDisableEButton->set_active(false);
#	}
#	$EnableDisableEButton->signal_connect('toggled' => sub 
#		{
#			if ($EnableDisableEButton->get_active())
#			{
#				if(DPQuestion(
#						$i18n->get("This will enable GNOME integration mode. When enabled you will be able to view Day Planner events in the calendar in the GNOME panel.\n\nIt is not recommended that you enable this if you use Evolution because Day Planner will override certain evolution functions.\n\nAre you sure you want to enable GNOME integration?")
#				))
#				{
#					EvoCompat_Enable();
#					DPInfo("Evolution integration mode has been enabled. You may need to log out and in again for it to take effect.");
#				}
#			}
#			else
#			{
#				EvoCompat_Disable();
#			}
#			if (EvoCompat_GetMode())
#			{
#				$EnableDisableEButton->set_active(true);
#			}
#			else
#			{
#				$EnableDisableEButton->set_active(false);
#			}
#		});
#	$EnableDisableEButton->show();

	# Enable/disable checkbox
	my $EnableDisableCButton = Gtk2::CheckButton->new($i18n->get('Automatically synchronize an online copy of this calendar'));
	$Sync_VBox->pack_start($EnableDisableCButton,0,0,0);
	$EnableDisableCButton->signal_connect('toggled' => sub {
			if($EnableDisableCButton->get_active) {
					$plugin->set_confval('DPS_enable',1);
					$Config_Table->set_sensitive(1);
			} else {
				$plugin->set_confval('DPS_enable',0);
				$Config_Table->set_sensitive(0);
			}});
	if($plugin->get_confval('DPS_enable')) {
		$EnableDisableCButton->set_active(1);
		$EnableDisableCButton->signal_emit('toggled');
	} else {
		$EnableDisableCButton->set_active(0);
		$EnableDisableCButton->signal_emit('toggled');
	}
	$EnableDisableCButton->show();

	# Add the table to the UI
	$Sync_VBox->pack_start($Config_Table,0,0,0);
	
	# ==================================================================
	# HOST/PORT
	# ==================================================================
	
	# Host

	#  Label
	my $UseHost = Gtk2::Label->new($i18n->get('Server:'));
	$UseHost->show();
	$Config_Table->attach_defaults($UseHost, 0,1,0,1);
	
	#  Entry
	my $HostEntry = Gtk2::Entry->new();
	$HostEntry->set_text($Host);
	$HostEntry->show();
	$Config_Table->attach_defaults($HostEntry, 1,2,0,1);
	
	# Port
	
	#  Label
	my $UsePort = Gtk2::Label->new(' ' . $i18n->get('Port:'));
	$UsePort->show();
	$Config_Table->attach_defaults($UsePort, 2,3,0,1);
	
	#  Spinner
	my $PortAdjustment = Gtk2::Adjustment->new(0.0, 0.0, 65000.0, 1.0, 5.0, 0.0);
	my $PortSpinner = Gtk2::SpinButton->new($PortAdjustment,0,0);
	$PortSpinner->set_value($Port);
	$PortSpinner->show();
	$Config_Table->attach_defaults($PortSpinner, 3,4,0,1);
	
	# ==================================================================
	# USERNAME/PASSWORD
	# ==================================================================
	
	# Username
	#  Label
	my $UsernameLabel = Gtk2::Label->new($i18n->get('Username:'));
	$UsernameLabel->show();
	$Config_Table->attach_defaults($UsernameLabel, 0,1,1,2);
	
	#  Entry
	my $UserEntry = Gtk2::Entry->new();
	$UserEntry->set_text($Username);
	$UserEntry->show();
	$Config_Table->attach_defaults($UserEntry, 1,4,1,2);
	
	# Password
	#  Label
	my $PasswordLabel = Gtk2::Label->new($i18n->get('Password:'));
	$PasswordLabel->show();
	$Config_Table->attach_defaults($PasswordLabel, 0,1,2,3);
	
	#  Entry
	my $PasswordEntry = Gtk2::Entry->new();
	$PasswordEntry->set_text($Password);
	$PasswordEntry->show();
	$PasswordEntry->set_visibility(0);
	$Config_Table->attach_defaults($PasswordEntry, 1,4,2,3);
	
	# ==================================================================
	# FINALIZE WINDOW
	# ==================================================================
	my $ClosePerform = sub {
			$plugin->set_confval('DPS_user',$UserEntry->get_text());
			$plugin->set_confval('DPS_pass',$PasswordEntry->get_text());
			$plugin->set_confval('DPS_host',$HostEntry->get_text());
			$plugin->set_confval('DPS_port',$PortSpinner->get_value());
			# Make sure that the proper DPS settings are in place
			if($plugin->get_confval('DPS_enable')) {
				if(not $plugin->get_confval('DPS_user') or not $plugin->get_confval('DPS_pass') or not $plugin->get_confval('DPS_host') or not $plugin->get_confval('DPS_port')) {
					DPError($i18n->get('You have not entered the information required for synchronization to be enabled, it has been disabled.'));
					$plugin->set_confval('DPS_enable',0);
				}
			}
			$PreferencesWindow->hide();
			$PreferencesWindow->destroy();
			$MainWindow->set_sensitive(1);
		};
	# Handle closing
	$PreferencesWindow->signal_connect('delete-event' => $ClosePerform);
	
	# Add the buttons
	my $ButtonHBox = Gtk2::HBox->new();
	$ButtonHBox->show();
	$Sync_VBox->pack_start($ButtonHBox,0,0,0);

	my $CloseButton = Gtk2::Button->new_from_stock('gtk-close');
	$CloseButton->signal_connect('clicked' => $ClosePerform);
	$CloseButton->show();
	$ButtonHBox->pack_end($CloseButton,0,0,0);

	# Show the config window
	$PreferencesWindow->show();
}

# Purpose: Output an error occurring with DPS
# Usage: DPS_Error(User_Error, Technical_Error)
#	User_Error is displayed as a pop-up error dialog.
#	Technical_Error is DPIntWarn()ed, it is optional.
#	If no technical_error is supplied then User_error is used.
sub DPS_Error {
	my $this = shift;
	my $user_error = shift;
	Assert(defined($user_error));
	# Tech_error is set to user_error when not supplied
	my $tech_error = $_[0] ? $_[0] : $user_error;
	DPIntWarn("DPS: $tech_error");
	$this->DPS_Log($tech_error);
	if(defined($user_error)) {
		$this->{Error} = $user_error;
	}
}

# Purpose: Set the status in the DPS GUI Window
# Usage: DPS_Status(TEXT, COMPLETED);
#	COMPLETED is a number between 0 and 1 (such as 0.1, 0.5)
#	0 = 0%
#	1 = 100%
sub DPS_Status {
	my $this = shift;
	my ($Text, $Completed) = @_;
	return unless($this->{plugin}->get_var('Gtk2Init'));
	if(defined($this->{ProgressWin})) {
		$this->{ProgressWin}->{ProgressBar}->set_fraction($Completed);
		$this->{ProgressWin}->{ProgressBar}->set_text($Text);
		GTK_Flush();
	}
}

# Purpose: Upload data to a Day Planner services server
# Usage: DPS_Upload();
sub DPS_Upload {
	my $this = shift;
	my $plugin = $this->{plugin};
	my $iCalendar = $this->{plugin}->get_var('calendar');
	my $LastMD5 = $plugin->get_confval('DPS_LastMD5') ? $plugin->get_confval('DPS_LastMD5') : 'undef';
	my $SendData = encode_base64($iCalendar->get_rawdata(),'');
	chomp($SendData);
	my $MD5 = md5_base64($SendData);
	my $Reply = $this->DPS_DataSegment("SENDDATA $MD5 $LastMD5 $SendData 0");
	if(not $Reply eq 'OK') {
		# TODO: These need cleaning
		if($Reply =~ s/^ERR\s+(.*)$/$1/) {
			$this->DPS_Error($this->{i18n}->get('An error ocurred while uploading the data'), 'An error ocurred during upload of the data: ' . $Reply);
		} elsif($Reply =~ /^EXPIRED/) {
			$this->DPS_Error($this->{i18n}->get('Your account has expired. If you are using a paid service this may be because you have not paid for the current period. If not, you should contact your service provider to get information on why your account has expired.'), 'Account expired');
		} else {
			# Sending the data failed
			$this->DPS_Error($this->{i18n}->get_advanced('The server did not accept the uploaded data and replied with an unknown value: %(value)', { value => $Reply }));
		}
		return(undef);
	}
	# We successfully uploaded the data. So set DPS_LastMD5 and return true
	$plugin->set_confval('DPS_LastMD5',$MD5);
	return(1);
}

# Purpose: Download data from a Day Planner services server
# Usage: DPS_Download(MERGE?);
#	If MERGE is true then it will not overwrite the current data
#	with the downloaded data, but rather use the DP::iCalendar merge
#	function to merge it into place.
# This function itself is stupid, it doesn't know about MD5 sums of local data
# or anything. It will download the data no matter what, it is up to the caller
# to check if we actually need to download data or not.
sub DPS_Download {
	my $this = shift;
	my $Merge = shift;
	my $Data = $this->DPS_DataSegment('GETDATA');
	if($Data =~ /^OK/) {
		$this->DPS_Log('Downloaded data');
		my $Initial = $Data;
		my $MD5 = $Data;
		my $MainData = $Data;
		$Initial =~ s/^(\S+)\s+.*$/$1/;
		$MD5 =~ s/^(\S+)\s+(\S+)\s+.*/$2/;
		if(not $MainData =~ s/^(\S+)\s+(\S+)\s+(\S+)\s*$/$3/)
		{
			# FIXME: Rewrite this
			$this->DPS_Error("FATAL: UNABLE TO GRAB DATA. DUMPING DATA:\nData recieved: $Initial");
		}
		elsif(not md5_base64($MainData) eq $MD5)
		{
			# FIXME: Rewrite this
			$this->DPS_Error($this->{i18n}->get('The data became corrupted during download. You may want to attempt to synchronize again.'),'MD5 mismatch during download: got ' . md5_base64($MainData) . ' expected ' . $MD5);
		} 
		else
		{
			# Decode the base64 encoded data
			$MainData = decode_base64($MainData);
			# Remove junk and populate @DataArray
			my @DataArray;
			$MainData =~ s/\r//g;
			push(@DataArray, $_) foreach(split(/\n/,$MainData));
			$MainData = undef;
			my $iCalendar = $this->{plugin}->get_var('calendar');
			# If we're in merge mode then enable SMART MERGE and then add
			# the file, if not then clean and add the file
			my $iCalendarMain = $iCalendar->get_primary();
			if($Merge)
			{
				$iCalendarMain->enable('SMART_MERGE');
				$iCalendarMain->addfile(\@DataArray);
				$iCalendarMain->disable('SMART_MERGE');
			} 
			else 
			{
				$iCalendarMain->clean();
				$iCalendarMain->addfile(\@DataArray);
			}
			# Download succesful. Set DPS_LastMD5
			$this->{plugin}->set_confval('DPS_LastMD5',$MD5);
			UpdatedData();
			return(1);
		}
	} else {
		$this->DPS_Log("Unable to download data. Server replied: $Data");
	}
	# If we got this far then it means we failed.
	return(undef);
}

# Purpose: Synchronize our local data with the server data
# Usage: DPS_DataSync();
sub DPS_DataSync {
	my $this = shift;
	$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.2);
	my $iCalendar = $this->{plugin}->get_var('calendar');
	# Get information we need
	#	The server's data MD5 sum
	my $ServerMD5 = $this->DPS_DataSegment('GET_MD5');
	#	The MD5 sum of our current local data
	my $LocalMD5 = md5_base64(encode_base64($iCalendar->get_rawdata(),""));
	#	The MD5 sum of the data we last uploaded
	my $LastUpMD5 = $this->{plugin}->get_confval('DPS_LastMD5') ? $this->{plugin}->get_confval('DPS_LastMD5') : 'undef';

	# Okay, the required information is available.
	# First check if our current local MD5 sum matches the one on the server.
	# If it does then we return without doing anything at all.
	if(defined($LocalMD5) and defined($ServerMD5) and $ServerMD5 eq $LocalMD5) {
		$this->DPS_Log("ServerMD5[$ServerMD5] matched our LocalMD5[$LocalMD5]. Not doing anything");
		return(1);
	} 
	# It didn't match. So now we check if our last uploaded MD5 matches the servers MD5.
	# If it does then we just upload.
	elsif ($ServerMD5 eq $LastUpMD5 or $ServerMD5 eq '[NONE]') {
		$this->DPS_Log("Local data changed, uploading to DPS (local MD5 is $LocalMD5 and the servers MD5 is $ServerMD5)");
		$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.4);
		my $Return = $this->DPS_Upload();
		$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.8);
		UpdatedData();
		$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.9);
		return($Return);
	}
	# That didn't match either. So we check if our local MD5 is identical to the
	# last uploaded MD5. If that is the case then we just need to download the
	# data from the server.
	elsif ($LastUpMD5 eq $LocalMD5) {
		$this->DPS_Log('Remote data changed, downloading from DPS');
		$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.5);
		my $Return = $this->DPS_Download();
		$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.8);
		UpdatedData();
		$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.9);
		return($Return);
	}
	# Okay, nothing matched. This means that we have one local MD5 sum,
	# one remote MD5 sum and one "local last uploaded" MD5 sum - and they all differ.
	# We must here download the data from the server, merge it with our own and then
	# upload the new data.
	else {
		$this->DPS_Log('Both remote and local data has changed. Downloading, merging and reuploading');
		$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.3);
		if($this->DPS_Download(1)) {
			$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.6);
			my $Return = $this->DPS_Upload();
			$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.8);
			UpdatedData();
			$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.9);
			return($Return);
		}
	}
}

# Purpose: Log DPS info
# Usage: DPS_Log(INFO);
sub DPS_Log {
	my $this = shift;
	Assert(defined $_[0]);
	if(defined($this->{Log_FH})) {
		my ($lsec,$lmin,$lhour,$lmday,$lmon,$lyear,$lwday,$lyday,$lisdst) = localtime(time);
		$lhour = "0$lhour" unless $lhour >= 10;
		$lmin = "0$lmin" unless $lmin >= 10;
		$lsec = "0$lsec" unless $lsec >= 10;
		my $FH = $this->{Log_FH};
		print $FH "[$lhour:$lmin:$lsec] $_[0]\n";
	}
	return(1);
}

# Purpose: High-level API to DPS
# Usage: DPS_Perform(FUNCTION);
#	FUNCTION can be one of:
#	SYNC
#	...
sub DPS_Perform {
	my $this = shift;
	my $MainWindow = $this->{plugin}->get_var('MainWindow');
	# The function we are going to perform
	my $Function = shift;
	Assert($Function =~ /^(SYNC)$/);
	# A coderef to the code which we need to run to close the GUI
	# dialogues used.
	my $GuiEnded = sub {
		return unless($this->{plugin}->get_var('Gtk2Init'));
		DP_DestroyProgressWin($this->{ProgressWin});
		if(defined($this->{Error})) {
			DPError($this->{i18n}->get_advanced("An error occurred with the Day Planner services:\n\n%(error)",{ error => $this->{Error}}));
			delete($this->{Error});
		}
		delete($this->{ProgressWin});
		$MainWindow->set_sensitive(1);
	};

	# Verify that all required options are set in the config
	foreach my $Option (qw(host port user pass)) {
		unless(defined($this->{plugin}->get_confval("DPS_$Option")))
		{
			DPIntWarn("DPS enabled but the setting DPS_$Option is missing. Disabling.");
			$this->{plugin}->set_confval("DPS_$Option",0);
			return(undef);
		} else {
			$this->{$Option} = $this->{plugin}->get_confval("DPS_$Option");
		}
	}
	# Create the progress window
	if($this->{plugin}->get_var('Gtk2Init')) {
		$MainWindow->set_sensitive(0);
		$this->{ProgressWin} = DPCreateProgressWin($this->{i18n}->get('Services'), $this->{i18n}->get('Initializing'));
	}
	# Open up the logfile if it isn't open. This should be left open for the
	# entirety of the DPS session.
	my $SaveToDir = $this->{plugin}->get_var('confdir');
	if(not defined($this->{Log_FH})) {
		open($this->{Log_FH}, '>', "$SaveToDir/services.log");
		chmod(oct(600),"$SaveToDir/services.log");
		$this->DPS_Log('DPS initialized');
	}
	$this->DPS_Status($this->{i18n}->get('Connecting'),0);
	# Connect to the server, if this fails then we return undef without doing anything
	if(not $this->DPS_Connect()) {
		$GuiEnded->();
		return(undef);
	}
	$this->DPS_Status($this->{i18n}->get('Connected'),0.1);
	# Connection established, process $Function
	if($Function eq 'SYNC')
	{
		$this->DPS_DataSync();
	}
	$this->DPS_Status($this->{i18n}->get('Complete'),1);
	# Disconnect and return
	$this->DPS_Disconnect();
	$GuiEnded->();
	return(1);
}

# Purpose: Connect to a Day Planner services server.
# Usage: my $Return = DPS_Connect();
#		The arguments are optional and will be read from %DPServices if not supplied
sub DPS_Connect {
	my $this = shift;
	my $Host = $this->{host};
	my $Port = $this->{port};
	my $User = $this->{user};
	my $Password = decode_base64(decode_base64($this->{pass}));
	my $Error;
	# Connect
	$this->{socket} = IO::Socket::SSL->new(
					PeerAddr => $Host,
					PeerPort => $Port,
					Timeout => 10,
			) or do { $Error = IO::Socket::SSL::errstr(); };
			
	# Process errors if any occurred
	if($Error) {
		# If we have already displayed an error to the user this session, don't do it again
		if(defined($this->{Offline}) and $this->{Offline} == 1) {
			$this->DPS_Error(undef, "Unable to connect to $Host on port $Port: $@");
			return(undef);
		}

		$Error = IO_Socket_INET_Errors($Error);	# Get errors that are easier to process

			# Process network unreachable and bad hostname
		if($Error eq 'OFFLINE' or $Error eq 'BADHOST') {
			$this->{Offline} = 1;
			$this->DPS_Error(sprintf($this->{i18n}->get('Unable to connect to the Day Planner services server (%s).'), "$Host:$Port",) . " " . $this->{i18n}->get("You're probably not connected to the internet"), "Unable to connect to $Host on port $Port: $@ ($Error)");
		}
			# Process connection refused
		elsif($Error eq 'REFUSED') {
			$this->{Offline} = 1;
			$this->DPS_Error(sprintf($this->{i18n}->get('Unable to connect to the Day Planner services server (%s).'), "$Host:$Port") . ' ' . $this->{i18n}->get('The connection was refused by the server. Please verify your Day Planner services settings.') . "\n\n" . $this->{i18n}->get('If this problem persists, please contact your service provider'), "Unable to connect to $Host on port $Port: $@ ($Error)");
		} 
			# Process unknown errors
		else {
			$this->DPS_Error(sprintf($this->{i18n}->get("Unable to connect to the Day Planner services server (%s)."), "$Host:$Port") . " " . $this->{i18n}->get('If this problem persists, please contact your service provider'), "Unable to connect to $Host on port $Port: $@");
		}
		return(undef);
	}

	# The connection didn't fail, so delete $this->{Offline} if it exists
	delete($this->{Offline});

	# Authentication
	# First verify the API level
	my $APIREPLY = $this->DPS_DataSegment("APILEVEL $DPS_APILevel");
	return(undef) if $this->DPS_ErrorIfNeeded('OK', $APIREPLY, sub { $this->DPS_Disconnect();  $this->DPS_Error($this->{i18n}->get_advanced("The Day Planner services server you are connecting to does not support this version of Day Planner (%(version)).", { version => $this->{plugin}->get_var('version')}), "API error received from the server (my APILEVEL is $DPS_APILevel).");});
	# Send AUTH
	my $AUTHREPLY = $this->DPS_DataSegment("AUTH $User $Password");
	# If AUTH did not return OK then it failed and we just return undef.
	return(undef) if $this->DPS_ErrorIfNeeded('OK', $AUTHREPLY, sub { $this->DPS_Disconnect(); $this->DPS_Error($this->{i18n}->get('The username and/or password is incorrect.'),'Authentication error');});
	$this->DPS_Log("Connected to $Host on port $Port as user $User");
	return('OK');
}

# Purpose: Disconnect from a Day Planner services daemon
# Usage: DPS_Disconnect();
sub DPS_Disconnect {
	my $this = shift;
	my $Socket = $this->{socket};
	close($Socket);
	delete($this->{socket});
	$this->DPS_Log('Disconnected');
	return(1);
}

# Purpose: Do something when an error has occurred
# Usage: my $Return = DPS_ErrorIfNeeded(EXPECTED_REPLY, RECIEVED_REPLY, CODEREF);
#	The CODEREF will be run if EXPECTED_REPLY does not eq RECIEVED_REPLY
sub DPS_ErrorIfNeeded {
	my $this = shift;
	my ($Expected, $Recieved, $ErrorSub) = @_;
	unless($Expected eq $Recieved) {
		$ErrorSub->($Recieved);
		return(1);
	} else {
		return(0);
	}
}

# Purpose: Send data to a Day Planner services daemon and get the reply
# Usage: my $Reply = DPS_DataSegment(DATA_TO_SEND);
sub DPS_DataSegment {
	my $this = shift;
	my $Socket = $this->{socket};
	print $Socket "$_[0]\n";
	my $Data = <$Socket>;
	if(not defined($Data)) {
		$Data = '';
	} else {
		chomp($Data);
	}
	return($Data);
}

# Purpose: Return better errors than IO::Socket::SSL does.
# Usage: my $ERROR = IO_Socket_INET_Errors($@);
#	Errors:
#		OFFLINE = Network is unreachable
#		REFUSED = Connection refused
#		BADHOST = Bad hostname (should often be handled as OFFLINE)
#		TIMEOUT = The connection timed out
#		* = Anything else simply returns $@
sub IO_Socket_INET_Errors {
	my $Error = shift;
	if($Error =~ /Network is unreachable/i) {
		return('OFFLINE');
	} elsif ($Error =~ /Bad hostname/i) {
		return('BADHOST');
	} elsif ($Error =~ /Connection refused/i) {
		return('REFUSED');
	} elsif ($Error =~ /timeout/i) {
		return('TIMEOUT');
	} else {
		DPIntWarn("Unknown IO::Socket::SSL error: $Error");
		return($Error);
	}
}
1;
