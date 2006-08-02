%define include_holidayparser 0
%{?_with_holidayparser: %{expand: %%global include_holidayparser 1}}

%define	name	dayplanner
%define	version [DAYPLANNER_VERSION]
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
BuildArch:	noarch

%description
Day planner is a simple time management program.

Day planner is designed to help you easily manage your time.
It can manage appointments, birthdays and more. It makes sure you
remember your appointments by popping up a dialog box reminding you about it.

%if %include_holidayparser
This package also includes the Date::HolidayParser perl module
%endif

%package tools
Summary: Various tools for use with day planner
Group: Office
Requires: dayplanner

%description tools
This package contains various tools for use with day planner:

dayplanner-commander     : Send raw commands to the day planner daemon

%prep
%setup -q

%install
rm -rf $RPM_BUILD_ROOT
mkdir -p $RPM_BUILD_ROOT%{_bindir}/
mkdir -p $RPM_BUILD_ROOT%{_datadir}/%name/

# Install the binaries
for a in dayplanner dayplanner-daemon dayplanner-notifier; do
	install -m755 $a $RPM_BUILD_ROOT%{_datadir}/%name/
	ln -s %{_datadir}/%name/$a $RPM_BUILD_ROOT%{_bindir}/
done
install -m755 ./tools/commander $RPM_BUILD_ROOT%{_bindir}/dayplanner-commander

install -m644 ./art/dayplanner-about.png $RPM_BUILD_ROOT%{_datadir}/%name/

# Install Date::HolidayParser if needed
%if %include_holidayparser
mkdir -p $RPM_BUILD_ROOT%{_datadir}/%name/modules/Date-HolidayParser/lib/
cp -r ./modules/Date-HolidayParser/lib/* $RPM_BUILD_ROOT%{_datadir}/%name/modules/Date-HolidayParser/lib/
%endif

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

./devel-tools/BuildLocale $RPM_BUILD_ROOT/%{_datadir}/locale/

# Find the localization
%find_lang %{name}

%post 
%{update_menus}

%postun
%{clean_menus}

%clean 
rm -rf $RPM_BUILD_ROOT 

%files -f dayplanner.lang
# Note to packagers: Please leave COPYING in here as this package is distributed
#  from the software website aswell
%defattr(-,root,root)
%doc AUTHORS COPYING NEWS THANKS TODO ./doc/*
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
