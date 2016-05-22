package Pod::Weaver::Plugin::PatchModule;

# DATE
# VERSION

use 5.010001;
use Moose;
with 'Pod::Weaver::Role::AddTextToSection';
with 'Pod::Weaver::Role::Section';

use Data::Sah::Normalize qw(normalize_schema);

sub _process_module {
    no strict 'refs';

    my ($self, $document, $input, $package) = @_;

    my $filename = $input->{filename};

    # XXX handle dynamically generated module (if there is such thing in the
    # future)
    local @INC = ("lib", @INC);

    {
        my $package_pm = $package;
        $package_pm =~ s!::!/!g;
        $package_pm .= ".pm";
        require $package_pm;
    }

    my ($target_mod, $desc) = $package =~ /(.+)::Patch::(.+)/;

    my $pd = $package->patch_data;
    $self->log_fatal(["I only support version 3 of patch data"])
        unless $pd->{v} == 3;

    {
        my $patches = $pd->{patches};
        my @pod;
        push @pod, "=over\n\n";
        for my $p (@$patches) {
            push @pod, "=item * $p->{action} C<$p->{sub_name}>\n\n";
        }
        push @pod, "=back\n\n";
        $self->add_text_to_section(
            $document, join("", @pod), 'PATCH CONTENTS',
            {after_section => ['DESCRIPTION']},
        );
    }

    {
        my $config = $pd->{config};
        last unless $config && keys(%$config);
        my @pod;
        push @pod, "=over\n\n";
        for my $cname (sort keys %$config) {
            my $c = $config->{$cname};
            my $sch = normalize_schema($c->{schema});

            push @pod, "=item * $cname => $sch->[0]\n\n";
            push @pod, "$c->{summary}.\n\n" if $c->{summary};
            # XXX add description (markdown to pod)
        }
        push @pod, "=back\n\n";
        $self->add_text_to_section(
            $document, join("", @pod), 'PATCH CONFIGURATION',
            {after_section => ['PATCH CONTENTS']},
        );
    }

    {
        my @pod = (
            "L<Module::Patch>\n\n",
            "L<$target_mod>\n\n",
        );
        $self->add_text_to_section(
            $document, join('', @pod), 'SEE ALSO',
        );
    }

    $self->log(["Generated POD for '%s'", $filename]);
}

sub weave_section {
    my ($self, $document, $input) = @_;

    my $filename = $input->{filename};

    my $package;
    if ($filename =~ m!^lib/(.+)\.pm$!) {
        $package = $1;
        $package =~ s!/!::!g;
        next unless $package =~ m/::Patch::/;
        $self->_process_module($document, $input, $package);
    }
}

1;
# ABSTRACT: Plugin to use when building patch modules

=for Pod::Coverage weave_section

=head1 SYNOPSIS

In F<weaver.ini>:

 [-PatchModule]


=head1 DESCRIPTION

This plugin is used when building patch modules (modules that use
L<Module::Patch> to bundle a set of monkey patches, for example
L<File::Which::Patch::Hide> or L<perl-LWP-UserAgent-Patch-FilterMirror>). It
currently does the following:

=over

=item * Create "PATCH CONTENTS" section from information given by C<patch_data>

=item * Create "PATCH CONFIGURATION" section from list of configuration given by C<patch_data>

=item * Mention some modules in SEE ALSO section

e.g. L<Module::Patch> (the base module), the target module.

=back


=head1 SEE ALSO

L<Module::Patch>

L<Dist::Zilla::Plugin::PatchModule>
