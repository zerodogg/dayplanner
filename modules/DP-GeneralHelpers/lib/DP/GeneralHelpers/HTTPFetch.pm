#!/usr/bin/perl
# DP::GeneralHelpers::HTTPFetch
# $Id$
# Copyright (C) Eskild Hustvedt 2007, 2008
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either:
# 
#    a) the GNU General Public License as published by the Free
#    Software Foundation; either version 3, or (at your option) any
#    later version, or
#    b) the "Artistic License" which comes with this Kit.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See either
# the GNU General Public License or the Artistic License for more details.
#
# You should have received a copy of the Artistic License
# in the file named "COPYING.artistic".  If not, I'll be glad to provide one.
#
# You should have received a copy of the GNU General Public License
# along with this program in a file named COPYING.gpl. 
# If not, see <http://www.gnu.org/licenses/>.
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
		debugOut("$addy: did not resolve");
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
	if(eval('use LWP;1')) {
		debugOut("Using LWP");
		return($self->_LWPFetch($file,$progress));
	}
	# Okay, LWP isn't available. Check for others
	if(DP::GeneralHelpers::InPath('wget')) {
		debugOut("Using wget");
		return($self->_WgetFetch($file,$progress));
	}
	if(DP::GeneralHelpers::InPath('curl')) {
		debugOut("Using curl");
		return($self->_CurlFetch($file,$progress));
	}
	if(DP::GeneralHelpers::InPath('lynx')) {
		debugOut("Using lynx");
		return($self->_LynxFetch($file,$progress));
	}
	return('NOPROGRAM');
}

# Purpose: Output a debugging message, only displayed when HTTPFETCH_DEBUG=1
# Usage: debgOut(blah);
sub debugOut
{
	if ($ENV{HTTPFETCH_DEBUG} eq '1')
	{
		print " DP::GeneralHelpers::HTTPFetch: Debug: ".$_[0]."\n";
	}
}

# Purpose: Download a file from HTTP using LWP
# Usage: $self->_LWPFetch(FILE,PROGRESS);
sub _LWPFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	my $UserAgent = LWP::UserAgent->new;
	$UserAgent->agent('DP::GeneralHelpers::HTTPFetch//LWP');
	my $content;
	my $content_cb = sub
	{
		$content .= shift;
		if ($progress)
		{
			$progress->('UNKNOWN');
		}
	};

	my $Reply = $UserAgent->get($file,':content_cb' => $content_cb);
	if($Reply->is_success) {
		if ($content)
		{
			return($content)
		}
		else
		{
			return($Reply->content);
		}
	} else {
		debugOut("Failure using LWP - not is_success");
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
		debugOut("Failure using Lynx, ret == $ret");
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
		debugOut("Failure using Curl, ret == $ret");
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
		if(defined($progress)) {
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
		debugOut("Failure using Wget, ret == $ret");
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
