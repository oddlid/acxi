#!/usr/bin/perl
#########################################################################
# Script Name: acxi - audio conversion script
# Script Version: 2.8.0
# Script Date: 23 March 2011
#########################################################################
# fork to acxi:
# Copyright (c) 2010-11 - Harald Hope - smxi.org 
# home page: http://techpatterns.com/forums/about1491.html
# download url: http://smxi.org/acxi
#
# Based on flac2ogg.pl
# Copyright (c) 2004 - Jason L. Buberel - jason@buberel.org
# Copyright (c) 2007 - Evan Boggs - etboggs@indiana.edu
# home page: http://www.buberel.org/linux/batch-flac-to-ogg-converter.php
#
# Modified: 2011-03-23 - Odd Eivind Ebbesen - www.oddware.net - <oddebb at gmail dot com>
# - Added functionality for Flac conversion to MP3, preserving tags.
#########################################################################
# This program is free software; you can redistribute it and/or modify it under
# the terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful, but WITHOUT
# ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
# FOR A PARTICULAR PURPOSE. See the GNU General Public License for more details.
#
# Get the full text of the GPL here: http://www.gnu.org/licenses/gpl.txt
#########################################################################
#########################################################################
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
our $B_FORCE;
our $B_QUIET;
our $B_SILENT;
our $COMMAND_FLAC;
our $COMMAND_LAME;
our $COMMAND_OGG;
our @COPY_TYPES;
our $DIR_PREFIX_DEST;
our $DIR_PREFIX_SOURCE;
our $EXTENSION;
our $INPUT_TYPE;
our $LINE_HEAVY;
our $LINE_LARGE;
our $LINE_SMALL;
our $OUTPUT_TYPE;
our $PRINT_LINE_HEAVY;
our $PRINT_LINE_LARGE;
our $PRINT_LINE_SMALL;
our $QUALITY;
our $SCRIPT_DATE;
our $SCRIPT_VERSION;
our $SILENT_ARG_FO;
our $SILENT_ARG_L;
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
# metaflac is required ONLY for flac to mp3, to copy over the ID3 tags
# If you are not going to make MP3s, only OGG files for output, you do not need this.
$COMMAND_METAFLAC = '/usr/bin/metaflac';

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
# You can turn these to always on either here or in config file by setting to 'true': 
# for example: $B_QUIET = 'true';
# or in config file (note no $, ;, and no quotes): B_QUIET=true
$B_QUIET = '';
$B_SILENT = '';
### END USER MODIFIABLE VARIABLES ###

### ASSIGN CONSTANTS ###
$LINE_HEAVY = "===========================================================================\n";
$LINE_SMALL = "-----------------------------------------------------------------\n";
$LINE_LARGE = "---------------------------------------------------------------------------\n";
$SCRIPT_DATE = '23 March 2011';
$SCRIPT_VERSION = '2.8.0';

