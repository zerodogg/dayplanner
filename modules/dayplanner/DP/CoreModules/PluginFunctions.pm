# Day Planner plugin system - aliases for functions
# Copyright (C) Eskild Hustvedt 2008, 2009
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

foreach my $sub (qw(DPIntWarn GTK_Flush ProgressMade PulsateProgressbar DP_DestroyProgressWin DPError DPInfo DPCreateProgressWin runtime_use UpdatedData Gtk2_Button_SetImage DPQuestion DetectImage QuitSub))
{
	eval('sub '.$sub.' { return main::'.$sub.'(@_); }');
	push(@EXPORT_OK,$sub);
}

# Purpose: Provide useful information if an assertion fails
# Usage: Assert(TRUE/FALSE EXPR);
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
	# this screws things up. We disable warnings on this line because if not
	# perl -c will whine and that annoys me during make test :)
	no warnings;
	$main::MainWindow->set_sensitive(1);
	use warnings;
	return 0;
}
1;
__END__

=head1 INTRODUCTION

This module provides an interface for plugins to call core Day Planner
functions and import them into their namespace (main::functionName is of
course still available if you require specific access, though the API for
those functions can change without any apiversion being bumped).

No functions are exported by default.

=head1 FUNCTIONS

=over

=item Assert(B<BOOLEAN/BOOLEAN EXPRESSION>)

Assert that the supplied expression should be true (ie. supplied boolean
should be true). If it isn't then the Assert will return false, and it will
try to repair the appliation state and provide a useful warning in the
terminal with the line number and file that the Assertion failed at.

=item DPIntwarn(B<STRING>)

Emit an internal warning. Outputs to STDERR and includes a standardized day
planner version number and app name, similar to internal gtk2 warnings.

=item GTK_Flush()

Flush any pending gtk2 operations.

=item my $hashref = DPCreateProgressWin(B<STRING> Window name, B<STRING> Initial text on the progress bar, B<BOOL> pulsate mode?);

Creates a gtk2 progress window with the supplied settings. You can then use
PulsateProgressbar(), ProgressMade(), and DP_DestroyProgressWin() using the
returned hashref as parameters.

The returned hashref contains the following settings:

=over

=item Window

The Gtk2::Window being displayed.

=item ProgressBar

The Gtk2::ProgressBar being used


=back

=item DP_DestroyProgressWin($hashref)

Destroy the progressbar and windows in hashref

=item ProgressMade(B<INT> $toPerform, B<INT>$hasPerformed, B<HASHREF> $hashref, B<STRING> $NewText?)

Indicate that some progress has been made. $toPerform is the number of actions
that is going to be performed. $hasPerformed is the number of actions that has
been performed. $hashref is the hasref returned by DP_CreateProgressWin().
$NewText is optional, the new text to put on the progress bar.

=item PulsateProgressbar($hashRef)

Pulsate the progress bar in $hashRef if there is one. If not, it simply does
nothing.

=item DPError(B<STRING> message), DPInfo(B<STRING> message)

Display an error, or information window respectively, containing the supplied
message.

=item runtime_use('Some::Module');

Load the supplied module during runtime. This keeps track of loaded modules so
you they're not loaded multiple times, and displays an error if it fails.

=item UpdatedData()

Indicate to Day Planner that the data has been updated. Causes it to
redraw various widgets.

=item Gtk2_Button_SetImage(B<OBJECT> Gtk2::Button, B<OBJECT> Gtk2::Image, B<STRING> fallback label)

Set the image Gtk2::Image as the image on Gtk2::Button, and if the Gtk2
version in use does not support images then it will set the label 'fallback
label' instead.

=item DPQuestion(B<STRING> question);

Ask the user a question. Returns a bool, true if the user clicked yes.

=item my $path = DetectImage('image');

Attempt to locate the image supplied in system or day planner directories.
Used to find the Day Planner icons.

=item QuitSub()

Quit Day Planner in a controlled manner. Closing GUI windows and saving the
data and configuration files.

=back
