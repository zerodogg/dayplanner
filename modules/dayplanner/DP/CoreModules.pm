# Day Planner core modules
# A graphical Day Planner written in perl that uses Gtk2
# Copyright (C) Eskild Hustvedt 2006, 2007, 2008
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

use strict;
use warnings;
# Useful constants for prettier code
use constant { true => 1, false => 0 };
use FindBin;

our $Version = '0.11';
my $VersionName = 'GIT';
my %RuntimeModules;		# Keeps track of modules loaded during runtime

# NOTE:
# THIS DOES NOT DEFINE A PACKAGE, ON PURPOSE!
# Some functions start with P_, this is because the "proper" function is here,
# while other components might have convenience wrappers.

# Purpose: Find out if a command is in PATH or not
# Usage: InPath(COMMAND);
sub InPath {
	foreach (split /:/, $ENV{PATH}) { if (-x "$_/@_" and ! -d "$_/@_" ) {   return 1; } } return 0;
}

# Purpose: Get the XDG dir
# Usage: GetXDGDir();
sub GetXDGDir
{
	# First detect the HOME directory, and set $ENV{HOME} if successfull,
	# if not we just fall back to the value of $ENV{HOME}.
	my $HOME = getpwuid($>);
	if(-d $HOME) {
		$ENV{HOME} = $HOME;
	}
	# Check for XDG_CONFIG_HOME in the env
	my $XDG_CONFIG_HOME;
	if(defined($ENV{XDG_CONFIG_HOME})) {
		$XDG_CONFIG_HOME = $ENV{XDG_CONFIG_HOME};
	}
	else
	{
		if(defined($ENV{HOME}) and length($ENV{HOME})) {
			# Verify that HOME is set properly
			if(not -d $ENV{HOME}) {
				DP_InitI18n();
				print(i18nwrapper_advanced("The home directory of the user %(user) doesn't exist at %(path)! Please verify that the environment variable %(VAR) is properly set. Unable to continue\n", { user => [getpwuid($<)]->[0], path => $ENV{HOME}, VAR => 'HOME'}));
				Gtk2Init();
				DPError(i18nwrapper_advanced("The home directory of the user %(user) doesn't exist at %(path)! Please verify that the environment variable %(VAR) is properly set. Unable to continue\n", { user => [getpwuid($<)]->[0], path => $ENV{HOME}, VAR => 'HOME'}));
				die("\n");
			}
			$XDG_CONFIG_HOME = "$ENV{HOME}/.config";
		} else {
			Gtk2Init();
			DPError(i18nwrapper_advanced("The environment variable %(VAR) is not set! Unable to continue\n", { VAR => 'HOME'}));
			die(i18nwrapper_advanced("The environment variable %(VAR) is not set! Unable to continue\n", { VAR => 'HOME'}));
		}
	}
	return($XDG_CONFIG_HOME);
}

# Purpose: Detect the user config  directory
# Usage: DetectConfDir();
sub DetectConfDir
{
	# Compatibility mode, using the old conf dir
	if(-d $ENV{HOME}.'/.dayplanner')
	{
		return($ENV{HOME}.'/.dayplanner');
	}

	my $XDG_CONFIG_HOME = GetXDGDir();

	return($XDG_CONFIG_HOME.'/dayplanner');
}

# Purpose: Parse a date string and return various date fields
# Usage: my ($Year, $Month, $Day) = ParseDateString(STRING);
sub ParseDateString {
	my $String = shift;
	# This function is currently stupid, so it doesn't really support more than
	# one format. It is also very strict about that format.
	# This can easily be improved though.
	my $Year = $String;
	my $Month = $String;
	my $Day = $String;
	$Year =~ s/^\d+\.\d+\.(\d\d\d\d)$/$1/;
	$Month =~ s/^\d+\.(\d+)\.\d\d\d\d$/$1/;
	$Day =~ s/^(\d+).*$/$1/;

	# Drop leading zeros from returning
	$Month =~ s/^0//;
	$Day =~ s/^0//;
	return($Year,$Month,$Day);
}

