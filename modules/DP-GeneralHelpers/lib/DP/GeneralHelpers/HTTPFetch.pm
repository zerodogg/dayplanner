package DP::GeneralHelpers::HTTPFetch;
use IPC::Open3;
use POSIX;
use Socket;

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
