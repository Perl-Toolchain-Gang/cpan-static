package CPAN::Static::Install;

use strict;
use warnings;

use Exporter 5.57 'import';
our @EXPORT_OK = qw/configure build test install/;
our %EXPORT_TAGS = (
	'all' => \@EXPORT_OK,
);

use CPAN::Meta;
use ExtUtils::Config 0.003;
use ExtUtils::Helpers 0.020 qw/make_executable split_like_shell man1_pagename man3_pagename detildefy/;
use ExtUtils::Install qw/pm_to_blib/;
use ExtUtils::InstallPaths 0.002;
use File::Basename qw/dirname/;
use File::Find ();
use File::Path qw/mkpath/;
use File::Spec::Functions qw/catfile catdir rel2abs abs2rel splitdir curdir/;
use Getopt::Long 2.36 qw/GetOptionsFromArray/;
use JSON::PP 2 qw/encode_json decode_json/;
use Scalar::Util 'blessed';

sub write_file {
	my ($filename, $content) = @_;
	open my $fh, '>', $filename or die "Could not open $filename: $!\n";
	print $fh $content;
}
sub read_file {
	my ($filename) = @_;
	open my $fh, '<', $filename or die "Could not open $filename: $!\n";
	return do { local $/; <$fh> };
}

sub configure {
	my %args = @_;
    $args{config} = $args{config}->values_set if blessed($args{config});
	my $meta = CPAN::Meta->load_file('META.json');
	printf "Saving configuration for '%s' version '%s'\n", $meta->name, $meta->version;
	my @env = defined $ENV{PERL_MB_OPT} ? split_like_shell($ENV{PERL_MB_OPT}) : ();
	GetOptionsFromArray(\@env, \my %env, qw/install_base=s install_path=s% installdirs=s destdir=s prefix=s config=s% uninst:1 verbose:1 dry_run:1 pureperl-only:1 create_packlist=i jobs=i/);
	write_file('_static_build_params', encode_json([ \%env, \%args ]));
	$meta->save('MYMETA.json');
}

sub manify {
	my ($input_file, $output_file, $section, $opts) = @_;
	return if -e $output_file && -M $input_file <= -M $output_file;
	my $dirname = dirname($output_file);
	mkpath($dirname, $opts->{verbose}) if not -d $dirname;
	require Pod::Man;
	Pod::Man->new(section => $section)->parse_from_file($input_file, $output_file);
	print "Manifying $output_file\n" if $opts->{verbose} && $opts->{verbose} > 0;
	return;
}

sub find {
	my ($pattern, $dir) = @_;
	my @ret;
	File::Find::find(sub { push @ret, $File::Find::name if /$pattern/ && -f }, $dir) if -d $dir;
	return @ret;
}

sub contains_pod {
	my ($file) = @_;
	return unless -T $file;
	return read_file($file) =~ /^\=(?:head|pod|item)/m;
}

sub get_opts {
	my ($env, $bargv) = @{ decode_json(read_file('_static_build_params')) };
	my %options = (%$env, %$bargv);
	$_ = detildefy($_) for grep { defined } @options{qw/install_base destdir prefix/}, values %{ $options{install_path} };
	$options{meta} = CPAN::Meta->load_file('MYMETA.json');
	$options{config} = ExtUtils::Config->new($options{config});
	$options{install_paths} = ExtUtils::InstallPaths->new(%options, dist_name => $options{meta}->name);
	return %options;
}

sub build {
	my %opt = get_opts;
	my %modules = map { $_ => catfile('blib', $_) } find(qr/\.pm$/, 'lib');
	my %docs    = map { $_ => catfile('blib', $_) } find(qr/\.pod$/, 'lib');
	my %scripts = map { $_ => catfile('blib', $_) } find(qr/(?:)/, 'script');
	my %sdocs   = map { $_ => delete $scripts{$_} } grep { /.pod$/ } keys %scripts;
	my %dist_shared    = map { $_ => catfile(qw/blib lib auto share dist/, $opt{meta}->name, abs2rel($_, 'share')) } find(qr/(?:)/, 'share');
	my %module_shared  = map { $_ => catfile(qw/blib lib auto share module/, abs2rel($_, 'module-share')) } find(qr/(?:)/, 'module-share');
	pm_to_blib({ %modules, %docs, %scripts, %dist_shared, %module_shared }, catdir(qw/blib lib auto/));
	make_executable($_) for values %scripts;
	mkpath(catdir(qw/blib arch/), $opt{verbose});

	if ($opt{install_paths}->is_default_installable('bindoc')) {
		my $section = $opt{config}->get('man1ext');
		for my $input (keys %scripts, keys %sdocs) {
			next unless contains_pod($input);
			my $output = catfile('blib', 'bindoc', man1_pagename($input));
			manify($input, $output, $section, \%opt);
		}
	}
	if ($opt{install_paths}->is_default_installable('libdoc')) {
		my $section = $opt{config}->get('man3ext');
		for my $input (keys %modules, keys %docs) {
			next unless contains_pod($input);
			my $output = catfile('blib', 'libdoc', man3_pagename($input));
			manify($input, $output, $section, \%opt);
		}
	}
}

sub test {
	my %opt = get_opts;
	die "Must run `./Build build` first\n" if not -d 'blib';
	require TAP::Harness::Env;
	my %test_args = (
		(verbosity => $opt{verbose}) x!! exists $opt{verbose},
		(jobs => $opt{jobs}) x!! exists $opt{jobs},
		(color => 1) x !!-t STDOUT,
		lib => [ map { rel2abs(catdir(qw/blib/, $_)) } qw/arch lib/ ],
	);
	my $tester = TAP::Harness::Env->create(\%test_args);
	$tester->runtests(sort +find(qr/\.t$/, 't'))->has_errors and die "Tests failed";
}

sub install {
	my %opt = get_opts;
	die "Must run `./Build build` first\n" if not -d 'blib';
	ExtUtils::Install::install($opt{install_paths}->install_map, @opt{qw/verbose dry_run uninst/});
}

1;

=head1 DESCRIPTION

=func configure

=func build

=func test

=func install