# Purpose: Parse the contents of a text entry field containing various dates
# 		and return an arrayref of dates in the format DD.MM.YYYY
# Usage: my $Ref = ParseEntryField(TEXT ENTRY OBJECT);
sub ParseEntryField {
	my $Field = shift;
	# First get the text
	my $FieldText = $Field->get_text();
	# If it is empty then return an empty array
	if(not $FieldText =~ /\S/) {
		return([]);
	}
	my @ReturnArray;
	# Parse the entry field
	foreach my $Text (split(/[,|\s]+/, $FieldText)) {
		$Text =~ s/\s+//g;
		if($Text =~ /^\d+\.\d+.\d\d\d\d$/) {
			push(@ReturnArray, $Text);
		} else {
			DPIntWarn("Unrecognized date string (should be DD.MM.YYYY): $Text");
		}
	}
	return(\@ReturnArray);
}

# Purpose: Report a bug
# Usage: ReportBug();
sub ReportBug
{
	my $BugUrl = 'http://www.day-planner.org/index.php/development/bugs/?b_version='.$Version;
	if ($VersionName eq 'GIT')
	{
		$BugUrl .= '&b_isgit=1';
	}
	else
	{
		$BugUrl .= '&b_isgit=0';
	}
	LaunchWebBrowser($BugUrl);
}

# Purpose: Get OS/distro version information
# Usage: print "OS: ",GetDistVer(),"\n";
sub GetDistVer {
	# Try LSB first
	my %LSB;
	if (-e '/etc/lsb-release')
	{
		LoadConfigFile('/etc/lsb-release',\%LSB);
		if(defined($LSB{DISTRIB_ID}) and $LSB{DISTRIB_ID} =~ /\S/ and defined($LSB{DISTRIB_RELEASE}) and $LSB{DISTRIB_RELEASE} =~ /\S/)
		{
			my $ret = '/etc/lsb-release: '.$LSB{DISTRIB_ID}.' '.$LSB{DISTRIB_RELEASE};
			if(defined($LSB{DISTRIB_CODENAME}))
			{
				$ret .= ' ('.$LSB{DISTRIB_CODENAME}.')';
			}
			return($ret);
		}
	}
	# GNU/Linux and BSD
	foreach(qw/mandriva mandrakelinux mandrake fedora redhat red-hat ubuntu debian gentoo suse distro dist slackware freebsd openbsd netbsd dragonflybsd NULL/)
	{
		if (-e "/etc/$_-release" or -e "/etc/$_-version" or -e "/etc/${_}_version" or $_ eq "NULL") {
			my ($DistVer, $File, $VERSION_FILE);
			if(-e "/etc/$_-release") {
				$File = "$_-release";
				open($VERSION_FILE, '<', "/etc/$_-release");
				$DistVer = <$VERSION_FILE>;
			} elsif (-e "/etc/$_-version") {
				$File = "$_-version";
				open($VERSION_FILE, '<', "/etc/$_-release");
				$DistVer = <$VERSION_FILE>;
			} elsif (-e "/etc/${_}_version") {
				$File = "${_}_version";
				open($VERSION_FILE, '<', "/etc/${_}_version");
				$DistVer = <$VERSION_FILE>;
			} elsif ($_ eq 'NULL') {
				last unless -e '/etc/version';
				$File = 'version';
				open($VERSION_FILE, '<', '/etc/version');
				$DistVer = <$VERSION_FILE>;
			}
			close($VERSION_FILE);
			chomp($DistVer);
			return("/etc/$File: $DistVer");
		}
	}
	# Didn't find anything yet. Get uname info
	my ($sysname, $nodename, $release, $version, $machine) = POSIX::uname();
	if ($sysname =~ /darwin/i) {
		my $DarwinName;
		my $DarwinOSVer;
		# Darwin kernel, try to get OS X info.
		if(InPath('sw_vers')) {
			if(eval('use IPC::Open2;1')) {
				if(open2(my $SW_VERS, my $NULL_IN, 'sw_vers')) {
					while(<$SW_VERS>) {
						chomp;
						if (s/^ProductName:\s+//gi) {
							$DarwinName = $_;
						} elsif(s/^ProductVersion:\s+//) {
							$DarwinOSVer = $_;
						}
					}
					close($SW_VERS);
				}
			}
		}
		if(defined($DarwinOSVer) and defined($DarwinName)) {
			return("$DarwinName $DarwinOSVer ($machine)");
		}
	}
	# Detect additional release/version files
	my $RelFile;
	foreach(glob('/etc/*'))
	{
		next if not /(release|version)/i;
		next if m/\/(subversion|lsb-release)$/;
		if ($RelFile)
		{
			$RelFile .= ', '.$_;
		}
		else
		{
			$RelFile = ' ('.$_;
		}
	}
	if ($RelFile)
	{
		$RelFile .= ')';
	}
	else
	{
		$RelFile = '';
	}
	# Some distros set a LSB DISTRIB_ID but no version, try DISTRIB_ID
	# along with the kernel info.
	if ($LSB{DISTRIB_ID})
	{
		return($LSB{DISTRIB_ID}."/Unknown$RelFile ($sysname $release $version $machine)");
	}
	return("Unknown$RelFile ($sysname $release $version $machine)");
}

