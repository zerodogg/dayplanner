#!/usr/bin/env python
# maemo-dp-gui.py
# Maemo Day Planner GUI
# Copyright (C) Eskild Hustvedt 2008
#
# $Id$
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

import gtk 
import hildon

def mainwindow:
	print "STUB"

def addevent:
	print "STUB"

def editevent:
	print "STUB"

def ParseSuppliedData(data):
	print "STUB"

if __name__ == "__main__":
	window = hildon.Window()
	window.connect("destroy", gtk.main_quit)
	label = gtk.Label("Day Planner World!")
	window.add(label)

	label.show()
	window.show()

	gtk.main()         
