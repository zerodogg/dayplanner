#!/usr/bin/perl
# DP::GeneralHelpers::HTTPFetch
# $Id$
# Copyright (C) Eskild Hustvedt 2007
#
# This program is free software; you can redistribute it and/or modify it
# under the same terms as Perl itself. There is NO warranty;
# not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
package DP::GeneralHelpers::HTTPFetch;
use IPC::Open3;
use POSIX;
use Socket;
use DP::GeneralHelpers;

# Purpose: Download a file from HTTP (other protocols might also work, but there are
# 		no guarantees for that)
# Usage: my $Data = DP::GeneralHelpers::HTTPFetch->get("URL",$ProgressCallback);
# 	Progresscallback is a function that can recieve values in order to run
# 	a progress window. It can also be undef.
# 	If not undef then the function referenced will recieve either a vlue from
# 	1-100, which is the percentage completed, or the string UNKOWN.
# 	UNKNOWN means that the download has progressed, but it is not known how
# 	much is left.
sub get {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	# First we try to resolve the IP. If this fails we just
	# error out.
	my $addy = $file;
	$addy =~ s#^\w+://##;
	$addy =~ s#^([^/]+)/.*#$1#;
	my $resolved = inet_ntoa(inet_aton($addy));
	if(not $resolved) {
		return('NORESOLVE');
	}

	if($ENV{DP_HTTP_FORCEUSEOF}) {
		if($ENV{DP_HTTP_FORCEUSEOF} =~ /^(LWP|wget|curl|lynx)/i)
		{
			if($ENV{DP_HTTP_FORCEUSEOF} =~ /LWP/i) {
				if(eval("use LWP;")) {
					return($self->_LWPFetch($file));
				}
			} elsif($ENV{DP_HTTP_FOCEUSEOF} =~ /wget/i) {
				if(DP::GeneralHelpers::InPath('wget')) {
					return($self->_WgetFetch($file));
				}
			} elsif($ENV{DP_HTTP_FORCEUSEOF} =~ /curl/i) {

				if(DP::GeneralHelpers::InPath('curl')) {
					return($self->_CurlFetch($file));
				}
			} elsif($ENV{DP_HTTP_FORCEUSEOF} =~ /lynx/i) {
				if(DP::GeneralHelpers::InPath('lynx')) {
					return($self->_LynxFetch($file));
				}
			}
			warn("DP_HTTP_FORCEUSEOF: $ENV{DP_HTTP_FORCEUSEOF}: Not available, falling back to automatic detection\n");
		} else {
			warn("DP_HTTP_FORCEUSEOF: $ENV{DP_HTTP_FORCEUSEOF}: Invalid setting, must be one of LWP, wget, curl, lynx\n");
		}
	}

	# First try LWP
	if(eval("use LWP;")) {
		return($self->_LWPFetch($file));
	}
	# Okay, LWP isn't available. Check for others
	if(DP::GeneralHelpers::InPath('wget')) {
		return($self->_WgetFetch($file));
	}
	if(DP::GeneralHelpers::InPath('curl')) {
		return($self->_CurlFetch($file));
	}
	if(DP::GeneralHelpers::InPath('lynx')) {
		return($self->_LynxFetch($file));
	}
	return('NOPROGRAM');
}

# Purpose: Download a file from HTTP using LWP
# Usage: $self->_LWPFetch(FILE,PROGRESS);
sub _LWPFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	my $UserAgent = LWP::UserAgent->new;
	$UserAgent->agent('DP::GeneralHelpers::HTTPFetch//LWP');

	my $Request = HTTP::Request->new(GET => $file);
	my $Reply = $UserAgent->request($Request);
	if($Reply->is_success) {
		return($Reply->content);
	} else {
		return('FAILED');
	}
}

