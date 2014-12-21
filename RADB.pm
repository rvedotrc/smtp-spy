#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use warnings;
use strict;

package RADB;

use Cache;

sub Query
{
	my ($class, $ip) = @_;

	(my $key = "radb-Query-$ip") =~ tr/ /_/;
	my $objs;

	unless ($objs = $::memc->get($key))
	{
		my $all = $class->whois($ip);
		# print "Parsing [$all]\n";

		require RPSL;
		my %objs;
		RPSL->Parse(\$all, sub {
			my $o = shift;
			my $t = $o->{_type};
			push @{ $objs{$t} }, $o;
		});

		$objs = \%objs;
		$::memc->set($key, $objs, 3600);
	}

	use Data::Dumper;
	print Data::Dumper->Dump([ $objs ],[ '*objs' ]);

	return $objs;
}

sub whois
{
	my ($class, $query) = @_;

	my $cmd = "whois -h whois.radb.net $query";
	(my $key = $cmd) =~ tr/_/ /;

	if (my $v = $::memc->get($key))
	{
		return $v;
	} else {
		my $all = `$cmd`;
		$::memc->set($key, $all, 3600);
		return $all;
	}
}

1;
# eof RPSLObject.pm
