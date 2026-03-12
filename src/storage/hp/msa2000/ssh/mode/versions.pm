#
# Copyright 2026 Centreon (http://www.centreon.com/)
#
# Centreon is a full-fledged industry-strength solution that meets
# the needs in IT infrastructure and application monitoring for
# service performance.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

package storage::hp::msa2000::ssh::mode::versions;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_mismatch_output {
    my ($self, %options) = @_;

    if ($self->{result_values}->{mismatch} eq 'yes') {
        return sprintf('firmware mismatch: %s', $self->{result_values}->{mismatch_detail});
    }
    return sprintf('bundle: %s, sc-fw: %s, mc-fw: %s, hw: %s',
        $self->{result_values}->{bundle_version},
        $self->{result_values}->{sc_fw},
        $self->{result_values}->{mc_fw},
        $self->{result_values}->{hw_rev}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'mismatch-status',
            type => 2,
            warning_default => '',
            critical_default => '%{mismatch} eq "yes"',
            set => {
                key_values => [ { name => 'mismatch' }, { name => 'mismatch_detail' }, { name => 'bundle_version' }, { name => 'sc_fw' }, { name => 'mc_fw' }, { name => 'hw_rev' } ],
                closure_custom_output => $self->can('custom_mismatch_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($result) = $options{custom}->get_infos(
        cmd => 'show versions',
        base_type => 'versions',
        properties_name => '^(?:bundle-version|bundle-status|bundle-status-numeric|sc-fw|sc-cpu-type|mc-fw|ec-fw|hw-rev|pld-rev|build-date|sc-loader|capi-version|sc-fu-version)$'
    );

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    my @bundle_versions;
    my @sc_fw_versions;
    my @mc_fw_versions;
    my @hw_revisions;

    foreach my $ver (@items) {
        my $bundle = defined($ver->{'bundle-version'}) ? $ver->{'bundle-version'} : '-';
        my $sc_fw = defined($ver->{'sc-fw'}) ? $ver->{'sc-fw'} : '-';
        my $mc_fw = defined($ver->{'mc-fw'}) ? $ver->{'mc-fw'} : '-';
        my $hw_rev = defined($ver->{'hw-rev'}) ? $ver->{'hw-rev'} : '-';

        push @bundle_versions, $bundle;
        push @sc_fw_versions, $sc_fw;
        push @mc_fw_versions, $mc_fw;
        push @hw_revisions, $hw_rev;

        # Verbose: show all version details per controller
        $self->{output}->output_add(long_msg => sprintf(
            "bundle: %s sc-fw: %s mc-fw: %s ec-fw: %s hw: %s cpld: %s cpu: %s build: %s",
            $bundle, $sc_fw, $mc_fw,
            defined($ver->{'ec-fw'}) ? $ver->{'ec-fw'} : '-',
            $hw_rev,
            defined($ver->{'pld-rev'}) ? $ver->{'pld-rev'} : '-',
            defined($ver->{'sc-cpu-type'}) ? $ver->{'sc-cpu-type'} : '-',
            defined($ver->{'build-date'}) ? $ver->{'build-date'} : '-'
        ));
    }

    # Check for version mismatch between controllers
    my @mismatches;
    if (scalar(@bundle_versions) >= 2) {
        if ($bundle_versions[0] ne $bundle_versions[1]) {
            push @mismatches, sprintf('bundle (%s vs %s)', $bundle_versions[0], $bundle_versions[1]);
        }
        if ($sc_fw_versions[0] ne $sc_fw_versions[1]) {
            push @mismatches, sprintf('sc-fw (%s vs %s)', $sc_fw_versions[0], $sc_fw_versions[1]);
        }
        if ($mc_fw_versions[0] ne $mc_fw_versions[1]) {
            push @mismatches, sprintf('mc-fw (%s vs %s)', $mc_fw_versions[0], $mc_fw_versions[1]);
        }
    }

    $self->{global} = {
        mismatch => scalar(@mismatches) > 0 ? 'yes' : 'no',
        mismatch_detail => scalar(@mismatches) > 0 ? join(', ', @mismatches) : 'all versions match',
        bundle_version => $bundle_versions[0] // '-',
        sc_fw => $sc_fw_versions[0] // '-',
        mc_fw => $mc_fw_versions[0] // '-',
        hw_rev => $hw_revisions[0] // '-',
    };

    if (scalar(@items) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No version information found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check controller firmware versions and validate both controllers run the same firmware.

Uses 'show versions' to retrieve bundle version, storage controller firmware,
management controller firmware, and hardware revision per controller.
Raises CRITICAL if controllers have mismatched firmware versions.

=over 8

=item B<--warning-mismatch-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{mismatch}, %{mismatch_detail},
%{bundle_version}, %{sc_fw}, %{mc_fw}, %{hw_rev}

=item B<--critical-mismatch-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{mismatch} eq "yes"').
You can use the following variables: %{mismatch}, %{mismatch_detail},
%{bundle_version}, %{sc_fw}, %{mc_fw}, %{hw_rev}

=back

=cut