# Purpose: Download a file from HTTP using lynx.
# Usage: $self->_LynxFetch(FILE,PROGRESS);
sub _LynxFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	# Have lynx output the file to STDOUT and read from that.
	# Ignore STDERR
	my ($in, $out, $err);
	my $ChildPID = open3($in,$out,$err,'lynx','-useragent=DP::GeneralHelpers::HTTPFetch//lynx','-source',$file);
	my $output;
	while($output .= <$out> and not eof($out)) {
		if($progress) {
			$progress->('UNKNOWN');
		}
	}
	close($in) if($in);
	close($out) if($out);
	close($err) if($err);
	waitpid($ChildPID,WNOHANG);
	my $ret = $? >> 8;
	if($ret == 0) {
		return($output);
	} else {
		return('FAIL');
	}
}

# Purpose: Download a file from HTTP using curl.
# Usage: $self->_CurlFetch(FILE,PROGRESS);
sub _CurlFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	# Have curl output the file to STDOUT and read from that.
	# Ignore STDERR
	my ($in, $out, $err);
	my $ChildPID = open3($in,$out,$err,'curl','--user-agent','DP::GeneralHelpers::HTTPFetch//curl','--fail','--location','--silent',$file);
	my $output;
	while($output .= <$out> and not eof($out)) {
		if($progress) {
			$progress->('UNKNOWN');
		}
	}
	close($in) if($in);
	close($out) if($out);
	close($err) if($err);
	waitpid($ChildPID,WNOHANG);
	my $ret = $? >> 8;
	if($ret == 0) {
		return($output);
	} else {
		return('FAIL');
	}
}

# Purpose: Download a file from HTTP using wget.
# Usage: $self->_WgetFetch(FILE,PROGRESS);
sub _WgetFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	# Have wget output the file to STDOUT and read from that. Ignore
	# STDERR.
	my ($in, $out, $err);
	my $ChildPID = open3($in,$out,$err,'wget','--user-agent','DP::GeneralHelpers::HTTPFetch//wget','--quiet','-O','-',$file);
	my $output;
	while($output .= <$out> and not eof($out)) {
		if($progress) {
			$progress->('UNKNOWN');
		}
	}
	close($in) if($in);
	close($out) if($out);
	close($err) if($err);
	waitpid($ChildPID,WNOHANG);
	my $ret = $? >> 8;
	if($ret == 0) {
		return($output);
	} else {
		return('FAIL');
	}
}

1;
__END__

=head1 NAME

DP::GeneralHelpers::HTTPFetch - A simple perl module for fetching data from HTTP

=head1 SYNOPSIS

  use DP::GeneralHelpers;
  my $data = DP::GeneralHelpers::HTTPFetch->get("http://www.day-planner.org/");

=head1 DESCRIPTION

This module helps you fetch data from any HTTP server.
It uses LWP, curl, wget or lynx for the actual fetching.

=head1 FUNCTIONS

=head2 my $content = DP::GeneralHelpers::HTTPFetch->get("URL",Callback);

This function will download URL and return the data. It will also call
callback for progress updates. Callback is optional.

If callback is present then it will be called at random intervals whenever
the download has progressed. It will either be called with a numerical value
between 1-100 (the percentage completed) or the string value UNKNOWN. UNKOWN means
that it has progressed but that it does not know how much is left.

It can return NORESOLVE if the address doesn't resolve (ie. machine is offline,
URL is not valid). Return NOPROGRAM if no downloader is available (this will
be very rare, but can happen). Return FAIL if the download failed for some
other reason. If none of the above is returned then the data downloaded is returned.

=head2 EXPORT

Nothing.

=head1 SEE ALSO

wget(1), curl(1), lynx(1), LWP, LWP::Simple

=head1 AUTHOR

Eskild Hustvedt - C<< <zerodogg@cpan.org> >>

=head1 LICENSE AND COPYRIGHT

Copyright (C) 2006, 2007 Eskild Hustvedt, all rights reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself. There is NO warranty;
not even for MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
=cut
