# Makefile for Day Planner
# Copyright (C) Eskild Hustvedt 2006, 2007
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

# If prefix is already set then use some distro-friendly install rules
ifdef PREFIX
INSTALLRULES=maininstall moduleinstall artinstall holidayinstall i18ninstall distribdesktop
else
# If not then use some user-friendly install rules
INSTALLRULES=maininstall moduleinstall artinstall holidayinstall DHPinstall nice_i18ninstall tools desktop essentialdocs
# This little trick ensures that make install will succeed both for a local
# user and for root. It will also succeed for distro installs as long as
# PREFIX is set by the builder.
PREFIX=$(shell perl -e 'if($$< == 0 or $$> == 0) { print "/usr" } else { print "$$ENV{HOME}/.local"}')
endif

DP_DATADIR ?= dayplanner
BINDIR ?= bin
DATADIR ?= $(PREFIX)/share

# So I have to type less
DP_MAINTARGET = $(DESTDIR)$(DATADIR)/$(DP_DATADIR)

# --- USER USABLE RULES ---
all:
	@echo Valid targets:
	@echo " install     - install Day Planner"
	@echo " uninstall   - uninstall a previously installed Day Planner"
	@echo " clean       - clean up the tree"
	@echo " updatepo    - update po-files"
	@echo " mo          - build the locale/ tree"
	@echo " packages    - create packages"
	@echo " DHPinstall  - install the Date::HolidayParser module (only needed for distro packages)"

install: $(INSTALLRULES)

updatepo:
	perl ./devel-tools/updatepo

packages:
	perl ./devel-tools/CreatePackages

mo:
	perl ./devel-tools/BuildLocale

uninstall:
	rm -rf $(DP_MAINTARGET)
	rm -f $(DESTDIR)$(PREFIX)/$(BINDIR)/dayplanner $(DESTDIR)$(PREFIX)/$(BINDIR)/dayplanner-daemon $(DESTDIR)$(PREFIX)/$(BINDIR)/dayplanner-notifier
	rm -f $(DESTDIR)$(DATADIR)/applications/dayplanner.desktop

clean:
	rm -f $(shell find|egrep '~$$')

# Date::HolidayParser installation
DHPinstall:
	mkdir -p $(DP_MAINTARGET)/modules/Date/
	install -m755 modules/Date-HolidayParser/lib/Date/HolidayParser.pm $(DP_MAINTARGET)/modules/Date/HolidayParser.pm

# --- INTERNAL RULES ---

# - Install rules -

# This is a 'nice' i18n installer, it won't kill the install even if it fails.
nice_i18ninstall:
	rm -rf locale
	mkdir locale
	perl ./devel-tools/BuildLocale || true
	cp -r locale $(DP_MAINTARGET)

# This is the normal one, it will die if it fails and it won't create additional
# symlinks
i18ninstall:
	rm -rf locale
	mkdir locale
	perl ./devel-tools/BuildLocale ./locale
	cp -r locale $(DP_MAINTARGET)

# Installation of DP
maininstall:
	mkdir -p $(DP_MAINTARGET)
	install -m755 ./dayplanner $(DP_MAINTARGET)
	mkdir -p $(DESTDIR)$(PREFIX)/$(BINDIR)
	-ln -s $(DP_MAINTARGET)/dayplanner $(DESTDIR)$(PREFIX)/$(BINDIR)
	install -m755 ./dayplanner-daemon $(DP_MAINTARGET)
	-ln -s $(DP_MAINTARGET)/dayplanner-daemon $(DESTDIR)$(PREFIX)/$(BINDIR)
	install -m755 ./dayplanner-notifier $(DP_MAINTARGET)
	-ln -s $(DP_MAINTARGET)/dayplanner-notifier $(DESTDIR)$(PREFIX)/$(BINDIR)

# Art installation
artinstall:
	mkdir -p $(DP_MAINTARGET)/art
	install -m644 $(shell ls ./art/*.png) $(DP_MAINTARGET)/art/
	mkdir -p $(DESTDIR)$(DATADIR)/pixmaps/
	install -m644 ./art/dayplanner-48x48.png  $(DESTDIR)$(DATADIR)/pixmaps/dayplanner.png

# Module installation
moduleinstall:
	mkdir -p $(DP_MAINTARGET)/modules/DP
	install -m755 $(shell ls ./modules/*/lib/DP/*pm) $(DP_MAINTARGET)/modules/DP

# Holiday installation
holidayinstall:
	mkdir -p $(DP_MAINTARGET)/holidays
	install -m644 $(shell ls ./holiday/holiday*) $(DP_MAINTARGET)/holidays

# Tool installation
tools:
	mkdir -p $(DP_MAINTARGET)/tools
	install -m755 $(shell ls ./tools/) $(DP_MAINTARGET)/tools
# Essential documentation
essentialdocs:
	install -m644 NEWS $(DP_MAINTARGET)
	install -m644 COPYING $(DP_MAINTARGET)
	install -m644 THANKS $(DP_MAINTARGET)
	install -m644 TODO $(DP_MAINTARGET)
# .desktop file installation
desktop:
	./devel-tools/GenDesktop $(DESTDIR) $(DP_MAINTARGET)/doc/
	mkdir -p $(DESTDIR)$(DATADIR)/applications
	install -m644 ./doc/dayplanner.desktop $(DESTDIR)$(DATADIR)/applications
# Distrib .desktop file installation
distribdesktop:
	./devel-tools/GenDesktop .
	mkdir -p $(DESTDIR)$(DATADIR)/applications
	install -m644 ./doc/dayplanner.desktop $(DESTDIR)$(DATADIR)/applications
