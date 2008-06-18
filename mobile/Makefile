# Makefile for Day Planner, mobile version
# Copyright (C) Eskild Hustvedt 2008
# $Id: Makefile 2247 2008-06-06 11:30:32Z zero_dogg $
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

VERSION=0.10

clean:
	rm -f *~
	rm -rf packages dayplanner-mobile-$(VERSION)
test:
	make -C .. test
mo:
	make -C .. mo
updatepo:
	make -C .. updatepo
distrib: tarball singlefile
tarball:
	mkdir -p packages
	mkdir -p dayplanner-mobile-$(VERSION)
	cp mobile-dp-gui.py dayplanner-data-servant README README.FIRST Makefile ./dayplanner-mobile-$(VERSION)
	cp -r ../holiday ../po ../modules ../NEWS ../COPYING ../AUTHORS ../THANKS ../TODO ./dayplanner-mobile-$(VERSION)
	rm -rf `find dayplanner-mobile-$(VERSION) -name \\.svn`
	tar -jcf ./packages/dayplanner-mobile-$(VERSION).tar.bz2 ./dayplanner-mobile-$(VERSION)
	rm -rf dayplanner-mobile-$(VERSION)
# This creates a single file executable that one can run to get a
# Day Planner mobile version without installing it. Useful for testing.
singlefile: tarball
	mkdir -p packages
	tar -jxvf packages/dayplanner-mobile-$(VERSION).tar.bz2
	( cd $$HOME/makeself* || cd $$HOME/downloads/makeself* || exit 1; ./makeself.sh --bzip2 --nox11 $$OLDPWD/dayplanner-mobile-$(VERSION) dayplanner-mobile-single-$(VERSION).run 'Day Planner mobile standalone single-executeable' ./mobile-dp-gui.py &> /dev/null || exit 1; mv ./dayplanner-mobile-single-$(VERSION).run $$OLDPWD/packages )
	rm -rf dayplanner-mobile-$(VERSION)
