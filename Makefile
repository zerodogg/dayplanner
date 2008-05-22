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
INSTALLRULES=maininstall moduleinstall artinstall holidayinstall DHPinstall nice_i18ninstall desktop essentialdocs
# This little trick ensures that make install will succeed both for a local
# user and for root. It will also succeed for distro installs as long as
# prefix is set by the builder.
prefix=$(shell perl -e 'if($$< == 0 or $$> == 0) { print "/usr" } else { print "$$ENV{HOME}/.local"}')
endif

# The package to build with distrib
PKG=$(shell if which debuild 2>&1 >/dev/null; then echo deb; else echo rpm;fi)

VERSION=0.9.1
DP_DATADIR ?= dayplanner
BINDIR ?= bin
DATADIR ?= $(prefix)/share

# So I have to type less
DP_MAINTARGET = $(DESTDIR)$(DATADIR)/$(DP_DATADIR)

# --- USER USABLE RULES ---
help:
	@echo "User targets:"
	@echo " install      - install Day Planner"
	@echo " uninstall    - uninstall a previously installed Day Planner"
	@-[ -e "./.svn" ] && echo " localinstall - install symlinks and .desktop files to use the current SVN checkout";true
	@echo "Advanced targets:"
	@echo " clean        - clean up the tree"
	@echo " updatepo     - update po-files"
	@echo " mo           - build the locale/ tree"
	@echo " DHPinstall   - install the Date::HolidayParser module (only needed for distro packages)"
	@echo "Developer targets:"
	@echo " distrib      - create packages (tarball, installer and rpm)"
	@echo " tarball      - create tarball"
	@echo " installer    - create tarball and installer"
	@echo " rpm          - create tarball and rpm"
	@echo " test         - verify release sanity"

install: $(INSTALLRULES)

localinstall: desktoplocal
	mkdir -p $(DESTDIR)$(prefix)/$(BINDIR)/
	ln -sf $(shell pwd)/dayplanner $(DESTDIR)$(prefix)/$(BINDIR)/dayplanner
	ln -sf $(shell pwd)/dayplanner-notifier $(DESTDIR)$(prefix)/$(BINDIR)/dayplanner-notifier
	ln -sf $(shell pwd)/dayplanner-daemon $(DESTDIR)$(prefix)/$(BINDIR)/dayplanner-daemon

updatepo:
	perl ./devel-tools/updatepo

mo:
	perl ./devel-tools/BuildLocale

uninstall:
	rm -rf $(DP_MAINTARGET)
	rm -f $(DESTDIR)$(prefix)/$(BINDIR)/dayplanner $(DESTDIR)$(prefix)/$(BINDIR)/dayplanner-daemon $(DESTDIR)$(prefix)/$(BINDIR)/dayplanner-notifier
	rm -f $(DESTDIR)$(DATADIR)/applications/dayplanner.desktop

