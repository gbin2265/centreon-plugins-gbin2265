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

package hardware::server::hp::oneview::restapi::mode::powerdevices;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [power: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{power_state}
    );
}

sub custom_global_output {
    my ($self, %options) = @_;
    return sprintf(
        'power devices: %d total, %d on, %d off, %d unknown',
        $self->{result_values}->{total},
        $self->{result_values}->{powered_on},
        $self->{result_values}->{powered_off},
        $self->{result_values}->{powered_unknown},
    );
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'devices', type => 1, cb_prefix_output => 'prefix_device_output',
          message_multiple => 'All power devices are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary counters ----
    $self->{maps_counters}->{global} = [
        { label => 'devices-total', nlabel => 'powerdevices.total.count', display_ok => 0, set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %d',
                perfdatas => [
                    { value => 'total', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'devices-powered-on', nlabel => 'powerdevices.powered.on.count', display_ok => 0, set => {
                key_values => [ { name => 'powered_on' } ],
                output_template => 'on: %d',
                perfdatas => [
                    { value => 'powered_on', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'devices-powered-off', nlabel => 'powerdevices.powered.off.count', display_ok => 0, set => {
                key_values => [ { name => 'powered_off' } ],
                output_template => 'off: %d',
                perfdatas => [
                    { value => 'powered_off', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'devices-status-ok', nlabel => 'powerdevices.status.ok.count', display_ok => 0, set => {
                key_values => [ { name => 'status_ok' } ],
                output_template => 'health ok: %d',
                perfdatas => [
                    { value => 'status_ok', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'devices-status-warning', nlabel => 'powerdevices.status.warning.count', display_ok => 0, set => {
                key_values => [ { name => 'status_warning' } ],
                output_template => 'health warning: %d',
                perfdatas => [
                    { value => 'status_warning', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'devices-status-critical', nlabel => 'powerdevices.status.critical.count', display_ok => 0, set => {
                key_values => [ { name => 'status_critical' } ],
                output_template => 'health critical: %d',
                perfdatas => [
                    { value => 'status_critical', template => '%d', min => 0 },
                ],
            }
        },
    ];

    # ---- Per-device counters ----
    $self->{maps_counters}->{devices} = [
        { label => 'device-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'power_state' },
                    { name => 'display' },
                ],
                closure_custom_calc           => \&catalog_status_calc,
                closure_custom_output         => $self->can('custom_status_output'),
                closure_custom_perfdata       => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },

        # --- Discovered power load (Watts) from utilization endpoint ---
        { label => 'device-power-load', nlabel => 'powerdevice.power.load.watts', display_ok => 0, set => {
                key_values => [ { name => 'power_load' }, { name => 'display' } ],
                output_template => 'power load: %.0f W',
                perfdatas => [
                    { value => 'power_load', template => '%.0f', unit => 'W', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # --- Voltage (V) ---
        { label => 'device-voltage', nlabel => 'powerdevice.voltage.volt', display_ok => 0, set => {
                key_values => [ { name => 'voltage' }, { name => 'display' } ],
                output_template => 'voltage: %.1f V',
                perfdatas => [
                    { value => 'voltage', template => '%.1f', unit => 'V',
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # --- Current (A) ---
        { label => 'device-current', nlabel => 'powerdevice.current.ampere', display_ok => 0, set => {
                key_values => [ { name => 'current' }, { name => 'display' } ],
                output_template => 'current: %.2f A',
                perfdatas => [
                    { value => 'current', template => '%.2f', unit => 'A', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

sub prefix_device_output {
    my ($self, %options) = @_;
    return "Power device '" . $options{instance_value}->{display} . "' ";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'          => { name => 'filter_name' },
        'filter-type:s'          => { name => 'filter_type' },
        'filter-location:s'      => { name => 'filter_location' },
        'no-utilization'         => { name => 'no_utilization' },
        'unknown-device-status:s'  => { name => 'unknown_device_status',  default => '%{status} =~ /unknown/i' },
        'warning-device-status:s'  => { name => 'warning_device_status',  default => '%{status} =~ /warning/i' },
        'critical-device-status:s' => { name => 'critical_device_status', default => '%{status} =~ /critical/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_device_status', 'critical_device_status', 'unknown_device_status',
    ]);
}

# -------------------------------------------------------------------------
# Utility: parse utilization metricList response
# -------------------------------------------------------------------------

sub _parse_utilization {
    my ($self, %options) = @_;

    my %metrics;
    return %metrics unless (defined($options{data}) && defined($options{data}->{metricList}));

    foreach my $metric (@{$options{data}->{metricList}}) {
        my $name = $metric->{metricName};
        if (defined($metric->{metricSamples}) && scalar(@{$metric->{metricSamples}}) > 0) {
            my $last_sample = $metric->{metricSamples}->[-1];
            $metrics{$name} = $last_sample->[1] if (defined($last_sample->[1]));
        }
    }

    return %metrics;
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/power-devices');

    $self->{global} = {
        total            => 0,
        powered_on       => 0,
        powered_off      => 0,
        powered_unknown  => 0,
        status_ok        => 0,
        status_warning   => 0,
        status_critical  => 0,
    };
    $self->{devices} = {};

    foreach my $device (@{$results->{members}}) {
        my $name = defined($device->{name}) ? $device->{name} : $device->{uri};

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(
                long_msg => "skipping power device '$name': no matching filter.", debug => 1
            );
            next;
        }

        my $device_type = defined($device->{deviceType}) ? $device->{deviceType} : 'Unknown';
        if (defined($self->{option_results}->{filter_type}) && $self->{option_results}->{filter_type} ne '' &&
            $device_type !~ /$self->{option_results}->{filter_type}/i) {
            $self->{output}->output_add(long_msg => "skipping power device '$name': type '$device_type' no matching filter.", debug => 1);
            next;
        }

        my $location = '';
        if (defined($device->{rackUri}) && $device->{rackUri} ne '') {
            ($location) = $device->{rackUri} =~ m{/([^/]+)$};
        } elsif (defined($device->{scopeUri}) && $device->{scopeUri} ne '') {
            ($location) = $device->{scopeUri} =~ m{/([^/]+)$};
        }
        if (defined($self->{option_results}->{filter_location}) && $self->{option_results}->{filter_location} ne '' &&
            $location !~ /$self->{option_results}->{filter_location}/i) {
            $self->{output}->output_add(long_msg => "skipping power device '$name': location '$location' no matching filter.", debug => 1);
            next;
        }

        my $status      = defined($device->{status})     ? lc($device->{status})     : 'unknown';
        my $power_state = defined($device->{powerState}) ? lc($device->{powerState}) : 'unknown';

        # Update global counters
        $self->{global}->{total}++;
        $self->{global}->{'powered_' . $power_state}++
            if (exists $self->{global}->{'powered_' . $power_state});
        $self->{global}->{'status_' . $status}++
            if (exists $self->{global}->{'status_' . $status});

        $self->{devices}->{$name} = {
            display     => $name,
            status      => $status,
            power_state => $power_state,
            power_load  => undef,
            voltage     => undef,
            current     => undef,
        };

        # Optional per-device utilization (iPDU / managed PDU)
        if (!defined($self->{option_results}->{no_utilization}) && defined($device->{uri}) && $device->{uri} ne '') {
            my $util_data = $options{custom}->request_api(
                url_path      => $device->{uri} . '/utilization?fields=PowerAvg,Voltage,Current&view=native',
                ignore_errors => 1
            );
            if (defined($util_data)) {
                my %metrics = $self->_parse_utilization(data => $util_data);
                $self->{devices}->{$name}->{power_load} = $metrics{PowerAvg} if (defined($metrics{PowerAvg}));
                $self->{devices}->{$name}->{voltage}    = $metrics{Voltage}   if (defined($metrics{Voltage}));
                $self->{devices}->{$name}->{current}    = $metrics{Current}   if (defined($metrics{Current}));
            }
        }
    }

    if (scalar(keys %{$self->{devices}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No power devices found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView power devices (PDUs, UPSes) status and utilization.

Global perfdata: total device count, powered on/off counts, health status counts.
Per-device perfdata: health status.
By default also fetches real-time utilization (power W, voltage V, current A) per device.
Use B<--no-utilization> to disable those extra API calls.

=over 8

=item B<--filter-name>

Filter power device by name (can be a regexp).

=item B<--filter-type>

Filter power devices by type (can be a regexp).
Common values: PDU, UPS, BranchCircuit, iPDU.

=item B<--filter-location>

Filter power devices by rack or location name (can be a regexp).
The location is derived from the device's rackUri or scopeUri.
Example: --filter-location='Rack-A'.

=item B<--no-utilization>

Disable real-time utilization data per device (power W, voltage V, current A).
Only supported on managed iPDUs. By default the plugin fetches utilization for each device.

=item B<--unknown-device-status>

Define the conditions to match for the device status to be UNKNOWN
(default: '%{status} =~ /unknown/i').
Variables available: %{status}, %{power_state}, %{display}

=item B<--warning-device-status>

Define the conditions to match for the device status to be WARNING
(default: '%{status} =~ /warning/i').
Variables available: %{status}, %{power_state}, %{display}

=item B<--critical-device-status>

Define the conditions to match for the device status to be CRITICAL
(default: '%{status} =~ /critical/i').
Variables available: %{status}, %{power_state}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds.
Global: 'devices-total', 'devices-powered-on', 'devices-powered-off',
        'devices-status-ok', 'devices-status-warning', 'devices-status-critical'.
Per-device: 'device-power-load' (W), 'device-voltage' (V), 'device-current' (A).

=back

=cut
