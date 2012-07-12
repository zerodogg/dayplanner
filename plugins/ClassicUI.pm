#!/usr/bin/perl
# Day Planner
# A graphical Day Planner written in perl that uses Gtk2
# Copyright (C) Eskild Hustvedt 2012
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

package DP::Plugin::ClassicUI;
use Moo;
extends 'DP::Plugin';

has 'stash' => (
    is => 'rw',
    default => sub { {} },
);

has 'menuButton' => (
    is => 'rw',
    );
has 'editEntry' => (
    is => 'rw',
    );
has 'deleteEntry' => (
    is => 'rw',
    );
has 'toolbar' => (
    is => 'rw',
    );
has 'leftVBox' => (
    is => 'rw',
    );

sub earlyInit
{
    my $this = shift;
	$this->p_subscribe('CREATE_MENUITEMS' => sub { $this->stashMenuItems(@_) });
	$this->p_subscribe('INIT' => sub { $this->initMenuBar(@_) });
    $this->p_subscribe('BUILD_TOOLBAR' => sub
        {
            my $data = shift;
            $this->toolbar($data->{toolbar});
        });
    $this->p_subscribe('AREA_READY' => sub {
            my $data = shift;
            $this->leftVBox($data->{left});
        });
    $this->p_subscribe('MENU_BUILT' => sub {
            my $data = shift;
            $data->{button}->hide;
        });
    $this->p_subscribe('EVENT_SELECTED' => sub {
            if ($this->editEntry)
            {
                $this->editEntry->set_sensitive(1);
                $this->deleteEntry->set_sensitive(1);
            }
        });
    $this->p_subscribe('EVENT_UNSELECTED' => sub {
            if ($this->editEntry)
            {
                $this->editEntry->set_sensitive(0);
                $this->deleteEntry->set_sensitive(0);
            }
        });
	return $this;
}

sub stashMenuItems
{
    my $this = shift;
    my $data = shift;
    foreach my $name (keys(%{$data}))
    {
        $this->stash->{$name} = $data->{$name};
    }
}

sub initMenuBar
{
    my $this = shift;
    my $i18n = $this->p_get_var('i18n');
    my $MainWindow = $this->p_get_var('MainWindow');

	# Get stock values
	my $EditStock = Gtk2::Stock->lookup('gtk-edit')->{label};
	my $QuitStock = Gtk2::Stock->lookup('gtk-quit')->{label};
	my $PrefsStock = Gtk2::Stock->lookup('gtk-preferences')->{label};
	my $AboutStock = Gtk2::Stock->lookup('gtk-about')->{label};
	my $HelpStock = Gtk2::Stock->lookup('gtk-help')->{label};
	my $DeleteStock = Gtk2::Stock->lookup('gtk-delete')->{label};

    my @MenuItems = (
		[ '/' . $i18n->get('_Calendar'),						undef,			undef,			0,	'<Branch>'],
    );

    foreach my $entry (@{ $this->stash->{importExport} })
    {
        $entry->[0] = '/'.$i18n->get('_Calendar').$entry->[0];
        push(@MenuItems,$entry);
    }
    push(@MenuItems,
        [ '/' . $i18n->get('_Calendar') . '/quitsep',                    undef,          undef,          4,  '<Separator>'],
        [ '/' . $i18n->get('_Calendar') . '/'.$QuitStock,        '<control>Q',       \&main::QuitSub,      3,  '<StockItem>',  'gtk-quit'],
    );
    foreach my $entry (@{ $this->stash->{addRemove} },
        [ '/prefsssep',                    undef,          undef,          4,  '<Separator>'],
        @{ $this->stash->{preferences} })
    {
        $entry->[0] = '/'.$EditStock.$entry->[0];
        push(@MenuItems,$entry);
    }
    push(@MenuItems,
        # Help menu
        [ "/$HelpStock",                        undef,          undef,          0,  '<Branch>' ],
        [ "/$HelpStock/" . $i18n->get('_Report a bug'), undef, \&main::ReportBug, 0, '<StockItem>', 'gtk-dialog-warning'],
        [ "/$HelpStock/$AboutStock" ,undef,         \&main::AboutBox,     0,  '<StockItem>',  'gtk-about'],
    );


	my $Menu_AccelGroup = Gtk2::AccelGroup->new;
	# The item factory (menubar) itself
	my $Menu_ItemFactory = Gtk2::ItemFactory->new('Gtk2::MenuBar', '<main>', $Menu_AccelGroup);

	# Tell the item factory to use the items defined in @MenuItems
	$Menu_ItemFactory->create_items (undef, @MenuItems);
	# Pack it onto the vbox
    my $orChild = $MainWindow->child;
    my $newVBox = Gtk2::VBox->new();
    $MainWindow->remove($orChild);
    $newVBox->pack_end($orChild,1,1,0);
    $newVBox->pack_start($Menu_ItemFactory->get_widget('<main>'),0,0,0);
    $newVBox->show();
    $MainWindow->add($newVBox);
	# Show it
	$Menu_ItemFactory->get_widget('<main>')->show();

    # Create two widget objects for the edit/delete menu entries
    my $Get = "/$EditStock/" . $i18n->get('_Edit This Event...');
    $Get =~ s/_//g;
    my $MenuEditEntry = $Menu_ItemFactory->get_widget($Get);
 
    $Get = "/$EditStock/" . $i18n->get('_Delete this event...');
    $Get =~ s/_//g;
    my $MenuDeleteEntry = $Menu_ItemFactory->get_widget($Get);

    $this->editEntry($MenuEditEntry);
    $this->deleteEntry($MenuDeleteEntry);
    $this->editEntry->set_sensitive(0);
    $this->deleteEntry->set_sensitive(0);

    $this->toolbar->set_style('icons');
    $this->toolbar->parent->remove($this->toolbar);
    $this->leftVBox->pack_end($this->toolbar,0,0,0);
}

# Plugin metadata
sub metainfo
{
    return
	{
		name => 'ClassicUI',
		title => 'Classic Day Planner UI',
		description => 'This adds a menu bar to Day Planner and moves the toolbar to the bottom of the window, emulating the UI of 0.11 and older versions of Day Planner',
		version => '0.1',
		apiversion => 2,
		needs_modules => '',
		author => 'Eskild Hustvedt',
		license => 'GNU General Public License version 3 or later',
	};
}

1;
