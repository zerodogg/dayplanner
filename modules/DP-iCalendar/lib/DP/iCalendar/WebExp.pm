# DP::iCalendar::WebExp
# $Id: iCalendar.pm 1615 2007-08-10 17:58:24Z zero_dogg $
# An DP::iCalendar handler that exports data to XHTML or PHP
# Copyright (C) Eskild Hustvedt 2008
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

# TODO:
# - Replace outdated i18n system with user-selectable strings
# - Supply private version of i18n->get_advanced() for the above
# - PHP version
#	- Needs rewrite of: _HTML_GetHeader _HTML_GetMenu

package DP::iCalendar::WebExp;
use DP::GeneralHelpers::I18N;
use File::Path qw(mkpath);
my $i18n = DP::GeneralHelpers::I18N->new();
use strict;
use warnings;
use Carp;
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

# Purpose: Create a new object
# Usage: obj = DP::iCalendar::WebExp->new();
sub new
{
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

# Purpose: Set the DP::iCalendar to work on
# Usage: obj->set_dpi(OBJ);
# FIXME: Maybe this should just be an arg for ->new();
sub set_dpi
{
	my $this = shift;
	$this->{DPI} = shift;
}

# Purpose: Set the generator
# Usage: obj->set_generator(NAME, URL);
sub set_generator
{
	STUB();
	my ($this,$name,$url) = @_;
	$this->{'generator'} = _HTML_Encode($name);
	$this->{'generator_url'} = _HTML_Encode($url);
}

# Purpose: Write HTML to the dir selected
# Usage: obj->writephp(DIR);
# FIXME: This should probably be split into two functions, where
# writephp and writehtml just wraps the new function.
sub writehtml
{
	my $this = shift;
	my $dir = shift;
	die("DPI not set!") if not $this->{DPI};
	die("DIR not supplied!") if not $dir;
	$this->{_currdir} = $dir;
	if(not -e $dir)
	{
		mkdir($dir) or do {
			# FIXME: Write better warning function
			carp("Dir did not exist and module couldn't create: $!\n");
			return undef;
		};
		carp("You should create the dir before supplying to writehtml() as the module isn't as smart when it comes to creating directories (though it managed now)");
	}
	elsif (not -d $dir)
	{
		carp("$dir: is not a directory");
		return undef;
	}
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
	$this->_HTML_WriteIndex($dir);
}

# Purpose: Write PHP to the dir selected
# Usage: obj->writephp(DIR);
# TODO: Implement
sub writephp
{
	STUB();
	warn('STUB');
	# Write year list
	# Write month list for each year
	# Write day list for each month for each year
}

# Purpose: Write the index page
# Usage: this->_HTML_WriteIndex(dir);
sub _HTML_WriteIndex
{
	my $this = shift;
	my $PHP .=  "<?php\n// This is a simple script written by Day Planner to add autodetection of\n// the current day to exported Day Planner HTML sites. Only useful on\n// webservers with php support.\n// See also Day Planners php export feature for a more complete\n// PHP export of Day Planner data.\n// Copyright (C) Eskild Hustvedt 2006, 2007, 2008. Licensed under the same license as Day Planner\n";
	$PHP .=  _HTML_PHP_DayDetectFunc();
	$PHP .=  '$file = DayDetectFunc("./");' . "\n";
	$PHP .=  'if($file) {' . "\n";
	$PHP .=  "\t" . 'include($file);' . "\n";
	$PHP .=  "} else {" . "\n";
	$PHP .=  "\t" . 'print("Unable to detect files. This export is corrupt!");' . "\n";
	$PHP .=  "}\n?>";
	my $HTML = $this->_HTML_YearList();
	$this->_writeFile($this->{_currdir}.'/index.php',$PHP);
	$this->_writeFile($this->{_currdir}.'/index.html',$HTML);
}

# Purpose: Function to detect todays day using php
# Usage: print _HTML_PHP_DayDetectFunc();
sub _HTML_PHP_DayDetectFunc {
	my $Return = 'function DayDetectFunc ($datadir) {' . "\n";
	$Return .= "\t" . '$Year = date("Y");' . "\n";
	$Return .= "\t" . '$Month = date("n");' . "\n";
	$Return .= "\t" . '$Day = date("j");' . "\n";
	$Return .= "\t" . '$Months = array(1 => "january", 2 => "february", 3 => "march", 4 => "april", 5 => "may", 6 => "june", 7 => "july", 8 =>"august", 9 =>"september", 10 => "october", 11 => "november", 12 =>"december");' . "\n";
	$Return .= "\t" . 'if(file_exists("$datadir/dp_$Year$Month$Day.html")) {' . "\n";
	$Return .= "\t\t" . 'return("$datadir/dp_$Year$Month$Day.html");' . "\n";
	$Return .= "\t" . '} elseif(file_exists("$datadir/$Months[$Month]-$Year.html")) {' . "\n";
	$Return .= "\t\t" . 'return("$datadir/$Months[$Month]-$Year.html");' . "\n";
	$Return .= "\t" . '} elseif(file_exists("$datadir/index.html")) {' . "\n";
	$Return .= "\t\t" . 'return("$datadir/index.html");' . "\n";
	$Return .= "\t} else {" . "\n";
	$Return .= "\t\treturn 0;\n";
	$Return .= "\t}\n}\n";
	return($Return);
}

# Purpose: Write a list of years to HTML
# Usage: this->_HTML_YearList();
sub _HTML_YearList
{
	my $this = shift;
	my $HTML =  $this->_HTML_GetHeader("", "Day Planner", "M");
	$HTML .=  _HTML_Encode($i18n->get("Select the year to view:")) . "<br />\n";
	foreach(@{$this->{DPI}->get_years()}) {
		$HTML .=  "<a href='dp_$_.html'>" . _HTML_Encode($_) . "</a><br />\n";
	}
	$HTML .=  $this->_HTML_GetFooter();
	return($HTML);
}

# Purpose: Write a year to HTML
# Usage: this->_HTML_YearIndex(TargetDir,Year);
sub _HTML_YearIndex
{
	my $this = shift;
	my $Dir = shift;
	my $Year = shift;
	# FIXME: Maybe this _getHeader() call can be improved.
	my $HTML = $this->_HTML_GetHeader($Year, $Year);
	$HTML .= $this->_HTML_GetMenu($Year);
	$HTML .= $this->_getYear($Year);
	$HTML .= $this->_HTML_GetFooter();
	my $File = $this->_getFileName(false,$Year);
	$this->_writeFile($File,$HTML);
}

# Purpose: Write a month to HTML
# Usage: this->_HTML_MonthIndex(TargetDir,Year,Month);
sub _HTML_MonthIndex
{
	my $this = shift;
	my $Dir = shift;
	my $Year = shift;
	my $Month = shift;
	# FIXME: Maybe this _getHeader() call can be improved.
	my $HTML = $this->_HTML_GetHeader($Year, $Month.'.'.$Year);
	$HTML .= $this->_HTML_GetMenu($Year,$Month);
	$HTML .= $this->_getMonth($Year,$Month);
	$HTML .= $this->_HTML_GetFooter();
	my $File = $this->_getFileName(false,$Year,$Month);
	$this->_writeFile($File,$HTML);
}

# Purpose: Write a day to HTML
# Usage: this->_HTML_DayIndex(TargetDir,Year,Month,Day);
sub _HTML_DayIndex
{
	my $this = shift;
	my $Dir = shift;
	my $Year = shift;
	my $Month = shift;
	my $Day = shift;
	# FIXME: Maybe this _getHeader() call can be improved.
	my $HTML = $this->_HTML_GetHeader($Year, $Day.'.'.$Month.'.'.$Year);
	$HTML .= $this->_HTML_GetMenu($Year,$Month);
	$HTML .= $this->_getDay($Year,$Month,$Day);
	$HTML .= $this->_HTML_GetFooter();
	my $File = $this->_getFileName(false,$Year,$Month,$Day);
	$this->_writeFile($File,$HTML);
}

# Purpose: Get the header
# Usage: header = this->_HTML_GetHeader(DATE);
# 	DATE is optional. If present should be the date to put in the title.
#
#	FIXME: Uses I18N object
sub _HTML_GetHeader
{
	my $this = shift;
	my $Date = shift;
	my $Header = '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">';
	$Header .= '<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">';
	$Header .= "<head>\n";
	$Header .= '<meta content="text/html; charset=iso-8859-1" http-equiv="content-type" />';
	$Header .= "<meta name='generator' content='".$this->{generator}. '- '.$this->{generator_url} ."' />\n";
	if($Date)
	{
		$Header .= '<title>' . _HTML_Encode($i18n->get_advanced('Day Planner for %(date)', { date => $Date})) . '</title>';
	}
	else
	{
		$Header .= "<title>" . _HTML_Encode($Date) . "</title>";
	}
	$Header .= "</head>\n";
	$Header .= '<body>';
	return($Header);
}

# Purpose: Get the footer
# Usage: Footer = this->_HTML_GetFooter();
#
# FIXME: Uses I18N object
# FIXME: Wants a $Version variable (temporarily replaced with FIXME)
sub _HTML_GetFooter
{
	my $this = shift;
	my $Footer = '<br /><small><small>' . _HTML_Encode($i18n->get('Generated by')) .  ' <a href="http://www.day-planner.org/">' . _HTML_Encode($i18n->get('Day Planner')) . '</a> ' . _HTML_Encode($i18n->get('version')) . " FIXME</small></small><br />";
	$Footer .= "</body></html>";
	return($Footer);
}

# Purpose: Get the menu
# Usage: menu = this->_HTML_GetMenu(YEAR, MONTH);
#
# 	FIXME: Uses I18N object
sub _HTML_GetMenu
{
	my $this = shift;
	my $Year = shift;
	my $Month = shift;
	# HTML-style links
	my %Links = (
		1 => $this->_getFileName(true,$Year,1),
		2 => $this->_getFileName(true,$Year,2),
		3 => $this->_getFileName(true,$Year,3),
		4 => $this->_getFileName(true,$Year,4),
		5 => $this->_getFileName(true,$Year,5),
		6 => $this->_getFileName(true,$Year,6),
		7 => $this->_getFileName(true,$Year,7),
		8 => $this->_getFileName(true,$Year,8),
		9 => $this->_getFileName(true,$Year,9),
		10 => $this->_getFileName(true,$Year,10),
		11 => $this->_getFileName(true,$Year,11),
		12 => $this->_getFileName(true,$Year,12),
		yearindex => 'index.html',
	);
	my $Menu .= _HTML_Encode($i18n->get("Tools")) . ": <a href='$Links{yearindex}'>" . _HTML_Encode($i18n->get("Change to another year")) . "</a> (" . _HTML_Encode($i18n->get_advanced("current: %(year)", { year => $Year })) . ") - </a><br />\n";
	$Menu .= _HTML_Encode($i18n->get("Months")) .
	": <a href='$Links{1}'>" . _HTML_Encode($i18n->get_month(1)) .
	"</a> - <a href='$Links{2}'>" . _HTML_Encode($i18n->get_month(2)).
	"</a> - <a href='$Links{3}'>" . _HTML_Encode($i18n->get_month(3)) .
	"</a> - \n<a href='$Links{4}'>" . _HTML_Encode($i18n->get_month(4)) .
	"</a> - <a href='$Links{5}'>" . _HTML_Encode($i18n->get_month(5)) .
	"</a> - <a href='$Links{6}'>" . _HTML_Encode($i18n->get_month(6)) .
	"</a> - \n<a href='$Links{7}'>" . _HTML_Encode($i18n->get_month(7)) .
	"</a> - <a href='$Links{8}'>" . _HTML_Encode($i18n->get_month(8)) .
	"</a> - <a href='$Links{9}'>" . _HTML_Encode($i18n->get_month(9)) .
	"</a> - \n<a href='$Links{10}'>" . _HTML_Encode($i18n->get_month(10)) .
	"</a> - <a href='$Links{11}'>" . _HTML_Encode($i18n->get_month(11)) .
	"</a> - <a href='$Links{12}'>" . _HTML_Encode($i18n->get_month(12)) . "</a><br/>\n";
	return($Menu);
}

# Purpose: Get the HTML containing information about a year
# Usage: this->_getYear(year);
sub _getYear
{
	my ($this,$Year) = @_;
	# FIXME: Uses i18n
	return _HTML_Encode($i18n->get('Select the month to view in the list above')) . "<br />\n";
}

# Purpose: Get the HTML containing information about a month
# Usage: this->_getMonth(year,month);
sub _getMonth
{
	my ($this,$Year,$Month) = @_;
	# TODO: This shouldn't be here.
	my %RawMonthNames = (
		1 => 'january',
		2 => 'february',
		3 => 'march',
		4 => 'april',
		5 => 'may',
		6 => 'june',
		7 => 'july',
		8 => 'august',
		9 => 'september',
		10 => 'october',
		11 => 'november',
		12 => 'december',
	);
	my $HadContent;
	my $MonthInfo = $this->{DPI}->get_monthinfo($Year,$Month);
	my $HTML;
	foreach my $Day (sort @{$MonthInfo}) {
		$HadContent = 1;
		$HTML .= "<a href='".$this->_getFileName(true,$Year,$Month,$Day)."'>" . _HTML_Encode("$Day. " . $i18n->get_month($Month) ." $Year") . "</a><br/>\n";
	}
	unless($HadContent) {
		# FIXME: Ises i18n
		$HTML .= '<i>' . _HTML_Encode($i18n->get('There are no events this month')) . '</i>';
	}
	return($HTML);
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
				# FIXME: Get summary using functions provided by user for additional processing.
				my $info = $this->{DPI}->get_info($UID);
				my $EventSummary = $info->{SUMMARY};
				# Don't add Time = DAY.
				if($Time eq 'DAY') {
					$Time = '';
				}
				$Return .= '<tr><td>'.$Time.'</td><td>'._HTML_Encode($EventSummary);
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

# Purpose: Actually write a file
# Usage: this->_writeFile(FILE,contents);
sub _writeFile
{
	my $this = shift;
	my $file = shift;
	my $contents = shift;
	die if not $file;
	die if not $contents;
	# FIXME: Check open() return value better
	open(my $o, '>',$file) or die;
	print {$o} $contents;
	close($o);
	return true;
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

# Purpose: Prefix a "0" to a number if it is only one digit.
# Usage: my $NewNumber = _prefixZero(NUMBER);
sub _prefixZero
{
	my $Number = shift;
	if ($Number =~ /^\d$/) {
		return("0$Number");
	}
	return($Number);
}

# Purpose: Get a filename
# Usage: name = this->_getFileName(base?,Year,Month,Day);
# If base is true then dir will not be included.
# Month and Day are optional.
# TODO: Better file naming based on %RawMonthNames
sub _getFileName
{
	my $this = shift;
	my $base = shift;
	my $Year = shift;
	my $Month = shift;
	my $Day = shift;
	my $fname = 'dp_';
	if (defined $Day)
	{
		#$fname .= $Day.$Month.$Year;
		$fname .= $Year . _prefixZero($Month) ._prefixZero($Day);
	}
	elsif(defined $Month)
	{
		#$fname .= $Month.$Year;
		$fname .= $Year . _prefixZero($Month);
	}
	else
	{
		$fname .= $Year;
	}
	$fname .= '.html';
	if ($base)
	{
		return($fname);
	}
	else
	{
		return($this->{_currdir}.'/'.$fname);
	}
}
