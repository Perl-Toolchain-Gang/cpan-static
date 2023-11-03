#! perl

use strict;
use warnings;

use File::Basename 'basename';
use File::Copy 'copy';

use lib 'lib';
use CPAN::Static::Install qw/configure build test install opts_from_args_list/;

my %opts = opts_from_args_list(@ARGV);
if (basename($0) eq 'Build.PL') {
	configure(%opts);
	copy('Build.PL', 'Build');
} else {
	my $command = shift || 'build';
	if ($command eq 'build') {
		build(%opts);
	} elsif ($command eq 'test') {
		test(%opts);
	} elsif ($command eq 'install') {
		install(%opts);
	} else {
		die "Unknown subcommand $command";
	}
}
