#!/usr/bin/env perl
# acxi_v3
# Trying to do a rewrite of acxi, mostly just to get totally into it
# myself, to be able to understand it better and help more constructively.
#
# Odd Eivind Ebbesen <oddebb@gmail.com>, 2011-04-07 02:20:24

use strict;
use warnings;
use Getopt::Long;


## Internal settings:
my %ACXI = (
    version     => '3.0.0', 
    date        => '2011-04-07',
    desc        => '', 
    authors     => 'Harald Hope, Odd Eivind Ebbesen', 
    credits     => '', 
    url         => ''
);
my %CMD = (
    ogg         => '', 
    flac        => '', 
    metaflac    => '', 
    lame        => ''
);
my %LOG = (
    quiet       => 0, 
    info        => 1, 
    warn        => 2, 
    debug       => 3
);

my %LINE = (
    small => '-----------------------------------------------------------------\n', 
    large => '---------------------------------------------------------------------------\n', 
    heavy => '===========================================================================\n'
);


## User settings:
my $DIR_SRC    = "$ENV{'HOME'}/flac";
my $DIR_DST    = "$ENV{'HOME'}/ogg";
my $LOG_LEVEL  = $LOG{debug};
## END user settings

use vars qw(%ACXI %CMD);

## Functions:

sub acxi_log {
    my ($msg, $lvl) = @_;
    if (!defined($lvl)) {
        $lvl = $LOG_LEVEL;
    }
    if ($LOG_LEVEL == $LOG{quiet}) {
        return;
    }
    if ($lvl <= $LOG_LEVEL) {
        print($msg);
    }
}

sub helpmsg {
    print <<EOM;
This is not helpful...
    ...but it will soon be!

EOM
}

sub app_version {
}

sub read_settings {
}



## Entry point:

acxi_log("Still working on it....\n", $LOG{debug});
acxi_log("Seems it's working ok now.\n");
