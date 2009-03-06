# DP::GeneralHelpers::I18N
# Copyright (C) Eskild Hustvedt 2007, 2008
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either:
# 
#    a) the GNU Lesser General Public License as published by the Free
#    Software Foundation; either version 3, or (at your option) any
#    later version, or
#    b) the "Artistic License" which comes with this Kit.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
# the GNU Lesser General Public License or the Artistic License for more details.
#
# You should have received a copy of the Artistic License
# in the file named "COPYING.artistic".  If not, I'll be glad to provide one.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program in a file named COPYING.lgpl. 
# If not, see <http://www.gnu.org/licenses/>.
package DP::GeneralHelpers::I18N;
use warnings;
use strict;
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
# Usage: new(DOMAIN, LOCALE);
# DOMAIN is the textdomain and mo filename, ie. dayplanner
# LOCALE is the locale, this is not needed in most cases and will
# 	be autodetected if not supplied.
sub new {
	my $Package = shift;
	my $self = {};
	bless($self,$Package);
	$self->{'workaround'} = 0;
	$self->{'domain'} = shift;
	$self->{'hasLocale'} = shift;
	
	$self->{'setlocale_said'} = setlocale(LC_ALL, $self->{'hasLocale'} ? $self->{'hasLocale'} : '');
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
			if(my $I18N = $self->_getLocale())
			{
				if (-e "$FindBin::RealBin/locale/$I18N/LC_MESSAGES/".$self->{'domain'}.'.mo')
				{
					$BindTo = "$FindBin::RealBin/locale";
				}
			}
		}
		# Set up the i18n fetching type
		if($Legacy) {
			warn("Using legacy Locale::gettext. This will work, but is not officially supported and you may have some issues with certain accented characters\n");
			$self->{I18N_Mode} = 1;
			if($BindTo) {
				bindtextdomain($self->{domain}, $BindTo);
			}
			textdomain($self->{domain});
		} else {
			$self->{I18N_Mode} = 2;
			$self->{'workaround'} = $self->_detectWorkaraound();
			if($self->{'workaround'}) {
				# This appears to be needed on /some/ boxes in certain cases.
				# Seems to be a bug in certain versions of perl-gtk2, though
				# it can also be forced on by the user.

				# Set the raw gettext domain and enforce an UTF-8 codeset
				$self->{Gettext} = Locale::gettext->domain_raw($self->{domain});
				$self->{Gettext}->codeset('UTF-8');
			} else {
				# Standard (no workaround applied)
				$self->{Gettext} = Locale::gettext->domain($self->{domain});
			}
			if($BindTo) {
				$self->{Gettext}->dir($BindTo);
			}
		}
	} else {
		$self->{I18N_Mode} = 0;
		# No Locale::Gettext available
		warn("Locale::gettext is not available. This will work, but localization will *not* be available\n");
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

# Purpose: Get locale
# Usage: this->_getLocale();
sub _getLocale
{
	my $this = shift;
	my $I18N;
	if ($this->{hasLocale})
	{
		return $this->{hasLocale};
	}
	elsif(defined($ENV{LC_ALL}) or defined($ENV{LANG}))
	{
		if(defined($ENV{LC_ALL}) and length($ENV{LC_ALL})) {
			$I18N = $ENV{LC_ALL};
		} else {
			$I18N = $ENV{LANG};
		}
	}
	elsif(defined ($this->{'setlocale_said'}) and length ($this->{'setlocale_said'}))
	{
		$I18N = $this->{'setlocale_said'};
	}
	else
	{
		warn("Warning: Using fallback locale detection\n");
		foreach my $k (sort keys(%ENV))
		{
			next if not $k =~ /^(LC_|LANG)/;
			if (length $ENV{$k})
			{
				$I18N = $ENV{$k};
				last;
			}
		}
	}
	if($I18N =~ /:/) {
		$I18N =~ s/^(.+):.*$/$1/;
	}
	$this->{hasLocale} = $I18N;
	return $I18N;
}

# Purpose: Detect if we should use the workaround or not
# Usage: workaround = this->_detectWorkaraound();
sub _detectWorkaraound
{
	# Check if the env var is set, if it is then ignore detection
	# and use that.
	if(defined($ENV{DP_FORCE_GETTEXT_WORKAROUND}))
	{
		if ($ENV{DP_FORCE_GETTEXT_WORKAROUND} eq '1')
		{
			return 1;
		} 
		else
		{
			return 0;
		}
	}
	# Ignore if we're not running under Gtk2
	if(not defined($Gtk2::VERSION))
	{
		return 0;
	}
	# Workaround detection. Appears to be a bug
	# in versions somewhere between 1.144 and 1.160.
	if($Gtk2::VERSION <= 1.144 || $Gtk2::VERSION > 1.160)
	{
		return 0;
	}
	# Ignore it on some distros
	if(main::GetDistVer() =~ /suse/i)
	{
		return 0
	}
	# Use it
	return 1;
}
1;
