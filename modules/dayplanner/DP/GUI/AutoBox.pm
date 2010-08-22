# DP::GUI::AutoBox
# Copyright (C) Eskild Hustvedt 2010
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

package DP::GUI::AutoBox;
use Mouse;
use Gtk2;
use constant {
	true => 1,
	false => undef,
};

has '_currNo' => (
	is => 'rw',
	isa => 'Int',
	default => 0,
);
has '_currWidgets' => (
	is => 'rw',
	isa => 'Ref',
	required => 0,
);

has '_primaryWidget' => (
	is => 'ro',
	isa => 'Ref',
	default => sub {
		return Gtk2::VBox->new();
		},
);

sub push_widgets
{
	my $self = shift;
	my $widgets = scalar(@_);

	if ($widgets != $self->_currNo)
	{
		$self->_currWidgets({});
		my $hbox = Gtk2::HBox->new();
		$self->_primaryWidget->pack_start($hbox,1,0,0);
		print "NEW ($widgets)\n";
		for my $no (1..$widgets)
		{
			my $widget = Gtk2::VBox->new();
			$self->_currWidgets->{"vbox_$no"} = $widget;
			$hbox->pack_start($widget,0,0,0);
		}
		$self->_currNo($widgets);
	}
	return $self->_performPush(@_);
}

sub _performPush
{
	my $self = shift;
	for my $no (1..scalar(@_))
	{
		my $widget = shift(@_);
		if ($widget->can('set_alignment'))
		{
			$widget->set_alignment(0,0.5);
		}
		$self->_currWidgets->{'vbox_'.$no}->pack_start($widget,1,0,0);
	}
}

sub get_rootWidget
{
	my $self = shift;
	return $self->_primaryWidget;
}

__PACKAGE__->meta->make_immutable;
1;

__END__

=head1 NAME

DP::GUI::AutoBox - An automatic manager for Gtk2 boxes with an arbitrary amount of non-aligning columns

=head1 SYNOPSIS

  use DP::GUI::AutoBox;
  my $box = DP::GUI::AutoBox->new();
  $box->push_widgets($w1,$w2);
  $box->push_widgets($w3,$w4);
  $box->push_widgets($w5);
  $win->add($box->get_rootWidget);
  my $data = DP::GeneralHelpers::HTTPFetch->get("http://www.day-planner.org/");

TODO

=cut
