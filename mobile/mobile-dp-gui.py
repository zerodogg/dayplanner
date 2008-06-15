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
# This so that we can run without the hildon toolkit
# (ie. on non-maemo platforms that doesn't have or use hildon)
try:
	import hildon
	HasHildon = True
except ImportError:
	HasHildon = False
import re
import sys
import socket
import os
import time
from posix import getpid

comSocket = file('/dev/null')
confDir = os.environ['HOME']+"/.config/dayplanner.mobile/"
socketPath = confDir+"Data_Servant"
pid = str(getpid())
UpcomingEventsBuffer = gtk.TextBuffer()
CalendarWidget = gtk.Calendar();
EventlistWin = gtk.ScrolledWindow()
liststore = gtk.ListStore(str, str, str)

if not os.environ['HOME']:
	print "HOME environment variable missing. Attempting stupid detection."
	if os.path.exists('/home/user') and os.path.exists('/usr/bin/ossofilemanager'):
		print "Stupid detection succeeded, using /home/user/"
		os.environ['HOME'] = '/home/user/'
	else:
		print "Stupid detection failed. HOME missing. Refusing to continue."
		sys.exit(1)

# -- Communication conversion methods --
# Purpose: Extract a quoted communication string.
# Returns: The new string
def UnGetComString(string):
	slashn = re.compile("{DPNL}")
	newstring = slashn.sub("\n",string)
	return(newstring)

# Purpose: Quote a string for communication
# Returns: The new string
def GetComString(string):
	slashn = re.compile("\n")
	newstring = slashn.sub("{DPNL}",string)
	return(newstring)

# Purpose: Extract a quoted perl hash (dictionary)
# Returns: The dictionary
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

# Purpose: Quote a dictionary (perl hash)
# Returns: String
def GetComHash(hash):
	newlist = list()
	for key in hash.keys():
		newKey = GetComString(key)
		newValue = GetComString(hash[key])
		newlist.add(newKey)
		newlist.add(newValue)
	return "HASH"+GetComArray(newdict)

# Purpose: Extract a quoted array
# Returns: Array
def UnGetComArray(string):
	mainre = re.compile('^ARRAY: ?')
	string = mainre.sub('',string)
	myArray = []
	for v in string.split("{DPSEP}"):
		if not v == "":
			myArray.append(GetComString(v))
	return myArray

# Purpose: Quote an array
# Returns: String
def GetComArray(array):
	ret = 'ARRAY: '
	for v in array:
		ret = ret+GetComString(v)+'{DPSEP}'
	return ret

# Purpose: Wrapper for socket IO functions, unquotes strings, arrays and dictionaries
# Returns: String, dictionary or array depending on what data was recieved
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
# Purpose: Open our socket
# Returns: (nothing)
#	The arguments are used internally for looping
def OpenSocket(loopa=False, loopb=False, loopc=False):
	global comSocket
	if os.path.exists(socketPath):
		mySocket = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
		mySocket.connect(socketPath)
		comSocket = mySocket.makefile()
		if not SocketIO("PING") == "PONG":
			print "SocketIO failure: Did not reply to PING request"
	else:
		if loopc:
			print "FATAL ERROR: Failed to connect to servant."
			print "             Attempted to connect to: "+socketPath
			if os.path.exists(socketPath):
				print "             The path existed, but still we failed."
			else:
				print "             The path did not exist"
			sys.exit(1)
		elif loopb:
			print "Second attempt to connect to servant failed. Waiting five seconds,"
			print "then attempting one final time"
			time.sleep(5)
			return(OpenSocket(True,True,True))
		elif loopa:
			time.sleep(1.5)
			return OpenSocket(True,True)
		StartServant()
		return OpenSocket(True)

# Purpose: Locate the dayplanner-data-servant perl part
# Returns: String, command to run to start it
def LocateServant():
	directories = [os.path.dirname(os.path.abspath(sys.argv[0])),"./","/usr/bin/"]
	strinc = str()
	for part in ['modules/','modules/DP-iCalendar/lib/','modules/DP-GeneralHelpers/lib/','modules/DP-CoreModules/lib/']:
		strinc = strinc+' -I./'+part+' -I../'+part+' '
	# Construct include list
	for dir in directories:
		if os.path.exists(dir+'/dayplanner-data-servant'):
			return('perl '+strinc+dir+'/dayplanner-data-servant')
	# Failure
	print "FATAL: Unable to locate servant. Sorry about that, but I can't work without it."
	print "       Startup cancelled. (dayplanner-data-servant not found)"
	sys.exit(1)

