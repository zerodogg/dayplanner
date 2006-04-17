%define	name	dayplanner
%define	version 0.1
%define rel	1
%define	release	%mkrel %rel

Name:		%{name} 
Summary:	An easy and clean day planner
Version:	%{version} 
Release:	%{release} 
Source0:	%{name}-%{version}.tar.bz2
URL:		http://home.gna.org/dayplanner/
Group:		Office
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-buildroot
License:	GPL
BuildRequires:	perl

%description
DESCRIPTION

%package tools
Summary: BLAH
Group: Junk
Requires: dayplanner

%description tools
DESCRIPTION

%prep
%setup -q

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_bindir}/

# Install the binaries
for a in dayplanner dayplanner-daemon dayplanner-notifier; do
	install -m755 $a $RPM_BUILD_ROOT%{_bindir}/
done
install -m755 ./tools/commander $RPM_BUILD_ROOT%{_bindir}/dayplanner-commander
install -m755 ./tools/plan-migration $RPM_BUILD_ROOT%{_bindir}/dayplanner-plan-migration

mkdir -p $RPM_BUILD_ROOT%{_datadir}/%name/
install -m644 ./art/dayplanner-about.png $RPM_BUILD_ROOT%{_datadir}/%name/

# Install the icons
install -m644 ./art/dayplanner_24.png -D $RPM_BUILD_ROOT%{_iconsdir}/dayplanner.png
install -m644 ./art/dayplanner_16.png -D $RPM_BUILD_ROOT%{_miconsdir}/dayplanner.png
install -m644 ./art/dayplanner_48.png -D $RPM_BUILD_ROOT%{_liconsdir}/dayplanner.png
# (High contrast versions)
install -m644 ./art/dayplanner_HC24.png -D $RPM_BUILD_ROOT%{_iconsdir}/dayplanner_HC.png
install -m644 ./art/dayplanner_HC16.png -D $RPM_BUILD_ROOT%{_miconsdir}/dayplanner_HC.png
install -m644 ./art/dayplanner_HC48.png -D $RPM_BUILD_ROOT%{_liconsdir}/dayplanner_HC.png

# Menu
mkdir -p $RPM_BUILD_ROOT%{_menudir}
cat << EOF > $RPM_BUILD_ROOT%{_menudir}/%{name}
?package(%{name}):command="%{_bindir}/dayplanner" \
	icon="dayplanner.png" \
	needs="x11" \
	section="Office/Time Management" \
	title="Day planner" \
	longtitle="An easy to use graphical day planner"
EOF

%post
%{update_menus}

%postun
%{clean_menus}

%clean 
rm -rf $RPM_BUILD_ROOT 

%files 
# Note to packagers: Please leave COPYING in here as this package is distributed
#  from the software website aswell
%defattr(-,root,root)
%doc AUTHORS COPYING NEWS THANKS TODO
%{_bindir}/dayplanner
%{_bindir}/dayplanner-daemon
%{_bindir}/dayplanner-notifier
%{_datadir}/%name/
%{_iconsdir}/dayplanner*.png
%{_miconsdir}/dayplanner*.png
%{_liconsdir}/dayplanner*.png
%{_menudir}/%{name}

%files tools
%{_bindir}/dayplanner-commander
%{_bindir}/dayplanner-plan-migration
