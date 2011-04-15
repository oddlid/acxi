#!/usr/bin/perl
#
# Script Name: acxi - audio conversion script
# Script Version: 2.6.1
# Script Date: 12 April 2010
#
# fork to acxi:
# Copyright (c) 2010 - Harald Hope - smxi.org 
# home page: http://techpatterns.com/forums/about1491.html
# download url: http://smxi.org/acxi
#
# Based on flac2ogg.pl
# Copyright (c) 2004 - Jason L. Buberel - jason@buberel.org
# Copyright (c) 2007 - Evan Boggs - etboggs@indiana.edu
# home page: http://www.buberel.org/linux/batch-flac-to-ogg-converter.php
#
# Licensed under the GNU GPL.
#
# Given a source directory tree of original data files (flac, wav, etc), 
# this script will recreate (or add to) a new directory tree of Ogg files by 
# recursively encoding only new source files to destination types.  The source and 
# destination directories can be hard-coded using the $DIR_PREFIX_SOURCE 
# and $DIR_PREFIX_DEST variables or passed on the command line.  
#
# If you are piping the output to a log file it would also be good to 
# modify line 92 so that the encoder command is silent (this is done 
# using -Q or --quiet) - oggenc only.  
#
# User config file at $HOME/.acxi.conf or global /etc/acxi.conf, set like this:
# DEST_DIR_PREFIX=/home/me/music/flac

### NO USER CHANGES IN THIS SECTION ###
#   Set use 
use Getopt::Long;
use File::stat;

#   Declare Globals
our $B_DEST_CHANGED;
our $COMMAND_FLAC;
our $COMMAND_LAME;
our $COMMAND_OGG;
our @COPY_TYPES;
our $DIR_PREFIX_DEST;
our $DIR_PREFIX_SOURCE;
our $EXTENSION;
our $FORCE;
our $INPUT_TYPE;
our $LINE_HEAVY;
our $LINE_LARGE;
our $LINE_SMALL;
our $OUTPUT_TYPE;
our $QUALITY;
our $SCRIPT_DATE;
our $SCRIPT_VERSION;
our $USER_TYPES;
### END GLOBALS/USE SECTION ###

### USER MODIFIABLE VALUES ###
#
# These can also be set in $HOME/.acxi.conf or /etc/acxi.conf if you prefer
# Anything in configs or in this section will be overridden if you use an
# option.
# Do not use the $ preceding the variable name, or the semiclonon 
# or " quote marks in the config file. Use this syntax for config files:
# DIR_PREFIX_SOURCE=/home/fred/music/flac
# DEST_DIR_PREFIX=/home/fred/music/ogg
# Application Commands:
$COMMAND_OGG = '/usr/bin/oggenc';
$COMMAND_FLAC = '/usr/bin/flac'; 
$COMMAND_LAME = '/usr/bin/lame';

## Assign music source/destination directory paths
## $DIR_PREFIX_SOURCE is the original, working, like flac, wav, etc
## $DIR_PREFIX_DEST is the processed, ie, ogg, mp3
## CHANGE TO FIT YOUR SYSTEM - do not end in /
$DIR_PREFIX_SOURCE = '/path/to/source/directory';
$DIR_PREFIX_DEST = '/path/to/your/output/directory';
# Change if you want these to default to different things
$QUALITY = 7;
## The following are NOT case sensitive,ie flac/FLAC, txt/TXT will be found
$INPUT_TYPE = 'flac';
$OUTPUT_TYPE = 'ogg';
# Add or remove types to copy over to ogg directories, do not include
# the input/output types, only extra data types like txt. Comma separated, use '..'
# If you want no copying done, simply change this to:
# @COPY_TYPES = ( );
# Or if you want to remove or add an extension, do (NO DOTS):
# @COPY_TYPES = ( 'bmp', 'doc', 'docx', 'jpg', 'jpeg', 'pdf', 'txt' );
@COPY_TYPES = ( 'bmp', 'jpg', 'jpeg', 'tif', 'doc', 'docx', 'odt', 'pdf', 'txt' );
# Note: if you want to override @COPY_TYPES in your config files, you
# must use this syntax in your config file:
# USER_TYPES=doc,docx,bmp,jpg,jpeg
#
### END USER MODIFIABLE VARIABLES ###

### ASSIGN CONSTANTS ###
$LINE_HEAVY = "===========================================================================\n";
$LINE_SMALL = "-----------------------------------------------------------------\n";
$LINE_LARGE = "---------------------------------------------------------------------------\n";
$SCRIPT_DATE = '12 April 2010';
$SCRIPT_VERSION = '2.6.1';

