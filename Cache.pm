#!/usr/bin/perl
# vi: set ts=4 sw=4 :

use warnings;
use strict;

require Cache::Memcached;
$::memc = Cache::Memcached->new({
    servers		=> [ "127.0.0.1:11211" ],
    debug		=> 0,
    compress_threshold	=> 10_000,
});

1;
# eof Cache.pm