# Purpose: Start the servant
# Returns: Nothing
def StartServant():
	if os.system(LocateServant()+" --force-fork") != 0:
		print "Servant startup failure?"

# Purpose: Send some data on our communication socket
# Returns: Empty str()
def SocketSend(data):
	global comSocket
	if data == "":
		print "SocketSend(): got '' - not sending"
		return str()
	try:
		encdata = data.encode('utf-8')
	except UnicodeEncodeError:
		encdata = data
	comSocket.write(pid+" "+encdata+"\n")
	comSocket.flush()
	return str()

# Purpose: Recieve some data from our communication socket
# Returns: Recieved string
def SocketRecv():
	global comSocket
	reply = comSocket.readline().rstrip()
	try:
		myreply = reply.decode('utf-8')
	except UnicodeDecodeError:
		myreply = reply
	return myreply

# Purpose: Send some data, and recieve some data
#			(wrapper around SocketSend() and SocketRecv())
# Returns: Recieved data
def SocketIO(data):
	SocketSend(data)
	recieveddata = ParseRecieved(SocketRecv())
	if type(recieveddata) == str:
		if recieveddata.startswith("ERR "):
			print "Recieved error on request '"+data+"': "+recieveddata
	return recieveddata

# -- Various data methods. Fetches and sends data --

# Purpose: Send updated iCalendar data to the data servant
# Returns: (nothing)
def SendIcalData(list):
	netsend = GetComHash(list)
	if SocketIO("SEND_ICAL "+netsend) != "OK":
		print "ERROR: FAILED TO SEND ICALENDAR DATA, SocketIO DID NOT RETURN OK"

# Purpose: Get events on the current day
# Returns: Array of UIDs
def GetEventsOnCurrentDay():
	(year,month,day) = CalendarWidget.get_date()
	month += 1
	list = SocketIO("GET_EVENTS "+str(year)+" "+str(month)+" "+str(day))
	return list

# Purpose: Get iCalendar data for the set day
# Returns: iCalendar dictionary
def GetIcalData(UID):
	netsend = "GET_ICAL "+UID
	iCalList = SocketIO(netsend)
	return iCalList

# Purpose: Get the iCalendar time for the string
# Returns: string
def GetIcalTime(string):
	return SocketIO("GET_ICSTIME "+string)

# Purpose: Exit the program
# Returns: Never
def Exit(argA=False, argB=False,retval = 0):
	SocketSend("SHUTDOWN")
	gtk.main_quit()
	sys.exit(retval)

# ----
# Add and edit functions
# ----
def NormalEventWindow ( UID, OK_BUTTON, VBOX_WIDGET, MAIN_WINDOW_WIDGET):
	print "NormalEventWindow(): STUB"

# -- Main --

# Purpose: Get the UID of the currently selected calendar entry
# Returns: UID (string) or False
def GetSelectedUID():
	iter = EventlistWidget.get_selection().get_selected()[1]
	if not iter:
		return False
	model = EventlistWidget.get_model()
	if not model:
		return False
	UID = model.get_value(iter,0)
	if not UID:
		return False
	return UID

# Purpose: Mark the days with events in the calendar
# Returns: Nothing
def SetActiveMonth():
	(year,month,day) = CalendarWidget.get_date()
	month += 1;
	list = SocketIO("GET_DAYS "+str(year)+" "+str(month))
	CalendarWidget.clear_marks()
	for day in list:
		CalendarWidget.mark_day(int(day))

# Purpose: Get the event type for an iCalendar event
# Returns: string - bday, norm or all
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

# Purpose: Get the upcoming events string
# Returns: Nothing, sets the text in the UpcomingEventsBuffer
def GetUpcomingEvents():
	UpcomingEventsBuffer.set_text(SocketIO("GET_UPCOMINGEVENTS"));

# Purpose: Add an event
# Returns: Undecided.
def addevent(arg):
	print "addevent(): STUB"

# Purpose: Edit an event
# Returns: Undecided.
def EditEvent(treeview,two,treeviewcolumn):
	print "EditEvent() called on "+GetSelectedUID()+": IS STUBBED"

