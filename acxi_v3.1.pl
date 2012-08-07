#!/usr/bin/env perl
# A totally new attempt on this thing...
# Odd Eivind Ebbesen, 2012-08-07 10:09:51

use 5.012;
use strict;
use warnings;
use mro 'c3';

package Acxi::Logger {
   # Helper class for logging

   use constant ERR    => 0;
   use constant WARN   => 1;
   use constant NOTICE => 2;
   use constant INFO   => 3;
   use constant DEBUG  => 4;

   sub new {
      my $class = shift;
      my $level = shift;
      my $self  = bless({}, $class);
      $self->{CUR_LVL} = $level;
      return $self;
   }

   sub _log_time() {
      my ($sec, $min, $hour, $day, $mon, $year) = localtime;
      return sprintf("%04d-%02d-%02d_%02d:%02d:%02d: ", $year + 1900, $mon + 1, $day, $hour, $min, $sec);
   }

   sub _pp {
      # Prepend given string to first arg
      my $ins  = shift;
      #my $argv = shift;
      $_[0] = "- $ins: " . $_[0];
   }

   sub log {
      my $self = shift;
      my ($lvl, $msg, @params) = @_;
      return if ($lvl > $self->{CUR_LVL});
      chomp($msg);
      $msg = sprintf($msg, @params) if (scalar(@params));
      # levels warn and err go to STDERR, the rest to STDOUT
      if ($self->{CUR_LVL} < NOTICE) {
         print(STDERR _log_time(), $msg, "\n");
      }
      else {
         print(STDOUT _log_time(), $msg, "\n");
      }
   }

   sub debug {
      my $self = shift;
      &_pp('DEBUG', @_);
      $self->log(DEBUG, @_);
   }

   sub info {
      my $self = shift;
      _pp('INFO', @_);
      $self->log(INFO, @_);
   }

   sub notice {
      my $self = shift;
      _pp('NOTICE', @_);
      $self->log(NOTICE, @_);
   }

   sub warn {
      my $self = shift;
      _pp('WARNING', @_);
      $self->log(WARN, @_);
   }

   sub error {
      my $self = shift;
      _pp('ERROR', @_);
      $self->log(ERR, @_);
   }

};

#---

package Acxi;

$Acxi::VERSION = $main::VERSION = '3.0.1';

use Data::Dumper;
use Getopt::Long qw(:config auto_version auto_help no_ignore_case);
use Pod::Usage;
use IO::Handle;
use IO::File;
use File::Find;
use File::Basename;
use File::Spec;
use Cwd;
#use Errno;



our $VERSION;

my $_config = {
   cfgfile_system => '/etc/acxi.conf',
   cfgfile_user   => "$ENV{HOME}/.acxi.conf",
   user_settings  => {
      LOG_LEVEL         => 4,   # see valid values in Acxi::Logger (at the top of the file)
      QUALITY           => 7,
      DIR_PREFIX_SOURCE => "$ENV{HOME}",
      DIR_PREFIX_DEST   => "$ENV{HOME}/acxi_output",
      INPUT_TYPE        => 'flac',
      OUTPUT_TYPE       => 'mp3',
      USER_TYPES        => 'png,jpg,jpeg',
      COMMAND_OGG       => 'oggenc',
      COMMAND_LAME      => 'lame',
      COMMAND_FLAC      => 'flac',
      COMMAND_METAFLAC  => 'metaflac',
      COMMAND_FILE      => 'file',
   },
   mime_types => {
      flac => 'audio/x-flac',
      ogg  => 'application/ogg',
      wav  => 'audio/x-wav',
      mp3  => 'audio/mpeg',
      #raw  => undef,
   },
};

my $_rx_srcdir;
my $_rx_dstdir;;

my $_l = Acxi::Logger->new($_config);