### MAIN - FUNCTIONS ###
sub print_help {
	# so it shows the user config data if present
	&set_config_data; 
	# but this should override the config data so follows
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
	print "--quality n -q n  For ogg: n can be 1-10, 10 is the biggest file/highest quality.\n";
	print "                  For mp3: n can be 0-9 (variable bit rate), 0 biggest file/highest quality.\n";
	print "                  Your current script default is: $QUALITY\n";
	print "--quiet           Turns off verbosity of flac/oggenc/lame for MP3 or OGG output.\n";
	print "--silent          Sets --quiet, and minimizes extra data printout as well.\n";
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

sub set_display_output_data {
	if ( $B_QUIET || $B_SILENT ) {
		if ( $OUTPUT_TYPE eq 'mp3' ) {
			$SILENT_ARG_FO = '--silent'; # flac ouput 
			$SILENT_ARG_L = '--silent'; # lame output
		}
		elsif ( $OUTPUT_TYPE eq 'ogg' ) {
			$SILENT_ARG_FO = '--quiet'; # for oggenc output
		}
	}
	if ( $B_SILENT ) {
		$PRINT_LINE_HEAVY = '';
		$PRINT_LINE_LARGE = '';
		$PRINT_LINE_SMALL = '';
	}
	else {
		$PRINT_LINE_HEAVY = 'print $LINE_HEAVY';
		$PRINT_LINE_LARGE = 'print $LINE_LARGE';
		$PRINT_LINE_SMALL = 'print $LINE_SMALL';
	}
}

sub validate_in_out_types {
	my $bTypeUnsupported; $errorMessage;
	$bTypeUnsupported = '0';
	eval $PRINT_LINE_LARGE;
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
	$bMissingDir = '0'; # no native t/f boolean?

	eval $PRINT_LINE_HEAVY;
	print "Checking script data for errors...\n";
	eval $PRINT_LINE_LARGE;
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
	$bMissingApp = '0'; # no barewords true/false, 'false' is true... 
	$errorMessage = '';
	$appPaths = '';
	print "Checking audio conversion tool path...";
	
	if ( $OUTPUT_TYPE eq 'ogg' ) {
		$appPaths .= "$COMMAND_OGG ";
		if ( ! -x "$COMMAND_OGG" ) {
			$bMissingApp = 'true';
			$errorMessage = "\n\tEncoding application not available: $COMMAND_OGG\n";
		}
	}
	if ( $OUTPUT_TYPE eq 'mp3' ) {
		$appPaths .= "$COMMAND_LAME ";
		if ( ! -x "$COMMAND_LAME" ) {
			$bMissingApp = 'true';
			$errorMessage .= "\n\tEncoding application not available: $COMMAND_LAME\n";
		}
	}
	if ( $OUTPUT_TYPE eq 'mp3' && $INPUT_TYPE eq 'flac' ) {
		$appPaths .= "$COMMAND_FLAC ";
		if ( ! -x "$COMMAND_FLAC" ) {
			$bMissingApp = 'true';
			$errorMessage .= "\n\tInput processor $COMMAND_FLAC needed by lame not available.\n";
		}
		$appPaths .= "$COMMAND_METAFLAC ";
		# Added: Odd @2011-03-23 01:55:28
		if ( ! -x "$COMMAND_METAFLAC" ) {
			$bMissingApp = 'true';
			$errorMessage .= "\n\t$COMMAND_METAFLAC not found. Required to copy ID3 tags from Flac to MP3.\n";
		}
	}
	elsif ( $OUTPUT_TYPE eq 'mp3' && $INPUT_TYPE ne 'flac' ) {
		$bMissingApp = 'true';
		$errorMessage .= "\n\t$COMMAND_LAME currently only supports flac as input.\n";
	}
	
	if ( $bMissingApp ) {
		print "\nError 3 - Exiting.$errorMessage\n";
		exit 3;
	}
	else {
		print "\t\tavailable: $appPaths\n";
	}
}

sub validate_quality{
	my $bBadQuality; $errorMessage;
	$bBadQuality = '0';
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
	$bDirCreated = '0';
	@dirs = `cd "$DIR_PREFIX_SOURCE" && find . -type d -print`;
	
	eval $PRINT_LINE_LARGE;
	if ( ! $B_SILENT ) {
		print "Checking to see if script needs to create new destination directories...\n";
	}
	else {
		print "Update destination directories... ";
	}
	
	foreach $dir (@dirs) {
		$dir =~ s/\n$//;
		$dir =~ s/^\.\///;
		
		# check to see if the destination dir already exists
		if ( !(stat ("$DIR_PREFIX_DEST/$dir")) ) {
			# stat failed so create the directory
			eval $PRINT_LINE_SMALL;
			if ( ! $B_SILENT ) {
				print "CREATING NEW DIRECTORY:\n\t$DIR_PREFIX_DEST/$dir\n";
			}
			else {
				print "\nCreating new directory: $dir";
			}
			$dir =~ s/\`/\'/g;
			$result = `cd "$DIR_PREFIX_DEST" && mkdir -p "$dir"`;
			$bDirCreated = 'true';
			$B_DEST_CHANGED = 'true';
		}
	}
	if ( ! $bDirCreated ){
		if ( ! $B_SILENT ) {
			print "No new directories required. Continuing...\n";
		}
		else {
			print "none required.";
		}
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
	$bFileCreated = '0';
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
		if ( !$destInfo || $B_FORCE || ( $srcModTime > $destModTime) ) {
			$file =~ s/\`/\'/g;
			$inFile = "$DIR_PREFIX_SOURCE/$file" . "c";
			chop ($inFile);
			$outFile = "$DIR_PREFIX_DEST/$destinationFile" . "g";
			chop ($outFile);
			eval $PRINT_LINE_SMALL;
			if ( $EXTENSION eq $INPUT_TYPE ){
				if ( ! $B_SILENT ) {
					print "ENCODE: $file ==> \n";
					print "        $destinationFile\n"; 
				}
				else {
					# add line break only when file exists
					print "\nEncoding $file to $OUTPUT_TYPE...";
				}
				$inFile =~ s/\0//g; 
				$outFile =~ s/\0//g;
				if ( $OUTPUT_TYPE eq 'ogg' ){
					$result = `$COMMAND_OGG $SILENT_ARG_FO -q $QUALITY -o "$outFile" "$inFile"`;
				}
				elsif ( $OUTPUT_TYPE eq 'mp3' ){
					# Modified: Odd @2011-03-23 01:51:26 - Include ID3 copying
					$cmd = &flac2mp3_cmd( $COMMAND_FLAC, "$inFile", $COMMAND_LAME, $QUALITY, "$outFile" );
					$result = `$cmd`;
				}
			} 
			else {
				if ( ! $B_SILENT ) {
					print "COPY: $file ==> \n";
					print "      $outFile\n"; 
				}
				else {
					print "\nCopying $file...";
				}
				$inFile =~ s/\0//g; 
				$outFile =~ s/\0//g;
				$result = `cp -f "$inFile" "$outFile"`;
			}
			$bFileCreated = 'true';
			$B_DEST_CHANGED = 'true';
		} 
	}
	if ( ! $bFileCreated ){
		if ( ! $B_SILENT ) {
			print "No files to process of type: $EXTENSION\n";
		}
		else {
			print "none found.";
		}
	}
}

# Added: Odd @2011-03-23 01:52:17
sub get_flac_tags {
	# For this function to work reliably, it should be passed tag queries in the order of:
	# artist, album, title, genre, date, tracknumber
	my ($ifile, @tags) = @_;
	my @origtags;
	@origtags = `$COMMAND_METAFLAC \"$ifile\" --show-tag=\"$tags[0]\" --show-tag=\"$tags[1]\" --show-tag=\"$tags[2]\" --show-tag=\"$tags[3]\" --show-tag=\"$tags[4]\" --show-tag=\"$tags[5]\"`;
	foreach (@origtags) {
		$_ =~ s/.*=//g;
	}
	return @origtags;
}

# Added: Odd @2011-03-23 01:52:31
sub flac2mp3_cmd {
	my ($flac, $ifile, $lame, $qual, $ofile) = @_;
	my $lame_params;
	my $cmd;
	my @tags = &get_flac_tags("$ifile", "ARTIST", "ALBUM", "TITLE", "GENRE", "DATE", "TRACKNUMBER");
	chomp(@tags);
	$lame_params = "--ta \"$tags[0]\" --tl \"$tags[1]\" --tt \"$tags[2]\" --tg \"$tags[3]\" --ty \"$tags[4]\" --tn \"$tags[5]\" - \"$ofile\"";
	$cmd = "$flac $SILENT_ARG_FO -d -c \"$ifile\" | $lame $SILENT_ARG_L -h -V $qual $lame_params";
	return $cmd;
}

sub sync_music_collections {
	my @extensions; @extensionFiles;
	$EXTENSION = '';
	# set the @COPY_TYPES if required by -c/--copy override
	&set_user_types;
	@extensions = ( @COPY_TYPES, $INPUT_TYPE );
	eval $PRINT_LINE_HEAVY;
	if ( ! $B_SILENT ) {
		print "Syncing $DIR_PREFIX_DEST (destination) with\n";
		print "        $DIR_PREFIX_SOURCE (source)...\n";
	}
	else {
		print "Starting sync of $DIR_PREFIX_DEST to $DIR_PREFIX_SOURCE...\n";
	}
	&sync_collection_directories;
	foreach $EXTENSION (@extensions) {
		@extensionFiles = `cd "$DIR_PREFIX_SOURCE" && find . -type f -iname "*.$EXTENSION" -print`;
		eval $PRINT_LINE_LARGE;
		if ( ! $B_SILENT ) {
			print "PROCESSING DATA TYPE: $EXTENSION\n";
		}
		else {
			print "\nProcessing $EXTENSION data type...  ";
		}
		&sync_collection_files (@extensionFiles);
	}
}

sub completion_message {
	eval $PRINT_LINE_HEAVY;
	if ( $B_DEST_CHANGED ) {
		if ( ! $B_SILENT ) {
			print "All done updating. Enjoy your music!\n";
		}
		else {
			print "\nUpdating completed. Enjoy your music!\n";
		}
	}
	else {
		print "\nThere was nothing to update today in your collection.\n";
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
	"f|force" => \$B_FORCE,
	"h|help|?" => \&print_help,
	"i|input:s" => \$INPUT_TYPE,
	"o|output:s" => \$OUTPUT_TYPE,
	"quiet" => \$B_QUIET,
	"q|quality:s" => \$QUALITY, # validate later
	"s|source:s" => \$DIR_PREFIX_SOURCE,
	"silent" => \$B_SILENT,
	"v|version" => \&print_version
);

# then exucute and process
&set_display_output_data;
&validate_src_dest_directories;
&validate_in_out_types;
&validate_quality;
&validate_application_paths;
&sync_music_collections;
&completion_message;

###**EOF**###
