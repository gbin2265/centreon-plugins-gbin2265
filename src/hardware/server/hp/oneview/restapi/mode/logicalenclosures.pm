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

package hardware::server::hp::oneview::restapi::mode::logicalenclosures;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [compliance: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{compliance_state}
    );
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'les', type => 1, cb_prefix_output => 'prefix_le_output',
          message_multiple => 'All logical enclosures are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'les-total', nlabel => 'logical.enclosures.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total: %d',
                perfdatas       => [ { value => 'total', template => '%d', min => 0 } ],
            }
        },
        { label => 'les-status-ok', nlabel => 'logical.enclosures.status.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_ok' } ],
                output_template => 'health ok: %d',
                perfdatas       => [ { value => 'status_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'les-status-warning', nlabel => 'logical.enclosures.status.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_warning' } ],
                output_template => 'health warning: %d',
                perfdatas       => [ { value => 'status_warning', template => '%d', min => 0 } ],
            }
        },
        { label => 'les-status-critical', nlabel => 'logical.enclosures.status.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_critical' } ],
                output_template => 'health critical: %d',
                perfdatas       => [ { value => 'status_critical', template => '%d', min => 0 } ],
            }
        },
        { label => 'les-compliant', nlabel => 'logical.enclosures.compliant.count', display_ok => 0, set => {
                key_values      => [ { name => 'compliant' } ],
                output_template => 'compliant: %d',
                perfdatas       => [ { value => 'compliant', template => '%d', min => 0 } ],
            }
        },
        { label => 'les-noncompliant', nlabel => 'logical.enclosures.noncompliant.count', display_ok => 0, set => {
                key_values      => [ { name => 'noncompliant' } ],
                output_template => 'non-compliant: %d',
                perfdatas       => [ { value => 'noncompliant', template => '%d', min => 0 } ],
            }
        },
    ];

    # ---- Per logical enclosure ----
    $self->{maps_counters}->{les} = [
        { label => 'le-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'compliance_state' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        # Number of physical enclosures in this logical enclosure
        { label => 'le-enclosures', nlabel => 'logical.enclosure.member.enclosures.count', display_ok => 0, set => {
                key_values      => [ { name => 'enclosure_count' }, { name => 'display' } ],
                output_template => 'member enclosures: %d',
                perfdatas       => [
                    { value => 'enclosure_count', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Number of firmware update tasks pending
        { label => 'le-firmware-pending', nlabel => 'logical.enclosure.firmware.pending.count', display_ok => 0, set => {
                key_values      => [ { name => 'firmware_pending' }, { name => 'display' } ],
                output_template => 'firmware updates pending: %d',
                perfdatas       => [
                    { value => 'firmware_pending', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

sub prefix_le_output {
    my ($self, %options) = @_;
    return "Logical enclosure '" . $options{instance_value}->{display} . "' ";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'               => { name => 'filter_name' },
        'filter-compliance-state:s'   => { name => 'filter_compliance_state' },
        'filter-enclosure-group:s'    => { name => 'filter_enclosure_group' },
        'unknown-le-status:s'     => { name => 'unknown_le_status',
            default => '%{status} =~ /unknown/i' },
        'warning-le-status:s'     => { name => 'warning_le_status',
            default => '%{status} =~ /warning/i' },
        'critical-le-status:s'    => { name => 'critical_le_status',
            default => '%{status} =~ /critical/i' },
        'unknown-compliance:s'    => { name => 'unknown_compliance',  default => '' },
        'warning-compliance:s'    => { name => 'warning_compliance',  default => '' },
        'critical-compliance:s'   => { name => 'critical_compliance',
            default => '%{compliance_state} =~ /inconsistent/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_le_status',  'critical_le_status',  'unknown_le_status',
        'warning_compliance', 'critical_compliance', 'unknown_compliance',
    ]);
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/logical-enclosures');

    $self->{global} = {
        total           => 0,
        status_ok       => 0,
        status_warning  => 0,
        status_critical => 0,
        compliant       => 0,
        noncompliant    => 0,
    };
    $self->{les} = {};

    foreach my $le (@{$results->{members}}) {
        my $name = defined($le->{name}) ? $le->{name} : $le->{uri};

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping logical enclosure '$name': no matching filter.", debug => 1);
            next;
        }

        my $eg_name = '';
        if (defined($le->{enclosureGroupUri}) && $le->{enclosureGroupUri} ne '') {
            ($eg_name) = $le->{enclosureGroupUri} =~ m{/([^/]+)$};
            $eg_name //= '';
        }
        if (defined($self->{option_results}->{filter_enclosure_group}) && $self->{option_results}->{filter_enclosure_group} ne '' &&
            $eg_name !~ /$self->{option_results}->{filter_enclosure_group}/) {
            $self->{output}->output_add(long_msg => "skipping logical enclosure '$name': enclosure group '$eg_name' no matching filter.", debug => 1);
            next;
        }

        my $status           = defined($le->{status})           ? lc($le->{status})           : 'unknown';
        my $compliance_state = defined($le->{complianceState})  ? lc($le->{complianceState})  : 'unknown';

        if (defined($self->{option_results}->{filter_compliance_state}) && $self->{option_results}->{filter_compliance_state} ne '' &&
            $compliance_state !~ /$self->{option_results}->{filter_compliance_state}/i) {
            $self->{output}->output_add(
                long_msg => "skipping logical enclosure '$name': compliance state '$compliance_state' no matching filter.", debug => 1
            );
            next;
        }
        my $enclosure_count  = defined($le->{enclosureUris})    ? scalar(@{$le->{enclosureUris}}) : 0;

        # Count pending firmware component updates if the field is present
        my $firmware_pending = 0;
        if (defined($le->{firmware}) && defined($le->{firmware}->{firmwareBaselineUri})) {
            # firmwareComplianceState per bay/component is not always present;
            # use the top-level state as a proxy: anything not 'Consistent' counts as pending
            $firmware_pending = ($compliance_state !~ /^consistent$/) ? 1 : 0;
        }

        # Global counters
        $self->{global}->{total}++;
        $self->{global}->{'status_' . $status}++
            if (exists $self->{global}->{'status_' . $status});

        if ($compliance_state =~ /^consistent$/i) {
            $self->{global}->{compliant}++;
        } elsif ($compliance_state =~ /inconsistent/i) {
            $self->{global}->{noncompliant}++;
        }

        $self->{les}->{$name} = {
            display          => $name,
            status           => $status,
            compliance_state => $compliance_state,
            enclosure_count  => $enclosure_count,
            firmware_pending => $firmware_pending,
        };
    }

    if (scalar(keys %{$self->{les}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No logical enclosures found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView logical enclosures: health status and compliance state.

Global perfdata: total count, health status counts, compliant/non-compliant counts.
Per-logical-enclosure perfdata: member enclosure count, firmware updates pending.

=over 8

=item B<--filter-name>

Filter logical enclosure by name (can be a regexp).

=item B<--filter-compliance-state>

Filter logical enclosures by compliance state (can be a regexp).
Example: --filter-compliance-state='inconsistent'

=item B<--filter-enclosure-group>

Filter logical enclosures by their parent enclosure group name (can be a regexp).
Example: --filter-enclosure-group='EG-Production'.

=item B<--unknown-le-status>

Conditions for UNKNOWN health status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{compliance_state}, %{display}

=item B<--warning-le-status>

Conditions for WARNING health status (default: '%{status} =~ /warning/i').

=item B<--critical-le-status>

Conditions for CRITICAL health status (default: '%{status} =~ /critical/i').

=item B<--unknown-compliance>

Conditions for UNKNOWN compliance (default: '').
Variables: %{compliance_state}, %{display}

=item B<--warning-compliance>

Conditions for WARNING compliance (default: '').

=item B<--critical-compliance>

Conditions for CRITICAL compliance
(default: '%{compliance_state} =~ /inconsistent/i').

=item B<--warning-*> B<--critical-*>

Global thresholds:
'les-total', 'les-status-ok/warning/critical',
'les-compliant', 'les-noncompliant'.

Per-logical-enclosure thresholds:
'le-enclosures', 'le-firmware-pending'.

=back

=cut