### MAIN - FUNCTIONS ###
sub print_help {
	&set_user_types;
	print "acxi v: $SCRIPT_VERSION :: Supported Options:\n";
	print "Examples: acxi -q 8 --destination /music/main/ogg\n";
	print "acxi --input wav --output ogg\n";
	print "acxi --copy doc,docx,bmp\n";
	print $LINE_SMALL;
	print "--copy -c         List of alternate data types to copy to Output type directories.\n";
	print "                  Must be comma separated, no spaces, see sample above.\n";
	print "                  Your current copy types are: ";
	print "@COPY_TYPES\n";
	print "--destination -d  The path to the directory where you want the processed (eg, ogg) files to go.\n";
	print "                  Your current script default is: $DIR_PREFIX_DEST\n";
	print "--force -f        Overwrite the ogg/jpg/txt files, even if they already exist.\n";
	print "--help -h         This help menu.\n";
	print "--input -i        Input type: supported - flac, wav, raw. mp3 only supports flac input.\n";
	print "                  Your current script default is: $INPUT_TYPE\n";
	print "--output -o       Output type: supported - ogg, mp3.\n";
	print "                  Your current script default is: $OUTPUT_TYPE\n";
	print "--quality n -q n  Where n is a number between 1 and 10, 10 being the best quality (ogg).\n";
	print "                  mp3 supports: 0-9 (variable bit rate: quality 0 biggest/highest, 9 smallest/lowest)\n";
	print "                  Your current script default is: $QUALITY\n";
	print "--source -s       The path to the top-most directory containing your source files (eg, flac).\n";
	print "                  Your current script default is: $DIR_PREFIX_SOURCE\n";
	print "--version -v      Show acxi version.\n\n";
	print $LINE_SMALL;
	print "User Configs: \$HOME/.acxi.conf or /etc/acxi.conf\n";
	print "Requires this syntax (any user modifiable variable can be used)\n";
	print "DIR_PREFIX_SOURCE=/home/me/music/flac\n";
	print "Do not use the \$ or \", \' in the config data\n";
	print "\n";
	
	exit 0;
}

sub print_version {
	print "You are using acxi version: $SCRIPT_VERSION\n";
	print "Script date: $SCRIPT_DATE\n";
	exit 0;
}

sub set_config_data {
	my @configFiles; $file;
	# set list of supported config files
	@configFiles = ( '/etc/acxi.conf', "$ENV{HOME}/.acxi.conf" );
	foreach $file (@configFiles) {
		open (CONFIG, "$file");
		while (<CONFIG>) {
			chomp;                  # no newline
			s/#.*//;                # no comments
			s/^\s+//;               # no leading white
			s/\s+$//;               # no trailing white
			next unless length;     # anything left?
			my ($var, $value) = split(/\s*=\s*/, $_, 2);
			no strict 'refs';
			$$var = $value;
		}
	}
}

sub set_user_types {
	# if --copy/-c is set, then use that data instead of default copy types
	if ( $USER_TYPES ){
		# 	@COPY_TYPES = split( /,/, join( ',', $USER_TYPES ) );
		@COPY_TYPES = split( /,/, $USER_TYPES );
	}
}

sub validate_in_out_types {
	my $bTypeUnsupported; $errorMessage;
	$bTypeUnsupported = '';
	print $largeLine;
	print "Checking input and output types...";
	if ( $INPUT_TYPE !~ m/^(flac|wav|raw)$/ ){
		$bTypeUnsupported = 'true';
		$errorMessage = "\n\tThe input type you entered is not supported: $INPUT_TYPE\n";
	}
	if ( $OUTPUT_TYPE !~ m/^(ogg|mp3)$/ ){
		$bTypeUnsupported = 'true';
		$errorMessage = "$errorMessage\n\tThe output type you entered is not supported: $OUTPUT_TYPE\n";
		if ( $OUTPUT_TYPE eq 'mp3' && $INPUT_TYPE ne 'flac' ){
			$bTypeUnsupported = 'true';
			$errorMessage = "$errorMessage\n\tThe output type $OUTPUT_TYPE you entered currently only supports input type: flac\n";
		}
	}
	if ( $bTypeUnsupported ){
		print "\nError 2 - Exiting.$errorMessage\n";
		exit 2
	}
	else {
		print "\t\tvalid: $INPUT_TYPE(in) $OUTPUT_TYPE(out)\n";
	}
}