# Purpose: Delete an event
# Returns: Undecided.
def DeleteEvent(arg):
	print "DeleteEvent(): STUBBED"

# Purpose: Get a localized string. Not implemented yet
# Returns: Localized string
def gettext(string):
	# FIXME
	return string;

# Purpose: Draw the event list
# Returns: Nothing
def DrawEventlist(EventlistWin):
	# NOTE: Difference from perl implementation: No SimpleList, using raw TreeView
	# create a liststore with one string column to use as the model
	global EventlistWidget
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

# Purpose: Update the event list
# Returns: Nothing
def UpdateEventList():
	liststore.clear()
	AddToEventList(liststore)

# Purpose: Add events to the liststore supplied
# Returns: Nothing
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
				summary = SocketIO('GET_SUMMARY '+UID)
				liststore.append([UID, time, summary])

# Purpose: Do stuff when the month changes
# Returns: Nothing
def MonthChangedEvent(cal):
	SetActiveMonth()

# Purpose: Do stuff when the day changes
# Returns: Nothing
def DayChangedEvent(cal):
	UpdateEventList()

# Purpose: Display an error dialog
# Returns: Nothing
def DPError(message):
	Dialog = gtk.MessageDialog(None, 0, gtk.MESSAGE_ERROR,gtk.BUTTONS_OK,message.encode("utf-8"))
	Dialog.set_title(gettext("Day Planner"))
	Dialog.run()
	Dialog.destroy()

# Purpose: Display an information dialog
# Returns: Nothing
def DPInfo(message):
	Dialog = gtk.MessageDialog(None, 0, gtk.MESSAGE_INFO,gtk.BUTTONS_OK,message.encode("utf-8"))
	Dialog.set_title(gettext("Day Planner"))
	Dialog.run()
	Dialog.destroy()

# Purpose: Draw the main window
# Returns: Nothing
def DrawMainWindow():
	if HasHildon:
		window = hildon.Window()
	else:
		window = gtk.Window()
	window.set_title(gettext("Day Planner"))
	# TODO: More signal handlers
	window.connect("destroy", Exit)
	window.connect("delete-event", Exit)
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
	# Create the calendar
	CalendarWidget.show()
	CalendarWidget.connect("day-selected",DayChangedEvent)
	CalendarWidget.connect("month-changed",MonthChangedEvent)
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

	# --- Toolbar ---
	Toolbar = gtk.Toolbar()
	Toolbar.set_style('icons')
	LeftHandVBox.pack_end(Toolbar,0,0,0);
	Toolbar.show()

	# Delete button
	ToolbarDeleteButton = gtk.ToolButton('gtk-delete')
	ToolbarDeleteButton.connect('clicked',DeleteEvent)
	Toolbar.insert(ToolbarDeleteButton,0)
	ToolbarDeleteButton.show()
	
	# Add button
	AddButton = gtk.ToolButton('gtk-add')
	AddButton.connect('clicked', addevent)
	Toolbar.insert(AddButton,0)
	AddButton.show()

	Toolbar.get_nth_item(0).set_is_important(True);
	Toolbar.get_nth_item(1).set_is_important(True);

	DrawEventlist(EventlistWin)
	GetUpcomingEvents()
	SetActiveMonth()

	window.show()

# Purpose: The main function
# Returns: Never
def main():
	try:
		# TODO: Commandline arguments
		# TODO: Put this into its own sub that can look for other files too (OpenMoko?)
		if not os.path.exists(confDir) and not os.path.exists("/usr/bin/ossofilemanager"):
			DPInfo("You're running the Day Planner maemo port on a desktop machine. This is completely unsupported. You REALLY should use the proper client instead, as they differ in significant ways, this one being tailored for use on the Maemo-based tablets.")
		OpenSocket()
		DrawMainWindow()
		gtk.main()
	except KeyboardInterrupt:
		print "\nInterrupted by the user.\n"
		SocketSend("SHUTDOWN")
		sys.exit(1)
	except StandardError:
		import traceback
		tb = traceback.format_exc()
		print tb
		DPError("An unhandled exception occurred. This is a bug and should be reported. Day Planner will attempt to continue, but is likely to crash.\n\n"+tb)

if __name__ == "__main__":
	main()
else:
	print "__name__ != __main__. Why?"
