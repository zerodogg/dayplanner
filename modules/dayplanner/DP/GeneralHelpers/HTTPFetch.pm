#!/usr/bin/perl
# DP::GeneralHelpers::HTTPFetch
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
use DP::GeneralHelpers qw(InPath);

# Purpose: Download a file from HTTP (other protocols might also work, but there are
# 		no guarantees for that)
# Usage: my $Data = DP::GeneralHelpers::HTTPFetch->get("URL",$ProgressCallback);
# 	Progresscallback is a function that can recieve values in order to run
# 	a progress window. It can also be undef.
# 	If not undef then the function referenced will recieve either a value from
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
		if($ENV{DP_HTTP_FORCEUSEOF} =~ /^(LWP|wget|curl|lynx|elinks|dummy)/i)
		{
			debugOut("DP_HTTP_FORCEUSEOF=$ENV{DP_HTTP_FORCEUSEOF}");
			my $ret = $self->_TryInterface($ENV{DP_HTTP_FORCEUSEOF},$file,$progress);
			if(defined($ret))
			{
				return($ret);
			}
			warn("DP_HTTP_FORCEUSEOF: $ENV{DP_HTTP_FORCEUSEOF}: Not available, falling back to automatic detection\n");
		} else {
			warn("DP_HTTP_FORCEUSEOF: $ENV{DP_HTTP_FORCEUSEOF}: Invalid setting, must be one of LWP, wget, curl, lynx\n");
		}
	}

	foreach my $i (qw(LWP wget curl lynx elinks))
	{
		my $ret = $self->_TryInterface($i,$file,$progress);
		if(defined($ret))
		{
			return($ret);
		}
	}
	debugOut("No program detected. What an odd system.");
	return('NOPROGRAM');
}

# Purpose: Try to use the interface specified for file+progress
# Usage: this->_TryInterface(INTERFACE,file,progress);
sub _TryInterface
{
	my $self = shift;
	my $interface = shift;
	my $file = shift;
	my $progress = shift;

	if ($interface eq 'LWP' && eval('use LWP;1'))
	{
		debugOut("Using LWP");
		return($self->_LWPFetch($file,$progress));
	}
	elsif($interface eq 'wget' && InPath('wget'))
	{
		debugOut("Using wget");
		return($self->_WgetFetch($file,$progress));
	}
	elsif($interface eq 'curl' && InPath('curl'))
	{
		debugOut("Using curl");
		return($self->_CurlFetch($file,$progress));
	}
	elsif($interface eq 'lynx' && InPath('lynx'))
	{
		debugOut("Using lynx");
		return($self->_LynxFetch($file,$progress));
	}
	elsif($interface eq 'elinks' && InPath('elinks'))
	{
		debugOut("Using elinks");
		return($self->_eLinksFetch($file,$progress));
	}
	elsif($interface =~ /^dummy/)
	{
		if ($interface =~ /noresolve/i)
		{
			return('NORESOLVE');
		}
		elsif ($interface =~ /fail/i)
		{
			return('FAIL');
		}
		else
		{
			return('NOPROGRAM');
		}
	}
	return(undef);
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
		return('FAIL');
	}
}

# Purpose: Download a file using a command
# Usage: $self->_FetchFileCMD(PROGRESS,COMMAND);
sub _FetchFileCMD
{
	my $self = shift;
	my $progress = shift;
	my $cmd = $_[0];

	my ($in, $out, $err);
	my $ChildPID = open3($in,$out,$err,@_);
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
	my $ret = $?;
	if ($ret == -1)
	{
		my $err = $!;
		# Generally only means it worked, but it exited. Assume this if length > 100
		if(length($output) > 100)
		{
			$ret = 0;
		}
		else
		{
			print " DP::GeneralHelpers::HTTPFetch: Odd error from $cmd: ret was -1: $!\n";
			return('FAIL');
		}
	}
	if($ret == 0) {
		return($output);
	} else {
		$ret = $ret >> 8;
		debugOut("Failure using $cmd, ret == $ret");
		if (defined($ENV{HTTPFETCH_DEBUG_RETONE}))
		{
			debugOut("Contents: $output");
		}
		return('FAIL');
	}
}

# Purpose: Download a file from HTTP using elinks.
# Usage: $self->_eLinksFetch(FILE,PROGRESS);
sub _eLinksFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	return($self->_FetchFileCMD($progress,'elinks','-eval',"set protocol.http.user_agent = 'DP::GeneralHelpers::HTTPFetch//eLinks'",'-source',$file));
}

# Purpose: Download a file from HTTP using lynx.
# Usage: $self->_LynxFetch(FILE,PROGRESS);
sub _LynxFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	return($self->_FetchFileCMD($progress,'lynx','-useragent=DP::GeneralHelpers::HTTPFetch//lynx','-source',$file));
}

# Purpose: Download a file from HTTP using curl.
# Usage: $self->_CurlFetch(FILE,PROGRESS);
sub _CurlFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	return($self->_FetchFileCMD($progress,'curl','--user-agent','DP::GeneralHelpers::HTTPFetch//curl','--fail','--location','--silent',$file));
}

# Purpose: Download a file from HTTP using wget.
# Usage: $self->_WgetFetch(FILE,PROGRESS);
sub _WgetFetch {
	my $self = shift;
	my $file = shift;
	my $progress = shift;

	return($self->_FetchFileCMD($progress,'wget','--user-agent','DP::GeneralHelpers::HTTPFetch//wget','--quiet','-O','-',$file));
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
