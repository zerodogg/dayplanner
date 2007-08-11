# DP::GeneralHelpers
# $Id$
# Copyright (C) Eskild Hustvedt 2007
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either:
# 
#    a) the GNU General Public License as published by the Free
#    Software Foundation; either version 3, or (at your option) any
#    later version, or
#    b) the "Artistic License" which comes with this Kit.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
# the GNU General Public License or the Artistic License for more details.
#
# You should have received a copy of the Artistic License
# in the file named "COPYING.artistic".  If not, I'll be glad to provide one.
#
# You should have received a copy of the GNU General Public License
# along with this program in a file named COPYING.gpl. 
# If not, see <http://www.gnu.org/licenses/>.

package DP::GeneralHelpers;
use strict;
use warnings;
use Exporter qw(import);
use constant {
	TRUE => 1,
	FALSE => undef,
	};

# Exported functions
our @EXPORT_OK = qw(DPIntWarn DPIntInfo WriteConfigFile LoadConfigFile AppendZero);

# Purpose: Print a warning to STDERR with proper output
# Usage: DPIntWarn("Warning");
sub DPIntWarn {
	warn "*** (Day Planner $main::Version) Warning: $_[0]\n";
}

# Purpose: Print an info message to STDOUT with proper output
# Usage: DPIntInfo("Info");
sub DPIntInfo {
	print "*** (Day Planner $main::Version): $_[0]\n";
}

# Purpose: Write a configuration file
# Usage: WriteConfigFile(/FILE, \%ConfigHash, \%ExplanationHash);
sub WriteConfigFile {
	my ($File, $Config, $Explanations) = @_;

	# Open the config for writing
	open(my $CONFIG, '>', "$File") or do {
		# If we can't then we error out, no need for failsafe stuff - it's just the config file
		DPIntWarn("Unable to save the configuration file $File: $!");
		return(0);
	};
	if(defined($Explanations->{HEADER})) {
		print $CONFIG "# $Explanations->{HEADER}\n";
	}
	foreach(sort(keys(%{$Config}))) {
		next unless length($Config->{$_});	# Don't write empty options
		if(defined($Explanations->{$_})) {
			print $CONFIG "\n# $Explanations->{$_}";
		}
		print $CONFIG "\n$_=$Config->{$_}\n";
	}
	close($CONFIG);
}

