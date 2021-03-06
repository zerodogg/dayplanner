package IO::Conduit;

use strict;
use warnings;
use Net::DBus;

our $VERSION;
$VERSION = '0.01';

sub new {
	my $Package = shift;
	my $self = {};
	bless($self,$Package);
	$self->{dbus} = Net::DBus->find();
	print "DBus connected\n";
	$self->{conduit} = $self->{dbus}->get_service('org.conduit.Application');
	print "Conduit service got\n";
	$self->{c_service} = $self->{conduit}->get_object('org/conduit/Application');
	print "Conduit Application object got\n";
	return($self);
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

IO::Conduit - Perl extension for blah blah blah

=head1 SYNOPSIS

  use IO::Conduit;
  blah blah blah

=head1 DESCRIPTION

Stub documentation for IO::Conduit, created by h2xs. It looks like the
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

Eskild Hustvedt, E<lt>zerodogg@localdomainE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2007 by Eskild Hustvedt

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.8 or,
at your option, any later version of Perl 5 you may have available.


=cut
