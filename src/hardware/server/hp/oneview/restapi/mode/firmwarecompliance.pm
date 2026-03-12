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

package hardware::server::hp::oneview::restapi::mode::firmwarecompliance;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf(
        'compliance: %s [baseline: %s] [installed: %s]',
        $self->{result_values}->{compliance_state},
        $self->{result_values}->{baseline_version},
        $self->{result_values}->{installed_version}
    );
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'servers', type => 1, cb_prefix_output => 'prefix_server_output',
          message_multiple => 'All server firmware is compliant', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'servers-total', nlabel => 'firmware.compliance.servers.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total servers: %d',
                perfdatas       => [ { value => 'total', template => '%d', min => 0 } ],
            }
        },
        { label => 'servers-compliant', nlabel => 'firmware.compliance.servers.compliant.count', set => {
                key_values      => [ { name => 'compliant' } ],
                output_template => 'compliant: %d',
                perfdatas       => [ { value => 'compliant', template => '%d', min => 0 } ],
            }
        },
        { label => 'servers-noncompliant', nlabel => 'firmware.compliance.servers.noncompliant.count', set => {
                key_values      => [ { name => 'noncompliant' } ],
                output_template => 'non-compliant: %d',
                perfdatas       => [ { value => 'noncompliant', template => '%d', min => 0 } ],
            }
        },
        { label => 'servers-unknown', nlabel => 'firmware.compliance.servers.unknown.count', display_ok => 0, set => {
                key_values      => [ { name => 'unknown' } ],
                output_template => 'unknown: %d',
                perfdatas       => [ { value => 'unknown', template => '%d', min => 0 } ],
            }
        },
        { label => 'servers-no-baseline', nlabel => 'firmware.compliance.servers.nobaseline.count', display_ok => 0, set => {
                key_values      => [ { name => 'no_baseline' } ],
                output_template => 'no baseline assigned: %d',
                perfdatas       => [ { value => 'no_baseline', template => '%d', min => 0 } ],
            }
        },
    ];

    # ---- Per server ----
    $self->{maps_counters}->{servers} = [
        { label => 'firmware-compliance', threshold => 0, set => {
                key_values => [
                    { name => 'compliance_state' },
                    { name => 'baseline_version' },
                    { name => 'installed_version' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        # Number of components out of compliance on this server
        { label => 'components-noncompliant', nlabel => 'server.firmware.components.noncompliant.count', display_ok => 0, set => {
                key_values      => [ { name => 'components_noncompliant' }, { name => 'display' } ],
                output_template => 'non-compliant components: %d',
                perfdatas       => [
                    { value => 'components_noncompliant', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Total number of firmware components tracked on this server
        { label => 'components-total', nlabel => 'server.firmware.components.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'components_total' }, { name => 'display' } ],
                output_template => 'total components: %d',
                perfdatas       => [
                    { value => 'components_total', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

sub prefix_server_output {
    my ($self, %options) = @_;
    return "Server '" . $options{instance_value}->{display} . "' ";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'                    => { name => 'filter_name' },
        'filter-baseline:s'                => { name => 'filter_baseline' },
        'filter-compliance-state:s'        => { name => 'filter_compliance_state' },
        'filter-enclosure:s'               => { name => 'filter_enclosure' },
        'filter-server-hardware-type:s'    => { name => 'filter_server_hardware_type' },
        'unknown-firmware-compliance:s'  => { name => 'unknown_firmware_compliance',
            default => '%{compliance_state} =~ /unknown/i' },
        'warning-firmware-compliance:s'  => { name => 'warning_firmware_compliance',
            default => '' },
        'critical-firmware-compliance:s' => { name => 'critical_firmware_compliance',
            default => '%{compliance_state} =~ /nonCompliant/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_firmware_compliance', 'critical_firmware_compliance', 'unknown_firmware_compliance',
    ]);
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/server-hardware');

    $self->{global} = {
        total        => 0,
        compliant    => 0,
        noncompliant => 0,
        unknown      => 0,
        no_baseline  => 0,
    };
    $self->{servers} = {};

    foreach my $server (@{$results->{members}}) {
        my $name = defined($server->{serverName}) && $server->{serverName} ne ''
            ? $server->{serverName}
            : (defined($server->{name}) ? $server->{name} : $server->{uri});

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping server '$name': no matching filter.", debug => 1);
            next;
        }

        my $enclosure_name = '';
        if (defined($server->{locationUri}) && $server->{locationUri} ne '') {
            ($enclosure_name) = $server->{locationUri} =~ m{/([^/]+)$};
            $enclosure_name //= '';
        }
        if (defined($self->{option_results}->{filter_enclosure}) && $self->{option_results}->{filter_enclosure} ne '' &&
            $enclosure_name !~ /$self->{option_results}->{filter_enclosure}/) {
            $self->{output}->output_add(long_msg => "skipping server '$name': enclosure '$enclosure_name' no matching filter.", debug => 1);
            next;
        }

        my $sht_name = '';
        if (defined($server->{serverHardwareTypeUri}) && $server->{serverHardwareTypeUri} ne '') {
            ($sht_name) = $server->{serverHardwareTypeUri} =~ m{/([^/]+)$};
            $sht_name //= '';
        }
        if (defined($self->{option_results}->{filter_server_hardware_type}) && $self->{option_results}->{filter_server_hardware_type} ne '' &&
            $sht_name !~ /$self->{option_results}->{filter_server_hardware_type}/i) {
            $self->{output}->output_add(long_msg => "skipping server '$name': hardware type '$sht_name' no matching filter.", debug => 1);
            next;
        }

        # firmware field lives in server-hardware response
        my $fw = $server->{firmware} // {};

        # firmwareAndDriversInstallState: installedStateTimestamp, installState
        # firmwareVersion: serverFirmwareVersion (the installed SPP/baseline version)
        # romVersion, ilo fields also present but we focus on SPP compliance

        my $installed_version = $fw->{serverFirmwareVersion}  // 'n/a';
        my $baseline_version  = 'none';
        my $compliance_state  = 'noBaseline';
        my $components_total       = 0;
        my $components_noncompliant = 0;

        # Check if a firmware baseline is assigned via the profile
        # The server-hardware object carries firmwareAndDriversInstallState
        if (defined($fw->{firmwareAndDriversInstallState})) {
            my $install_state = lc($fw->{firmwareAndDriversInstallState}->{installState} // 'unknown');
            # Map installState to a compliance state
            if ($install_state eq 'installed') {
                $compliance_state = 'compliant';
            } elsif ($install_state =~ /failed|mismatch|noncompliant/) {
                $compliance_state = 'nonCompliant';
            } elsif ($install_state eq 'unknown' || $install_state eq '') {
                $compliance_state = 'unknown';
            } else {
                $compliance_state = $install_state;
            }
        }

        # romVersion can serve as a proxy for the installed baseline label
        $baseline_version = $fw->{romVersion} if (defined($fw->{romVersion}) && $fw->{romVersion} ne '');

        if (defined($self->{option_results}->{filter_baseline}) && $self->{option_results}->{filter_baseline} ne '' &&
            $baseline_version !~ /$self->{option_results}->{filter_baseline}/) {
            $self->{output}->output_add(
                long_msg => "skipping server '$name': baseline '$baseline_version' no matching filter.", debug => 1
            );
            next;
        }

        # Count component-level compliance if available
        if (defined($server->{firmware}->{components})) {
            foreach my $comp (@{$server->{firmware}->{components}}) {
                $components_total++;
                my $comp_state = lc($comp->{componentVersion} // '');
                # A component is non-compliant if its installed version differs from the expected
                if (defined($comp->{expectedVersion}) && defined($comp->{componentVersion}) &&
                    $comp->{componentVersion} ne $comp->{expectedVersion}) {
                    $components_noncompliant++;
                }
            }
        }

        # Global counters
        $self->{global}->{total}++;
        if ($compliance_state eq 'compliant') {
            $self->{global}->{compliant}++;
        } elsif ($compliance_state eq 'nonCompliant') {
            $self->{global}->{noncompliant}++;
        } elsif ($compliance_state eq 'noBaseline') {
            $self->{global}->{no_baseline}++;
        } else {
            $self->{global}->{unknown}++;
        }

        # Apply compliance state filter after counting globals
        if (defined($self->{option_results}->{filter_compliance_state}) && $self->{option_results}->{filter_compliance_state} ne '' &&
            $compliance_state !~ /$self->{option_results}->{filter_compliance_state}/i) {
            $self->{output}->output_add(
                long_msg => "skipping server '$name': compliance state '$compliance_state' no matching filter.", debug => 1
            );
            next;
        }

        $self->{servers}->{$name} = {
            display                => $name,
            compliance_state       => $compliance_state,
            baseline_version       => $baseline_version,
            installed_version      => $installed_version,
            components_total       => $components_total,
            components_noncompliant => $components_noncompliant,
        };

        $self->{output}->output_add(
            long_msg => sprintf(
                "server '%s' firmware compliance: %s [baseline: %s] [installed: %s] [non-compliant components: %d/%d]",
                $name, $compliance_state, $baseline_version, $installed_version,
                $components_noncompliant, $components_total
            )
        );
    }

    if (scalar(keys %{$self->{servers}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No servers found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView server hardware firmware compliance against the assigned baseline.

Uses the firmware information embedded in the B</rest/server-hardware> response —
no extra API call per server is needed.

Global perfdata: total servers, compliant, non-compliant, unknown, no-baseline counts.
Per-server perfdata: non-compliant component count, total component count.

=over 8

=item B<--filter-name>

Filter server by name (can be a regexp).

=item B<--filter-baseline>

Filter servers by baseline version label (can be a regexp).
Useful to scope checks to a specific SPP version.

=item B<--filter-compliance-state>

Filter servers by compliance state (can be a regexp).
Example: --filter-compliance-state='nonCompliant' to only report non-compliant servers.
Note: global counters are computed before this filter is applied.

=item B<--filter-enclosure>

Filter servers by their parent enclosure name (can be a regexp).
Example: --filter-enclosure='Synergy-Frame-1'.

=item B<--filter-server-hardware-type>

Filter servers by their hardware type name (can be a regexp).
Example: --filter-server-hardware-type='BL460c Gen10'.

=item B<--unknown-firmware-compliance>

Conditions for UNKNOWN compliance status (default: '%{compliance_state} =~ /unknown/i').
Variables: %{compliance_state}, %{baseline_version}, %{installed_version}, %{display}

=item B<--warning-firmware-compliance>

Conditions for WARNING compliance status (default: '').
Example: --warning-firmware-compliance='%{components_noncompliant} > 0'

=item B<--critical-firmware-compliance>

Conditions for CRITICAL compliance status
(default: '%{compliance_state} =~ /nonCompliant/i').
Variables: %{compliance_state}, %{baseline_version}, %{installed_version}, %{display}

=item B<--warning-*> B<--critical-*>

Global thresholds:
'servers-total', 'servers-compliant', 'servers-noncompliant',
'servers-unknown', 'servers-no-baseline'.

Per-server thresholds:
'components-noncompliant', 'components-total'.

=back

=cut
