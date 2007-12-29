# DP::GeneralHelpers
# $Id$
# Copyright (C) Eskild Hustvedt 2007
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

package DP::GeneralHelpers;
use strict;
use warnings;
use Exporter qw(import);
use constant {
	TRUE => 1,
	FALSE => undef,
	};

# Exported functions
our @EXPORT_OK = qw(DPIntWarn DPIntInfo WriteConfigFile LoadConfigFile AppendZero);

# Purpose: Print a warning to STDERR with proper output
# Usage: DPIntWarn("Warning");
sub DPIntWarn {
	warn "*** (Day Planner $main::Version) Warning: $_[0]\n";
}

# Purpose: Print an info message to STDOUT with proper output
# Usage: DPIntInfo("Info");
sub DPIntInfo {
	print "*** (Day Planner $main::Version): $_[0]\n";
}

# Purpose: Write a configuration file
# Usage: WriteConfigFile(/FILE, \%ConfigHash, \%ExplanationHash);
sub WriteConfigFile {
	my ($File, $Config, $Explanations) = @_;

	# Open the config for writing
	open(my $CONFIG, '>', "$File") or do {
		# If we can't then we error out, no need for failsafe stuff - it's just the config file
		DPIntWarn("Unable to save the configuration file $File: $!");
		return(0);
	};
	if(defined($Explanations->{HEADER})) {
		print $CONFIG "# $Explanations->{HEADER}\n";
	}
	foreach(sort(keys(%{$Config}))) {
		next unless length($Config->{$_});	# Don't write empty options
		if(defined($Explanations->{$_})) {
			print $CONFIG "\n# $Explanations->{$_}";
		}
		print $CONFIG "\n$_=$Config->{$_}\n";
	}
	close($CONFIG);
}

# Purpose: Load a configuration file
# Usage: LoadConfigFile(/FILE, \%ConfigHash, \%OptionRegexHash, OnlyValidOptions?);
#  OptionRegeXhash can be available for only a select few of the config options
#  or skipped completely (by replacing it by undef).
#  If OnlyValidOptions is true it will cause LoadConfigFile to skip options not in
#  the OptionRegexHash.
sub LoadConfigFile {
	my ($File, $ConfigHash, $OptionRegex, $OnlyValidOptions) = @_;

	open(my $CONFIG, '<', "$File") or do {
		DPIntWarn(sprintf("Unable to read the configuration settings from %s: %s", $File, $!));
		return(0);
	};
	while(<$CONFIG>) {
		next if m/^\s*(#.*)?$/;
		next unless m/=/;
		chomp;
		my $Option = $_;
		my $Value = $_;
		$Option =~ s/^\s*(\w+)\s*=.*/$1/;
		$Value =~ s/^\s*\w+\s*=\s*(.*)\s*/$1/;
		if($OnlyValidOptions) {
			unless(defined($OptionRegex->{$Option})) {
				DPIntWarn("Unknown configuration option \"$Option\" (=$Value) in $File: Ignored.");
				next;
			}
		}
		unless(defined($Value)) {
			DPIntWarn("Empty value for option $Option in $File");
		}
		if(defined($OptionRegex) and defined($OptionRegex->{$Option})) {
			my $MustMatch = $OptionRegex->{$Option};
			unless ($Value =~ /$MustMatch/) {
				DPIntWarn("Invalid setting of $Option (=$Value) in the config file: Must match $OptionRegex->{Option}.");
				next;
			}
		}
		$ConfigHash->{$Option} = $Value;
	}
	close($CONFIG);
}

# Purpose: Append a "0" to a number if it is only one digit.
# Usage: my $NewNumber = AppendZero(NUMBER);
sub AppendZero {
	my $Number = shift;
	if ($Number =~ /^\d$/) {
		return("0$Number");
	}
	return($Number);
}

# Version number
our $VERSION;
$VERSION = 0.1;

# Purpose: Find out if a command is in PATH or not
# Usage: InPath(COMMAND);
sub InPath {
	foreach (split /:/, $ENV{PATH}) { if (-x "$_/@_" and ! -d "$_/@_" ) {   return 1; } } return 0;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

DP::GeneralHelpers - Perl extension for blah blah blah

=head1 SYNOPSIS

  use DP::GeneralHelpers;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for DP::GeneralHelpers, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

Mention other useful documentation such as the documentation of
related modules or operating system documentation (such as man pages
in UNIX), or any relevant external documentation such as RFCs or
standards.

If you have a mailing list set up for your module, mention it here.

If you have a web site set up for your module, mention it here.

=head1 AUTHOR

zerodogg, E<lt>zerodogg@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by zerodogg

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.

=cut
