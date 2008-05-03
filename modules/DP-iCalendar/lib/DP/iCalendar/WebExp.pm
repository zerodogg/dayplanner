# DP::iCalendar::WebExp
# $Id: iCalendar.pm 1615 2007-08-10 17:58:24Z zero_dogg $
# An DP::iCalendar handler that exports data to XHTML or PHP
# Copyright (C) Eskild Hustvedt 2008
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package DP::iCalendar::WebExp;
use DP::GeneralHelpers::I18N;
use File::Path qw(mkpath);
my $i18n = DP::GeneralHelpers::I18N->new();
use strict;
use warnings;
use constant { true => 1, false => undef };

# Purpose: Mark something as a stub
# Usage: STUB();
sub STUB
{
	my ($package, $filename, $line, $subroutine, $hasargs,
		$wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
	my $msg = "STUB: $subroutine";
	warn($msg);
}

sub new
{
	STUB();
	my $this = {};
	bless($this);
	$this->{'generator'} = 'DP::iCalendar::WebExp';
	$this->{'generator_url'} = 'http://www.day-planner.org/';
	# These are needed, but undef by default
	$this->{out_dir} = undef;
	$this->{DPI} = undef;
	# TODO: This should be a hash of KEY => contents
	$this->{i18n} = {
	};
	return($this);
}

sub set_dpi
{
	STUB();
	my $this = shift;
	$this->{DPI} = shift;
}

sub set_generator
{
	STUB();
	my ($this,$name,$url) = @_;
	$this->{'generator'} = _HTML_Encode($name);
	$this->{'generator_url'} = _HTML_Encode($url);
}

sub writehtml
{
	my $this = shift;
	my $dir = shift;
	die("DPI not set!") if not $this->{DPI};
	die("DIR not supplied!") if not $dir;
	# This is a rather deep loop.
	#  We loop through each (existing) day of each (existing) month
	#  of each (exisiting) year.
	# Start with the year.
	foreach my $Year (@{$this->{DPI}->get_years()})
	{
		$this->_HTML_YearIndex($dir,$Year);
		# Proceed with months
		foreach my $Month (@{$this->{DPI}->get_months($Year)})
		{
			$this->_HTML_MonthIndex($dir,$Year,$Month);
			# And finish with the days
			foreach my $Day (@{$this->{DPI}->get_monthinfo($Year,$Month)})
			{
				$this->_HTML_DayIndex($dir,$Year,$Month,$Day);
			}
		}
	}
}

sub writephp
{
	STUB();
	warn('STUB');
	# Write year list
	# Write month list for each year
	# Write day list for each month for each year
}

sub _HTML_YearIndex
{
	my $this = shift;
	my $Year = shift;
	my $Dir = shift;
	my $HTML = $this->_getYear($Year);
	STUB();
}
sub _HTML_MonthIndex
{
	my $this = shift;
	my $Year = shift;
	my $Month = shift;
	my $Dir = shift;
	my $HTML = $this->_getMonth($Year,$Month);
	STUB();
}
sub _HTML_DayIndex
{
	my $this = shift;
	my $Dir = shift;
	my $Year = shift;
	my $Month = shift;
	my $Day = shift;
	my $HTML = $this->_getDay($Year,$Month,$Day);
	STUB();
}
sub _HTML_GetHeader
{
	my $this = shift;
	STUB();
	return('');
}
sub _HTML_GetFooter
{
	my $this = shift;
	STUB();
	return('');
}
sub _HTML_GetMenu
{
	my $this = shift;
	my $Year = shift;
	my $Month = shift;
	STUB();
	return('');
}

# Purpose: Get the HTML containing information about a year
# Usage: this->_getYear(year);
sub _getYear
{
	STUB();
	my ($this,$Year) = @_;
	return('');
}

# Purpose: Get the HTML containing information about a month
# Usage: this->_getMonth(year,month);
sub _getMonth
{
	STUB();
	my ($this,$Year,$Month) = @_;
	return('');
}

# Purpose: Get the HTML containing events for a specific day
# Usage: this->_getDay(year,month,day);
sub _getDay
{
	my ($this,$Year,$Month,$Day) = @_;
	my $Return = '<table style="text-align: left;" border="1" cellpadding="2" cellspacing="2"><tbody><tr><td>' . _HTML_Encode($i18n->get('Time')) . '</td><td>' . _HTML_Encode($i18n->get('Description')) . "</td></tr>\n";
	if (my $TimeArray = $this->{DPI}->get_dateinfo($Year,$Month,$Day)) {
		foreach my $Time (sort @{$TimeArray}) {
			foreach my $UID (@{$this->{DPI}->get_timeinfo($Year,$Month,$Day,$Time)}) {
				# FIXME
				my $EventSummary = main::GetSummaryString($UID);
				# Don't add Time = DAY.
				if($Time eq 'DAY') {
					$Time = '';
				}
				$Return .= '<tr><td>'.$Time.'</td><td>'._HTML_Encode($EventSummary);
				my $info = $this->{DPI}->get_info($UID);
				if (defined($info->{DESCRIPTION}))
				{
					$Return .= '<br /><i>'._HTML_Encode($info->{DESCRIPTION}).'</i>';
				}
				$Return .= '</td></tr>';
			}
		}
	}
	return($Return);
}

# Purpose: Encode special HTML entities
# Usage: _HTML_Encode(STRING);
sub _HTML_Encode {
	my $String = shift;
	study($String);
	$String =~ s#\n#<br />#g;
	$String =~ s/&/&amp;/g;
	$String =~ s/</&lt;/g;
	$String =~ s/>/&gt;/g;
	$String =~ s/"/&quot;/g;
	return($String);
}