# Purpose: Launch a web browser with the supplied URL
# Usage: LaunchWebBrowser(URL);
sub LaunchWebBrowser {
	my $URL = shift;
	# Check if URL is a ref. If it is that means we're being used in a gtk2 callback
	# and the first arg is the object we're called from, so shift again to the second
	# arg we recieved which is the real url.
	if(ref($URL)) {
		$URL = shift;
	}
	my $Browser;
	# First check for the BROWSER env var
	if(defined($ENV{BROWSER}) and length($ENV{BROWSER})) {
		# Allow it to be a :-seperated variable - this doesn't slow us down
		# and is future-proof(tm)
		foreach my $Part (split(/:/,$ENV{BROWSER}))
		{
			if(InPath($Part) or -x $Part) {
				$Browser = $Part;
			}
		}
	}
	# Then check for various known file launchers and web browsers
	if(not $Browser) {
		foreach(qw/xdg-open gnome-open exo-open mozffremote mozilla-firefox firefox iceweasel epiphany galeon midori mozilla seamonkey konqueror dillo opera www-browser/) {
			if(InPath($_)) {
				$Browser = $_;
				last;
			}
		}
	}
	# Then launch if found, or output an error if not found
	if($Browser) {
		my $PID = fork();
		if(not $PID) {
			exec($Browser,$URL);
		}
	} else {
		# This should very rarely happen
		DPIntWarn("Failed to detect any browser to launch for the URL $URL");
	}
}

# Purpose: Write the configuration file
# Usage: P_WriteConfig(DIRECTORY, FILENAME,HASH);
sub P_WriteConfig {
	# The parameters
	my $Dir = shift;
	my $File = shift;
	my %UserConfig = @_;
	# Verify the options first
	unless(defined($UserConfig{Events_NotifyPre}) and length($UserConfig{Events_NotifyPre})) {
		$UserConfig{Events_NotifyPre} = '30min';
	}
	unless(defined($UserConfig{Events_DayNotify}) and length($UserConfig{Events_DayNotify})) {
		$UserConfig{Events_DayNotify} = 0;
	}

	my %Explanations = (
		Events_NotifyPre => "If Day Planner should notify about an event ahead of time.\n#  0 = Don't notify\n# Other valid values: 10min, 20min, 30min, 45min, 1hr, 2hrs, 4hrs, 6hrs",
		Events_DayNotify => "If Day Planner should notify about an event one day before it occurs.\n#  0 - Don't notify one day in advance\n#  1 - Do notify one day in advance",
		HTTP_Calendars => 'The space-seperated list of http calendar subscriptions',
		HEADER => "Day Planner $Version configuration file",
	);
	
	# Write the actual file
	WriteConfigFile("$Dir/$File", \%UserConfig, \%Explanations);

	# Tell the daemon to reload the config file
	# FIXME: Need some generic method to check.
#	if($DaemonInitialized) {
#		Daemon_SendData('RELOAD_CONFIG');
#	}
	# Enforce perms
	chmod(oct(600),"$Dir/$File");
	return(%UserConfig);
}

