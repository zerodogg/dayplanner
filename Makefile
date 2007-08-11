# Makefile for Day Planner
# Copyright (C) Eskild Hustvedt 2007
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
ifdef prefix
INSTALLRULES=maininstall moduleinstall artinstall holidayinstall i18ninstall distribdesktop
else
# If not then use some user-friendly install rules
INSTALLRULES=maininstall moduleinstall artinstall holidayinstall DHPinstall nice_i18ninstall tools desktop essentialdocs
# This little trick ensures that make install will succeed both for a local
# user and for root. It will also succeed for distro installs as long as
# prefix is set by the builder.
prefix=$(shell perl -e 'if($$< == 0 or $$> == 0) { print "/usr" } else { print "$$ENV{HOME}/.local"}')
endif

DP_DATADIR ?= dayplanner
BINDIR ?= bin
DATADIR ?= $(prefix)/share

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
	@echo " distrib     - create packages"
	@echo " test        - verify release sanity"
	@echo " DHPinstall  - install the Date::HolidayParser module (only needed for distro packages)"

install: $(INSTALLRULES)

updatepo:
	perl ./devel-tools/updatepo

distrib:
	perl ./devel-tools/CreatePackages

mo:
	perl ./devel-tools/BuildLocale

uninstall:
	rm -rf $(DP_MAINTARGET)
	rm -f $(DESTDIR)$(prefix)/$(BINDIR)/dayplanner $(DESTDIR)$(prefix)/$(BINDIR)/dayplanner-daemon $(DESTDIR)$(prefix)/$(BINDIR)/dayplanner-notifier
	rm -f $(DESTDIR)$(DATADIR)/applications/dayplanner.desktop

clean:
	rm -f $(shell find|egrep '~$$')
	rm -f po/*.mo
	rm -f po/*.pot
	rm -f doc/dayplanner.desktop
	rm -rf packages/
	rm -rf locale/
distclean: clean
	perl -MFile::Find -e 'use File::Path qw/rmtree/;find(sub { return if $$File::Find::name =~ m#/\.svn#; if(not -d $$_) { if(not -e "./.svn/text-base/$$_.svn-base") { print "unlink: $$File::Find::name\n";unlink($$_);}} else { if (not -d "$$_/.svn") { print "rmtree: $$_\n";rmtree($$_)}} },"./");'

# Verify sanity
test:
	@perl -c ./modules/DP-iCalendar/lib/DP/iCalendar.pm
	@perl -c ./modules/DP-GeneralHelpers/lib/DP/GeneralHelpers/IPC.pm
	@perl -c ./modules/DP-GeneralHelpers/lib/DP/GeneralHelpers/HTTPFetch.pm
	@perl -c ./modules/DP-GeneralHelpers/lib/DP/GeneralHelpers/I18N.pm
	@perl -I./modules/DP-GeneralHelpers/lib/ -c ./modules/DP-GeneralHelpers/lib/DP/GeneralHelpers.pm
	@perl -c ./dayplanner
	@perl -c ./dayplanner-daemon
	@perl -c ./dayplanner-notifier
	@perl -c ./devel-tools/installer/MainInstallerPart
	@perl -c ./devel-tools/installer/InstallLocal
	@perl -c ./devel-tools/GenDesktop
	@perl -c ./devel-tools/BuildLocale
	@perl -c ./devel-tools/SetVersion
	@perl -c ./devel-tools/postat
	@perl -c ./devel-tools/updatepo
	@perl -c ./devel-tools/CreatePackages
	@perl -c ./services/tools/DPSAdmin
	@perl -c ./services/tools/GenHTML
	@perl -c ./services/dayplanner-services-daemon

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
	cp -r locale $(DESTDIR)$(prefix)

# This is the normal one, it will die if it fails and it won't create additional
# symlinks
i18ninstall:
	rm -rf locale
	mkdir locale
	perl ./devel-tools/BuildLocale ./locale
	cp -r locale $(DESTDIR)$(prefix)

# Installation of DP
maininstall:
	mkdir -p $(DP_MAINTARGET)
	install -m755 ./dayplanner $(DP_MAINTARGET)
	mkdir -p $(DESTDIR)$(prefix)/$(BINDIR)
	-ln -s ../share/dayplanner/dayplanner $(DESTDIR)$(prefix)/$(BINDIR)
	install -m755 ./dayplanner-daemon $(DP_MAINTARGET)
	-ln -s ../share/dayplanner/dayplanner-daemon $(DESTDIR)$(prefix)/$(BINDIR)
	install -m755 ./dayplanner-notifier $(DP_MAINTARGET)
	-ln -s ../share/dayplanner/dayplanner-notifier $(DESTDIR)$(prefix)/$(BINDIR)

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