#### Functions ####
sub validate_src_dest_directories {
	my $bMissingDir; $missingDirs;
	$bMissingDir = ''; # no native t/f boolean?

	print $LINE_HEAVY;
	print "Checking script data for errors...\n";
	print $LINE_LARGE;
	print "Checking source / destination directories...";
	if ( ! -d "$DIR_PREFIX_SOURCE" ){
		$bMissingDir = 'true';
		$missingDirs = "\n\tSource Directory: $DIR_PREFIX_SOURCE";
	}
	if ( ! -d "$DIR_PREFIX_DEST" ){
		$bMissingDir = 'true';
		$missingDirs = "$missingDirs\n\tDestination Directory: $DIR_PREFIX_DEST";
	}

	if ( $bMissingDir ) {
		print "\nError 1 - Exiting.\nThe paths for the following required directories do not exist on your system:";
		print "$missingDirs";
		print "\nUnable to continue. Please check the directory paths you provided.\n\n";
		exit 1;
	} 
	else {
		print "\tdirectories: exist\n";
	}
}

sub validate_application_paths {
	my $bMissingApp; $errorMessage; $appPath; 
	$bMissingApp = '';
	print "Checking audio conversion tool path...";
	
	if ( $OUTPUT_TYPE eq 'ogg' ) {
		$appPath = $COMMAND_OGG;
		if ( ! -x "$COMMAND_OGG" ) {
			$bMissingApp = 'true';
			$errorMessage = "\n\tEncoding application not available: $appPath\n";
		}
	}
	if ( $OUTPUT_TYPE eq 'mp3' ) {
		$appPath = $COMMAND_LAME;
		if ( ! -x "$COMMAND_LAME" ) {
			$bMissingApp = 'true';
			$errorMessage = "$errorMessage\n\tEncoding application not available: $appPath\n";
		}
	}
	if ( $OUTPUT_TYPE eq 'mp3' && $INPUT_TYPE eq 'flac' ) {
		$appPath = $COMMAND_FLAC;
		if ( ! -x "$COMMAND_FLAC" ) {
			$bMissingApp = 'true';
			$errorMessage = "$errorMessage\n\tInput processor $appPath needed by lame not available.\n";
		}
	}
	elsif ( $OUTPUT_TYPE eq 'mp3' && $INPUT_TYPE ne 'flac' ) {
		$appPath = $COMMAND_LAME;
		$bMissingApp = 'true';
		$errorMessage = "$errorMessage\n\t$appPath currently only supports flac as input.\n";
	}
	
	if ( $bMissingApp ) {
		print "\nError 3 - Exiting.$errorMessage\n";
		exit 3;
	}
	else {
		print "\t\tavailable: $appPath\n";
	}
}

sub validate_quality{
	my $bBadQuality; $errorMessage;
	$bBadQuality = '';
	print "Checking quality support for $OUTPUT_TYPE...";
	if ( $OUTPUT_TYPE eq 'ogg' && $QUALITY !~ m/^([1-9]|10)$/ ) {
		$bBadQuality = 'true';
		$errorMessage = "$errorMessage\n\t$OUTPUT_TYPE only supports 1-10 quality. You entered: $QUALITY\n";
	}
	elsif ( $OUTPUT_TYPE eq 'mp3' && $QUALITY !~ m/^([0-9])$/ ) {
		$bBadQuality = 'true';
		$errorMessage = "$errorMessage\n\t$OUTPUT_TYPE only supports 0-9 quality. You entered: $QUALITY\n";
	}
	
	if ( $bBadQuality ) {
		print "\nError 4 - Exiting.$errorMessage\n";
		exit 4;
	}
	else {
		print "\t\tsupported: $QUALITY\n";
	}
}