# Purpose: Load the configuration file
# Usage: P_LoadConfig(DIR,FILE,HASH);
sub P_LoadConfig {
	# The parameters
	my $Dir = shift;
	my $File = shift;
	my %UserConfig;
	# If it doesn't exist then we call WriteConfig first
	if(not -e "$Dir/$File")
	{
		WriteConfig($Dir, $File);
	}
	
	my %OptionRegexHash = (
			Events_NotifyPre => '^(\d+(min|hrs?){1}|0){1}$',
			Events_DayNotify => '^\d+$',
			HTTP_Calendars => '.?',
			# Kept for backwards compatibility
			DPS_enable => '^(1|0)$',
			DPS_port => '^\d+$',
			DPS_user => '^.+$',
			DPS_host => '^.+$',
			DPS_pass => '^.+$',
		);

	LoadConfigFile("$Dir/$File", \%UserConfig, \%OptionRegexHash,1);
	return(%UserConfig);
}

# Purpose: Portable mkpath()
# Usage: DP_mkpath(PATH);
sub DP_mkpath
{
	my $path = shift;
	if(runtime_use('File::Path',true))
	{
		return(File::Path::mkpath($path));
	}
	else
	{
		DPIntWarn("Load of module 'File::Path' failed. Will attempt to use fallback version. This may not work on non-maemo platforms");
		my $tpath = '/';
		foreach my $part(split(/\//,$path))
		{
			$tpath .= $part .'/';
			if (not -d $tpath)
			{
				my $ret = mkdir($tpath);
				if(not $ret)
				{
					return $ret;
				}
			}
		}
		return true;
	}
}

# Purpose: Create the directory in $SaveToDir if it doesn't exist and display a error if it fails
# Usage: CreateSaveDir();
sub P_CreateSaveDir {
	my $SaveToDir = shift;
	if(not -e $SaveToDir)
	{
		DP_mkpath($SaveToDir) or do {
				DPError(i18nwrapper_advanced("Unable to create the directory %(directory): %(error)\nManually create this directory before closing this dialog.", { directory => $SaveToDir, error => $!}));
				unless(-d $SaveToDir) {
					die("$SaveToDir does not exist, I was unable to create it and the user didn't create it\n");
				}
		};
		chmod(oct(700),$SaveToDir);
	}
}

# Purpose: Create the upcoming events string
# Usage: GetUpcomingEventsString()
sub GetUpcomingEventsString
{
	my $iCalendar = shift;
	my $NewUpcoming;
	my $HasUpcoming;
	my %InformationHash;
	my %DayNames = (
		0 => i18nwrapper('Sunday'),
		1 => i18nwrapper('Monday'),
		2 => i18nwrapper('Tuesday'),
		3 => i18nwrapper('Wednesday'),
		4 => i18nwrapper('Thursday'),
		5 => i18nwrapper('Friday'),
		6 => i18nwrapper('Saturday'),
	);

	# Today is
	my $TheTime = time();

	# Prepare
	my $FirstDay = 1;
	my $AddDays = 7;

	# Loop used to populate the %InformationHash
	while($AddDays) {
		$AddDays--;	# One less day to add
		$TheTime += 86400;

		$InformationHash{$TheTime} = {};
		my $h = $InformationHash{$TheTime};
		
		my ($getsec,$getmin,$gethour,$getmday,$getmonth,$getyear,$getwday,$getyday,$getisdst) = localtime($TheTime);	# Get the real time of this day
		$getmonth++;	# Month should be 1-12 not 0-11
		my $Year = $getyear;

		my $HumanYear = $getyear+1900;	# Human readable year

		if($FirstDay) {
			$h->{text}= i18nwrapper('Tomorrow');
			$h->{dayname} = $h->{text};
			$FirstDay = 0;
		} else {
			$h->{text} .= "\n\n";
			$h->{text} .= $DayNames{$getwday};
			$h->{dayname} = $DayNames{$getwday};
		}
		$h->{date} = "$getmday.$getmonth.$HumanYear";
		$h->{text} .= " ($getmday.$getmonth.$HumanYear) :";
		my $HasEvents;
		if(my $DateHash = $iCalendar->get_dateinfo($Year+1900, $getmonth, $getmday)) {
			# FIXME: This sort should be so that alphabetical chars come first, then numbers
			# This so that DAY comes before the normal events.
			foreach my $time (sort(@{$iCalendar->get_dateinfo($HumanYear,$getmonth,$getmday)})) {
				foreach my $UID (@{$iCalendar->get_timeinfo($HumanYear,$getmonth,$getmday,$time)}) {
					$HasEvents = 1;
					# If the time is DAY then it lasts the entire day
					if($time eq 'DAY') {
						$h->{text} .= "\n" . GetSummaryString($UID);
					} else {
						# TRANSLATORS: String used in the list of upcoming events in the
						# 		lower right hand corner of the UI. You should
						# 		probably keep this short.
						$h->{text} .= "\n" . i18nwrapper_advanced('At %(time)', { 'time' =>  i18nwrapper_AMPM_From24($time)}) . ': ' . GetSummaryString($UID);
					}
				}
			}
		}
		unless($HasEvents) {
			# TRANSLATORS: This is used in the upcoming events widget. It is displayed for a day (or set of days)
			#  when no events are present. Ie: Tomorrow (24.02.2007): (nothing).
			$h->{text} .= "\n" . i18nwrapper('(nothing)');
			$h->{noevents} = 1;
		} else {
			$HasUpcoming = 1;
		}

	}
	unless($HasUpcoming) {
		$NewUpcoming = i18nwrapper('No upcoming events exist for the next seven days');
	} else {
		my $LoopNum;
		# Remove duplicate (nothing)'s
		foreach my $key (sort(keys(%InformationHash))) {
			# If the key doesn't exist (any more) or doesn't have noevents then skip it
			next unless(defined($InformationHash{$key}));
			$LoopNum++;		# Up the loop counter
			next unless(defined($InformationHash{$key}{noevents}));
			# Find out which key is next
			my $Next = $key;
			$Next += 86400;
			# Skip if the next key doesn't have noevents set
			next unless(defined($InformationHash{$Next}) and defined($InformationHash{$Next}{noevents}));

			my @OtherNoevents;	# Array of the next keys without any events
			my $LastDate;
			my $LastDay;		# The last day with noevents

			# For each of the next dates with no events set it up for usage here and if we had another
			# noevents before this push it onto the @OtherNoevents array and replace the $LastDay value
			# with ours.
			while(defined($InformationHash{$Next}) and defined($InformationHash{$Next}{noevents})) {
				$LastDate = $InformationHash{$Next}{date};
				if(defined($LastDay)) {
					push(@OtherNoevents, $LastDay);
				}
				$LastDay = $Next;
				$Next += 86400;
			}
			# Reset the current text 
			if($LoopNum > 1) {
				$InformationHash{$key}{text} = "\n\n";
			} else {
				$InformationHash{$key}{text} = '';
			}
			# If there is something in @OtherNoevents then do more processing
			if(@OtherNoevents) {
				# First day (current key)
				$InformationHash{$key}{text} .= "$InformationHash{$key}{dayname},";

				my $Counter;	# Count how many times we've gone through the foreach
				foreach(@OtherNoevents) {
					$Counter++;	# Up the counter
					$InformationHash{$key}{text} .= " $InformationHash{$_}{dayname}";
					unless($Counter eq scalar(@OtherNoevents)) {	# If the counter doesn't equal the number of entries
											# in the array then append a comma.
						$InformationHash{$key}{text} .= ',';
					}
					# Delete the key
					delete($InformationHash{$_});
				}
				# Append the last entries
				# TRANSLATORS: This is used to bind together a list. It is a list of days
				# 	such as: Friday, Saturday *and* Sunday.
				$InformationHash{$key}{text} .= ' ' . i18nwrapper('and') . " $InformationHash{$LastDay}{dayname}";
			} else {
				# Build the string
				$InformationHash{$key}{text} .= "$InformationHash{$key}{dayname} " . i18nwrapper('and') . " $InformationHash{$LastDay}{dayname}";
			}
			# Delete the $LastDay key
			delete($InformationHash{$LastDay});
			# Finalize the string
			$InformationHash{$key}{text} .= " ($InformationHash{$key}{date}-$LastDate): " . i18nwrapper('(nothing)');
		}
		# Build our $NewUpcoming
		foreach my $key(sort(keys(%InformationHash))) {
			$NewUpcoming .= $InformationHash{$key}{text};
		}
	}
	return($NewUpcoming);
}

# Purpose: Load a module during runtime or display an error if we can't
# Usage: runtime_use('MODULENAME',SILENT?);
# 	If not in silent mode it will output an error about a missing core module
# 	and explain that the installation is corrupt.
sub runtime_use
{
	my $module = shift;
	# Return if it is present in the hash, regardless of true/false value.
	return($RuntimeModules{$module}) if defined($RuntimeModules{$module});
	if(eval("use $module; 1")) {
		$RuntimeModules{$module} = true;
		return(true);
	} else {
		$RuntimeModules{$module} = false;
		my $silent = shift;
		if(not $silent) {
			DPIntWarn("FATAL: Module missing: $module");
			DPError(i18nwrapper_advanced("A fatal error has occurred. Your installation of Day Planner is missing some files. This makes certain functions in Day Planner unusable. Please re-install Day Planner. See %(website) for more information on how to download and re-install Day Planner.\nDay Planner will continue to run but it is likely to crash.\n\n(The missing file was: %(module))", { website => 'http://www.day-planner.org/', module => $module }));
		}
		return(false);
	}
}

# Purpose: Detect the path to the image file(s) supplied. Returns the path to the
#		first one found or undef
# Usage: $Image = DetectImage(image1, image2);
sub DetectImage {
	my $I_Am_At = $FindBin::RealBin;
	foreach my $Image (@_) {
		foreach my $Dir ("$I_Am_At/art", $I_Am_At, '/usr/share/dayplanner', '/usr/local/dayplanner', '/usr/local/share/dayplanner', '/usr/share/dayplanner/art', '/usr/local/dayplanner/art', '/usr/local/share/dayplanner/art', '/usr/share/icons/large', '/usr/share/icons', '/usr/share/icons/mini') {
			if (-e "$Dir/$Image") {
				return("$Dir/$Image");
			}
		}
	}
	return(undef);
}

# Purpose: Get the SUMMARY string for an UID
# Usage: my $Summary = GetSummaryString(CALWIDGET, ICALENDAR, UID, CURRENT?, YEAR?, MONTH?);
#  The returned summary string is properly formatted (ie. it will return
#  a properly localized birthday string if needed).
#
# 	If CURRENT is true GetSummaryString() will base its birthday information
# 	on the current date/time instead of the selected date/time
# 	If YEAR/MONTH is true and CURRENT is false then that will be used in place
# 	of the selection from $CalendarWidget
sub P_GetSummaryString {
	my $CalendarWidget = shift;
	my $iCalendar = shift;
	my $UID = shift;
	my $CURRENT = shift;
	my ($AltYear, $AltMonth) = @_;
	if(not length($UID))
	{
		DPIntWarn("P_GetSummaryString(): Got UNDEF UID");
		return(undef);
	}
	my $UID_Obj = $iCalendar->get_info($UID);
	if (not $UID_Obj)
	{
		return(undef);
	}
	if(defined($UID_Obj->{'X-DP-BIRTHDAY'}) and $UID_Obj->{'X-DP-BIRTHDAY'} eq 'TRUE') {
		if($UID_Obj->{'X-DP-BIRTHDAYNAME'}) {
			if(defined($UID_Obj->{'X-DP-BORNATDTSTART'}) and $UID_Obj->{'X-DP-BORNATDTSTART'} eq 'TRUE') {
				# Calculate birthday here
				my ($BYear,$BMonth,$BDay) = iCal_ParseDateTime($UID_Obj->{'DTSTART'});
				my ($SelYear, $SelMonth, $SelDay);
				# If CalendarWidget is false and no arguments has been supplied, warn and set current
				if(not $CURRENT and not $CalendarWidget and not ($AltYear and $AltMonth)) {
					$CURRENT = 1;
					DPIntWarn("Bug: GetSummaryString() called without CURRENT and without Year/Month. Assuming CURRENT");
				}
				if(not $CURRENT) {
					if($AltYear and $AltMonth) {
						$SelYear = $AltYear;
						$SelMonth = $AltMonth;
					} else {
						($SelYear, $SelMonth, $SelDay) = $CalendarWidget->get_date();$SelMonth++;
					}
				} else {
					# Get the current time
					my ($currsec,$currmin,$currhour,$currmday,$currmonth,$curryear,$currwday,$curryday,$currisdst) = GetDate();
					$SelYear = $curryear;
					$SelMonth = $currmonth;
				}

				my $YearsOld = $SelYear - $BYear;

				# Handle the December/January change
				if($SelMonth == 12 && $BMonth == 1) {
					$YearsOld++;
				}

				if($YearsOld == 0) {
					return(i18nwrapper_advanced('%(name) was born', { name => $UID_Obj->{'X-DP-BIRTHDAYNAME'}}));
				} elsif ($YearsOld < 0) {
					return('');
				} else {
					return(i18nwrapper_advanced("%(name)'s birthday (%(year) years old)", { name => $UID_Obj->{'X-DP-BIRTHDAYNAME'}, year => $YearsOld}));
				}

			} else {
				return(i18nwrapper_advanced("%(name)'s birthday",{ name => $UID_Obj->{'X-DP-BIRTHDAYNAME'}}));
			}
		} else {
			DPIntWarn("UID $UID is set to be a birthday but is missing X-DP-BIRTHDAYNAME, using SUMMARY string");
		}
	}
	if(not $UID_Obj->{SUMMARY}) {
		DPIntWarn("No SUMMARY found for the UID $UID");
		# TRANSLATORS: This string is used when there is some issue getting the description
		# 	of an event. It is rarely used but kept just in case.
		return(i18nwrapper('Unknown'));
	}
	return($UID_Obj->{SUMMARY});
}

# Purpose: The same as localtime(TIME?); but returns proper years and months
# Usage: my ($currsec,$currmin,$currhour,$currmday,$currmonth,$curryear,$currwday,$curryday,$currisdst) = GetDate(TIME);
#  TIME is optional. If not present then the builtin time function is called.
sub GetDate {
	my $Time = $_[0] ? $_[0] : time;
	my ($currsec,$currmin,$currhour,$currmday,$currmonth,$curryear,$currwday,$curryday,$currisdst) = localtime($Time);
	$curryear += 1900;						# Fix the year format
	$currmonth++;							# Fix the month format
	return($currsec,$currmin,$currhour,$currmday,$currmonth,$curryear,$currwday,$curryday,$currisdst);
}
1;
