#!/usr/bin/env perl
# vim: tabstop=3 softtabstop=3 shiftwidth=3 tw=0

#-------------------------------------------------------------------------------
# acxi-mt_v3.pl
# New attempt on acxi, with multithreading.
#
# Odd Eivind Ebbesen, 2011-07-25 15:03:08
#-------------------------------------------------------------------------------

use strict;
use warnings;

BEGIN {
   use Config;
   my $threadlevel = -1;
   if ($Config{usethreads}) {
      $threadlevel = 1;
   }
   if ($Config{useithreads}) {
      $threadlevel = 2;
   }
   if ($Config{use5005threads}) {
      $threadlevel = 0;
   }
   if ($threadlevel < 1) {
      print("Sorry, your Perl is not compiled with proper threading.\n");
      exit 78;
   }
   else {
      print("Threading is OK (level: $threadlevel), good to go!\n");
   }
}
# if we got here, threads are in place and ok
use threads;
use threads::shared;
use Thread::Queue;
use Getopt::Long qw(:config auto_version auto_help no_ignore_case);
use Pod::Usage;
use File::Find;
use File::Basename;
use File::Spec;
use Cwd;
use Data::Dumper;

# G = global. Hash for all global settings/values.
my %_G = (
   EX => {  # Exception/exit codes
      OK          => 0,   # successful termination 
      _BASE       => 64,  # base value for error messages 
      USAGE       => 64,  # command line usage error 
      DATAERR     => 65,  # data format error 
      NOINPUT     => 66,  # cannot open input 
      NOUSER      => 67,  # addressee unknown 
      NOHOST      => 68,  # host name unknown 
      UNAVAILABLE => 69,  # service unavailable 
      SOFTWARE    => 70,  # internal software error 
      OSERR       => 71,  # system error (e.g., can't fork) 
      OSFILE      => 72,  # critical OS file missing 
      CANTCREAT   => 73,  # can't create (user) output file 
      IOERR       => 74,  # input/output error 
      TEMPFAIL    => 75,  # temp failure; user is invited to retry 
      PROTOCOL    => 76,  # remote error in protocol 
      NOPERM      => 77,  # permission denied 
      CONFIG      => 78,  # configuration error 
      _MAX        => 78   # maximum listed value 
   }, 
   LOG => { # Same name for levels as in Log4perl
      OFF   => 0,
      FATAL => 0, 
      ERROR => 0, 
      WARN  => 0, 
      INFO  => 0, 
      DEBUG => 0, 
      TRACE => 0, 
      ALL   => 0
   }
);
#-------------------------------------------------------------------------------
#{
#   package Acxi_worker; 
#   sub hello {
#      print('Hello from ', __PACKAGE__, "\n");
#   }
#
#   sub enqueue {
#      my ($srcdir, $dstdir) = @_;
#      if (defined($srcdir) && defined($dstdir)) {
#         threads->create(\&_exec, $srcdir, $dstdir);
#      }
#   }
#
#   sub _exec {
#      sleep(int(rand(20)));
#      threads->yield();
#      printf("In a new thread (ID: %d), with srcdir: %s and dstdir: %s\n", 
#         threads->tid(), $_[0], $_[1]);
#      print('-' x threads->tid(), "\n");
#   }
#
#   sub cleanup {
#      foreach my $t (threads->list()) {
#         $t->join();
#      }
#   }
#   1;
#}   # END Acxi_worker

