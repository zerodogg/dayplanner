# Makefile for Day Planner
# Copyright (C) Eskild Hustvedt 2007, 2008, 2009
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

PLUGINPREP=$(shell perl -e 'if(-d "./.git" ) { print "pluginprep" } elsif (not glob("./plugins/*.dpi")) { print "pluginprep" }')

# If prefix is already set then use some distro-friendly install rules
ifdef prefix
INSTALLRULES=maininstall maninstall moduleinstall plugininstall artinstall i18ninstall distribdesktop
else
# If not then use some user-friendly install rules
INSTALLRULES=deps maininstall maninstall moduleinstall plugininstall artinstall nice_i18ninstall desktop essentialdocs
# This little trick ensures that make install will succeed both for a local
# user and for root. It will also succeed for distro installs as long as
# prefix is set by the builder.
prefix=$(shell perl -e 'if($$< == 0 or $$> == 0) { print "/usr" } else { print "$$ENV{HOME}/.local"}')
endif

# The package to build with distrib
PKG=$(shell if which debuild 2>/dev/null >/dev/null; then echo deb; else echo rpm;fi)

# If this file does not exist it means manpages aren't built. So build them.
MANPAGES=$(shell [ ! -e ./dayplanner.1 ] && echo man)

VERSION=0.12
DP_DATADIR ?= dayplanner
BINDIR ?= bin
DATADIR ?= $(prefix)/share
LOCALMODULES=-I./modules/DP-iCalendar/lib/ -I./modules/dayplanner/ -I./modules/external/

# So I have to type less
DP_MAINTARGET = $(DESTDIR)$(DATADIR)/$(DP_DATADIR)

# Set these so that it can be overridden by the calld if needed
CP ?= cp

# Silencing perl helper
BESILENT = perl -e "open(STDIN,'<','/dev/null'); open(STDOUT,'>','/dev/null'); exec(@ARGV);"

# --- USER USABLE RULES ---
help:
	@echo "User targets:"
	@echo " install      - install Day Planner"
	@echo " uninstall    - uninstall a previously installed Day Planner"
	@-[ -e "./.git" ] && echo " localinstall - install symlinks and .desktop files to use the current git checkout";true
	@echo " deps         - install Day Planner dependencies to ./modules/external"
	@echo "Advanced targets:"
	@echo " clean        - clean up the tree"
	@echo " updatepo     - update po-files"
	@echo " mo           - build the locale/ tree"
	@echo " pluginprep   - build plugin metafiles"
	@echo "Developer targets:"
	@echo " distrib      - create packages (tarball, installer and rpm)"
	@echo " tarball      - create tarball"
	@echo " installer    - create tarball and installer"
	@echo " rpm          - create tarball and rpm"
	@echo " test         - run automated tests"

