# DP::iCalendar::HTTPSubscription
# $Id: iCalendar.pm 1615 2007-08-10 17:58:24Z zero_dogg $
# An wrapper around DP::iCalendar that allows subscriptions to iCalendar calendars
# via the internet.
# Copyright (C) Eskild Hustvedt 2007
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

package DP::iCalendar::HTTPSubscription;
use constant { TRUE => 1, FALSE => 0 };

my $DPI_API_Version = '1Alpha';

# Usage: DP::iCalendar::HTTPSubscription->new(ADDRESS, DP::ICALENDAR_OBJECT, CALLBACK);
sub new {
	my $self = shift;
	$self = {};
	bless($self);
	$self->{address} = shift;
	$self->{DPI} = shift;
	$self->{callback} = shift;

	if(not $self->{DPI}->API_Call('REGISTER', { OBJECT => $self, VERSION => $DPI_API_Version })) {
		return(FALSE);
	}

	$self->{private_DPI} = DP::iCalendar->new([]);
	
	# Do the actual adding
	$self->update();
	return($self);
}

sub update {
	$self->{data} = DP::GeneralHelpers::HTTPFetch->get($self->{address},$self->{callback});

	my %ErrorInformation = (
		NORESOLVE => "Unable to resolve the address",
		NOPROGRAM => "Unable to detect any program to use for downloading",
		FAIL => "Unknown failure",
	);
	# Check for errors
	foreach(keys(%ErrorInformation)) {
		if($self->{data} eq $_) {
			print " DP::iCalendar::HTTPSubscription: Unable to download icalendar file: $ErrorInformation{$_}\n";
			return(FALSE);
		}
	}

	# Clean the objects
	$self->{private_DPI}->clean();
	$self->{DPI}->API_Call('RECALCULATE',{});
	# We call private DPI functions since technically we are part of DPI
	my $arrayref = $self->{private_DPI}->_ParseData($self->{data});
	$self->{private_DPI}->addfile($arrayref);

	foreach my $href (keys(%{$self->{private_DPI}->{RawCalendar}})) {
		$href->{'DP-iCalendar-PluggedinUID'} = 1;
		$self->API_Call
	}

	return(TRUE);
}
1;
