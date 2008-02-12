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
import re
import sys
import socket
import os
from posix import getpid

comSocket = file('/dev/null')
socketPath = '/home/zerodogg/.config/dayplanner.maemo/Data_Servant'
pid = str(getpid())
UpcomingEventsBuffer = gtk.TextBuffer()
CalendarWidget = gtk.Calendar();
EventlistWin = gtk.ScrolledWindow()
liststore = gtk.ListStore(str, str, str)

# -- Communication conversion methods --
def UnGetComString(string):
	slashn = re.compile("{DPNL}")
	newstring = slashn.sub("\n",string)
	return(newstring)
def GetComString(string):
	slashn = re.compile("\n")
	newstring = slashn.sub("{DPNL}",string)
	return(newstring)

def UnGetComHash(string):
	there = re.compile("^HASH")
	string = there.sub('',string)
	array = UnGetComArray(string)

	key = str()
	newDict = dict()
	for entry in array:
		if key != "":
			newDict[key] =  entry
			key = ""
		else:
			key = entry
	return newDict

def GetComHash(hash):
	newlist = list()
	for key in hash.keys():
		newKey = GetComString(key)
		newValue = GetComString(hash[key])
		newlist.add(newKey)
		newlist.add(newValue)
	return "HASH"+GetComArray(newdict)

def UnGetComArray(string):
	mainre = re.compile('^ARRAY: ?')
	string = mainre.sub('',string)
	myArray = []
	for v in string.split("{DPSEP}"):
		if not v == "":
			myArray.append(GetComString(v))
	return myArray

def GetComArray(array):
	ret = 'ARRAY: '
	for v in array:
		ret = ret+GetComString(v)+'{DPSEP}'
	return ret

def ParseRecieved(data):
	if data == "":
		print "ParseRecieved(): got ''"
		return str()
	hash = re.compile("^HASH")
	array = re.compile("^ARRAY")
	if hash.match(data):
		return UnGetComHash(data)
	elif array.match(data):
		return UnGetComArray(data)
	else:
		return UnGetComString(data)

# -- Communication methods --
def OpenSocket(loop=False):
	global comSocket
	if os.path.exists(socketPath):
		mySocket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
		mySocket.connect(socketPath)
		comSocket = mySocket.makefile()
		if not SocketIO("PING") == "PONG":
			print "SocketIO failure: Did not reply to PING request"
	else:
		if loop:
			print "FATAL: Failed to start servant. Giving up."
			sys.exit(1)
		StartServant()
		OpenSocket(True)

def LocateServant():
	directories = [os.path.dirname(os.path.abspath(sys.argv[0])),"./","/usr/bin/"]
	strinc = str()
	for part in ['modules/','modules/DP-iCalendar/lib/','modules/DP-GeneralHelpers/lib/','modules/DP-CoreModules/lib/']:
		strinc = strinc+' -I./'+part+' -I../'+part+' '
	print strinc
	# Construct include list
	for dir in directories:
		if os.path.exists(dir+'/dayplanner-data-servant'):
			return('perl '+strinc+dir+'/dayplanner-data-servant')
	# Failure
	print "FATAL: Unable to locate servant. Sorry about that, but I can't work without it."
	print "       Startup cancelled. (dayplanner-data-servant not found)"
	sys.exit(1)

def StartServant():
	if os.system(LocateServant()+" --force-fork") != 0:
		print "Servant startup failure?"

def SocketSend(data):
	global comSocket
	if data == "":
		print "SocketSend(): got '' - not sending"
		return str()
	comSocket.write(pid+" "+data.encode('utf-8')+"\n")
	comSocket.flush()
	return str()

def SocketRecv():
	global comSocket
	reply = comSocket.readline().rstrip().decode('utf-8')
	return reply

def SocketIO(data):
	SocketSend(data)
	recieveddata = ParseRecieved(SocketRecv())
	if type(recieveddata) == str:
		if recieveddata.startswith("ERR "):
			print "Recieved error on request '"+data+"': "+recieveddata
	return recieveddata

# -- Various data methods. Fetches and sends data --
def SendIcalData(list):
	netsend = GetComHash(list)
	if SocketIO("SEND_ICAL "+netsend) != "OK":
		print "ERROR: FAILED TO SEND ICALENDAR DATA, SocketIO DID NOT RETURN OK"

def GetEventsOnCurrentDay():
	(year,month,day) = CalendarWidget.get_date()
	month += 1
	list = SocketIO("GET_EVENTS "+str(year)+" "+str(month)+" "+str(day))
	return list

def GetIcalData(UID):
	netsend = "GET_ICAL "+UID
	iCalList = SocketIO(netsend)
	return iCalList

def Ical_MonthList(NIXTIME):
	print "STUB"

def Ical_DayEventList(NIXTIME):
	print "STUB"

def GetIcalTime(string):
	return SocketIO("GET_ICSTIME "+string)

