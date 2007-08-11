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
			warn("Using legacy Locale::gettext. This will work, but is not officially supported and you may have some issues with certain accented characters\n");
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
1;
