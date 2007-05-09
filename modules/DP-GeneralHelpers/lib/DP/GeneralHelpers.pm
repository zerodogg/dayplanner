# DP::GeneralHelpers
# $Id$
# Copyright (C) Eskild Hustvedt 2007
#
# This program is free software; you can redistribute it and/or modify
# it under the terms of either:
# 
#    a) the GNU General Public License as published by the Free
#    Software Foundation; either version 2, or (at your option) any
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
# You should also have received a copy of the GNU General Public License
# along with this program in the file named "COPYING.gpl". If not, write to the
# Free Software Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA
# 02111-1307, USA. Or visit their web page on the internet at
# http://www.gnu.org/copyleft/gpl.html.

package DP::GeneralHelpers;
use 5.008008;
use strict;
use warnings;
use Exporter qw(import);
use constant {
	TRUE => 1,
	FALSE => undef,
	};

# Version number
our $VERSION;
$VERSION = 0.1;

# ----
# IPC HANDLER
# ---
package DP::GeneralHelpers::IPC;
use IO::Socket::UNIX;
use Glib;
use constant {
	TRUE => 1,
	FALSE => undef,
	};

# -- PUBLIC IPC HANDLER FUNCTIONS --

# Purpose: Create a new object
# Usage: my $IPC = DP::GeneralHelpers::IPC->new_client();
sub new_client {
	my $Package = shift;
	my $Path = shift;
	my $Handler = shift;

	my $self = {};
	bless($self,$Package);

	$self->{FileName} = $Path;
	$self->{Handler} = $Handler;
	$self->{Type} = 'client';
	$self->{Socket} = IO::Socket::UNIX->new(
		Peer    => $self->{FileName},
		Type	=> SOCK_STREAM,) or return(FALSE,$@);
	if(not Glib::IO->add_watch(fileno($self->{Socket}), 'in', sub { $self->_IO_IN_EVENT($self->{Socket});})) {
			return(FALSE);
		}
	return($self);
}

# Purpose: Create a new object
# Usage: my $IPC = DP::GeneralHelpers::IPC->new_server(PATH,HANDLER);
# 	PATH is the path to the socket to create
# 	HANDLER is a coderef to the code to handle the socket
sub new_server {
	my $Package = shift;
	my $Path = shift;
	my $Handler = shift;

	my $self = {};
	bless($self,$Package);

	$self->{FileName} = $Path;
	$self->{Handler} = $Handler;
	$self->{Type} = 'server';
	$self->{ClientSockets} = [];
	if(not $self->_CheckOrUnlink) {
		return(FALSE);
	}
	# TODO: Handle the case of DYING much much more gracefully
	$self->{Socket} = IO::Socket::UNIX->new(
					Local	=> $self->{FileName},
					Type	=> SOCK_STREAM,
					Listen	=> TRUE,
			) or return(FALSE,$@);
	if(not Glib::IO->add_watch(fileno($self->{Socket}), 'in', sub { $self->_IO_IN(@_);})) {
			return(FALSE);
		}
	return($self);
}

# Purpose: Destory the object
# Usage: obj->destroy
sub destroy {
	my $self = shift;
	if($self->{Type} eq 'server') {
		close($self->{Socket});
		unlink($self->{FileName});
		foreach(@{$self->{ClientSockets}}) {
			if($_) {
				close($_);
			}
		}
	} else {
		close($self->{Socket});
	}
	return(TRUE);
}

# Purpose: Send data to the server
# Usage: obj->client_send(DATA);
sub client_send {
	my $self = shift;

	my $data = shift;
	my $Socket = $self->{Socket};
	print $Socket $data,"\n";
}

# -- INTERNAL IPC HANDLER FUNCTIONS --

# Purpose: Handle incoming IO connections
# Usage: $self->_IO_IN();
sub _IO_IN {
	my $self = shift;
	# Accept the client
	my $Client = $self->{Socket}->accept();
	# Install a new Glib::IO watch handler for it
	Glib::IO->add_watch(fileno($Client), 'in', sub { $self->_IO_IN_EVENT($Client);});
	# Push it onto our list of client sockets
	push(@{$self->{ClientSockets}}, $Client);
	# Handled it, so return
	return(TRUE);
}

# Purpose: Handle an open IO connection with events
# Usage: $self->_IO_IN_EVENT();
sub _IO_IN_EVENT {
	my $self = shift;
	my $Client = shift;
	my $Data = <$Client>;
	# If we could read from it, then there's data to be processed!
	if($Data) {
		my $Return = $self->{Handler}->($Data);
		if($Return) {
			print $Client $Return,"\n";
		}
		return(TRUE);
	} else { # If we couldn't then it's dead, so just close it
		close($Client);
		return(FALSE);
	}
}

# TODO: Clean and document
sub _CheckOrUnlink {
	my $self = shift;
	if(-e $self->{FileName}) {
		# Don't try to connect to nor unlink if it isn't a socket
		if(not -S $self->{FileName}) {
			return(FALSE);
		} else {
			# Try to connect to the socket.
			# If we can connect we simply assume that the app in the other end
			# is alive, so we return false.
			my $Client = DP::GeneralHelpers::IPC->new_client($self->{FileName}, sub { return });
			if($Client) {
				$Client->destroy();
				return(FALSE);
			} else {
				unlink($self->{FileName});
				return(TRUE);
			}
		}
	}
	return(TRUE);
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