{
   package Acxi_mediaFile;
   use strict;
   use warnings;
   use Data::Dumper;

   use constant {
      MP3   => 0x4D5033,   # 'MP3' in hex
      OGG   => 0x4F4747,   # 'OGG' in hex
      WAV   => 0x574156,   # 'WAV' in hex
      RAW   => 0x524156,   # 'RAW' in hex
      FLAC  => 0x0DDEE     # ...who wrote this...?
   };

   # static class data
   my %_x = (
      lame     => undef,
      flac     => undef,
      file     => undef,
      oggenc   => undef,
      metaflac => undef
   );
   my $_output_format = undef;

   # stub for constructor
   sub new {
      # This inits the object instance with the required info.
      # Expected parameters:
      # - hash reference, with these keywords accepted:
      #   * filename - full path to the flac file
      my $this    = shift;
      my $class   = ref($this) || $this;
      my $self    = {};
      bless($self, $class);

      #$self->{err} = 0; # OK if 0, else, something wrong...

      my $arg_href = shift || \{}; # should be a hash ref 
      if (!ref($arg_href) eq 'HASH') {
         print(__PACKAGE__ . "::new() : Not a HASH reference\n");
      }
      if (defined($arg_href->{filename}) && (-r $arg_href->{filename})){
         $self->{filename} = $arg_href->{filename};
      }
      if (defined($arg_href->{dstdir}) && (-d $arg_href->{dstdir} && -w $arg_href->{dstdir})){
         $self->{dstdir} = $arg_href->{dstdir};
      }

      if (defined($self->{filename})) {
         $self->_set_mime_type();
         $self->_load_flac_tags();
         #$self->_convert();
      }

      print(Dumper($self), "\n");

      return $self;
   }  # END new()

   sub set_extbins {
      my $xhref = shift;
      #print(Dumper($xhref), "\n");
      while (my ($name, $path) = each(%$xhref)) {
         if (-x $path) {
            $_x{$name} = $path;
         }
      }
   }

   sub set_output_format {
      my $f = shift;
      if ($f == MP3 || $f == OGG || $f == WAV || $f == RAW || $f == FLAC) {
         $_output_format = $f;
      }
   }

   sub _set_mime_type {
      my $self = shift;
      my $mtype;
      if (defined($_x{file})) {
         $mtype = `$_x{file} -bi "$self->{filename}"`;
         chomp($mtype);
         $mtype =~ s/;.*//g;
         $self->{mimetype} = $mtype;
      }
   }

   sub _load_flac_tags {
      my $self = shift;
      return unless ($self->{mimetype} eq 'audio/x-flac');
      my $cmd;
      my @tagnames = qw(ARTIST ALBUM TITLE GENRE DATE TRACKNUMBER);
      $cmd = $_x{metaflac} . qq( "$self->{filename}" );
      foreach (@tagnames) {
         $cmd .= ' --show-tag=' . $_;
      }
      my @tags = `$cmd`;
      foreach (@tags) {
         $_ =~ s/.*=//g;
         chomp;
      }
      $self->{tags} = {
         artist      => $tags[0],
         album       => $tags[1], 
         title       => $tags[2], 
         genre       => $tags[3], 
         date        => $tags[4],
         tracknumber => $tags[5]
      };
   }

   sub get_tags {
      my $self = shift;
      #return undef if ($self->{err});
      return $self->{tags};
   }

   sub get_tag {
      my $self = shift;
      #return undef if ($self->{err});
      my $key = shift;
      return $self->{tags}{$key};
   }

   sub _to_mp3 {}
   sub _to_ogg {}

   sub convert {
      printf(__PACKAGE__ . "::_convert() : format = %x\n", $_output_format);
   }

   1;
}   # END Acxi_mediaFile

#-------------------------------------------------------------------------------


my @threads;
my %bin = (
   lame     => '/usr/bin/lame',
   flac     => '/usr/bin/flac',
   file     => '/usr/bin/file',
   oggenc   => '/usr/bin/oggenc',
   metaflac => '/usr/bin/metaflac'
);
Acxi_mediaFile::set_extbins(\%bin);
Acxi_mediaFile::set_output_format(Acxi_mediaFile::OGG);

sub _q {
   my $arg_href = shift;
   push(@threads, 
      threads->create(
         sub { 
            Acxi_mediaFile->new($arg_href);
         }
      )
   );
}

_q( { filename => '/mnt/net/media/music/Madder Mortem/Desiderata/02 - Evasions.flac' });
_q( { filename => '/mnt/net/media/music/Madder Mortem/Desiderata/10 - Sedition.flac' });

print("Number of threads: ", scalar(@threads), "\n");

#-------------------------------------------------------------------------------
# Global module destructor
END {
   while (my $t = shift(@threads)) {
      printf("Waiting for thread: %d ...\n", $t->tid());
      $t->join();
   }

}
#-------------------------------------------------------------------------------

1;  # return "true"
__END__

#-------------------------------------------------------------------------------
# POD docs go here:
