#!/usr/bin/env perl
# A totally new attempt on this thing...
# Odd Eivind Ebbesen, 2012-08-07 10:09:51

use 5.012;
use strict;
use warnings;
use mro 'c3';

{    # Helper class for logging

   package Acxi::Logger;

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

   sub _is {
      my $self = shift;
      my $lvl  = shift;
      return ($self->{CUR_LVL} == $lvl);
   }

   sub is_d {
      my $self = shift;
      return $self->_is(DEBUG);
   }

   sub is_i {
      my $self = shift;
      return $self->_is(INFO);
   }

   sub _pp {
      # Prepend given string to first arg
      my $ins  = shift;
      my @args = @_;
      $args[0] = "- $ins: " . $args[0];
      return @args;
   }

   sub log {
      my $self = shift;
      my ($lvl, $msg, @params) = @_;
      return if ($lvl > $self->{CUR_LVL});
      #chomp($msg);
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
      $self->log(DEBUG, _pp('DEBUG', @_));
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

}    # END package Acxi::Logger

#---

{    # Helper class for stat operations

   package Acxi::Fcmp;
   use File::stat;    # for named fields from stat()

   use constant F_BASE      => 0x001;
   use constant F_SRC_EXIST => F_BASE << 1;
   use constant F_DST_EXIST => F_BASE << 2;
   use constant F_SRC_AGE   => F_BASE << 3;
   use constant F_DST_AGE   => F_BASE << 4;

   my $_instance;

   sub new {
      $_instance //= bless({}, shift);
      return $_instance;
   }

   sub statbuf {
      my $self  = shift;
      my $which = shift;    # 0 for src, 1 for dst

      # Undef if not initialized
      return $which ? $self->{dst}{stat} : $self->{src}{stat};
   }

   sub mtime {
      my $self     = shift;
      my $src_file = shift;
      my $dst_file = shift;
      my $flags    = F_BASE;
      $self->{src}{stat} = my $s = stat($src_file);
      $self->{dst}{stat} = my $d = stat($dst_file);

      $flags |= F_SRC_EXIST if ($s);
      $flags |= F_DST_EXIST if ($d);
      return $flags if (!$s);
      if ($s && $d && $s->mtime > $d->mtime) {
         $flags |= F_SRC_AGE;
      }
      elsif ($s && $d && $s->mtime == $d->mtime) {
         $flags |= F_SRC_AGE | F_DST_AGE;
      }
      elsif ($s && $d && $s->mtime < $d->mtime) {
         $flags |= F_DST_AGE;
      }

      return $flags;
   }
};    # END package Acxi::Fcmp

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
use IPC::Cmd qw(can_run run run_forked QUOTE);
use POSIX ':sys_wait_h';
use Errno;
use Cwd;
use Carp;

# set to 0 in production
$Carp::Verbose = 1;

our $VERSION;

my $_config = {
   cfgfile_system => '/etc/acxi.conf',
   cfgfile_user   => "$ENV{HOME}/.acxi.conf",
   user_settings  => {
      LOG_LEVEL         => Acxi::Logger::DEBUG,
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
   ok_in  => [qw/flac ogg wav/],
   ok_out => [qw/ogg mp3/],
};

my $_rx_srcdir;
my $_rx_dstdir;
my $_cur_mime;

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
   # This one uses a global var $_cur_mime, so that the value can be read
   # without forking a subprocess once again if still operating on the same
   # file as on the previous invocation
   my $file = shift;
   chomp($_cur_mime = qx/$_config->{user_settings}{COMMAND_FILE} -bi "$file"/);
   $_cur_mime =~ s/;.*//;
   return $_cur_mime;
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
   return (-x $$file_ref);
}

sub _fext {
   my $rfilename = scalar reverse $_[0];
   my ($ext) = $rfilename =~ /(\S*?)\./;
   return unless (defined($ext));
   return reverse $ext if (@_ > 1);    # give any second param to disable lowercase
   return lc reverse $ext;
}

sub _iotype_ok {
   my %args = @_;
   my %p    = (
      direction => 'in',
      file      => undef,
   );
   @p{ keys(%args) } = values(%args);    # merge args with defaults
   return unless (defined($p{file}));

   my $ext     = _fext($p{file});
   my $aptr    = $p{direction} eq 'in' ? \$_config->{ok_in} : \$_config->{ok_out};
   my @hits    = grep { $_ eq $ext } @$$aptr;
   my $mime_ok = $p{direction} eq 'in' ? _check_mime($ext, $p{file}) : 1;

   return wantarray ? @hits : (@hits > 0 && $mime_ok);
}

sub _utype_ok {
   my $file = shift;
   my $ext  = _fext($file);
   my $aptr = \$_config->{user_settings}{USER_TYPES};
   my @hits = grep { $_ eq $ext } @$$aptr;
   return wantarray ? @hits : scalar @hits;
}

sub _type_ignore {
   my $file        = shift;
   my $ext         = _fext($file);
   my @valid_types = (@{ $_config->{ok_in} }, @{ $_config->{ok_out} }, @{ $_config->{user_settings}{USER_TYPES} });
   my @hits        = grep { $_ eq $ext } @valid_types;
   return wantarray ? @hits : @hits == 0;
}

#sub _cmp_file_mtime {
#   my $src = shift;
#   my $dst = shift;
#   my $src_sdata = stat($src);
#   my $dst_sdata = stat($dst);
#
#   #return -1 unless($dst_sdata and $src_sdata);
#   return 1 if ($src_sdata->mtime > $dst_sdata->mtime);
#   return 0 if ($src_sdata->mtime == $dst_sdata->mtime);
#   return -1;
#}

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
     || croak;
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
   $_rx_srcdir = qq($_config->{user_settings}{DIR_PREFIX_SOURCE});
   $_rx_dstdir = qq($_config->{user_settings}{DIR_PREFIX_DEST});
}

