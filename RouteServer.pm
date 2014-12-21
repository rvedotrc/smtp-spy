#!/usr/bin/perl

use warnings;
use strict;

package RouteServer;

sub List
{
	my $class = shift;

	my $servers = <<'EOF';
<A HREF="telnet://ner-routes.bbnplanet.net">BBN Planet NER route monitor (AS1)</A></LI>
<A HREF="telnet://route-server.belwue.de">BelWue (AS553)</A></LI>
<A HREF="telnet://route-views.on.bb.telus.com">Telus - East Coast (AS852)</A></LI>
<A HREF="telnet://route-views.ab.bb.telus.com">Telus - West Coast (AS852)</A></LI>
<A HREF="telnet://route-server.cerf.net">CerfNet Route Server (AS1838)</A></LI>
<A HREF="telnet://route-server.ip.tiscali.net">Tiscali (AS3257)</A></LI>
<A HREF="telnet://route-server.gblx.net">Global Crossing (AS3549)</A></LI>
<A HREF="telnet://route-server.eu.gblx.net">Global Crossing Europe (AS3549)</A></LI>
<A HREF="telnet://route-server.savvis.net/">SAVVIS Communications (AS3561)</A></LI>
<A HREF="telnet://public-route-server.is.co.za" TARGET=NEW>Internet Solutions (AS3741)</A></LI>
<A HREF="telnet://route-server-ap.exodus.net">Exodus Communications Asia (AS4197)</A></LI>
<A HREF="telnet://route-server.as5388.net">Planet Online (AS5388)</A></LI>
<A HREF="telnet://route-server.opentransit.net">Opentransit (AS5511)</A></LI>
<A HREF="telnet://tpr-route-server.saix.net">South African Internet eXchange SAIX (AS5713)</A></LI>
<A HREF="telnet://route-server.gt.ca">GT Group Telecom (AS6539)</A></LI>
<A HREF="telnet://route-server.as6667.net">EUNet Finland (AS6667)</A></LI>
<A HREF="telnet://routeserver.sunrise.ch/">Sunrise (AS6730)</A></LI>
<A HREF="telnet://route-server.he.net">Hurricane Electric (AS6939)</A></LI>
<A HREF="telnet://route-server.ip.att.net">AT&T (AS7018)</A></LI>
<A HREF="telnet://route-views.optus.net.au">Optus Route Server Australia (AS7474)</A></LI>
<A HREF="telnet://route-server.wcg.net">Wiltel (AS7911)</A></LI>
<A HREF="telnet://route-server.colt.net">Colt Internet (AS8220)</A></LI>
<A HREF="telnet://route-server-eu.exodus.net">Exodus Communications Europe (AS8709)</A></LI>
<A HREF="telnet://route-views.bmcag.net">Broadnet mediascape communications AG (AS9132)</A></LI>
<A HREF="telnet://route-server-au.exodus.net">Exodus Communications Australia (AS9328)</A></LI>
<A HREF="telnet://route-server.manilaix.net.ph">Manila Internet Exchange, Philippines (AS9670)</A></LI>
<A HREF="telnet://route-view.tiscali.de">Tiscali Germany (AS12312)</A></LI>
<A HREF="telnet://route-server.host.net">Host.net (AS13645)</A></LI>
<A HREF="telnet://route-server.east.allstream.com">Allstream - East (AS15290)</A></LI>
<A HREF="telnet://route-server.west.allstream.com">Allstream - West (AS15290)</A></LI>
<A HREF="telnet://route-server.rhein-main-saar.net">MainzKom Telekommunikation GmbH (AS15837)</A></LI>
<A HREF="telnet://route-server.ip.ndsoftware.net">NDSoftware (AS25358)</A></LI>
<A HREF="telnet://route-server.loudpacket.net">Loud Packet (AS27276)</A></LI>
<A HREF="telnet://route-server.as28747.net/">RealROOT (AS28747)</A></LI>
<A HREF="telnet://route-views.oregon-ix.net">Oregon-ix.net Route Server</A></LI>
<A HREF="telnet://route-server.utah.rep.net">Utah Regional Exchange Point Route Server</A></LI>
<A HREF="telnet://www.netlantis.org">The NetLantis Project Route Server</A></LI>
EOF

	my @route_servers;

	while ($servers =~ m[<A HREF="telnet://(.*?)/?"(?: .*?)?>(.*?)</A>]g)
	{
		my ($host, $name) = ($1, $2);
		my $asnum;
		$asnum = $1 if $name =~ /\((AS\d+)\)/;
		push @route_servers, [ $host, $name, $asnum ];
	}

	return @route_servers;
}

sub GetRandom
{
	my $class = shift;
	my $num = shift || 1;
	my @route_servers = $class->List;
	require List::Util;
	@route_servers = List::Util::shuffle(@route_servers);
	return $route_servers[0] if not wantarray;
	return @route_servers[0..$num-1];
}

sub Query
{
	my ($class, $ip, $route_server) = @_;

	{ no warnings; local $^W = 0; require Net::Telnet::Cisco; }
	my $session = Net::Telnet::Cisco->new(Host => $route_server->[0]) or die $!;
	$session->login or die $!;

	my @output = $session->cmd("show ip bgp $ip");

=pod

Local example:

BGP routing table entry for 209.1.0.0/16, version 4073427
Paths: (2 available, best #1)
  Not advertised to any peer
  Local
    208.172.146.29 from 208.172.146.29 (208.172.146.29)
      Origin IGP, localpref 100, valid, internal, best
  Local
    208.172.146.30 from 208.172.146.30 (208.172.146.30)
      Origin IGP, localpref 100, valid, internal

Remote example:

BGP routing table entry for 195.60.0.0/19, version 15216316
Paths: (2 available, best #1)
  Not advertised to any peer
  5400 8689
    208.172.146.29 from 208.172.146.29 (206.24.194.141)
      Origin IGP, localpref 100, valid, internal, best
      Originator: 206.24.194.141, Cluster list: 208.172.146.29, 208.173.55.25, 206.24.194.105
  5400 8689
    208.172.146.30 from 208.172.146.30 (206.24.194.141)
      Origin IGP, localpref 100, valid, internal
      Originator: 206.24.194.141, Cluster list: 208.172.146.29, 208.173.55.25, 206.24.194.105

=cut

	my $all = join "\n", @output;
	(my $route) = $all =~ m{^BGP routing table entry for ([0-9./]+), version \d+$}m;

	my $as_num;
	if ($all =~ /^\s+(?:\d+ )+(\d+)$/m)
	{
		$as_num = $1;
	} else {
		$all =~ /^\s+Local$/m or die;
		# What AS is local?
		@output = $session->cmd("show ip bgp peer-group");
=pod

BGP peer-group is ibgp, no member, remote AS 3561
 Index 0, Offset 0, Mask 0x0
  NEXT_HOP is always this router
  BGP version 4
  Neighbor NLRI negotiation:
    Configured for unicast routes only
  Minimum time between advertisement runs is 5 seconds
  Update messages formatted 0, replicated 0
  Outgoing update network filter list is 98
  Route map for incoming advertisements is ibgp

=cut
		$all = join "\n", @output;
		$all =~ / remote AS (\d+)$/m or die "Can't work out local AS number ($all)";
		$as_num = $1;
	}

	$session->close;

	return($as_num, $route);
}

1;
# eof RouteServer.pm
