#!/usr/bin/env perl
# acxi_v3
# Trying to do a rewrite of acxi, mostly just to get totally into it
# myself, to be able to understand it better and help more constructively.
#
# Odd Eivind Ebbesen <oddebb@gmail.com>, 2011-04-07 02:20:24

## POD documentation (a lot more flexible than inline help functions)

=pod

=head1 NAME

    acxi - wrapper script for converting various audio formats to ogg or mp3.

=head1 SYNOPSIS

B<acxi> [options]

=over

=item -c, --copy=LIST

List of alternate data types to copy to output type directories. Must be comma separated, no spaces, see sample.

=item -d, --destination=PATH

The path to the directory where you want the processed (eg, ogg) files to go.

=item -f, --force

=item -i, --input=FORMAT

Input type/format. Supported values are: flac, wav, raw,

=item -o, --output=FORMAT

Output type/format. Supported values are: ogg, mp3.

=item -q, --quality=VALUE

Encoding quality. For ogg, accepted values are 1-10, where 10 is the best quality, and the bigggest file size. For mp3, accepted values are 0-9 (VBR), where 0 is the best quality, and the biggest file size.

=item -q, --quiet

=item -s, --source=PATH

The source/root directory for your input files (flac/wav/raw).

=item -?, -h, --help

This help text.

=item --version

Print acxi version number, and some more details.


=cut

## Start code
use strict;
use warnings;
use Getopt::Long qw(:config auto_version auto_help no_ignore_case);
use File::Find;
use Cwd;


## Internal settings:

# Getopt::Long will automatically control --version if this variable is set:
$main::VERSION = "3.0.0";

# Not used yet, but as a future thought...
my %ACXI = (
    version     => $main::VERSION, 
    date        => q(2011-04-15),
    desc        => q(Audio file conversion script), 
    authors     => q(Harald Hope, Odd Eivind Ebbesen), 
    credits     => q(Jason L. Buberel <jason@buberel.org>, Evan Boggs <etboggs@indiana.edu>), 
    url         => q(http://techpatterns.com/forums/about1491.html)
);
# Internal log/message levels (use corresponding values, not variables in config files)
my %LOG = (
    quiet       => 0, 
    info        => 1, 
    verbose     => 2, 
    debug       => 3
);

my %LINE = (
    small => qq(-----------------------------------------------------------------\n), 
    large => qq(---------------------------------------------------------------------------\n), 
    heavy => qq(===========================================================================\n)
);

my @CONFIGS = (
    qq(/etc/acxi.conf), 
    qq($ENV{HOME}/.acxi.conf)
);

my @OUTPUT_TYPES = ("ogg", "mp3");

#my %ARG_ENCODER_VERBOSITY = (
#    mp3 => %{$LOG{QUIET} => "--quiet";
#);
## User settings:
# In the config file, you just write KEY = value, eg:
# DIR_PREFIX_SOURCE = /home/user/flac 
# Settings not present in the config file will stay as defined here.
my %USER_SETTINGS = (
    LOG_LEVEL           => $LOG{info}, 
    DIR_PREFIX_SOURCE   => "$ENV{HOME}/flac", 
    DIR_PREFIX_DEST     => "$ENV{HOME}/ogg", 
    QUALITY             => 7, 
    INPUT_TYPE          => "flac", 
    OUTPUT_TYPE         => "ogg", 
    COPY_TYPES          => "bmp,jpg,jpeg,tif,doc,docx,odt,pdf,txt", 
    COMMAND_OGG         => "/usr/bin/oggenc", 
    COMMAND_LAME        => "/usr/bin/lame", 
    COMMAND_FLAC        => "/usr/bin/flac", 
    COMMAND_METAFLAC    => "/usr/bin/metaflac"
);
## END user settings

# This can be used to export enclosed vars if this script were to be used as a module
#use vars qw(%ACXI);

## Functions:

sub acxi_log {
    # The result of calling this function without a level param, is that
    # the message is shown at which ever level is set, except "quiet",
    my ($msg, $lvl) = @_;
    if (!defined($lvl)) {
        $lvl = $USER_SETTINGS{LOG_LEVEL};
    }
    if ($USER_SETTINGS{LOG_LEVEL} == $LOG{quiet}) {
        return;
    }
    if ($lvl <= $USER_SETTINGS{LOG_LEVEL}) {
        print($msg);
    }
}

sub read_config_file {
    my ($file, $var, $val);
    # Config files should be passed in an array as a param to this function.
    # Default intended use: global @CONFIGS;
    foreach $file (@_) {
        next unless open (CONFIG, "$file");
        while (<CONFIG>) {
            chomp;
            s/#.*//;
            s/^\s+//;
            s/\s+$//;
            next unless length;
            ($var, $val) = split(/\s*=\s*/, $_, 2);
            $USER_SETTINGS{$var} = $val;
        }
    }
}

# Create destination directories as in source
sub dircopy {
    acxi_log($LINE{large}, $LOG{verbose});
    acxi_log(qq(Syncing source and destinations directories...\n), $LOG{verbose});
    find(\&dircopy_helper, $USER_SETTINGS{DIR_PREFIX_SOURCE});
    acxi_log(qq(Directory syncronization complete.\n), $LOG{verbose});
}

# Helper function for File::Find ("wanted")
sub dircopy_helper {
    # not symlink, is dir, not . or .. and no newline
    if (! -l && -d && ! /^\.{1,2}$/ && ! /\n$/) {
        my $srcx = qq($USER_SETTINGS{DIR_PREFIX_SOURCE});
        my $dstx = qq($USER_SETTINGS{DIR_PREFIX_DEST});
        my $newdir = $File::Find::name;
        $newdir =~ s/$srcx/$dstx/;
        acxi_log($LINE{small}, $LOG{verbose});
        acxi_log(qq(Creating new directory:\n\t$newdir\n), $LOG{verbose});
        mkdir(qq($newdir)) or warn(qq(Failed to create directory: "$newdir" -  $!));
    }
}

#sub set_arg_audio {
#    my ($llvl, $itype, $otype) = @_;
#    if ($llvl eq $LOG{quiet}) {
#        $ARG_ENCODER{$otype} = "--silent";
#    }
#}

## Entry point:

# This so far only serves the purpose of loading Getopt::Long, so that the automatic
# --version and -?|-h|--help works with the POD docs.
my $dummy;
GetOptions(
    "d|dummy:s" => \$dummy
);

read_config_file(@CONFIGS);
while (my ($k, $v) = each %USER_SETTINGS) {
    acxi_log(qq($k => $v\n), $LOG{debug});
}

acxi_log(qq(Ladidadida, logging at user or predefined level ($USER_SETTINGS{LOG_LEVEL})\n));
acxi_log(qq(Logging at DEBUG, which should not be seen if level < 3\n), $LOG{debug});

dircopy();
