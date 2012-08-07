#!/usr/bin/env perl
# A totally new attempt on this thing...
# Odd Eivind Ebbesen, 2012-08-07 10:09:51

package Acxi;

$Acxi::VERSION = $main::VERSION = '3.0.1';

# This might not be needed...
use Modern::Perl '2012';

use Data::Dumper;
use Getopt::Long qw(:config auto_version auto_help no_ignore_case);
use Pod::Usage;
use File::Find;
use File::Basename;
use File::Spec;
use Cwd;
use Errno;


our $VERSION;

my $_config = {
   cfgfile_system => '/etc/acxi.conf',
   cfgfile_user   => "$ENV{HOME}/.acxi.conf",
   user_settings => {
      LOG_LEVEL         => 0,
      DIR_PREFIX_SOURCE => '',
      DIR_PREFIX_DEST   => '',
      QUALITY           => '',
      INPUT_TYPE        => '',
      OUTPUT_TYPE       => '',
      USER_TYPES        => '',
      COMMAND_OGG       => 'oggenc',     # set to undef to disable
      COMMAND_LAME      => 'lame',       # set to undef to disable
      COMMAND_FLAC      => 'flac',       # set to undef to disable
      COMMAND_METAFLAC  => 'metaflac'    # set to undef to disable
     }
};

sub _x(\$) {
   # Returns whether a given path points to a valid executable
   my $file_ref = shift;
   return (-X $$file_ref);
}

sub _locate_ext_binaries {
   my @paths = split(/:/, $ENV{PATH});    # cache this before loop
   foreach my $cmd (qw/FLAC METAFLAC OGG LAME/) {
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
   #say Dumper($_config);
}


### 

_locate_ext_binaries();

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