clean:
	rm -f `find|egrep '(~|\.swp)$$'`
	rm -f po/*.mo po/*.pot
	rm -rf po/locale packages locale dayplanner-$(VERSION) installer
	rm -f dayplanner.spec $$HOME/rpm/SOURCES/dayplanner-$(VERSION).tar.bz2
	[ ! -e ./modules/DP-iCalendar/Makefile ] || make -C ./modules/DP-iCalendar/ distclean
	[ ! -e ./modules/Date-HolidayParser/Makefile ] || make -C ./modules/Date-HolidayParser/ distclean
distclean: clean
	perl -MFile::Find -e 'use File::Path qw/rmtree/;find(sub { return if $$File::Find::name =~ m#/\.svn#; if(not -d $$_) { if(not -e "./.svn/text-base/$$_.svn-base") { print "unlink: $$File::Find::name\n";unlink($$_);}} else { if (not -d "$$_/.svn") { print "rmtree: $$_\n";rmtree($$_)}} },"./");'
	rm -f doc/dayplanner.desktop

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
	cp -r locale $(DESTDIR)$(DATADIR)

# This is the normal one, it will die if it fails and it won't create additional
# symlinks
i18ninstall:
	rm -rf locale
	mkdir locale
	perl ./devel-tools/BuildLocale ./locale
	cp -r locale $(DESTDIR)$(DATADIR)

# Installation of DP
maininstall:
	mkdir -p $(DP_MAINTARGET)
	install -m755 ./dayplanner $(DP_MAINTARGET)
	mkdir -p $(DESTDIR)$(prefix)/$(BINDIR)
	-ln -sf ../share/dayplanner/dayplanner $(DESTDIR)$(prefix)/$(BINDIR)
	install -m755 ./dayplanner-daemon $(DP_MAINTARGET)
	-ln -sf ../share/dayplanner/dayplanner-daemon $(DESTDIR)$(prefix)/$(BINDIR)
	install -m755 ./dayplanner-notifier $(DP_MAINTARGET)
	-ln -sf ../share/dayplanner/dayplanner-notifier $(DESTDIR)$(prefix)/$(BINDIR)

# Art installation
artinstall:
	mkdir -p $(DP_MAINTARGET)/art
	install -m644 $(shell ls ./art/*.png) $(DP_MAINTARGET)/art/
	mkdir -p $(DESTDIR)$(DATADIR)/pixmaps/
	install -m644 ./art/dayplanner-48x48.png  $(DESTDIR)$(DATADIR)/pixmaps/dayplanner.png

# Module installation
moduleinstall:
	mkdir -p $(DP_MAINTARGET)/modules/DP
	mkdir -p $(DP_MAINTARGET)/modules/DP/iCalendar
	mkdir -p $(DP_MAINTARGET)/modules/DP/GeneralHelpers
	install -m755 $(shell ls ./modules/*/lib/DP/*pm) $(DP_MAINTARGET)/modules/DP
	install -m755 $(shell ls ./modules/*/lib/DP/GeneralHelpers/*pm) $(DP_MAINTARGET)/modules/DP/GeneralHelpers/
	install -m755 $(shell ls ./modules/*/lib/DP/iCalendar/*pm) $(DP_MAINTARGET)/modules/DP/iCalendar/

# Holiday installation
holidayinstall:
	mkdir -p $(DP_MAINTARGET)/holiday
	install -m644 $(shell ls ./holiday/holiday*) $(DP_MAINTARGET)/holiday
	install -m644 ./holiday/dayplanner_detection $(DP_MAINTARGET)/holiday
	install -m644 ./holiday/dayplanner_upgrade $(DP_MAINTARGET)/holiday

# Essential documentation
essentialdocs:
	install -m644 NEWS $(DP_MAINTARGET)
	install -m644 COPYING $(DP_MAINTARGET)
	install -m644 THANKS $(DP_MAINTARGET)
	install -m644 TODO $(DP_MAINTARGET)
# .desktop file installation
desktop:
	./devel-tools/GenDesktop $(DP_MAINTARGET) $(DP_MAINTARGET)/art
	mkdir -p $(DESTDIR)$(DATADIR)/applications
	install -m644 ./doc/dayplanner.desktop $(DESTDIR)$(DATADIR)/applications
# Local .desktop file installation
desktoplocal:
	./devel-tools/GenDesktop $(shell pwd) $(shell pwd)/art/
	mkdir -p $(DESTDIR)$(DATADIR)/applications
	install -m644 ./doc/dayplanner.desktop $(DESTDIR)$(DATADIR)/applications
# Distrib .desktop file installation
distribdesktop: ./doc/dayplanner.desktop
	mkdir -p $(DESTDIR)$(DATADIR)/applications
	install -m644 ./doc/dayplanner.desktop $(DESTDIR)$(DATADIR)/applications
# Gen distrib desktop file
gendistribdesktop:
	./devel-tools/GenDesktop .
./doc/dayplanner.desktop: gendistribdesktop
# --- DISTRIB TARGETS ---
distrib: prepdistrib tarball $(PKG) installer
prepdistrib: gendistribdesktop test clean
	mkdir -p packages
tarball: prepdistrib
	mkdir -p dayplanner-$(VERSION)
	cp -r ./`ls|grep -v dayplanner-$(VERSION)` ./.svn ./dayplanner-$(VERSION)
	make -C ./dayplanner-$(VERSION) distclean
	rm -rf `find dayplanner-$(VERSION) -name \\.svn`
	tar -jcf ./packages/dayplanner-$(VERSION).tar.bz2 ./dayplanner-$(VERSION)
	rm -rf dayplanner-$(VERSION)
rpm: prepdistrib tarball rpmonly
rpmonly:
	[ -e ./packages/dayplanner-$(VERSION).tar.bz2 ]
	mkdir -p $$HOME/rpm/SOURCES/ $$HOME/rpm/RPMS/noarch/ $$HOME/rpm/BUILD/ $$HOME/rpm/SRPMS
	cp ./packages/dayplanner-$(VERSION).tar.bz2 $$HOME/rpm/SOURCES/
	cp ./devel-tools/rpm/package.spec ./dayplanner.spec
	perl -pi -e 's#\[DAYPLANNER_VERSION\]#$(VERSION)#gi' ./dayplanner.spec
	rpmbuild --define '_with_unstable 1' --with old_menu --with holidayparser -ba ./dayplanner.spec &> packages/rpmbuild.log
	rm -f packages/rpmbuild.log
	rm -f ./dayplanner.spec
	mv $$HOME/rpm/RPMS/noarch/dayplanner*.rpm $$HOME/rpm/SRPMS/dayplanner*.rpm ./packages/
	rm -f $$HOME/rpm/SOURCES/dayplanner-$(VERSION).tar.bz2
deb: prepdistrib tarball debonly
debonly:
	[ -e ./packages/dayplanner-$(VERSION).tar.bz2 ]
	rm -rf ./dp_deb_tmp
	mkdir -p ./dp_deb_tmp
	(cd dp_deb_tmp; tar -jxvf ../packages/dayplanner-$(VERSION).tar.bz2)
	(cd dp_deb_tmp; cp ../packages/dayplanner-$(VERSION).tar.bz2 ./dayplanner_$(VERSION).orig.tar.bz2)
	(cd dp_deb_tmp; bunzip2 ./dayplanner_$(VERSION).orig.tar.bz2 && gzip ./dayplanner_$(VERSION).orig.tar)
	(if ! grep $(VERSION) ./devel-tools/debian/changelog; then $$EDITOR ./devel-tools/debian/changelog;fi)
	cp -r ./devel-tools/debian ./dp_deb_tmp/dayplanner-$(VERSION)/debian
	(cd dp_deb_tmp/dayplanner-$(VERSION); debuild -i -us -uc -b)
	mv dp_deb_tmp/*deb packages/
	rm -rf dp_deb_tmp
installer: prepdistrib tarball
	tar -jxf ./packages/dayplanner-$(VERSION).tar.bz2
	mkdir -p installer
	mv dayplanner-$(VERSION) installer/dayplanner-data
	cp ./devel-tools/installer/* ./installer
	rm -f installer/InstallLocal
	./installer/dayplanner-data/devel-tools/GenDesktop DAYPLANNER_INST_DIR DAYPLANNER_INST_DIR/art &> /dev/null
	./installer/dayplanner-data/devel-tools/BuildLocale &> /dev/null
	( cd $$HOME/makeself* || cd $$HOME/downloads/makeself* || exit 1; ./makeself.sh --bzip2 --nox11 $$OLDPWD/installer/ dayplanner-$(VERSION).run 'Generic Day Planner installation script' ./StartInstaller &> /dev/null || exit 1; mv ./dayplanner-$(VERSION).run $$OLDPWD/packages )
	rm -f $$HOME/rpm/SOURCES/dayplanner-$(VERSION).tar.bz2
	rm -rf installer

# -- Tests --
test: sanity dpi_test date_holiday

# Verify sanity
sanity:
	@perl -I./modules/DP-GeneralHelpers/lib/ -I ./modules/DP-iCalendar/lib/ -c ./modules/DP-iCalendar/lib/DP/iCalendar/HTTPSubscription.pm
	@perl -I./modules/DP-GeneralHelpers/lib/ -c ./modules/DP-iCalendar/lib/DP/iCalendar/Manager.pm
	@perl -I./modules/DP-GeneralHelpers/lib/ -I ./modules/DP-iCalendar/lib/ -c ./modules/DP-iCalendar/lib/DP/iCalendar/StructHandler.pm
	@perl -I./modules/DP-GeneralHelpers/lib/ -I ./modules/DP-iCalendar/lib/ -c ./modules/DP-iCalendar/lib/DP/iCalendar.pm
	@perl -I./modules/DP-GeneralHelpers/lib/ -c ./modules/DP-GeneralHelpers/lib/DP/GeneralHelpers/IPC.pm
	@perl -I./modules/DP-GeneralHelpers/lib/ -c ./modules/DP-GeneralHelpers/lib/DP/GeneralHelpers/HTTPFetch.pm
	@perl -I./modules/DP-GeneralHelpers/lib/ -c ./modules/DP-GeneralHelpers/lib/DP/GeneralHelpers/I18N.pm
	@perl -I./modules/DP-GeneralHelpers/lib/ -c ./modules/DP-GeneralHelpers/lib/DP/GeneralHelpers.pm
	@perl -I./modules/DP-GeneralHelpers/lib/ -c ./dayplanner
	@perl -I./modules/DP-GeneralHelpers/lib/ -c ./dayplanner-daemon
	@perl -I./modules/DP-GeneralHelpers/lib/ -c ./dayplanner-notifier
	@perl -c ./devel-tools/installer/MainInstallerPart
	@perl -c ./devel-tools/installer/InstallLocal
	@perl -c ./devel-tools/GenDesktop
	@perl -c ./devel-tools/BuildLocale
	@perl -c ./devel-tools/SetVersion
	@perl -c ./devel-tools/postat
	@perl -c ./devel-tools/updatepo
	@perl -c ./services/tools/DPSAdmin
	@perl -c ./services/tools/GenHTML
	@perl -c ./services/dayplanner-services-daemon

# DP::iCalendar tests
dpi_test: sanity
	[ -e ./modules/DP-iCalendar/Makefile ] || (cd ./modules/DP-iCalendar/ && perl Makefile.PL)
	make -C ./modules/DP-iCalendar/ test
# Date::HolidayParser tests
date_holiday: sanity
	[ -e ./modules/Date-HolidayParser/Makefile ] || (cd ./modules/Date-HolidayParser/ && perl Makefile.PL)
	make -C ./modules/Date-HolidayParser/ test
