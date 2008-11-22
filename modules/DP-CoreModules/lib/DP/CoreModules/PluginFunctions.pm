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

our @EXPORT_OK = qw(DPIntWarn GTK_Flush DP_DestroyProgressWin DPError DPInfo DPCreateProgressWin runtime_use);

foreach my $sub (@EXPORT_OK)
{
	eval('sub '.$sub.' { return main::'.$sub.'(@_); }');
}
1;
