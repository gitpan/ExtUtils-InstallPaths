package ExtUtils::InstallPaths;
{
  $ExtUtils::InstallPaths::VERSION = '0.005';
}
use 5.006;
use strict;
use warnings;

use File::Spec ();
use Carp ();
use ExtUtils::Config 0.002;

my %explicit_accessors = map { $_ => 1 } qw/installdirs install_path install_base_relpaths prefix_relpaths/;

my %attributes = (
	installdirs     => 'site',
	install_base    => undef,
	prefix          => undef,
	verbose         => 0,
	blib            => 'blib',
	create_packlist => 1,
	dist_name       => undef,
	module_name     => undef,
	destdir         => undef,
	config          => sub { ExtUtils::Config->new },
	map { ($_ => sub { {} }) } grep { $_ ne 'installdirs' } keys %explicit_accessors,
);

for my $attribute (grep { not exists $explicit_accessors{$_} } keys %attributes) {
	no strict qw/refs/;
	*{$attribute} = sub {
		my $self = shift;
		$self->{$attribute} = shift if @_;
		return $self->{$attribute};
	};
}

my $default_value = sub {
	my $name = shift;
	return (ref $attributes{$name} ?  return $attributes{$name}->() : $attributes{$name});
};

sub new {
	my ($class, %args) = @_;
	my %self = (
		map { $_ => exists $args{$_} ? $args{$_} : $default_value->($_) } keys %attributes,
	);
	$self{module_name} ||= do { my $module_name = $self{dist_name}; $module_name =~ s/-/::/g; $module_name } if defined $self{dist_name};
	return bless \%self, $class;
}

sub _default_install_sets {
	my $self = shift;
	my $c = $self->{config};

	my $bindoc  = $c->get('installman1dir') || undef;
	my $libdoc  = $c->get('installman3dir') || undef;

	my $binhtml = $c->get('installhtml1dir') || $c->get('installhtmldir') || undef;
	my $libhtml = $c->get('installhtml3dir') || $c->get('installhtmldir') || undef;

	return {
		core   => {
			lib     => $c->get('installprivlib'),
			arch    => $c->get('installarchlib'),
			bin     => $c->get('installbin'),
			script  => $c->get('installscript'),
			bindoc  => $bindoc,
			libdoc  => $libdoc,
			binhtml => $binhtml,
			libhtml => $libhtml,
		},
		site   => {
			lib     => $c->get('installsitelib'),
			arch    => $c->get('installsitearch'),
			bin     => $c->get('installsitebin') || $c->get('installbin'),
			script  => $c->get('installsitescript') || $c->get('installsitebin') || $c->get('installscript'),
			bindoc  => $c->get('installsiteman1dir') || $bindoc,
			libdoc  => $c->get('installsiteman3dir') || $libdoc,
			binhtml => $c->get('installsitehtml1dir') || $binhtml,
			libhtml => $c->get('installsitehtml3dir') || $libhtml,
		},
		vendor => {
			lib     => $c->get('installvendorlib'),
			arch    => $c->get('installvendorarch'),
			bin     => $c->get('installvendorbin') || $c->get('installbin'),
			script  => $c->get('installvendorscript') || $c->get('installvendorbin') || $c->get('installscript'),
			bindoc  => $c->get('installvendorman1dir') || $bindoc,
			libdoc  => $c->get('installvendorman3dir') || $libdoc,
			binhtml => $c->get('installvendorhtml1dir') || $binhtml,
			libhtml => $c->get('installvendorhtml3dir') || $libhtml,
		},
	};
}

sub _default_base_relpaths {
	# Note: you might be tempted to use $Config{installstyle} here
	# instead of hard-coding lib/perl5, but that's been considered and
	# (at least for now) rejected.  `perldoc Config` has some wisdom
	# about it.

	my $self = shift;
	return {
		lib     => ['lib', 'perl5'],
		arch    => ['lib', 'perl5', $self->config->get('archname')],
		bin     => ['bin'],
		script  => ['bin'],
		bindoc  => ['man', 'man1'],
		libdoc  => ['man', 'man3'],
		binhtml => ['html'],
		libhtml => ['html'],
	};
}

