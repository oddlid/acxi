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
use Getopt::Long qw(:config auto_version auto_help no_ignore_case);
use Pod::Usage;
use File::Find;
use File::Basename;
use File::Spec;
use Cwd;

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
{
   package Acxi_worker; 
   sub hello {
      print('Hello from ', __PACKAGE__, "\n");
   }

   sub enqueue {
      my ($srcdir, $dstdir) = @_;
      if (defined($srcdir) && defined($dstdir)) {
         threads->create(\&_exec, $srcdir, $dstdir);
      }
   }

   sub _exec {
      sleep(int(rand(20)));
      threads->yield();
      printf("In a new thread (ID: %d), with srcdir: %s and dstdir: %s\n", 
         threads->tid(), $_[0], $_[1]);
      print('-' x threads->tid(), "\n");
   }

   sub cleanup {
      foreach my $t (threads->list()) {
         $t->join();
      }
   }
}   # END Acxi_worker

{
   package Acxi_util;

   sub get_flac_tags {
      my $ifile = shift;
      return unless (defined($ifile));
      return unless (-r "$ifile");
      my @tags = qw(ARTIST ALBUM TITLE GENRE DATE TRACKNUMBER);
      my $cmd = qq(/usr/bin/metaflac "$ifile");
      foreach (@tags) {
         $cmd .= ' --show-tag=' . $_;
      }
      print($cmd, "\n");
   }
}   # END Acxi_util

{
   package Acxi_mediaFile;
   use strict;
   use warnings;
   use Data::Dumper;

   # stub for constructor
   sub new {
      # This inits the object instance with the required info.
      # Expected parameters:
      # - hash reference, with these keywords accepted:
      #   * filename - full path to the flac file
      #   * metaflac - reference to a string with the full path to metaflac binary
      #   * ...
      my $this = shift;
      my $class = ref($this) || $this;
      my $self = {};
      bless($self, $class);
      #...

      my $arg_href = shift || \{}; # should be a hash ref 
      if (!ref($arg_href) eq 'HASH') {
         print(__PACKAGE__ . "::new() : Not a HASH reference\n");
      }
      foreach my $k (keys(%$arg_href)) {
         print("Arg: " . $k . " = " . $$arg_href{$k} . "\n");
      }

      $self->{filename} = $arg_href->{filename} if defined($arg_href->{filename});
      $self->{metaflac} = $arg_href->{metaflac};# if defined($arg_href->{metaflac});
      print(Dumper($self), "\n");
      #print("grias...." . ref $self->{metaflac} . "\n");

      #$self->{_path} = "/some/where";
      #$self->{_filename} = "file.flac";
      #$self->{_fullpath} = "";
      #$self->{_fullpath} = File::Spec->catfile($self->{_path}, $self->{_filename});

      return $self;
   }

   sub load_tags {
      my $self = shift;
      #my $mf_path = shift || \'/usr/bin/metaflac';
      #return unless (ref($mf_path));
      #print("MF: $$mf_path\n");
      #return unless (-X $self->{metaflac});
      my $cmd;
      my @tagnames = qw(ARTIST ALBUM TITLE GENRE DATE TRACKNUMBER);
      $cmd = ${$self->{metaflac}} . qq( "$self->{filename}" );
      foreach (@tagnames) {
         $cmd .= ' --show-tag=' . $_;
      }
      print("Acxi_mediaFile::load_tags() : cmd = $cmd\n");
   }
}   # END Acxi_mediaFile

{
   package Acxi_test;
   sub ding {
      print('Ding from ', __PACKAGE__, "\n");
      Acxi_worker::hello();
   }
}
#-------------------------------------------------------------------------------


#sub dong {
#   print('Dong from ', __PACKAGE__, "\n");
#   Acxi_test::ding();
#}

#for my $i (0 .. 20) {
#   Acxi_worker::enqueue($i, $i + 1);
#}
#Acxi_worker::cleanup();
#dong();
#Acxi_util::get_flac_tags('raff.flac');

#foreach my $key (keys %!) {
#   printf("%s\n", $key);
#}


my $mflac = '/usr/bin/file';
my %args = (
   metaflac => \$mflac,
   test => 'raff',
   filename => '/a/file/some/where.flac'
);
my $mf = Acxi_mediaFile->new(\%args);
$mf->load_tags();


#-------------------------------------------------------------------------------
# Global module destructor
#END {
#}
#-------------------------------------------------------------------------------

1;  # return "true"
__END__

#-------------------------------------------------------------------------------
# POD docs go here:
