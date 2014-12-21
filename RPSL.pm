#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use warnings;
use strict;

package RPSL;

use Cache;

sub Parse
{
	my ($self, $allref, $callback) = @_;

	$$allref =~ s/^Warning:.*\n//mg;

	# DPRINT "RPSL Parser: sub1" if DEBUG;
	$$allref =~ s/#.*$//mg;			# remove comments
	# DPRINT "RPSL Parser: sub2" if DEBUG;
	$$allref =~ s/[ \cI]+$//mg;		# remove trailing space
	# DPRINT "RPSL Parser: sub3" if DEBUG;
	$$allref =~ s/\cJ[ \cI]+/ /g;	# unfold lines
	# DPRINT "RPSL Parser: sub4" if DEBUG;
	$$allref =~ s/%.*\cJ//mg;		# remove comments
	# DPRINT "RPSL Parser: sub5" if DEBUG;
	$$allref =~ s/\A\cJ+//;			# remove leading blank
	# DPRINT "RPSL Parser: sub6" if DEBUG;
	$$allref =~ s/\cJ+\z//;			# remove trailing blank
	# DPRINT "RPSL Parser: sub-" if DEBUG;

	$$allref .= "\n\n";
	while (1)
	{
		my ($chunk) = $$allref =~ m/(.*?)\n\n/s
			or last;
		substr($$allref, 0, $+[1]+2, "");
		my @lines = split /\cJ/, $chunk;
		my @pairs;

		for (@lines)
		{
			next unless /\S/;
			/^(.*?):\s*(.*)$/ or die "Error parsing RPSL line [$_] (no colon?).\nChunk is:<<EOF\n" . $chunk . "\nEOF";
			push @pairs, $1, $2;
		}

		&$callback($self->newFromPairs(@pairs))
			if @pairs;
	}
}

sub newFromPairs
{
	my ($self, @pairs) = @_;

	$self = bless {}, $self;

	$self->{'_type'} = $pairs[0];

	my @t = @pairs;
	my %seen;
	while (my ($k, $v) = splice(@pairs, 0, 2))
	{
		push @{ $self->{'_pairs'} }, [ $k => $v ];
		push @{ $self->{$k} }, $v;
		push @{ $self->{'_attributes'} }, $k
			unless $seen{$k};
		++$seen{$k};
	}

	$self->{'_key'} = join ";", $self->asKeyValues;

	$self->{'_source'} = $self->{'source'}[0];

	$self;
}

sub asKeyValues
{
	my ($self) = @_;
	map { $self->{$_}[0] } $self->asKeyAttributes;
}

sub asKeyAttributes
{
	my $self = shift;
	my $sType = $self->{'_type'};

	return qw/ route origin / if $sType eq "route";
	return qw/ aut-num / if $sType eq "aut-num";
	return qw/ inetnum / if $sType eq "inetnum";
	return qw/ nic-hdl / if $sType eq "role";
	return qw/ nic-hdl / if $sType eq "person";
	return qw/ mntner / if $sType eq "mntner";
	return qw/ as-block / if $sType eq "as-block";
	return qw/ key-cert / if $sType eq "key-cert"; # guessed

	die "Don't know the keys for a '$sType' RPSL object";
}

# Classes: mntner person role route as-set route-set filter-set rtr-set
# peering-set aut-num dictionary inet-rtr.

1;
# eof RPSL.pm
