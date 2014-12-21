#!/usr/bin/perl -w
# vi: set ts=4 sw=4 :

use strict;

package E2EFilter::DNSBlacklist;

require Net::DNS;

use constant DEFAULT_TIMEOUT => 5;
use constant DEFAULT_SLEEP => 0.25;

sub list_from_packet
{
	my ($class, $ans) = @_;

	my @a_ips;
	my @txt_strings;

	for ($ans->answer)
	{
		push(@a_ips, $_->address), next
			if $_->type eq "A";
		push(@txt_strings, $_->char_str_list), next
			if $_->type eq "TXT";
	}

	($ans->header->ancount, $ans, \@a_ips, \@txt_strings);
}

=pod

	->Lookup("i.p.n.o", "zone.example.org", %options)

Options: 'nameservers' - an array ref to a list of name servers to use.
'timeout' - the timeout to use.

In scalar context, returns undef for timeouts etc, 0 for NXDOMAIN,
otherwise it's a Net::DNS::Packet object.

In list context, returns ($number_of_answers, $packet, $ref_to_A, $ref_to_TXT)
where $ref_to_A is an array ref to a series of "A" answers (e.g. ["127.0.0.2"])
and $ref_to_TXT is an array ret to a series of TXT answers (e.g. ["Please see ..."]).

=cut

sub Lookup
{
	my ($class, $ip, $zone, %opts) = @_;

	my $rev = join ".", reverse split /\./, $ip;
	my $query = "$rev.$zone";

	my $res = Net::DNS::Resolver->new;
	$res->nameservers(@{ $opts{nameservers} }) if $opts{nameservers};
	$res->udp_timeout($opts{timeout} || DEFAULT_TIMEOUT);

	my $ans = $res->send($query, "ANY", "IN")
		or return undef;

	my @ans = $ans->answer
		or return 0;

	wantarray
		? $class->list_from_packet($ans)
		: $ans;
}

if (0 and not caller)
{
	package main;
	my $test = sub {
		print "Looking up $_[0] at $_[1]\n";
		my ($count, $ans, $rA, $rTXT) = E2EFilter::DNSBlacklist->Lookup(@_);
		use Data::Dumper;
		print Data::Dumper->Dump([ $count, $rA, $rTXT ],[ 'count', '*A', '*TXT' ]);
		my $scalar = E2EFilter::DNSBlacklist->Lookup(@_);
		print Data::Dumper->Dump([ $scalar ],[ 'scalar' ]);
	};
	&$test("127.0.0.2", "sbl-xbl.spamhaus.org");
	&$test("10.0.0.0", "sbl-xbl.spamhaus.org");
	&$test("0.0.0.0", "anything", nameservers => ["195.60.0.99"]);
}

=pod

Here $zones is an array ref to a list of zones.

options "timeout" and "nameservers" are as above.

With the "all" option, returns a reference to a hash of results.
The keys are the zones, and the results are:

* in scalar context: undef, 0, or a Net::DNS::Packet (as above)
* in list context: a list ref of undef, 0, or [ $anscount, $packet, $Alist, $TXTlist ]

Without "all", the first "hit" ends the lookup.  Returns:

* in scalar context: a Net::DNS::Packet with answer(s); or 0 (no answers);
  or undef (all timed out)
* in list context: as above but a list of [ $anscount, $packet, $Alist, $TXTlist ]
  instead of a Net::DNS::Packet.

=cut

sub MultipleLookup
{
	my ($class, $ip, $zones, %opts) = @_;

	my @unique_zones = do {
		my %h = map { $_ => undef } @$zones;
		sort keys %h;
	};

	@unique_zones or die;

	my $res = Net::DNS::Resolver->new;
	$res->nameservers(@{ $opts{nameservers} }) if $opts{nameservers};
	$res->udp_timeout($opts{timeout} || DEFAULT_TIMEOUT);

	my $rev = join ".", reverse split /\./, $ip;

	my %sockets;
	for my $zone (@unique_zones)
	{
		my $query = "$rev.$zone";
		my $socket = $res->bgsend($query, "ANY", "IN")
			or warn("Failed to query $ip in $zone: $!"), next;
		$sockets{$zone} = $socket;
	}

	use Time::HiRes qw( time sleep );
	my $endtime = time() + ($opts{timeout} || DEFAULT_TIMEOUT);

	my %results;
	my $best_result = undef;

	while (time() < $endtime and keys %sockets)
	{
		while (my ($zone, $socket) = each %sockets)
		{
			$res->bgisready($socket)
				or next;

			my $ans = $res->bgread($socket);
			my @ans = $ans->answer;

			if ($opts{'all'})
			{
				# We want all the results; so stash the appropriate thing in
				# %results and loop around.
				if (@ans)
				{
					$results{$zone} = (
						wantarray
							? [ $class->list_from_packet($ans) ]
							: $ans
					);
				} else {
					$results{$zone} = (
						wantarray
							? [ 0 ]
							: 0
					);
				}
			} else {
				# We don't want all the results, so the first "hit" is
				# returned
				if (@ans)
				{
					return (
						wantarray
							? [ $class->list_from_packet($ans) ]
							: $ans
					);
				} else {
					$best_result = 0;
				}
			}

			delete $sockets{$zone};
		}

		sleep($opts{'sleep'} || DEFAULT_SLEEP)
			if keys %sockets;
	}

	return $best_result
		unless $opts{all};

	# Fill in the missing answers as "undef"
	exists($results{$_}) or $results{$_} = ( wantarray ? [undef] : undef )
		for @unique_zones;
	
	\%results;
}

if (0 and not caller)
{
	my $test = sub {
		print "Querying...\n";
		my $scalar = __PACKAGE__->MultipleLookup(@_);
		(my $list) = __PACKAGE__->MultipleLookup(@_);
		use Data::Dumper;
		print Data::Dumper->Dump([ \@_, $scalar, $list ],[ '*_', 'scalar', 'list' ]);
	};
	&$test("127.0.0.2", [ "sbl-xbl.spamhaus.org", "ordb.org" ], all => 0);
	&$test("127.0.0.2", [ "sbl-xbl.spamhaus.org", "ordb.org" ], all => 1);
	&$test("127.0.0.2", [ "power.net.uk", "powernet.com" ], all => 0);
	&$test("127.0.0.2", [ "power.net.uk", "powernet.com" ], all => 1);
	&$test("127.0.0.2", [ "anything.net", "powernet.com" ], all => 0, nameservers => [ "195.60.0.99" ]);
	&$test("127.0.0.2", [ "anything.net", "powernet.com" ], all => 1, nameservers => [ "195.60.0.99" ]);
}

1;
# eof DNSBlacklist.pm