# Purpose: Load a configuration file
# Usage: LoadConfigFile(/FILE, \%ConfigHash, \%OptionRegexHash, OnlyValidOptions?);
#  OptionRegeXhash can be available for only a select few of the config options
#  or skipped completely (by replacing it by undef).
#  If OnlyValidOptions is true it will cause LoadConfigFile to skip options not in
#  the OptionRegexHash.
sub LoadConfigFile {
	my ($File, $ConfigHash, $OptionRegex, $OnlyValidOptions) = @_;

	open(my $CONFIG, '<', "$File") or do {
		DPIntWarn(sprintf("Unable to read the configuration settings from %s: %s", $File, $!));
		return(0);
	};
	while(<$CONFIG>) {
		next if m/^\s*(#.*)?$/;
		next unless m/=/;
		chomp;
		my $Option = $_;
		my $Value = $_;
		$Option =~ s/^\s*(\w+)\s*=.*/$1/;
		$Value =~ s/^\w+=\s*(.*)\s*/$1/;
		if($OnlyValidOptions) {
			unless(defined($OptionRegex->{$Option})) {
				DPIntWarn("Unknown configuration option \"$Option\" (=$Value) in $File: Ignored.");
				next;
			}
		}
		unless(defined($Value)) {
			DPIntWarn("Empty value for option $Option in $File");
		}
		if(defined($OptionRegex) and defined($OptionRegex->{$Option})) {
			my $MustMatch = $OptionRegex->{$Option};
			unless ($Value =~ /$MustMatch/) {
				DPIntWarn("Invalid setting of $Option (=$Value) in the config file: Must match $OptionRegex->{Option}.");
				next;
			}
		}
		$ConfigHash->{$Option} = $Value;
	}
	close($CONFIG);
}

# Purpose: Append a "0" to a number if it is only one digit.
# Usage: my $NewNumber = AppendZero(NUMBER);
sub AppendZero {
	my $Number = shift;
	if ($Number =~ /^\d$/) {
		return("0$Number");
	}
	return($Number);
}

# Version number
our $VERSION;
$VERSION = 0.1;

# Purpose: Find out if a command is in PATH or not
# Usage: InPath(COMMAND);
sub InPath {
	foreach (split /:/, $ENV{PATH}) { if (-x "$_/@_" and ! -d "$_/@_" ) {   return 1; } } return 0;
}

# ----
# IPC HANDLER
# ---
package DP::GeneralHelpers::IPC;
use IO::Socket::UNIX;
use Glib;
use constant {
	TRUE => 1,
	FALSE => undef,
	};

# -- PUBLIC IPC HANDLER FUNCTIONS --

# Purpose: Create a new object
# Usage: my $IPC = DP::GeneralHelpers::IPC->new_client();
sub new_client {
	my $Package = shift;
	my $Path = shift;
	my $Handler = shift;

	my $self = {};
	bless($self,$Package);

	$self->{FileName} = $Path;
	$self->{Handler} = $Handler;
	$self->{Type} = 'client';
	$self->{Socket} = IO::Socket::UNIX->new(
		Peer    => $self->{FileName},
		Type	=> SOCK_STREAM,) or do {
			       if(wantarray()) {
			       	       return(FALSE,$@);
			       } else {
				       return(FALSE);
			       } };
	if(not Glib::IO->add_watch(fileno($self->{Socket}), 'in', sub { $self->_IO_IN_EVENT($self->{Socket});})) {
			return(FALSE);
		}
	return($self);
}

# Purpose: Create a new object
# Usage: my $IPC = DP::GeneralHelpers::IPC->new_server(PATH,HANDLER);
# 	PATH is the path to the socket to create
# 	HANDLER is a coderef to the code to handle the socket
sub new_server {
	my $Package = shift;
	my $Path = shift;
	my $Handler = shift;

	my $self = {};
	bless($self,$Package);

	$self->{FileName} = $Path;
	$self->{Handler} = $Handler;
	$self->{Type} = 'server';
	$self->{ClientSockets} = [];
	if(not $self->_CheckOrUnlink) {
		return(FALSE);
	}
	$self->{Socket} = IO::Socket::UNIX->new(
					Local	=> $self->{FileName},
					Type	=> SOCK_STREAM,
					Listen	=> TRUE,
			) or do {
			       if(wantarray()) {
			       	       return(FALSE,$@);
			       } else {
				       return(FALSE);
			       } };
	chmod(oct(600), $self->{FileName});
	if(not Glib::IO->add_watch(fileno($self->{Socket}), 'in', sub { $self->_IO_IN(@_);})) {
			$self->destroy();
			return(FALSE);
		}
	return($self);
}

# Purpose: Destory the object
# Usage: obj->destroy
sub destroy {
	my $self = shift;
	if($self->{Type} eq 'server') {
		close($self->{Socket});
		unlink($self->{FileName});
		foreach(@{$self->{ClientSockets}}) {
			if($_) {
				close($_);
			}
		}
	} else {
		close($self->{Socket});
	}
	return(TRUE);
}

# Purpose: Send data to the server
# Usage: obj->client_send(DATA);
sub client_send {
	my $self = shift;

	my $data = shift;
	my $Socket = $self->{Socket};
	print $Socket $data,"\n";
}

# -- INTERNAL IPC HANDLER FUNCTIONS --

# Purpose: Handle incoming IO connections
# Usage: $self->_IO_IN();
sub _IO_IN {
	my $self = shift;
	# Accept the client
	my $Client = $self->{Socket}->accept();
	# Install a new Glib::IO watch handler for it
	Glib::IO->add_watch(fileno($Client), 'in', sub { $self->_IO_IN_EVENT($Client);});
	# Push it onto our list of client sockets
	push(@{$self->{ClientSockets}}, $Client);
	# Handled it, so return
	return(TRUE);
}

# Purpose: Handle an open IO connection with events
# Usage: $self->_IO_IN_EVENT();
sub _IO_IN_EVENT {
	my $self = shift;
	my $Client = shift;
	my $Data = <$Client>;
	# If we could read from it, then there's data to be processed!
	if($Data) {
		my $Return = $self->{Handler}->($Data);
		if($Return) {
			print $Client $Return,"\n";
		}
		return(TRUE);
	} else { # If we couldn't then it's dead, so just close it
		close($Client);
		return(FALSE);
	}
}

# TODO: Clean and document
sub _CheckOrUnlink {
	my $self = shift;
	if(-e $self->{FileName}) {
		# Don't try to connect to nor unlink if it isn't a socket
		if(not -S $self->{FileName}) {
			return(FALSE);
		} else {
			# Try to connect to the socket.
			# If we can connect we simply assume that the app in the other end
			# is alive, so we return false.
			my $Client = DP::GeneralHelpers::IPC->new_client($self->{FileName}, sub { return });
			if($Client) {
				$Client->destroy();
				return(FALSE);
			} else {
				unlink($self->{FileName});
				return(TRUE);
			}
		}
	}
	return(TRUE);
}
package DP::GeneralHelpers::I18N;
use POSIX;

# Purpose: Wrapper around the gettext functions that does the right thing(tm)
# Usage: $self->get(STANDARD_GETTEXT_SYNTAX);
sub get {
	my $self = shift;
	if($self->{I18N_Mode} == 1) {	# 1 is Legacy
		return(gettext(@_));
	} elsif ($self->{I18N_Mode} == 2 ) {	# 2 is new Locale::gettext OO-interface
		return($self->{Gettext}->get(@_));
	} else {			# Neither of those means it's not available, just return
					# a scalar of the supplied data.
		my $String;
		foreach(@_) {
			$String .= $_;
		}
		return($String);
	}
}

# Purpose: Better way to fetch advanced strings
# Usage: $self->get_advanced("STRING",HASH);
# 	The STRING is a normal string containing a series of % fields.
# 	The HASH is a hash of % fields => values.
# 	Ex:
# 	$self->get_advanced('Adding an event at %(HH):%(MM)',{ 'HH' => $HOUR, 'MM' => $MINUTE, });
sub get_advanced {
	my $self = shift;
	my $OrigString = shift;
	my $Values = shift;
	my $String = $self->get($OrigString);
	return($self->raw_advanced($String,$Values));
}

# Purpose: Just do replacements on an advanced string. Don't get any translation.
# Usage: Same as get_advanced
sub raw_advanced {
	my $self = shift;
	my $String = shift;
	my $Values = shift;
	foreach my $Key (keys(%{$Values})) {
		$String =~ s/%\($Key\)/$Values->{$Key}/g;
	}
	return($String);
}

# Purpose: get month string
# Usage: get_month(NUMBER);
sub get_month {
	my $self = shift;
	my $month = shift;
	return($self->{MonthNames}{$month});
}

# Purpose: Create a new I18N object
# Usage: new();
sub new {
	my $Package = shift;
	my $self = {};
	bless($self,$Package);
	
	setlocale(LC_ALL, '' );
	if(eval('use Locale::gettext;1')) {
		my $BindTo;
		my $Legacy;
		if($Locale::gettext::VERSION > 1.04) {
			$Legacy = 0;
		} else {
			$Legacy = 1;
		}
		if(defined($ENV{DP_FORCE_LEGACY_I18N}) and $ENV{DP_FORCE_LEGACY_I18N} eq '1') {
			$Legacy = 1;
		}
		# Find out if we have a locale directory in our main dir
		if (-d "$FindBin::RealBin/locale/") {
			if(defined($ENV{LC_ALL}) or defined($ENV{LANG})) {
				my $I18N;
				if(defined($ENV{LC_ALL}) and length($ENV{LC_ALL})) {
					$I18N = $ENV{LC_ALL};
				} else {
					$I18N = $ENV{LANG};
				}
				if($I18N =~ /:/) {
					$I18N =~ s/^(.+):.*$/$1/;
				}
				if (-e "$FindBin::RealBin/locale/$I18N/LC_MESSAGES/dayplanner.mo") {
					$BindTo = "$FindBin::RealBin/locale";
				}
			}
		}
		# Set up the i18n fetching type
		if($Legacy) {
			DP::GeneralHelpers::DPIntWarn('Using legacy Locale::gettext. This will work, but is not officially supported and you may have some issues with certain accented characters');
			$self->{I18N_Mode} = 1;
			if($BindTo) {
				bindtextdomain('dayplanner', $BindTo);
			}
			textdomain('dayplanner');
		} else {
			$self->{I18N_Mode} = 2;
			my $Workaround;
			if($Gtk2::VERSION >= 1.144) {
				$Workaround = 1;
			}
			if(defined($ENV{DP_FORCE_GETTEXT_WORKAROUND})) {
				if ($ENV{DP_FORCE_GETTEXT_WORKAROUND} eq '1') {
					$Workaround = 1;
				} else {
					$Workaround = 0;
				}
			}
			if($Workaround) {
				# This is needed on some boxes in some cases. It appears to be when using one of the
				# later Gtk2 versions.
				$self->{Gettext} = Locale::gettext->domain_raw('dayplanner');	# Set the gettext domain
				$self->{Gettext}->codeset('UTF-8');
			} else {
				$self->{Gettext} = Locale::gettext->domain('dayplanner');
			}
			if($BindTo) {
				$self->{Gettext}->dir($BindTo);
			}
		}
	} else {
		$self->{I18N_Mode} = 0;
		# No Locale::Gettext available
		DP::GeneralHelpers::DPIntWarn('Locale::gettext is not available. This will work, but localization will *not* be available');
	}
	# The reason we do not use strftime() or I18N::Langinfo is that these return
	# values in random encodings. By using Gettext we get values
	# in a proper encoding
	$self->{MonthNames} = {
		1 => $self->get('January'),
		2 => $self->get('February'),
		3 => $self->get('March'),
		4 => $self->get('April'),
		5 => $self->get('May'),
		6 => $self->get('June'),
		7 => $self->get('July'),
		8 => $self->get('August'),
		9 => $self->get('September'),
		10 => $self->get('October'),
		11 => $self->get('November'),
		12 => $self->get('December'),
	};	# Localized hash of month number => Name values

	# AM/PM setup.
	# The %% in the end is *required*. It works around bugs in recent versions
	# of strftime()
	if(defined($ENV{DP_FORCE_24H}) and $ENV{DP_FORCE_24H}) {
		$self->{ClockSystem} = '24';
	} else {
		$self->{AM_String} = strftime('%p%%', 0,0,0,0,0,106,0);
		$self->{PM_String} = strftime('%p%%', 0,0,12,0,0,106,0);
		$self->{AM_String} =~ s/%p?%?$//;	# Remove junk
		$self->{PM_String} =~ s/%p?%?$//;	# Remove junk
		$self->{ClockSystem} = $self->{AM_String} eq '' ? '24' : '12';
	}
	return($self);
}

# Purpose: Get information about the clocksystem
# Usage: get_clocktype();
sub get_clocktype {
	my $self = shift;
	return($self->{ClockSystem});
}

# Purpose: Get AM/PM strings
# Usage: get_ampmstring(AM/PM);
sub get_ampmstring {
	my $self = shift;
	my $string = shift;
	if($string eq 'AM') {
		return($self->{AM_String});
	} elsif ($string eq 'PM') {
		return($self->{PM_String});
	} else {
		return(undef);
	}
}

# Purpose: Convert AM/PM to internal 24H time
# Usage: AMPM_To24(TIME [AM|PM]);
sub AMPM_To24 {
	my $self = shift;
	my $Time = shift;
	return($Time) if $self->{ClockSystem} eq '24';
	my $Hour = $Time;
	my $Minutes = $Time;
	my $Suffix = $Time;
	$Hour =~ s/^(\d+):.*$/$1/;
	$Minutes =~ s/^\d+:(\d+).*$/$1/;
	$Suffix =~ s/^\d+:\d+\s+(.+)/$1/;
	if($Suffix eq $self->{PM_String}) {
		$Hour = $Hour+12;
	} elsif($Suffix eq $self->{AM_String}) {
		if($Hour == 12) {
			$Hour = '00';
		}
	}
	if(wantarray()) {
		return($Hour, $Minutes);
	} else {
		return("$Hour:$Minutes");
	}
}

# Purpose: Convert internal 24H time to AM/PM
# Usage: AM_PM_From24(TIME);
sub AMPM_From24 {
	my $self = shift;
	my $Time = shift;
	return($Time) if $self->{ClockSystem} eq '24' or not length($Time);
	my $Hour = $Time;
	my $Minutes = $Time;
	my $Suffix;
	$Hour =~ s/^(\d+):.*$/$1/;
	$Minutes =~ s/^\d+:(\d+).*$/$1/;
	if($Hour >= 12) {
		$Suffix = $self->{PM_String};
		$Hour = $Hour-12;
	} else {
		if($Hour == 0) {
			$Hour = '12';
		}
		$Suffix = $self->{AM_String};
	}
	return("$Hour:$Minutes $Suffix");
}
package DP::GeneralHelpers::HTTPFetch;
use IPC::Open3;
use POSIX;
use Socket;

# Purpose: Download a file from HTTP (other protocols might also work, but there are
# 		no guarantees for that)
# Usage: my $Data = DP::GeneralHelpers::HTTPFetch->get("URL",$ProgressCallback);
# 	Progresscallback is a function that can recieve values in order to run
# 	a progress window. It can also be undef.
# 	If not undef then the function referenced will recieve either a vlue from
# 	1-100, which is the percentage completed, or the string UNKOWN.
# 	UNKNOWN means that the download has progressed, but it is not known how
# 	much is left.
sub get {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	# First we try to resolve the IP. If this fails we just
	# error out.
	my $addy = $file;
	$addy =~ s#^\w+://##;
	$addy =~ s#^([^/]+)/.*#$1#;
	my $resolved = inet_ntoa(inet_aton($addy));
	if(not $resolved) {
		return('NORESOLVE');
	}

	# First try LWP
	if(eval("use LWP;")) {
		return($self->_LWPFetch($file));
	}
	# Okay, LWP isn't available. Check for others
	if(DP::GeneralHelpers::InPath('wget')) {
		return($self->_WgetFetch($file));
	}
	if(DP::GeneralHelpers::InPath('curl')) {
		return($self->_CurlFetch($file));
	}
	if(DP::GeneralHelpers::InPath('lynx')) {
		return($self->_LynxFetch($file));
	}
	return('NOPROGRAM');
}

# Purpose: Download a file from HTTP using LWP
# Usage: $self->_LWPFetch(FILE,PROGRESS);
sub _LWPFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	my $UserAgent = LWP::UserAgent->new;
	$UserAgent->agent('DP::GeneralHelpers::HTTPFetch//LWP');

	my $Request = HTTP::Request->new(GET => $file);
	my $Reply = $UserAgent->request($Request);
	if($Reply->is_success) {
		return($Reply->content);
	} else {
		return('FAILED');
	}
}

