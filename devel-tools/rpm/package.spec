%define _requires_exceptions perl\(DP::CoreModules\)
%define	name	dayplanner
%define	version [DAYPLANNER_VERSION]
%define rel	1
%define	release	%mkrel %rel

Name:		%{name} 
Summary:	An easy and clean Day Planner
Version:	%{version} 
Release:	%{release} 
Source0:	http://download.gna.org/dayplanner/%{name}-%{version}.tar.bz2
URL:		http://www.day-planner.org/
Group:		Office
BuildRoot:	%{_tmppath}/%{name}-%{version}-%{release}-buildroot
License:	GPLv3+
BuildRequires:	perl
BuildArch:	noarch

%description
Day Planner is a simple time management program.

Day Planner is designed to help you easily manage your time.
It can manage appointments, birthdays and more. It makes sure you
remember your appointments by popping up a dialog box reminding you about it.

%prep
%setup -q

%install
rm -rf $RPM_BUILD_ROOT

%makeinstall_std prefix=/sur

# Install the icons
install -m644 ./art/dayplanner-24x24.png -D $RPM_BUILD_ROOT%{_iconsdir}/dayplanner.png
install -m644 ./art/dayplanner-16x16.png -D $RPM_BUILD_ROOT%{_miconsdir}/dayplanner.png
install -m644 ./art/dayplanner-48x48.png -D $RPM_BUILD_ROOT%{_liconsdir}/dayplanner.png
# (High contrast icons)
install -m644 ./art/dayplanner_HC24.png -D $RPM_BUILD_ROOT%{_iconsdir}/dayplanner_HC.png
install -m644 ./art/dayplanner_HC16.png -D $RPM_BUILD_ROOT%{_miconsdir}/dayplanner_HC.png
install -m644 ./art/dayplanner_HC48.png -D $RPM_BUILD_ROOT%{_liconsdir}/dayplanner_HC.png

# Find the localization
%find_lang %{name}

%if %mdkversion < 200900
%post 
%{update_menus}
%endif

%if %mdkversion < 200900
%postun
%{clean_menus}
%endif

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
%{_datadir}/man/man1/*
%{_iconsdir}/dayplanner*.png
%{_miconsdir}/dayplanner*.png
%{_liconsdir}/dayplanner*.png
%{_datadir}/applications/%{name}.desktop
%{_datadir}/pixmaps/%{name}.png
