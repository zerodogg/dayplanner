#!/usr/bin/perl
package DP::Plugin::HelloWorld;
use strict;
use warnings;

sub new_instance
{
	my $this = shift;
	$this = {};
	bless($this);
	my $plugin = shift;
	$this->{plugin} = $plugin;
	$this->{plugin}->signal_connect('INIT',$this,'helloWorld');
	return $this;
}

sub helloWorld
{
	main::DPInfo('Hello world');
}
