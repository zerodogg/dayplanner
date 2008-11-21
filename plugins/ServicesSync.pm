#!/usr/bin/perl
# Day Planner
# A graphical Day Planner written in perl that uses Gtk2
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

package DP::Plugin::ServicesSync;
use strict;
use warnings;
use IO::Socket::SSL;
use MIME::Base64;
use Digest::MD5 qw(md5_base64);
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
	my $UserConfig = $this->{plugin}->get_data('config');

	# Make sure that DPS is enabled in the config
	if(not (defined($UserConfig->{DPS_enable}) and $UserConfig->{DPS_enable} eq "1"))
	{
		return;
	}
	# Check if the user wants to temporarily disable DPS
	return if(defined($ENV{DP_DISABLE_SERVICES}) and $ENV{DP_DISABLE_SERVICES} eq "1");

	$plugin->signal_connect('SAVEDATA',$this,'synchronize');
	$plugin->signal_connect('INIT',$this,'synchronize');
	$plugin->signal_connect('MK_PREFS_WINDOW',$this,'prefsWindow');
	$this->{i18n} = $plugin->get_data('i18n');
	return $this;
}

sub synchronize
{
	my $this = shift;
	$this->DPS_Perform('SYNC');
}

sub prefsWindow
{
	my $this = shift;
}

# Purpose: Output an error occurring with DPS
# Usage: DPS_Error(User_Error, Technical_Error)
#	User_Error is displayed as a pop-up error dialog.
#	Technical_Error is DPIntWarn()ed, it is optional.
#	If no technical_error is supplied then User_error is used.
sub DPS_Error {
	my $this = shift;
	my $user_error = shift;
	main::Assert(defined($user_error));
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
	return unless($this->{plugin}->get_data('Gtk2Init'));
	if(defined($this->{ProgressWin})) {
		$this->{ProgressWin}->{ProgressBar}->set_fraction($Completed);
		$this->{ProgressWin}->{ProgressBar}->set_text($Text);
		main::GTK_Flush();
	}
}