def Exit(arg):
	SocketSend("SHUTDOWN")
	gtk.main_quit()
	sys.exit(0)

# -- Main --

def SetActiveMonth():
	(year,month,day) = CalendarWidget.get_date()
	month += 1;
	list = SocketIO("GET_DAYS "+str(year)+" "+str(month))
	CalendarWidget.clear_marks()
	for day in list:
		CalendarWidget.mark_day(int(day))

def GetEtype(UIDInfo):
	if UIDInfo.has_key('X-DP-BIRTHDAY') and UIDInfo.get('X-DP-BIRTHDAY') == "TRUE":
		return "bday"
	else:
		time = UIDInfo.get('DTSTART')
		myre = re.compile('^\d+T\d+$')
		if myre.match(time):
			return("norm")
		else:
			return("all")

def GetUpcomingEvents():
	UpcomingEventsBuffer.set_text(SocketIO("GET_UPCOMINGEVENTS"));

def addevent():
	print "STUB"

def EditEvent(treeview,two,treeviewcolumn):
	print "EditEvent(): STUBBED"

def gettext(string):
	return string;

def DrawEventlist(EventlistWin):
	# NOTE: Difference from perl implementation: No SimpleList, using raw TreeView
	# create a liststore with one string column to use as the model
	EventlistWidget = gtk.TreeView(liststore)
	# create the TreeViewColumns to display the data
	tvcolumn = gtk.TreeViewColumn(gettext('Time'))
	tvcolumn1 = gtk.TreeViewColumn(gettext('Event'))
	# add columns to EventlistWidget
	EventlistWidget.append_column(tvcolumn)
	EventlistWidget.append_column(tvcolumn1)
	cell = gtk.CellRendererText()
	cell1 = gtk.CellRendererText()
	# add the cells to the columns
	tvcolumn.pack_start(cell, True)
	tvcolumn1.pack_start(cell1, True)
	tvcolumn.set_attributes(cell, text=1)
	tvcolumn1.set_attributes(cell1, text=2)
	EventlistWidget.connect('row_activated', EditEvent)
	EventlistWidget.show()
	# Add entries
	AddToEventList(liststore)

	EventlistWin.add(EventlistWidget);

def UpdateEventList():
	liststore.clear()
	AddToEventList(liststore)

def AddToEventList(liststore):
	UIDs = GetEventsOnCurrentDay()
	if type(UIDs) == list:
		for UID in UIDs:
			eventInfo = GetIcalData(UID)
			if type(eventInfo) == dict:
				if GetEtype(eventInfo) ==  "norm":
					time = GetIcalTime(eventInfo.get("DTSTART"))
				else:
					time = ""
				liststore.append(['UID',time, eventInfo.get("SUMMARY")])

def MonthChangedEvent(cal):
	SetActiveMonth()

def DayChangedEvent(cal):
	UpdateEventList()

# Purpose: Draw the main window
def DrawMainWindow():
	window = hildon.Window()
	window.set_title(gettext("Day Planner"))
	# TODO: More signal handlers
	window.connect("destroy", Exit)
	# Check something that will only be present on desktops.
	# If it is present, then set a default size. If we're on a Maemo that file
	# won't be present, and the maemo WM will force the size of our main window
	# to fit the screen anyway
	if os.path.exists("/usr/bin/gnome-about-me"):
		print "WARNING: You are running the maemo port of Day Planner on a desktop"
		print "         This is NOT supported and NOT recommended. You should go use the"
		print "         desktop version."
		window.set_default_size(600,365)

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
	CalendarWidget.show()
	CalendarWidget.connect("day-selected",DayChangedEvent)
	CalendarWidget.connect("month-changed",MonthChangedEvent)
	#$CalendarWidget->display_options(['show-week-numbers', 'show-day-names','show-heading']);
	#$currmonth--;
	# Work around a possible Gtk2::Calendar bug by explicitly setting the month/year combo
	#$CalendarWidget->select_month($currmonth, $curryear);
	#$RightHandVBox->pack_start($CalendarWidget,0,0,0);
	RightHandVBox.pack_start(CalendarWidget,0,0,0)

	# UPCOMING EVENTS
	# Create the scrolled window
	UpcomingEventsWindow = gtk.ScrolledWindow()
	UpcomingEventsWindow.set_policy('automatic','automatic');
	UpcomingEventsWindow.show();
	# Create the TextView and TextBuffer objects
	UpcomingEventsWidget = gtk.TextView()
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
	EventlistWin.set_policy('automatic','automatic')
	LeftHandVBox.pack_start(EventlistWin,1,1,0)
	EventlistWin.show()

	DrawEventlist(EventlistWin)
	GetUpcomingEvents()
	SetActiveMonth()

	window.show()

if __name__ == "__main__":
	OpenSocket()
	DrawMainWindow()
	gtk.main()         