sub _default_prefix_relpaths {
	my $self = shift;
	my $c = $self->{config};

	my @libstyle = $c->get('installstyle') ?  File::Spec->splitdir($c->get('installstyle')) : qw(lib perl5);
	my $arch     = $c->get('archname');
	my $version  = $c->get('version');

	return {
		core => {
			lib        => [@libstyle],
			arch       => [@libstyle, $version, $arch],
			bin        => ['bin'],
			script     => ['bin'],
			bindoc     => ['man', 'man1'],
			libdoc     => ['man', 'man3'],
			binhtml    => ['html'],
			libhtml    => ['html'],
		},
		vendor => {
			lib        => [@libstyle],
			arch       => [@libstyle, $version, $arch],
			bin        => ['bin'],
			script     => ['bin'],
			bindoc     => ['man', 'man1'],
			libdoc     => ['man', 'man3'],
			binhtml    => ['html'],
			libhtml    => ['html'],
		},
		site => {
			lib        => [@libstyle, 'site_perl'],
			arch       => [@libstyle, 'site_perl', $version, $arch],
			bin        => ['bin'],
			script     => ['bin'],
			bindoc     => ['man', 'man1'],
			libdoc     => ['man', 'man3'],
			binhtml    => ['html'],
			libhtml    => ['html'],
		},
	};
}

sub _default_original_prefix {
	my $self = shift;
	my $c = $self->{config};

	my %ret = (
		core   => $c->get('installprefixexp') || $c->get('installprefix') || $c->get('prefixexp') || $c->get('prefix') || '',
		site   => $c->get('siteprefixexp'),
		vendor => $c->get('usevendorprefix') ? $c->get('vendorprefixexp') : '',
	);
	$ret{site} ||= $ret{core};

	return \%ret;
}

my %allowed_installdir = map { $_ => 1 } qw/core site vendor/;
sub installdirs {
	my $self = shift;
	if (@_) {
		my $value = shift;
		$value = 'core', Carp::carp('Perhaps you meant installdirs to be "core" rather than "perl"?') if $value eq 'perl';
		Carp::croak('installdirs must be one of "core", "site", or "vendor"') if not $allowed_installdir{$value};
		$self->{installdirs} = $value;
	}
	return $self->{installdirs};
}

sub _log_verbose {
	my $self = shift;
	print @_ if $self->verbose;
	return;
}

sub _merge_arglist {
	my( $self, $opts1, $opts2 ) = @_;

	$opts1 ||= {};
	$opts2 ||= {};
	my %new_opts = %$opts1;
	while (my ($key, $val) = each %$opts2) {
		if (exists $opts1->{$key}) {
			if (ref($val) eq 'HASH') {
				while (my ($k, $v) = each %$val) {
					$new_opts{$key}{$k} = $v unless exists $opts1->{$key}{$k};
				}
			}
		} else {
			$new_opts{$key} = $val
		}
	}

	return \%new_opts;
}

# Given a file type, will return true if the file type would normally
# be installed when neither install-base nor prefix has been set.
# I.e. it will be true only if the path is set from Config.pm or
# set explicitly by the user via install-path.
sub is_default_installable {
	my $self = shift;
	my $type = shift;
	my $installable = $self->install_destination($type) && ( $self->install_path($type) || $self->install_sets($self->installdirs)->{$type});
	return $installable ? 1 : 0;
}

sub install_path {
	my $self = shift;

	my $map = $self->{install_path};
	return { %{$map} } unless @_;

	my $type = shift;
	Carp::croak('Type argument missing') unless defined $type ;
	
	if (@_) {
		my $new_value = shift;
		if (!defined $new_value) {
			# delete existing value if $value is literal undef()
			delete $map->{$type};
			return;
		}
		else {
			# set value if $value is a valid relative path
			return $map->{$type} = $new_value;
		}
	}
	# return existing value if no new $value is given
	return unless exists $map->{$type};
	return $map->{$type};
}

sub install_sets {
	# Usage: install_sets('site'), install_sets('site', 'lib'),
	#   or install_sets('site', 'lib' => $value);
	my ($self, $dirs, $key, $value) = @_;
	$dirs = $self->installdirs unless defined $dirs;
	# update property before merging with defaults
	if ( @_ == 4 && defined $dirs && defined $key) {
		# $value can be undef; will mask default
		$self->{install_sets}{$dirs}{$key} = $value;
	}
	my $map = $self->_merge_arglist($self->{install_sets}, $self->_default_install_sets);
	if (defined $dirs and defined $key) {
		return $map->{$dirs}{$key};
	}
	elsif (defined $dirs) {
		return { %{ $map->{$dirs} } };
	}
	else {
		Carp::croak('Can\'t determine installdirs for install_sets()');
	}
}