# Purpose: Upload data to a Day Planner services server
# Usage: DPS_Upload();
sub DPS_Upload {
	my $this = shift;
	my $iCalendar = $this->{plugin}->get_data('calendar');
	my $LastMD5 = $this->{plugin}->get_data('state')->{DPS_LastMD5} ? $this->{plugin}->get_data('state')->{DPS_LastMD5} : "undef";
	my $SendData = encode_base64($iCalendar->get_rawdata(),'');
	chomp($SendData);
	my $MD5 = md5_base64($SendData);
	my $Reply = $this->DPS_DataSegment("SENDDATA $MD5 $LastMD5 $SendData 0");
	if(not $Reply eq 'OK') {
		# TODO: These need cleaning
		if($Reply =~ s/^ERR\s+(.*)$/$1/) {
			DPS_Error($this->{i18n}->get('An error ocurred while uploading the data'), 'An error ocurred during upload of the data: ' . $Reply);
		} elsif($Reply =~ /^EXPIRED/) {
			DPS_Error($this->{i18n}->get('Your account has expired. If you are using a paid service this may be because you have not paid for the current period. If not, you should contact your service provider to get information on why your account has expired.'), 'Account expired');
		} else {
			# Sending the data failed
			DPS_Error($this->{i18n}->get_advanced('The server did not accept the uploaded data and replied with an unknown value: %(value)', { value => $Reply }));
		}
		return(undef);
	}
	# We successfully uploaded the data. So set DPS_LastMD5 and return true
	$this->{plugin}->get_data('state')->{DPS_LastMD5} = $MD5;
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
			DPS_Error("FATAL: UNABLE TO GRAB DATA. DUMPING DATA:\nData recieved: $Initial");
		}
		elsif(not md5_base64($MainData) eq $MD5)
		{
			# FIXME: Rewrite this
			DPS_Error($this->{i18n}->get('The data became corrupted during download. You may want to attempt to synchronize again.'),'MD5 mismatch during download: got ' . md5_base64($MainData) . ' expected ' . $MD5);
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
			my $iCalendar = $this->{plugin}->get_data('calendar');
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
			$this->{plugin}->get_data('state')->{DPS_LastMD5} = $MD5;
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
	my $iCalendar = $this->{plugin}->get_data('calendar');
	# Get information we need
	#	The server's data MD5 sum
	my $ServerMD5 = $this->DPS_DataSegment('GET_MD5');
	#	The MD5 sum of our current local data
	my $LocalMD5 = md5_base64(encode_base64($iCalendar->get_rawdata(),""));
	#	The MD5 sum of the data we last uploaded
	my $LastUpMD5 = $this->{plugin}->get_data('state')->{DPS_LastMD5};

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
		my $Return = DPS_Upload();
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
		my $Return = DPS_Download();
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
		if(DPS_Download(1)) {
			$this->DPS_Status($this->{i18n}->get('Synchronizing'),0.6);
			my $Return = DPS_Upload();
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
	main::Assert(defined $_[0]);
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
	my $UserConfig = $this->{plugin}->get_data('config');
	my $MainWindow = $this->{plugin}->get_data('MainWindow');
	# The function we are going to perform
	my $Function = shift;
	main::Assert($Function =~ /^(SYNC)$/);
	# A coderef to the code which we need to run to close the GUI
	# dialogues used.
	my $GuiEnded = sub {
		return unless($this->{plugin}->get_data('Gtk2Init'));
		main::DP_DestroyProgressWin($this->{ProgressWin});
		if(defined($this->{Error})) {
			DPError($this->{i18n}->get_advanced("An error occurred with the Day Planner services:\n\n%(error)",{ error => $this->{Error}}));
			delete($this->{Error});
		}
		delete($this->{ProgressWin});
		$MainWindow->set_sensitive(1);
	};

	# Verify that all required options are set in the config
	foreach my $Option (qw(host port user pass)) {
		unless(defined($UserConfig->{"DPS_$Option"}) and length($UserConfig->{"DPS_$Option"})) {
			DPIntWarn("DPS enabled but the setting DPS_$Option is missing. Disabling.");
			$UserConfig->{DPS_enable} = 0;
			return(undef);
		} else {
			$this->{$Option} = $UserConfig->{"DPS_$Option"};
		}
	}
	return if not DPS_SSLSocketTest();
	# Create the progress window
	if($this->{plugin}->get_data('Gtk2Init')) {
		$MainWindow->set_sensitive(0);
		$this->{ProgressWin} = main::DPCreateProgressWin($this->{i18n}->get('Services'), $this->{i18n}->get('Initializing'));
	}
	# Open up the logfile if it isn't open. This should be left open for the
	# entirety of the DPS session.
	my $SaveToDir = $this->{plugin}->get_data('confdir');
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

# Purpose: Test for IO::Socket::SSL
# Usage: DPS_SSLSocketTest();
sub DPS_SSLSocketTest {
	my $this = shift;
	# Make sure the IO::Socket::SSL module is available and loaded
	if(not main::runtime_use('IO::Socket::SSL',true)) {
		if (not $this->{IO_SOCKET_SSL_ERR_DISPLAYED}) {
			DPError($this->{i18n}->get("You don't have the IO::Socket:SSL module. This module is required for the Day Planner services to function. The services will not function until this module is installed."));
			$this->{IO_SOCKET_SSL_ERR_DISPLAYED} = true;
		}
		return(false);
	}
	return(true);
}

# Purpose: Connect to a Day Planner services server.
# Usage: my $Return = DPS_Connect();
#		The arguments are optional and will be read from %DPServices if not supplied
sub DPS_Connect {
	my $this = shift;
	my $Host = $this->{host};
	my $Port = $this->{port};
	my $User = $this->{user};
	my $Password = $this->{pass};
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
			DPS_Error(undef, "Unable to connect to $Host on port $Port: $@");
			return(undef);
		}

		$Error = IO_Socket_INET_Errors($Error);	# Get errors that are easier to process

			# Process network unreachable and bad hostname
		if($Error eq 'OFFLINE' or $Error eq 'BADHOST') {
			$this->{Offline} = 1;
			DPS_Error(sprintf($this->{i18n}->get('Unable to connect to the Day Planner services server (%s).'), "$Host:$Port",) . " " . $this->{i18n}->get("You're probably not connected to the internet"), "Unable to connect to $Host on port $Port: $@ ($Error)");
		}
			# Process connection refused
		elsif($Error eq 'REFUSED') {
			$this->{Offline} = 1;
			DPS_Error(sprintf($this->{i18n}->get('Unable to connect to the Day Planner services server (%s).'), "$Host:$Port") . ' ' . $this->{i18n}->get('The connection was refused by the server. Please verify your Day Planner services settings.') . "\n\n" . $this->{i18n}->get('If this problem persists, please contact your service provider'), "Unable to connect to $Host on port $Port: $@ ($Error)");
		} 
			# Process unknown errors
		else {
			DPS_Error(sprintf($this->{i18n}->get("Unable to connect to the Day Planner services server (%s)."), "$Host:$Port") . " " . $this->{i18n}->get('If this problem persists, please contact your service provider'), "Unable to connect to $Host on port $Port: $@");
		}
		return(undef);
	}

	# The connection didn't fail, so delete $this->{Offline} if it exists
	delete($this->{Offline});

	# Authentication
	# First verify the API level
	my $APIREPLY = $this->DPS_DataSegment("APILEVEL $DPS_APILevel");
	return(undef) if $this->DPS_ErrorIfNeeded('OK', $APIREPLY, sub { $this->DPS_Disconnect();  DPS_Error($this->{i18n}->get_advanced("The Day Planner services server you are connecting to does not support this version of Day Planner (%(version)).", { version => $this->{plugin}->get_data('version')}), "API error received from the server (my APILEVEL is $DPS_APILevel).");});
	# Send AUTH
	my $AUTHREPLY = $this->DPS_DataSegment("AUTH $User $Password");
	# If AUTH did not return OK then it failed and we just return undef.
	return(undef) if $this->DPS_ErrorIfNeeded('OK', $AUTHREPLY, sub { $this->DPS_Disconnect(); DPS_Error($this->{i18n}->get('The username and/or password is incorrect.'),'Authentication error');});
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

1;
