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
# Useful constants for prettier code
use constant { true => 1, false => 0 };

our @EXPORT_OK = qw(DPIntWarn GTK_Flush DP_DestroyProgressWin DPError DPCreateProgressWin runtime_use);

sub DPIntWarn
{
	return main::DPIntWarn(@_);
}

sub GTK_Flush
{
	return main::GTK_Flush(@_);
}

sub DP_DestroyProgressWin
{
	return main::DP_DestroyProgressWin(@_);
}

sub DPError
{
	return main::DPError(@_);
}

sub DPCreateProgressWin
{
	return main::DPCreateProgressWin(@_);
}

sub runtime_use
{
	return main::runtime_use(@_);
}

1;