# Recreate the directory hierarchy.
sub sync_collection_directories {
	my $dir; @dirs; $bDirCreated;
	$bDirCreated = '';
	@dirs = `cd "$DIR_PREFIX_SOURCE" && find . -type d -print`;
	
	print $LINE_LARGE;
	print "Checking to see if script needs to create new destination directories...\n";
	
	foreach $dir (@dirs) {
		$dir =~ s/\n$//;
		$dir =~ s/^\.\///;
		
		# check to see if the destination dir already exists
		if ( !(stat ("$DIR_PREFIX_DEST/$dir")) ) {
			# stat failed so create the directory
			print $LINE_SMALL;
			print "CREATING NEW DIRECTORY:\n\t$DIR_PREFIX_DEST/$dir\n";
			$dir =~ s/\`/\'/g;
			$result = `cd "$DIR_PREFIX_DEST" && mkdir -p "$dir"`;
			$bDirCreated = 'true';
			$B_DEST_CHANGED = 'true';
		}
	}
	if ( ! $bDirCreated ){
		print "No new directories required. Continuing...\n";
	}
}

sub sync_collection_files {
	my $file; @files; $destinationFile; $srcInfo; $srcModTime; $destInfo; $destModTime;
	my $inFile; $outFile; $bFileCreated;
	@files = @_; 
	$file = '';
	$outFile = '';
	$inFile = '';
	$destinationFile = '';
	$bFileCreated = '';
	$srcInfo = ''; 
	$srcModTime = ''; 
	$destInfo = ''; 
	$destModTime = '';

	foreach $file (@files) {
		$file =~ s/\n$//;
		$file =~ s/^\.\///;
		#print "F: $DIR_PREFIX_DEST/$file\n";
		
		# Figure out what the destination file would be...
		$destinationFile = $file;
		if ( $EXTENSION eq $INPUT_TYPE ){
			$destinationFile =~ s/\.$INPUT_TYPE$/\.$OUTPUT_TYPE/;
		}
		#print "D: $destinationFile\n";

		# Now stat the destinationFile, and see if it's date is more recent
		# than that of the original file. If so, we re-encode.
		# We also re-encode if the user supplied --force
		$srcInfo = stat ("$DIR_PREFIX_SOURCE/$file");

		$srcModTime = $srcInfo->mtime;
		$destInfo = stat ("$DIR_PREFIX_DEST/$destinationFile");
		if ( $destInfo ) {
			$destModTime = $destInfo->mtime;
			# print "DEST_MOD: $destModTime :: SRC_MOD: $srcModTime :: FORCE: $force\n"; 
# 		} else {
# 			print "NOT EXISTS: $destinationFile \n"; 
# 			print "P1: $file ==> \n\t$destinationFile\n"; 
		}
		# If the destination file does not exist, or the user specified force,
		# or the srcfile is more recent then the dest file, we encode.
		if ( !$destInfo || $FORCE || ( $srcModTime > $destModTime) ) {
			$file =~ s/\`/\'/g;
			$inFile = "$DIR_PREFIX_SOURCE/$file" . "c";
			chop ($inFile);
			$outFile = "$DIR_PREFIX_DEST/$destinationFile" . "g";
			chop ($outFile);
			print $LINE_SMALL;
			if ( $EXTENSION eq $INPUT_TYPE ){
				print "ENCODE: $inFile ==> \n";
				print "        $outFile\n"; 
				$inFile =~ s/\0//g; 
				$outFile =~ s/\0//g;
				if ( $OUTPUT_TYPE eq 'ogg' ){
					$result = `$COMMAND_OGG -q $QUALITY -o "$outFile" "$inFile"`;
				}
				elsif ( $OUTPUT_TYPE eq 'mp3' ){
					$result = `$COMMAND_FLAC -d -o - "$inFile" | $COMMAND_LAME -V $QUALITY -h - "$outFile"`;
				}
			} 
			else {
				print "COPY: $inFile ==> \n";
				print "      $outFile\n"; 
				$inFile =~ s/\0//g; 
				$outFile =~ s/\0//g;
				$result = `cp -f "$inFile" "$outFile"`;
			}
			$bFileCreated = 'true';
			$B_DEST_CHANGED = 'true';
		} 
	}
	if ( ! $bFileCreated ){
		print "No files to process of type: $EXTENSION\n";
	}
}

sub sync_music_collections {
	my @extensions; @extensionFiles;
	$EXTENSION = '';
	# set the @COPY_TYPES if required by -c/--copy override
	&set_user_types;
	@extensions = ( @COPY_TYPES, $INPUT_TYPE );
	print $LINE_HEAVY;
	print "Syncing $DIR_PREFIX_SOURCE (source) with\n";
	print "        $DIR_PREFIX_DEST (destination)...\n";
	&sync_collection_directories;
	foreach $EXTENSION (@extensions) {
		@extensionFiles = `cd "$DIR_PREFIX_SOURCE" && find . -type f -iname "*.$EXTENSION" -print`;
		print $LINE_LARGE;
		print "PROCESSING DATA TYPE: $EXTENSION\n";
		&sync_collection_files (@extensionFiles);
	}
}

sub completion_message {
	print $LINE_HEAVY;
	if ( $B_DEST_CHANGED ) {
		print "All done updating. Enjoy your music!\n\n";
	}
	else {
		print "There was nothing to update today in your collection.\n\n";
	}
	exit 0;
}

### SCRIPT EXECUTION ###
# get defaults from user config files if present
&set_config_data;
# Get Options and set values, this overrides the defaults
# from top globals and config files
GetOptions (
	"c|copy:s" => \$USER_TYPES,
	"d|destination:s" => \$DIR_PREFIX_DEST,
	"f|force" => \$FORCE,
	"h|help|?" => \&print_help,
	"i|input:s" => \$INPUT_TYPE,
	"o|output:s" => \$OUTPUT_TYPE,
	"q|quality:s" => \$QUALITY, # validate later
	"s|source:s" => \$DIR_PREFIX_SOURCE,
	"v|version" => \&print_version
);

# then exucute and process
&validate_src_dest_directories;
&validate_in_out_types;
&validate_quality;
&validate_application_paths;
&sync_music_collections;
&completion_message;

###**EOF**###
