#!/usr/bin/perl
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

# This plugin provides debugging information about the Day Planner event/PubSub
# system.
#
# Usage: DP_LOAD_PLUGINS="EventDebugger" ./dayplanner

package DP::Plugin::EventDebugger;
use Moo;
extends 'DP::Plugin';

sub earlyInit
{
    my $this = shift;
	$this->p_subscribe('*' => sub {
            my $data = shift;
            print '[Day Planner EventDebugger] Event "'.$data->{event}.'" published';
            if ($data->{data})
            {
                if(ref($data->{data}) eq 'HASH')
                {
                    my $dataString = '';
                    foreach my $key (keys %{$data->{data}})
                    {
                        $dataString .= $key.' => ';
                        if(ref($data->{data}->{$key}))
                        {
                            $dataString .= ref($data->{data}->{$key});
                        }
                        else
                        {
                            $dataString .= $data->{data}->{$key};
                        }
                        $dataString .= ', ';
                    }
                    $dataString =~ s/,\s+$//;
                    print ' (with data: '.$dataString.')';
                }
                else
                {
                    print ' (with data)';
                }
            }
            my ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(3);
            if ($subroutine eq 'DP::CoreModules::Plugin::publish')
            {
                ($package, $filename, $line, $subroutine, $hasargs, $wantarray, $evaltext, $is_require, $hints, $bitmask) = caller(5);
            }
            print ' by '.$subroutine."\n";
        } );
}

sub metainfo
{
	# NOTE: Although this is a plugin, it does not have any metainfo, because
	# 	it isn't suppose to be displayed in the plugin manager
    return
    {
		apiversion => 2,
    };
}

1;