# Purpose: Download a file from HTTP using lynx.
# Usage: $self->_LynxFetch(FILE,PROGRESS);
sub _LynxFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	# Have lynx output the file to STDOUT and read from that.
	# Ignore STDERR
	my ($in, $out, $err);
	my $ChildPID = open3($in,$out,$err,'lynx','-useragent=DP::GeneralHelpers::HTTPFetch//lynx','-source',$file);
	my $output;
	while($output .= <$out> and not eof($out)) {
		if($progress) {
			$progress->('UNKNOWN');
		}
	}
	close($in) if($in);
	close($out) if($out);
	close($err) if($err);
	waitpid($ChildPID,WNOHANG);
	my $ret = $? >> 8;
	if($ret == 0) {
		return($output);
	} else {
		return('FAIL');
	}
}

# Purpose: Download a file from HTTP using curl.
# Usage: $self->_CurlFetch(FILE,PROGRESS);
sub _CurlFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	# Have curl output the file to STDOUT and read from that.
	# Ignore STDERR
	my ($in, $out, $err);
	my $ChildPID = open3($in,$out,$err,'curl','--user-agent','DP::GeneralHelpers::HTTPFetch//curl','--fail','--location','--silent',$file);
	my $output;
	while($output .= <$out> and not eof($out)) {
		if($progress) {
			$progress->('UNKNOWN');
		}
	}
	close($in) if($in);
	close($out) if($out);
	close($err) if($err);
	waitpid($ChildPID,WNOHANG);
	my $ret = $? >> 8;
	if($ret == 0) {
		return($output);
	} else {
		return('FAIL');
	}
}

# Purpose: Download a file from HTTP using wget.
# Usage: $self->_WgetFetch(FILE,PROGRESS);
sub _WgetFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	# Have wget output the file to STDOUT and read from that. Ignore
	# STDERR.
	my ($in, $out, $err);
	my $ChildPID = open3($in,$out,$err,'wget','--user-agent','DP::GeneralHelpers::HTTPFetch//wget','--quiet','-O','-',$file);
	my $output;
	while($output .= <$out> and not eof($out)) {
		if($progress) {
			$progress->('UNKNOWN');
		}
	}
	close($in) if($in);
	close($out) if($out);
	close($err) if($err);
	waitpid($ChildPID,WNOHANG);
	my $ret = $? >> 8;
	if($ret == 0) {
		return($output);
	} else {
		return('FAIL');
	}
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

DP::GeneralHelpers - Perl extension for blah blah blah

=head1 SYNOPSIS

  use DP::GeneralHelpers;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for DP::GeneralHelpers, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

zerodogg, E<lt>zerodogg@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by zerodogg

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
