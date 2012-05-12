package CPAN::Static;
use strict;
use warnings;

1;

# ABSTRACT: Static install specification for CPAN distributions

__END__

=head1 DESCRIPTION

This document describes a way for CPAN clients to install distributions without having to run a F<Makefile.PL> or a F<Build.PL> 

=head1 PURPOSE

Historically, Perl distributions have always been able to build, test and install without any help of a CPAN client. C<perl Makefile.PL><, C<make>, C<make test>, C<make install>. This is a powerful feature, but it is overly complicated for many modules that have no non-standard needs.

=head1 CONTEXT

This specification relies on a number of other specifications. This includes in particular L<CPAN::Meta::Spec>, L<CPAN::API::BuildPL>.  The terms B<must>, B<should>, B<may> and their negations have the usual IETF semantics L<RFC2119|https://www.ietf.org/rfc/rfc2119.txt>.

=head1 FLOW OF EXECUTION

Building a distribution has four stages. They B<must> be performed in order, and any error in one stage B<must> abort the entire process, unless the user explicitly asks otherwise; the CPAN client B<may> try to fall back on dynamic install on error. Actions  B<must> be done during build-time unless noted otherwise. The order of different actions within the same phase is unspecified. Arguments that would be passed to a stage for a dynamic install B<must> be handled by the CPAN client exactly as in CPAN::API::BuildPL. The stages are:

=over 4

=item * configure

=item * build

=item * test

=item * install

=back

=head1 EXTERNAL REQUIREMENTS

As static install intends to be an optimization, a valid F<Build.PL> (per CPAN::API::BuildPL) or F<Makefile.PL> B<must> be present as a fallback.

=head1 FEATURES

For a CPAN client to use static install, it B<must> be able to satisfy all requirements in the C<x_static_install> in the Meta file. The value of this key is a prereq hash as described in C<CPAN::Meta::Spec>, except that it uses features instead of modules for subkeys.

The following features are defined in this specification. New features can be defined outside of this spec. The features described here can be updated by a new version of this spec. Any I<appropriate install location> refers to CPAN::API::BuildPL's install location section.

=over 4

=item * configure

Version 1 of this feature requires the cpan client to be able to configure a distribution. A valid F<MYMETA.json> (with the C<dynamic_config> key set to C<0>) B<must> be generated. It B<may> be copied verbatim to from F<META.json>. The same may be done for F<MYMETA.yml>/F<META.yml>. This action B<must> be done during configure-time.

=item * pm

Version 1 of this feature requires the cpan client to be able to build and install modules. It B<must> look recursively in F<lib/> for all F<*.pm> and F<*.pod> files and copy these to the appropriate location C<lib> files during install. If applicable, these modules B<should> be autosplit and their permissions B<should> be set appropriately for that platform.

=item * script

Version 1 of this feature requires the cpan client to be able to build and install scripts. It B<must> look non-recursively in F<script/> for all files and install these to the appropriate location for C<script> files during intstall. Their permissions B<must> be set appropriately for that platform for an executable and if necessary on that platform helpers B<must> be added.

=item * doc

Version 1 of this feature requires the cpan client to be able to build and install platform appropriate documentation for modules and scripts from POD. The modules and scripts B<must> be found as described in the C<pm> and C<script> features. If generating man pages, they B<must> be put in appropriate location for C<libdoc> and C<bindoc>. If generating HTML documentation, they B<must> be put in the location for C<libhtml> and C<binhtml>.

=item * share

Version 1 of this feature requires the cpan client to be able to build and install a sharedir. The cpan client B<must> install the content of F<share/> to F<auto/share/dist/$distribution_name/> subdirectory of the appropriate directory for C<lib> files, where C<$distribution_name> is defined by the C<name> field in the META file.

=item * test 

Version 1 of this feature requires the cpan client to be able to build and install modules. Unless the user has explicitly asked this step to be skipped, it B<must> look recursively in F<t/> for all F<*.t> files and run them through a TAP harness. A failure of any of the tests B<must> be considered a fatal error. This action B<must> be done during test-time.

=item * install

Version 1 of this feature requires the cpan client to be able to install the contents of F<blib/>. The files and the generated metadata B<must> be installed as described in C<CPAN::API::BuildPL> 1.0. This action B<must> be done during install-time.

=back

All CPAN clients implementing static install B<must> support version 1 of C<pm>, C<script>, C<test> and C<install>. They B<should> support version 1 of C<doc> and C<share>.

