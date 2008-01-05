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
use constant { true => 1, false => 0 };
use strict;
use warnings;
use DP::iCalendar;
use DP::GeneralHelpers::HTTPFetch;

our @ISA = ('DP::iCalendar');

# Purpose: Create a new HTTPSubscription object. Downloads and prepares for you.
# Usage: DP::iCalendar::HTTPSubscription->new(ADDRESS, CALLBACK);
sub new {
	my $name = shift;
	my $tempbless = {};
	bless($tempbless,'DP::iCalendar::HTTPSubscription');
	my $self = $tempbless->_NewObj();
	bless($self,'DP::iCalendar::HTTPSubscription');
	$self->{HTTP_address} = shift;
	$self->{HTTP_callback} = shift;
	$self->{HTTP_data} = '';
	$self->{HTTP_UPD_RET} = false;
	
	# Do the actual adding
	$self->update();
	return($self);
}

# Purpose: Update the calendar
# Usage: object->update();
sub update {
	my $self = shift;
	$self->{HTTP_data} = DP::GeneralHelpers::HTTPFetch->get($self->{HTTP_address},$self->{HTTP_callback});

	my %ErrorInformation = (
		NORESOLVE => "Unable to resolve the address",
		NOPROGRAM => "Unable to detect any program to use for downloading",
		FAIL => "Unknown failure",
	);
	# Check for errors
	if($ErrorInformation{$self->{HTTP_data}}) {
			print " DP::iCalendar::HTTPSubscription: Unable to download icalendar file: $ErrorInformation{$self->{HTTP_data}}\n";
			$self->{HTTP_UPD_RET} = $ErrorInformation{$self->{HTTP_data}};
			return(false);
	}

	my @Array;
	$self->{HTTP_data} =~ s/\r//g;
	push(@Array, $_) foreach(split(/\n/,$self->{HTTP_data}));
	$self->addfile(\@Array);
	$self->{HTTP_UPD_RET} = false;

	return(true);
}

# Purpose: Check if the update succeeded or not. This will be FALSE when no error occurred, true
# 			with the DP::GeneralHelpers::HTTPFetch error value if not.
# Usage: object->update_error();
sub update_error
{
	return($self->{HTTP_UPD_RET});
}
1;
