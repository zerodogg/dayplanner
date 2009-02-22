# Day Planner plugin system - aliases for functions
# Copyright (C) Eskild Hustvedt 2008
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

package DP::CoreModules::PluginFunctions;
use strict;
use warnings;
use Exporter qw(import);

our @EXPORT_OK = qw(Assert);

foreach my $sub (qw(DPIntWarn GTK_Flush DP_DestroyProgressWin DPError DPInfo DPCreateProgressWin runtime_use UpdatedData Gtk2_Button_SetImage))
{
	eval('sub '.$sub.' { return main::'.$sub.'(@_); }');
	push(@EXPORT_OK,$sub);
}

# Purpose: Provide useful information if an assertion fails
# Usage: Assert(TRUE/FALSE EXPR, REASON);
# NOTE: This is for use in PLUGINS, not inside Day Planner itself. Use the internal
# Assert there, this one in modules.
sub Assert
{
	my $expr = shift;
	return 1 if $expr;
	my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(1);
	my ($s2_package, $s2_filename, $s2_line, $s2_subroutine, $s2_hasargs, $s2_wantarray, $s2_evaltext, $s2_is_require, $s2_hints, $s2_bitmask) = caller(0);
	my $msg = "Assertion failure at $s2_filename:$s2_line in $subroutine originating from call at $filename:$line";
	if(defined($_[0]))
	{
		$msg .= ': '.$_[0]."\n";
	}
	else
	{
		$msg .= "\n";
	}
	DPIntWarn($msg);
	# Attempt to make the main window usable again, in case
	# this screws things up.
	$main::MainWindow->set_sensitive(1);
	return 1;
}
1;
