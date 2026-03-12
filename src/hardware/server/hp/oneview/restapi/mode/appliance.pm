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

package hardware::server::hp::oneview::restapi::mode::appliance;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_health_output {
    my ($self, %options) = @_;
    return sprintf('appliance health: %s', $self->{result_values}->{health_status});
}

sub custom_info_output {
    my ($self, %options) = @_;
    return sprintf(
        'model: %s, serial: %s, firmware: %s, hostname: %s',
        $self->{result_values}->{model},
        $self->{result_values}->{serial_number},
        $self->{result_values}->{firmware_version},
        $self->{result_values}->{hostname}
    );
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'appliance', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'licenses',  type => 1, cb_prefix_output => 'prefix_license_output',
          message_multiple => 'All licenses are ok', skipped_code => { -10 => 1 } },
        { name => 'components', type => 1, cb_prefix_output => 'prefix_component_output',
          message_multiple => 'All appliance components are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Appliance global ----
    $self->{maps_counters}->{appliance} = [
        # Health status (drives OK/WARN/CRIT)
        { label => 'appliance-health', threshold => 0, set => {
                key_values => [ { name => 'health_status' } ],
                closure_custom_calc   => \&catalog_status_calc,
                closure_custom_output => $self->can('custom_health_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        # Informational output (no perfdata, no threshold)
        { label => 'appliance-info', threshold => 0, set => {
                key_values => [
                    { name => 'model' },
                    { name => 'serial_number' },
                    { name => 'firmware_version' },
                    { name => 'hostname' },
                ],
                closure_custom_calc   => \&catalog_status_calc,
                closure_custom_output => $self->can('custom_info_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => sub { return 'ok'; },
            }
        },
        # API version (numeric perfdata - useful for change detection)
        { label => 'api-version', nlabel => 'appliance.api.version', display_ok => 0, set => {
                key_values      => [ { name => 'api_version' } ],
                output_template => 'API version: %d',
                perfdatas       => [
                    { value => 'api_version', template => '%d', min => 0 },
                ],
            }
        },
        # Uptime in seconds
        { label => 'uptime', nlabel => 'appliance.uptime.seconds', display_ok => 0, set => {
                key_values      => [ { name => 'uptime_seconds' } ],
                output_template => 'uptime: %d s',
                perfdatas       => [
                    { value => 'uptime_seconds', template => '%d', unit => 's', min => 0 },
                ],
            }
        },
        # Health components counts
        { label => 'health-components-ok', nlabel => 'appliance.health.components.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'components_ok' } ],
                output_template => 'health components ok: %d',
                perfdatas       => [ { value => 'components_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'health-components-warning', nlabel => 'appliance.health.components.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'components_warning' } ],
                output_template => 'health components warning: %d',
                perfdatas       => [ { value => 'components_warning', template => '%d', min => 0 } ],
            }
        },
        { label => 'health-components-critical', nlabel => 'appliance.health.components.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'components_critical' } ],
                output_template => 'health components critical: %d',
                perfdatas       => [ { value => 'components_critical', template => '%d', min => 0 } ],
            }
        },
        # License counts
        { label => 'licenses-total', nlabel => 'appliance.licenses.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'licenses_total' } ],
                output_template => 'licenses total: %d',
                perfdatas       => [ { value => 'licenses_total', template => '%d', min => 0 } ],
            }
        },
    ];

    # ---- Per health component ----
    $self->{maps_counters}->{components} = [
        { label => 'component-health', threshold => 0, set => {
                key_values => [
                    { name => 'health_status' },
                    { name => 'display' },
                ],
                closure_custom_calc   => \&catalog_status_calc,
                closure_custom_output => sub {
                    my ($self, %options) = @_;
                    return sprintf('health: %s', $self->{result_values}->{health_status});
                },
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];

    # ---- Per license ----
    $self->{maps_counters}->{licenses} = [
        { label => 'license-consumed', nlabel => 'appliance.license.consumed.count', display_ok => 0, set => {
                key_values      => [ { name => 'consumed' }, { name => 'display' } ],
                output_template => 'consumed: %d',
                perfdatas       => [
                    { value => 'consumed', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'license-available', nlabel => 'appliance.license.available.count', display_ok => 0, set => {
                key_values      => [ { name => 'available' }, { name => 'total' }, { name => 'display' } ],
                output_template => 'available: %d',
                perfdatas       => [
                    { value => 'available', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'license-total', nlabel => 'appliance.license.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' }, { name => 'display' } ],
                output_template => 'total: %d',
                perfdatas       => [
                    { value => 'total', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

sub prefix_license_output {
    my ($self, %options) = @_;
    return "License '" . $options{instance_value}->{display} . "' ";
}

sub prefix_component_output {
    my ($self, %options) = @_;
    return "Component '" . $options{instance_value}->{display} . "' ";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-component:s'          => { name => 'filter_component' },
        'filter-license-type:s'       => { name => 'filter_license_type' },
        'unknown-appliance-health:s'  => { name => 'unknown_appliance_health',
            default => '%{health_status} =~ /unknown/i' },
        'warning-appliance-health:s'  => { name => 'warning_appliance_health',
            default => '%{health_status} =~ /warning/i' },
        'critical-appliance-health:s' => { name => 'critical_appliance_health',
            default => '%{health_status} =~ /critical/i' },
        'unknown-component-health:s'  => { name => 'unknown_component_health',
            default => '%{health_status} =~ /unknown/i' },
        'warning-component-health:s'  => { name => 'warning_component_health',
            default => '%{health_status} =~ /warning/i' },
        'critical-component-health:s' => { name => 'critical_component_health',
            default => '%{health_status} =~ /critical/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_appliance_health', 'critical_appliance_health', 'unknown_appliance_health',
        'warning_component_health', 'critical_component_health', 'unknown_component_health',
    ]);
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    # 1. Node info via ha-nodes (works on all OneView versions)
    my $ha_nodes = $options{custom}->request_api(
        url_path      => '/rest/appliance/ha-nodes',
        ignore_errors => 1
    );
    $ha_nodes //= {};
    # Use the active node for model/hostname info
    my $active_node = {};
    foreach my $node (@{$ha_nodes->{members} // []}) {
        if (lc($node->{role} // '') eq 'active') {
            $active_node = $node;
            last;
        }
    }
    $active_node = $ha_nodes->{members}->[0] if (!%$active_node && @{$ha_nodes->{members} // []});

    # 2. Health status + per-component breakdown
    my $health = $options{custom}->request_api(
        url_path      => '/rest/appliance/health-status',
        ignore_errors => 1
    );
    $health //= {};

    # 3. API version
    my $version = $options{custom}->request_api(
        url_path      => '/rest/version',
        ignore_errors => 1
    );
    $version //= {};

    # 4. Licenses
    my $licenses = $options{custom}->request_api(
        url_path      => '/rest/licenses?start=0&count=-1',
        ignore_errors => 1
    );
    $licenses //= { members => [] };

    # ---- Appliance global ----
    # Derive overall health from members severity (no top-level healthStatus field in this API version)
    my $overall_health;
    if (defined($health->{healthStatus})) {
        $overall_health = lc($health->{healthStatus});
    } else {
        # Aggregate: critical > warning > info/ok
        my $has_critical = 0;
        my $has_warning  = 0;
        my $has_members  = 0;
        foreach my $comp (@{$health->{members} // []}) {
            my $s = lc($comp->{severity} // $comp->{status} // '');
            $has_members = 1;
            $has_critical = 1 if ($s =~ /^(critical|error)$/);
            $has_warning  = 1 if ($s eq 'warning');
        }
        $overall_health = $has_critical ? 'critical'
                        : $has_warning  ? 'warning'
                        : $has_members  ? 'ok'
                        : 'unknown';
    }

    my ($comp_ok, $comp_warning, $comp_critical) = (0, 0, 0);
    foreach my $comp (@{$health->{members} // []}) {
        my $cs = lc($comp->{severity} // $comp->{status} // 'unknown');
        $comp_ok++       if ($cs =~ /^(ok|info|normal)$/);
        $comp_warning++  if ($cs eq 'warning');
        $comp_critical++ if ($cs =~ /^(critical|error)$/);
    }

    # Uptime from active ha-node
    my $uptime = $active_node->{uptime} // undef;

    $self->{appliance} = {
        health_status       => $overall_health,
        model               => $active_node->{model}           // 'n/a',
        serial_number       => $active_node->{serialNumber}    // 'n/a',
        firmware_version    => $active_node->{softwareVersion} // 'n/a',
        hostname            => $active_node->{hostname}        // $active_node->{name} // 'n/a',
        api_version         => $version->{currentVersion}   // undef,
        uptime_seconds      => $uptime,
        components_ok       => $comp_ok,
        components_warning  => $comp_warning,
        components_critical => $comp_critical,
        licenses_total      => scalar(@{$licenses->{members} // []}),
    };

    # ---- Per health component ----
    $self->{components} = {};
    my $comp_idx = 0;
    foreach my $comp (@{$health->{members} // []}) {
        # resourceType is the primary name field (e.g. MEMORY, CPU, DISK)
        my $cname = $comp->{resourceType} // $comp->{name} // $comp->{resourceName} // $comp->{description} // $comp->{category} // '';
        if ($cname eq '') {
            my $type = $comp->{type} // '';
            $type =~ s/^ApplianceHealthStatus//i;
            $type =~ s/V\d+$//i;
            $cname = $type;
        }
        if ($cname eq '') {
            my $uri = $comp->{uri} // $comp->{resourceUri} // '';
            ($cname) = $uri =~ m{/([^/]+)$};
            $cname //= '';
        }
        $comp_idx++;
        $cname = 'component-' . $comp_idx if ($cname eq '');
        if (defined($self->{option_results}->{filter_component}) && $self->{option_results}->{filter_component} ne '' &&
            $cname !~ /$self->{option_results}->{filter_component}/i) {
            $self->{output}->output_add(long_msg => "skipping component '$cname': no matching filter.", debug => 1);
            next;
        }
        $self->{components}->{$cname} = {
            display       => $cname,
            health_status => do {
                my $s = lc($comp->{severity} // $comp->{status} // 'unknown');
                # Normalize OneView severity values to standard ok/warning/critical
                $s =~ s/^(info|normal|sufficient[_\w]*)$/ok/i;
                $s =~ s/^(error)$/critical/i;
                $s;
            },
        };
    }

    # ---- Per license ----
    $self->{licenses} = {};
    foreach my $lic (@{$licenses->{members} // []}) {
        my $lname = $lic->{product} // $lic->{licenseType} // 'unknown';
        if (defined($self->{option_results}->{filter_license_type}) && $self->{option_results}->{filter_license_type} ne '' &&
            $lname !~ /$self->{option_results}->{filter_license_type}/i) {
            $self->{output}->output_add(long_msg => "skipping license '$lname': no matching filter.", debug => 1);
            next;
        }
        # Make key unique if multiple entries with same product name
        my $key = $lname;
        my $idx = 1;
        while (exists $self->{licenses}->{$key}) {
            $key = $lname . '_' . $idx++;
        }

        my $total     = $lic->{totalLicenses}     // 0;
        my $consumed  = $lic->{consumedLicenses}  // 0;
        my $available = $total - $consumed;

        $self->{licenses}->{$key} = {
            display   => $lname,
            total     => $total,
            consumed  => $consumed,
            available => $available >= 0 ? $available : 0,
        };
    }
}

1;

__END__

=head1 MODE

Check HPE OneView appliance health, node information and license usage.

Combines data from:
  /rest/appliance/ha-nodes   — model, serial, firmware version, hostname (from active node)
  /rest/appliance/health-status — overall health + per-component breakdown
  /rest/version               — current API version
  /rest/licenses              — license consumption per product

Global perfdata: API version, uptime (s), health component counts (ok/warning/critical),
total license count.
Per-component perfdata: health status check.
Per-license perfdata: total, consumed, available count.

=over 8

=item B<--filter-component>

Filter health components by name (can be a regexp).
Example: --filter-component='Management' to only check the Management component.

=item B<--filter-license-type>

Filter licenses by product name (can be a regexp).
Example: --filter-license-type='Advanced' to only check Advanced licenses.

=item B<--unknown-appliance-health>

Conditions for UNKNOWN appliance health (default: '%{health_status} =~ /unknown/i').
Variables: %{health_status}

=item B<--warning-appliance-health>

Conditions for WARNING appliance health (default: '%{health_status} =~ /warning/i').

=item B<--critical-appliance-health>

Conditions for CRITICAL appliance health (default: '%{health_status} =~ /critical/i').

=item B<--unknown-component-health>

Conditions for UNKNOWN per-component health (default: '%{health_status} =~ /unknown/i').
Variables: %{health_status}, %{display}

=item B<--warning-component-health>

Conditions for WARNING per-component health (default: '%{health_status} =~ /warning/i').

=item B<--critical-component-health>

Conditions for CRITICAL per-component health (default: '%{health_status} =~ /critical/i').

=item B<--warning-*> B<--critical-*>

Thresholds:
'api-version', 'uptime' (s),
'health-components-ok/warning/critical',
'licenses-total'.
Per-license: 'license-consumed', 'license-available', 'license-total'.

=back

=cut