sub _load_config($) {
   my $cfile = shift;
   return unless (-r $cfile);
   my $fh = IO::File->new($cfile, O_RDONLY);
   return unless (defined($fh));
   my $rx_valid_line = qr/\s*([A-Z_]+)\s*=\s*(\S+)/;
   while (<$fh>) {
      chomp;
      my ($k, $v) = $_ =~ /$rx_valid_line/;
      next unless (defined($k) && defined($v));
      $_config->{user_settings}{$k} = $v;
   }
   undef $fh;    # closes the file

   # make USER_TYPES an array for easier use later
   my $ut = \$_config->{user_settings}{USER_TYPES};
   if (defined($$ut)) {
      $$ut = [ split(/,/, $$ut) ];
   }
   $_l->debug(Dumper($_config->{user_settings}));
}

sub _get_mime($) {
   my $file = shift;
   chomp(my $type = qx/$_config->{user_settings}{COMMAND_FILE} -bi "$file"/);
   $type =~ s/;.*//;
   return $type;
}

sub _check_mime {
   my $type = shift;
   my $file = shift;
   return (_get_mime($file) eq $_config->{mime_types}{$type});
}

sub _is_flac($) {
   return _check_mime('flac', shift);
}

sub _is_mp3($) {
   return _check_mime('mp3', shift);
}

sub _is_ogg($) {
   return _check_mime('ogg', shift);
}

sub _is_wav($) {
   return _check_mime('wav', shift);
}

sub _x(\$) {
   # Returns whether a given path points to a valid executable
   my $file_ref = shift;
   return (-X $$file_ref);
}

sub _locate_ext_binaries() {
   my @paths = split(/:/, $ENV{PATH});    # cache this before loop
   foreach my $cmd (qw/FLAC METAFLAC OGG LAME FILE/) {
      my $key = 'COMMAND_' . $cmd;
      my $val = \$_config->{user_settings}{$key};
      next unless defined($$val);         # no value means disabled
      next if _x($val);                   # the value is a full, valid path to an executable, skip
      my $filename = fileparse($$val);
      foreach (@paths) {
         my $abs_path = File::Spec->catfile($_, $filename);
         if (_x($abs_path)) {
            $$val = $abs_path;
            last;
         }
      }
   }
   $_l->debug(Dumper($_config->{user_settings}));
}

sub _get_tags_flac($) {
   my $file = shift;
   return unless _is_flac($file);
   my %tags;
   open(my $fh, "-|", qq($_config->{user_settings}{COMMAND_METAFLAC} --no-utf8-convert --export-tags-to=- "$file"))
     || die;
   while (defined(my $line = <$fh>)) {
      chomp($line);
      my ($k, $v) = split(/=/, $line);
      $tags{$k} = $v;
   }
   close($fh);
   $_l->debug(Dumper(\%tags));
   return \%tags;
}

sub _init {
   _load_config($_config->{cfgfile_user});
   _locate_ext_binaries();
   $_rx_srcdir = qr/$_config->{user_settings}{DIR_PREFIX_SOURCE}/;
   $_rx_dstdir = qr/$_config->{user_settings}{DIR_PREFIX_DEST}/;
}

sub _find_flt {
   #return unless (! -l && -d && !/^\.{1,2}$/ && !/\n$/);
   my $f = {
      full => $File::Find::name,
      dir  => $File::Find::dir,
      file => $_
   };
   $_l->debug(Dumper($f));
   my ($newdir) = $File::Find::name =~ s/$_rx_srcdir/$_rx_dstdir/;
   $_l->debug("Create new directory: %s", $newdir);
}

### 

_init();
find(\&_find_flt, "/home/oddee/tmp");

__END__

=pod

=head1 NAME

acxi - Audio Conversion script

=head1 SYNOPSIS

acxi [options]

=head1 DESCRIPTION

Bla, bla, bla

=head1 AUTHOR

Odd Eivind Ebbesen <odd@oddware.net>
Harald Hope <>

=head1 VERSION

v3.0.1 @ 2012-08-07 10:49:19

=head1 SEE ALSO

acxi v2.x : http://techpatterns.com/forums/about1491.html

=cut