sub _grim_reaper {
   local $!;
   while ((my $pid = waitpid(-1, WNOHANG)) > 0 && WIFEXITED($?)) {
      $_l->debug("Reaped PID $pid with exit: $?") if ($_l->is_d());
   }
   $SIG{CHLD} = \&_grim_reaper;
}

sub _spawn(&) {
   my $coderef = shift;
#   unless (@_ == 0 && $coderef && ref($coderef) eq "CODE") {
#      confess "usage: _spawn CODEREF";
#   }

   my $pid;
   unless (defined($pid = fork())) {
      $_l->error("can't fork: $!");
      return;
   }
   elsif ($pid) {
      # I am parent
      return;
   }
   # If we're here, we're the child process
   exit($coderef->());
}

my $_worker = sub {
   # 1: find out input format, and read tag info
   # 2: find out output format, and generate correct params to encoder
   # 3: exec decoder <args> | encoder <args>
   # Alternatively, open two IPC pipes instead of a subshell
};

sub _build_cmd {
   my $ifile = shift;
   my @deccmds;    # decoder, left of pipe
   my @enccmds;    # encoder, right of pipe
   my $tags;

   if ($_config->{user_settings}{INPUT_TYPE} eq 'flac') {
      push(@deccmds, $_config->{user_settings}{COMMAND_FLAC}, '-d', '-c', QUOTE . $ifile . QUOTE);
      $tags = _get_tags_flac($ifile);
   }
   #...
   if ($_config->{user_settings}{OUTPUT_TYPE} eq 'mp3') {
      push(@enccmds,
         $_config->{user_settings}{COMMAND_LAME}, '-h',
         '-V',                                    $_config->{user_settings}{QUALITY},
         '--ta',                                  QUOTE . $tags->{ARTIST} . QUOTE,
         '--tl',                                  QUOTE . $tags->{ALBUM} . QUOTE,
         '--tt',                                  QUOTE . $tags->{TITLE} . QUOTE,
         '--tn',                                  QUOTE . $tags->{TRACKNUMBER} . QUOTE,
         '--tg',                                  QUOTE . $tags->{GENRE} . QUOTE,
         '--ty',                                  QUOTE . $tags->{DATE} . QUOTE);
   }
   return [ @deccmds, '|', @enccmds ];
}