sub _set_relpaths {
	my $self = shift;
	my( $map, $type, $value ) = @_;

	Carp::croak('Type argument missing') unless defined $type;

	# set undef if $value is literal undef()
	if (not defined $value) {
		$map->{$type} = undef;
		return;
	}
	# set value if $value is a valid relative path
	else {
		Carp::croak('Value must be a relative path') if File::Spec::Unix->file_name_is_absolute($value);

		my @value = split( /\//, $value );
		return $map->{$type} = \@value;
	}
}

sub install_base_relpaths {
	# Usage: install_base_relpaths(), install_base_relpaths('lib'),
	#   or install_base_relpaths('lib' => $value);
	my $self = shift;
	if ( @_ > 1 ) { # change values before merge
		$self->_set_relpaths($self->{install_base_relpaths}, @_);
	}
	my $map = $self->_merge_arglist($self->{install_base_relpaths}, $self->_default_base_relpaths);
	return { %{$map} } unless @_;
	my $relpath = $map->{$_[0]};
	return defined $relpath ? File::Spec->catdir( @$relpath ) : undef;
}

# Defaults to use in case the config install paths cannot be prefixified.
sub prefix_relpaths {
	# Usage: prefix_relpaths('site'), prefix_relpaths('site', 'lib'),
	#   or prefix_relpaths('site', 'lib' => $value);
	my $self = shift;
	my $installdirs = shift || $self->installdirs or Carp::croak('Can\'t determine installdirs for prefix_relpaths()');
	if ( @_ > 1 ) { # change values before merge
		$self->{prefix_relpaths}{$installdirs} ||= {};
		$self->_set_relpaths($self->{prefix_relpaths}{$installdirs}, @_);
	}
	my $map = $self->_merge_arglist($self->{prefix_relpaths}{$installdirs}, $self->_default_prefix_relpaths->{$installdirs});
	return { %{$map} } unless @_;
	my $relpath = $map->{$_[0]};
	return defined $relpath ? File::Spec->catdir( @$relpath ) : undef;
}

sub _prefixify_default {
	my $self = shift;
	my $type = shift;
	my $rprefix = shift;

	my $default = $self->prefix_relpaths($self->installdirs, $type);
	if( !$default ) {
		$self->_log_verbose("    no default install location for type '$type', using prefix '$rprefix'.\n");
		return $rprefix;
	} else {
		return $default;
	}
}

# Translated from ExtUtils::MM_Unix::prefixify()
sub _prefixify_novms {
	my($self, $path, $sprefix, $type) = @_;

	my $rprefix = $self->prefix;
	$rprefix .= '/' if $sprefix =~ m{/$};

	$self->_log_verbose("  prefixify $path from $sprefix to $rprefix\n") if defined $path && length $path;

	if (not defined $path or length $path == 0 ) {
		$self->_log_verbose("  no path to prefixify, falling back to default.\n");
		return $self->_prefixify_default( $type, $rprefix );
	} elsif( !File::Spec->file_name_is_absolute($path) ) {
		$self->_log_verbose("    path is relative, not prefixifying.\n");
	} elsif( $path !~ s{^\Q$sprefix\E\b}{}s ) {
		$self->_log_verbose("    cannot prefixify, falling back to default.\n");
		return $self->_prefixify_default( $type, $rprefix );
	}

	$self->_log_verbose("    now $path in $rprefix\n");

	return $path;
}

sub _catprefix_vms {
	my ($self, $rprefix, $default) = @_;

	my ($rvol, $rdirs) = File::Spec->splitpath($rprefix);
	if ($rvol) {
		return File::Spec->catpath($rvol, File::Spec->catdir($rdirs, $default), '');
	}
	else {
		return File::Spec->catdir($rdirs, $default);
	}
}
sub _prefixify_vms {
	my($self, $path, $sprefix, $type) = @_;
	my $rprefix = $self->prefix;

	return '' unless defined $path;

	$self->_log_verbose("  prefixify $path from $sprefix to $rprefix\n");

	require VMS::Filespec;
	# Translate $(PERLPREFIX) to a real path.
	$rprefix = VMS::Filespec::vmspath($rprefix) if $rprefix;
	$sprefix = VMS::Filespec::vmspath($sprefix) if $sprefix;

	$self->_log_verbose("  rprefix translated to $rprefix\n  sprefix translated to $sprefix\n");

	if (length($path) == 0 ) {
		$self->_log_verbose("  no path to prefixify.\n")
	}
	elsif (!File::Spec->file_name_is_absolute($path)) {
		$self->_log_verbose("	path is relative, not prefixifying.\n");
	}
	elsif ($sprefix eq $rprefix) {
		$self->_log_verbose("  no new prefix.\n");
	}
	else {
		my ($path_vol, $path_dirs) = File::Spec->splitpath( $path );
		my $vms_prefix = $self->config->get('vms_prefix');
		if ($path_vol eq $vms_prefix.':') {
			$self->_log_verbose("  $vms_prefix: seen\n");

			$path_dirs =~ s{^\[}{\[.} unless $path_dirs =~ m{^\[\.};
			$path = $self->_catprefix_vms($rprefix, $path_dirs);
		}
		else {
			$self->_log_verbose("	cannot prefixify.\n");
			return $self->prefix_relpaths($self->installdirs, $type);
		}
	}

	$self->_log_verbose("	now $path\n");

	return $path;
}

BEGIN { *_prefixify = $^O eq 'VMS' ? \&_prefixify_vms : \&_prefixify_novms }

sub original_prefix {
	# Usage: original_prefix(), original_prefix('lib'),
	#   or original_prefix('lib' => $value);
	my ($self, $key, $value) = @_;
	# update property before merging with defaults
	if ( @_ == 3 && defined $key) {
		# $value can be undef; will mask default
		$self->{original_prefix}{$key} = $value;
	}
	my $map = $self->_merge_arglist($self->{original_prefix}, $self->_default_original_prefix);
	return { %{$map} } unless defined $key;
	return $map->{$key}
}

# Translated from ExtUtils::MM_Any::init_INSTALL_from_PREFIX
sub prefix_relative {
	my ($self, $type) = @_;
	my $installdirs = $self->installdirs;

	my $relpath = $self->install_sets($installdirs)->{$type};

	return $self->_prefixify($relpath, $self->original_prefix($installdirs), $type);
}

sub install_destination {
	my ($self, $type) = @_;

	return $self->install_path($type) if $self->install_path($type);

	if ( $self->install_base ) {
		my $relpath = $self->install_base_relpaths($type);
		return $relpath ? File::Spec->catdir($self->install_base, $relpath) : undef;
	}

	if ( $self->prefix ) {
		my $relpath = $self->prefix_relative($type);
		return $relpath ? File::Spec->catdir($self->prefix, $relpath) : undef;
	}

	return $self->install_sets($self->installdirs)->{$type};
}

sub install_types {
	my $self = shift;

	my %types;
	if ( $self->install_base ) {
		%types = %{$self->install_base_relpaths};
	} elsif ( $self->prefix ) {
		%types = %{$self->prefix_relpaths};
	} else {
		%types = %{$self->install_sets($self->installdirs)};
	}

	%types = (%types, %{$self->install_path});

	my @types = sort keys %types;
	return @types;
}

sub install_map {
	my ($self, $blib) = @_;
	$blib ||= $self->blib;

	my (%map, @skipping);
	foreach my $type ($self->install_types) {
		my $localdir = File::Spec->catdir( $blib, $type );
		next unless -e $localdir;

		# the line "...next if (($type eq 'bindoc'..." was one of many changes introduced for
		# improving HTML generation on ActivePerl, see https://rt.cpan.org/Public/Bug/Display.html?id=53478
		# Most changes were ok, but this particular line caused test failures in t/manifypods.t on windows,
		# therefore it is commented out.

		# ********* next if (($type eq 'bindoc' || $type eq 'libdoc') && not $self->is_unixish);

		if (my $dest = $self->install_destination($type)) {
			$map{$localdir} = $dest;
		} else {
			push @skipping, $type;
		}
	}

	warn "WARNING: Can't figure out install path for types: @skipping\nFiles will not be installed.\n" if @skipping;

	# Write the packlist into the same place as ExtUtils::MakeMaker.
	if ($self->create_packlist and my $module_name = $self->module_name) {
		my $archdir = $self->install_destination('arch');
		my @ext = split /::/, $module_name;
		$map{write} = File::Spec->catfile($archdir, 'auto', @ext, '.packlist');
	}

	# Handle destdir
	if (length(my $destdir = $self->destdir || '')) {
		foreach (keys %map) {
			# Need to remove volume from $map{$_} using splitpath, or else
			# we'll create something crazy like C:\Foo\Bar\E:\Baz\Quux
			# VMS will always have the file separate than the path.
			my ($volume, $path, $file) = File::Spec->splitpath( $map{$_}, 0 );

			# catdir needs a list of directories, or it will create something
			# crazy like volume:[Foo.Bar.volume.Baz.Quux]
			my @dirs = File::Spec->splitdir($path);

			# First merge the directories
			$path = File::Spec->catdir($destdir, @dirs);

			# Then put the file back on if there is one.
			if ($file ne '') {
			    $map{$_} = File::Spec->catfile($path, $file)
			} else {
			    $map{$_} = $path;
			}
		}
	}

	$map{read} = '';  # To keep ExtUtils::Install quiet

	return \%map;
}

1;

# ABSTRACT: Build.PL install path logic made easy



=pod

=head1 NAME

ExtUtils::InstallPaths - Build.PL install path logic made easy

=head1 VERSION

version 0.005

=head1 SYNOPSIS

 use ExtUtils::InstallPaths;
 use ExtUtils::Install 'install';
 GetOptions(\my %opt, 'install_base=s', 'install_path=s%', 'installdirs=s', 'destdir=s', 'prefix=s', 'uninst:1', 'verbose:1');
 my $paths = ExtUtils::InstallPaths->new(%opt, dist_name => $dist_name);
 install($paths->install_map, $opt{verbose}, 0, $opt{uninst});

=head1 DESCRIPTION

This module tries to make install path resolution as easy as possible.

When you want to install a module, it needs to figure out where to install things. The nutshell version of how this works is that default installation locations are determined from L<ExtUtils::Config>, and they may be overridden by using the C<install_path> attribute. An C<install_base> attribute lets you specify an alternative installation root like F</home/foo> and C<prefix> does something similar in a rather different (and more complicated) way. C<destdir> lets you specify a temporary installation directory like F</tmp/install> in case you want to create bundled-up installable packages.

The following types are supported in any circumstance.

=over 4

=item * lib

Usually pure-Perl module files ending in F<.pm>.

=item * arch

"Architecture-dependent" module files, usually produced by compiling XS, L<Inline>, or similar code.

=item * script

Programs written in pure Perl.  In order to improve reuse, try to make these as small as possible - put the code into modules whenever possible.

=item * bin

"Architecture-dependent" executable programs, i.e. compiled C code or something.  Pretty rare to see this in a perl distribution, but it happens.

=item * bindoc

Documentation for the stuff in C<script> and C<bin>.  Usually generated from the POD in those files.  Under Unix, these are manual pages belonging to the 'man1' category.

=item * libdoc

Documentation for the stuff in C<lib> and C<arch>.  This is usually generated from the POD in F<.pm> files.  Under Unix, these are manual pages belonging to the 'man3' category.

=item * binhtml

This is the same as C<bindoc> above, but applies to HTML documents.

=item * libhtml

This is the same as C<bindoc> above, but applies to HTML documents.

=back

=head1 ATTRIBUTES

=head2 installdirs

The default destinations for these installable things come from entries in your system's configuration. You can select from three different sets of default locations by setting the C<installdirs> parameter as follows:

                          'installdirs' set to:
                   core          site                vendor

              uses the following defaults from ExtUtils::Config:

  lib     => installprivlib  installsitelib      installvendorlib
  arch    => installarchlib  installsitearch     installvendorarch
  script  => installscript   installsitebin      installvendorbin
  bin     => installbin      installsitebin      installvendorbin
  bindoc  => installman1dir  installsiteman1dir  installvendorman1dir
  libdoc  => installman3dir  installsiteman3dir  installvendorman3dir
  binhtml => installhtml1dir installsitehtml1dir installvendorhtml1dir [*]
  libhtml => installhtml3dir installsitehtml3dir installvendorhtml3dir [*]

  * Under some OS (eg. MSWin32) the destination for HTML documents is determined by the C<Config.pm> entry C<installhtmldir>.

The default value of C<installdirs> is "site".

=head2 install_base

You can also set the whole bunch of installation paths by supplying the C<install_base> parameter to point to a directory on your system.  For instance, if you set C<install_base> to "/home/ken" on a Linux system, you'll install as follows:

  lib     => /home/ken/lib/perl5
  arch    => /home/ken/lib/perl5/i386-linux
  script  => /home/ken/bin
  bin     => /home/ken/bin
  bindoc  => /home/ken/man/man1
  libdoc  => /home/ken/man/man3
  binhtml => /home/ken/html
  libhtml => /home/ken/html

=head2 prefix

This sets a prefix, identical to ExtUtils::MakeMaker's PREFIX option. This does something similar to C<install_base> in a much more complicated way.

=head2 config()

Gets the L<ExtUtils::Config|ExtUtils::Config> object used for this object.

=head2 verbose

Sets the verbosity of ExtUtils::InstallPaths. It defaults to 0

=head2 blib

Sets the location of the blib directory, it defaults to 'blib'.

=head2 create_packlist

Controls whether a packlist will be added together with C<module_name>. Defaults to 1.

=head2 dist_name

The name of the current module.

=head2 module_name

The name of the main module of the package. This is required for packlist creation, but in the future it may be replaced by dist_name. It defaults to dist_name =~ s/-/::/gr if dist_name is set.

=head2 destdir

If you want to install everything into a temporary directory first (for instance, if you want to create a directory tree that a package manager like C<rpm> or C<dpkg> could create a package from), you can use the C<destdir> parameter. E.g. Setting C<destdir> to C<"/tmp/foo"> will effectively install to "/tmp/foo/$sitelib", "/tmp/foo/$sitearch", and the like, except that it will use C<File::Spec> to make the pathnames work correctly on whatever platform you're installing on.

=head1 METHODS

=head2 new

Create a new ExtUtils::InstallPaths object. B<All attributes are valid arguments> to the contructor, as well as this:

=over 4

=item * install_path

This must be a hashref with the type as keys and the destination as values.

=item * install_base_relpaths

This must be a hashref with types as keys and a path relative to the install_base as value.

=item * prefix_relpaths

This must be a hashref any of these three keys: core, vendor, site. Each of the values mush be a hashref with types as keys and a path relative to the prefix as value. You probably want to make these three hashrefs identical.

=back

=head2 install_map()

Return a map suitable for use with L<ExtUtils::Install>. B<In most cases, this is the only method you'll need>.

=head2 install_destination($type)

Returns the destination of a certain type

=head2 install_types()

Return a list of all supported install types in the current configuration.

=head2 is_default_installable($type)

Given a file type, will return true if the file type would normally be installed when neither install-base nor prefix has been set.  I.e. it will be true only if the path is set from the configuration object or set explicitly by the user via install_path.

=head2 install_path($type [, $value])

Gets or sets the install path for a certain type. Note that this overrides all other options.

=head2 install_sets($installdirs, $type [, $path ])

Get or set the path for a certain C<$type> with a certain C<$installdirs>.

=head2 install_base_relpaths($type, $relpath)

Get or set the relative paths for use with install_base for a certain type.

=head2 prefix_relative($type)

Gets the path of a certain type relative to the prefix.

=head2 prefix_relpaths($install_dirs, $type [, $relpath])

Get or set the default relative path to use in case the config install paths cannot be prefixified. You do not want to use this to get any relative path, but may require it to set it for custom types.

=head2 original_prefix($installdirs)

Get the original prefix for a certain type of $installdirs.

=head1 SEE ALSO

=over 4

=item * L<Build.PL spec|http://github.com/dagolden/cpan-api-buildpl/blob/master/lib/CPAN/API/BuildPL.pm>

=back

=head1 AUTHORS

=over 4

=item *

Ken Williams <kwilliams@cpan.org>

=item *

Leon Timmermans <leont@cpan.org>

=back

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2011 by Ken Williams, Leon Timmermans.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut


__END__

