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

def mainwindow():
	print "STUB"

def addevent():
	print "STUB"

def editevent():
	print "STUB"

def ParseSuppliedData(data):
	print "STUB"

def parseHash(hash):
	print "STUB"

def parseArray(array):
	print "STUB"

def EditEvent(treeview,two,treeviewcolumn):
	print "EditEvent(): STUBBED"

def parseString(string):
	print "STUB"

def gettext(string):
	return string;

def DrawEventlist(EventlistWin):
	# NOTE: Difference from perl implementation: No SimpleList, using raw TreeView
	# create a liststore with one string column to use as the model
	liststore = gtk.ListStore(str, str, str)
	EventlistWidget = gtk.TreeView(liststore)
	# create the TreeViewColumns to display the data
	tvcolumn = gtk.TreeViewColumn(gettext('Time'))
	tvcolumn1 = gtk.TreeViewColumn(gettext('Event'))
	# add columns to EventlistWidget
	EventlistWidget.append_column(tvcolumn)
	EventlistWidget.append_column(tvcolumn1)
	# TODO: Get every event on the date here
	liststore.append(['UID','19:30', 'Write Maemo/Python DP GUI'])
	cell = gtk.CellRendererText()
	cell1 = gtk.CellRendererText()
	# add the cells to the columns
	tvcolumn.pack_start(cell, True)
	tvcolumn1.pack_start(cell1, True)
	tvcolumn.set_attributes(cell, text=1)
	tvcolumn1.set_attributes(cell1, text=2)
	EventlistWidget.connect('row_activated', EditEvent)
	EventlistWidget.show()
	EventlistWin.add(EventlistWidget);

# Purpose: Draw the main window
def DrawMainWindow():
	window = hildon.Window()
	window.set_title(gettext("Day Planner"))
	# TODO: Clean exit
	# TODO: More signal handlers
	window.connect("destroy", gtk.main_quit)

	# TODO: Set icon
	PrimaryWindowVBox = gtk.VBox()
	PrimaryWindowVBox.show()
	window.add(PrimaryWindowVBox)
	# TODO: Menu
	# ==================================================================
	# WORKING AREA
	# ==================================================================
	# Create the hbox which will contain the rest of the program
	WorkingAreaHBox = gtk.HBox()
	WorkingAreaHBox.show()
	PrimaryWindowVBox.pack_start(WorkingAreaHBox)

	# ==================================================================
	# THE RIGHT HAND AREA
	# ==================================================================
	
	# Create the vbox for use in it
	RightHandVBox = gtk.VBox()
	WorkingAreaHBox.pack_end(RightHandVBox,0,0,0)
	RightHandVBox.show()
	# CALENDAR
	# TODO: Get the current time and set it as done in the perl GUI
	#my ($currsec,$currmin,$currhour,$currmday,$currmonth,$curryear,$currwday,$curryday,$currisdst) = GetDate();
	# Create the calendar
	CalendarWidget = gtk.Calendar();
	# TODO SetActiveCalItems
	CalendarWidget.show()
	#$CalendarWidget->display_options(['show-week-numbers', 'show-day-names','show-heading']);
	#$currmonth--;
	# Work around a possible Gtk2::Calendar bug by explicitly setting the month/year combo
	#$CalendarWidget->select_month($currmonth, $curryear);
	#$RightHandVBox->pack_start($CalendarWidget,0,0,0);
	# TODO: Signal handling in the calendar
	RightHandVBox.pack_start(CalendarWidget)

	# UPCOMING EVENTS
	# Create the scrolled window
	UpcomingEventsWindow = gtk.ScrolledWindow()
	UpcomingEventsWindow.set_policy('automatic','automatic');
	UpcomingEventsWindow.show();
	# Create the TextView and TextBuffer objects
	UpcomingEventsWidget = gtk.TextView()
	UpcomingEventsBuffer = gtk.TextBuffer()
	UpcomingEventsBuffer.set_text("Upcoming events here")
	UpcomingEventsWidget.set_buffer(UpcomingEventsBuffer)
	UpcomingEventsWidget.set_editable(0)
	UpcomingEventsWidget.set_wrap_mode('word');
	UpcomingEventsWidget.show()
	UpcomingEventsWindow.add(UpcomingEventsWidget)
	# Pack it onto the main window
	RightHandVBox.pack_end(UpcomingEventsWindow,1,1,0);

	# ==================================================================
	# LEFT HAND AREA
	# ==================================================================
	# Create the vbox for use in it
	LeftHandVBox = gtk.VBox()
	WorkingAreaHBox.pack_start(LeftHandVBox,1,1,0)
	LeftHandVBox.show()
	
	# Add a window for use for it
	EventlistWin = gtk.ScrolledWindow()
	EventlistWin.set_policy('automatic','automatic')
	LeftHandVBox.pack_start(EventlistWin,1,1,0)
	EventlistWin.show()

	DrawEventlist(EventlistWin)

	window.show()

if __name__ == "__main__":
	DrawMainWindow()
	gtk.main()         