install: $(MANPAGES) $(INSTALLRULES)

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
	rm -rf ./dp_deb_tmp
	rm -f ./plugins/*dpi
	rm -f po/*.mo po/*.pot
	rm -rf po/locale packages locale dayplanner-$(VERSION) installer
	rm -f dayplanner.spec $$HOME/rpm/SOURCES/dayplanner-$(VERSION).tar.bz2
	[ ! -e ./modules/DP-iCalendar/Makefile ] || make -C ./modules/DP-iCalendar/ distclean
distclean: clean
	rm -rf ./external
	git clean -fd
	rm -f ./dayplanner-daemon.1 ./dayplanner-notifier.1 ./dayplanner.1
	rm -f doc/dayplanner.desktop


# Create manpages
man:
	pod2man --name "Day Planner" --center "" --release "Day Planner $(VERSION)" ./dayplanner ./dayplanner.1
	pod2man --name "Day Planner Daemon" --center "" --release "Day Planner $(VERSION)" ./dayplanner-daemon ./dayplanner-daemon.1
	pod2man --name "Day Planner" --center "" --release "Day Planner Notifier $(VERSION)" ./dayplanner-notifier ./dayplanner-notifier.1
# Install manpages
maninstall:
	mkdir -p "$(DESTDIR)$(DATADIR)/man/man1"
	$(CP) -f dayplanner.1 dayplanner-daemon.1 dayplanner-notifier.1 "$(DESTDIR)$(DATADIR)/man/man1" 

# --- Dependency fetching ---

CPANM=cpanm --notest --quiet --force --reinstall -l ./modules/external
DEPS=Date::HolidayParser Moo
PERL_ARCH=$(shell perl -V|grep archname=|head -n1|perl -pi -e 's/.*archname=//';)
deps:
	rm -rf ./modules/external
	$(CPANM) $(DEPS)
	rm -rf modules/external/lib/perl5/Test
	-mv modules/external/lib/perl5/$(PERL_ARCH)/* modules/external/
	-mv modules/external/lib/perl5/* modules/external/
	rm -rf modules/external/lib modules/external/man modules/external/auto modules/external/Test modules/external/$(PERL_ARCH)
	find modules/external -iname '*.pod' -print0 |xargs -0 rm -f
deps_dhp: DEPS=Date::HolidayParser
deps_dhp: deps

# --- INTERNAL RULES ---

# - Install rules -

# This is a 'nice' i18n installer, it won't kill the install even if it fails.
nice_i18ninstall:
	rm -rf locale
	mkdir locale
	perl ./devel-tools/BuildLocale || true
	$(CP) -r locale $(DESTDIR)$(DATADIR)

# This is the normal one, it will die if it fails and it won't create additional
# symlinks
i18ninstall:
	rm -rf locale
	mkdir locale
	perl ./devel-tools/BuildLocale ./locale
	$(CP) -r locale $(DESTDIR)$(DATADIR)

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
	mkdir -p "$(DP_MAINTARGET)/modules/"
	cp -r ./modules/* "$(DP_MAINTARGET)/modules/"

# Plugin prep
pluginprep:
	for file in $(shell ls ./plugins/*pm|egrep -v '(PluginManager|HelloWorld)') ; do ./devel-tools/plugin_mkmetafile $$file;done
# Plugin installation
plugininstall: $(PLUGINPREP)
	mkdir -p $(DP_MAINTARGET)/plugins
	install -m644 $(shell ls ./plugins/*pm) $(DP_MAINTARGET)/plugins
	install -m644 $(shell ls ./plugins/*dpi) $(DP_MAINTARGET)/plugins

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
distribdesktop: gendistribdesktop
	mkdir -p $(DESTDIR)$(DATADIR)/applications
	install -m644 ./doc/dayplanner.desktop $(DESTDIR)$(DATADIR)/applications
# Gen distrib desktop file
gendistribdesktop:
	./devel-tools/GenDesktop .
# --- DISTRIB TARGETS ---
distrib: prepdistrib tarball $(PKG) installer 
simpledistrib: prepdistrib tarball installer 
prepdistrib: gendistribdesktop test clean pluginprep
	mkdir -p packages
tarball: prepdistrib
	mkdir -p dayplanner-$(VERSION)
	$(CP) -r ./`ls|grep -v dayplanner-$(VERSION)` ./.git ./dayplanner-$(VERSION)
	make -C ./dayplanner-$(VERSION) distclean man pluginprep
	rm -rf ./dayplanner-$(VERSION)/devel-tools/rpm ./dayplanner-$(VERSION)/devel-tools/debian
	rm -rf ./dayplanner-$(VERSION)/.git
	tar -jcf ./packages/dayplanner-$(VERSION).tar.bz2 ./dayplanner-$(VERSION)
	rm -rf dayplanner-$(VERSION)
rpm: prepdistrib tarball rpmonly
rpmonly:
	[ -e ./packages/dayplanner-$(VERSION).tar.bz2 ]
	mkdir -p $$HOME/rpm/SOURCES/ $$HOME/rpm/RPMS/noarch/ $$HOME/rpm/BUILD/ $$HOME/rpm/SRPMS
	$(CP) ./packages/dayplanner-$(VERSION).tar.bz2 $$HOME/rpm/SOURCES/
	$(CP) ./devel-tools/rpm/package.spec ./dayplanner.spec
	perl -pi -e 's#\[DAYPLANNER_VERSION\]#$(VERSION)#gi' ./dayplanner.spec
	$(BESILENT) rpmbuild --define '_with_unstable 1' --with old_menu -ba ./dayplanner.spec
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
	(cd dp_deb_tmp; $(CP) ../packages/dayplanner-$(VERSION).tar.bz2 ./dayplanner_$(VERSION).orig.tar.bz2)
	(cd dp_deb_tmp; bunzip2 ./dayplanner_$(VERSION).orig.tar.bz2 && gzip ./dayplanner_$(VERSION).orig.tar)
	(if ! grep $(VERSION) ./devel-tools/debian/changelog; then $$EDITOR ./devel-tools/debian/changelog;fi)
	$(CP) -r ./devel-tools/debian ./dp_deb_tmp/dayplanner-$(VERSION)/debian
	(cd dp_deb_tmp/dayplanner-$(VERSION); debuild -i -us -uc -b)
	mv dp_deb_tmp/*deb packages/
	rm -rf dp_deb_tmp
installer: prepdistrib tarball
	tar -jxf ./packages/dayplanner-$(VERSION).tar.bz2
	mkdir -p installer
	mv dayplanner-$(VERSION) installer/dayplanner-data
	make -C installer/dayplanner-data deps
	$(CP) ./devel-tools/installer/* ./installer
	rm -f installer/InstallLocal
	$(BESILENT) ./installer/dayplanner-data/devel-tools/GenDesktop DAYPLANNER_INST_DIR DAYPLANNER_INST_DIR/art
	$(BESILENT) ./installer/dayplanner-data/devel-tools/BuildLocale
	( cd $$HOME/makeself* || cd $$HOME/downloads/makeself* || exit 1; $(BESILENT) ./makeself.sh --bzip2 --nox11 $$OLDPWD/installer/ dayplanner-$(VERSION).run 'Generic Day Planner installation script' ./StartInstaller || exit 1; mv ./dayplanner-$(VERSION).run $$OLDPWD/packages )
	rm -f $$HOME/rpm/SOURCES/dayplanner-$(VERSION).tar.bz2
	rm -rf installer

# -- Tests --
test: sanity dpi_test

# Verify sanity
sanity:
	@perl $(LOCALMODULES) -c ./modules/DP-iCalendar/lib/DP/iCalendar/HTTPSubscription.pm
	@perl $(LOCALMODULES) -c ./modules/DP-iCalendar/lib/DP/iCalendar/WebExp.pm
	@perl $(LOCALMODULES) -c ./modules/DP-iCalendar/lib/DP/iCalendar/Manager.pm
	@perl $(LOCALMODULES) -c ./modules/DP-iCalendar/lib/DP/iCalendar/StructHandler.pm
	@perl $(LOCALMODULES) -c ./modules/DP-iCalendar/lib/DP/iCalendar.pm
	@perl $(LOCALMODULES) -c ./modules/dayplanner/DP/GeneralHelpers/IPC.pm
	@perl $(LOCALMODULES) -c ./modules/dayplanner/DP/GeneralHelpers/HTTPFetch.pm
	@perl $(LOCALMODULES) -c ./modules/dayplanner/DP/GeneralHelpers/I18N.pm
	@perl $(LOCALMODULES) -c ./modules/dayplanner/DP/GeneralHelpers.pm
	@perl $(LOCALMODULES) -c ./modules/dayplanner/DP/CoreModules.pm
	@perl $(LOCALMODULES) -c ./modules/dayplanner/DP/CoreModules/Plugin.pm
	@perl $(LOCALMODULES) -c ./modules/dayplanner/DP/CoreModules/PluginFunctions.pm
	@perl $(LOCALMODULES) -c ./dayplanner
	@perl $(LOCALMODULES) -c ./dayplanner-daemon
	@perl $(LOCALMODULES) -c ./dayplanner-notifier
	@perl $(LOCALMODULES) -c ./plugins/HelloWorld.pm
	@perl $(LOCALMODULES) -c ./plugins/PluginManager.pm
	@perl $(LOCALMODULES) -c ./plugins/ServicesSync.pm
	@perl $(LOCALMODULES) -c ./plugins/TrayIcon.pm
	@perl $(LOCALMODULES) -c ./devel-tools/plugin_mkmetafile
	@perl $(LOCALMODULES) -c ./devel-tools/plugin_package
	@perl $(LOCALMODULES) -c ./devel-tools/installer/MainInstallerPart
	@perl $(LOCALMODULES) -c ./devel-tools/installer/InstallLocal
	@perl $(LOCALMODULES) -c ./devel-tools/GenDesktop
	@perl $(LOCALMODULES) -c ./devel-tools/BuildLocale
	@perl $(LOCALMODULES) -c ./devel-tools/SetVersion
	@perl $(LOCALMODULES) -c ./devel-tools/postat
	@perl $(LOCALMODULES) -c ./devel-tools/updatepo
	@perl $(LOCALMODULES) -c ./services/tools/DPSAdmin
	@perl $(LOCALMODULES) -c ./services/tools/GenHTML
	@perl $(LOCALMODULES) -c ./services/dayplanner-services-daemon

# DP::iCalendar tests
dpi_test: sanity
	[ -e ./modules/DP-iCalendar/Makefile ] || (cd ./modules/DP-iCalendar/ && perl Makefile.PL)
	make -C ./modules/DP-iCalendar/ test