sub _find_flt {
   # 1: bail out if symlink or banned name
   return unless (!-l && !/^.{1,2}$/ && !/\n$/);
   # cache if file can be read
   my $readable = -r;
   # 2: check if directory -
   #        * create destination dir if not exists
   if (-d) {
      (my $newdir = $File::Find::name) =~ s/$_rx_srcdir/$_rx_dstdir/;
      last unless (defined($newdir));
      $_l->debug("%s => %s", $File::Find::name, $newdir);

      if (-d $newdir) {
         $_l->debug(qq(Dir "$newdir" already exists));
      }
      else {
         $_l->debug(qq(Creating dir "$newdir"));
      }
   }
   # 3: check if this type is not in any format we care about
   elsif (_type_ignore($_)) {
      $_l->debug("Ignoring: $_");
      return;
   }
   # 4: check if in USER_TYPES -
   #        * copy file over
   elsif ($readable && _utype_ok($_)) {
      $_l->debug("User type, copying: $_");
   }
   # 5: check if valid media input file -
   #        * spawn off and convert/encode src to trg media file
   elsif ($readable && _iotype_ok(file => $File::Find::name, direction => 'in')) {
      $_l->debug("Valid media file: $File::Find::name");
      if ($_cur_mime eq $_config->{mime_types}{ $_config->{user_settings}{INPUT_TYPE} }) {
         $_l->debug("Match found, forking...");
#         _spawn(sub {
#            $| = 1;
#            sleep(3);
#            open(my $hnd, "|-", '/bin/cat') or croak($!);
#            print($hnd "\nFrom child, jajaja\n");
#            close($hnd) or croak($!);
#            $_l->notice("Child done");
#         });
         _spawn (
            sub {
#               my ($rv, $err, $buf_all, $buf_stdout, $buf_stderr) =
#                 run(command => [ '/bin/echo', 'testing', '|', '/bin/cat' ], [ verbose => 1 ]);
#               sleep(3);
#               $_l->debug("Output from child: " . Dumper($buf_stdout));
               my $cmds = _build_cmd($File::Find::name);
               $_l->debug("Commands to run: \n\t@$cmds");
            }
         );
         #$_l->debug("Return from forked run: " . Dumper($ret));
      }
   }
   else {
      # if it reaches here, it might be that the file has a valid input
      # format extension, but that the mime type is not verified, and
      # hence should not be opened by decoders or similar.
      # We can read $_cur_mime here, as it has to have been set from the call to
      # _iotype_ok above.
      $_l->debug(qq{File ignored for unknown reason: "$File::Find::name" (mime-type = $_cur_mime)\n});
   }
}

###

#_init();
#$SIG{CHLD} = \&_grim_reaper;
#find(\&_find_flt, $_rx_srcdir);

# wait for children
#while (wait() != -1) {}

my $src  = shift;
my $dst  = shift;
my $fcmp = Acxi::Fcmp->new();
my $rv   = $fcmp->mtime($src, $dst);
printf("Comparing $src and $dst returns: %#.4o\n", $rv);
if ($rv & Acxi::Fcmp::F_SRC_EXIST) {
   if ($rv & Acxi::Fcmp::F_DST_EXIST) {
      if (($rv & Acxi::Fcmp::F_SRC_AGE) && !($rv & Acxi::Fcmp::F_DST_AGE)) {
         print("src exists, dst exists, src is newer, so dst will be updated\n");
      }
      elsif (($rv & Acxi::Fcmp::F_DST_AGE) && !($rv & Acxi::Fcmp::F_SRC_AGE)) {
         print("src exists, dst exists, dst is newer, so nothing will be done\n");
      }
      elsif (($rv & Acxi::Fcmp::F_SRC_AGE) && ($rv & Acxi::Fcmp::F_DST_AGE)) {
         print("src exists, dst exists, both are the same age, nothing to do\n");
      }
   }
   else {
      print("src exists, dst does not, so go ahead and create new file\n");
   }
}
else {
   print("src does not exist, nothing can be done\n");
}

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

