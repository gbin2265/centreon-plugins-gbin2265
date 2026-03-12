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

package hardware::server::hp::oneview::restapi::mode::serverhardware;

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

sub custom_memory_output {
    my ($self, %options) = @_;
    my ($total_value, $total_unit) = $self->{perfdata}->change_bytes(
        value => $self->{result_values}->{memory_mb} * 1024 * 1024
    );
    return sprintf('memory: %s', $total_value . ' ' . $total_unit);
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'servers', type => 1, cb_prefix_output => 'prefix_server_output',
          message_multiple => 'All server hardware are ok', skipped_code => { -10 => 1 } },
    ];

    $self->{maps_counters}->{servers} = [
        # --- Status (no perfdata, but drives OK/WARN/CRIT) ---
        { label => 'status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'power_state' },
                    { name => 'display' },
                ],
                closure_custom_calc       => \&catalog_status_calc,
                closure_custom_output     => $self->can('custom_status_output'),
                closure_custom_perfdata   => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },

        # --- CPU count ---
        { label => 'cpu-count', nlabel => 'server.cpu.count', display_ok => 0, set => {
                key_values => [ { name => 'processor_count' }, { name => 'display' } ],
                output_template => 'cpu count: %d',
                perfdatas => [
                    { value => 'processor_count', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # --- Total cores ---
        { label => 'cpu-cores', nlabel => 'server.cpu.cores.total.count', display_ok => 0, set => {
                key_values => [ { name => 'total_cores' }, { name => 'display' } ],
                output_template => 'total cores: %d',
                perfdatas => [
                    { value => 'total_cores', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # --- Memory MB ---
        { label => 'memory', nlabel => 'server.memory.megabytes', display_ok => 0, set => {
                key_values => [ { name => 'memory_mb' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_memory_output'),
                perfdatas => [
                    { value => 'memory_mb', template => '%d', unit => 'MB', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # --- CPU utilization % (disabled with --no-utilization) ---
        { label => 'cpu-utilization', nlabel => 'server.cpu.utilization.percentage', display_ok => 0, set => {
                key_values => [ { name => 'cpu_utilization' }, { name => 'display' } ],
                output_template => 'cpu utilization: %.1f %%',
                perfdatas => [
                    { value => 'cpu_utilization', template => '%.1f', unit => '%',
                      min => 0, max => 100,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # --- Power consumption (Watts) ---
        { label => 'power-average', nlabel => 'server.power.usage.watts', display_ok => 0, set => {
                key_values => [ { name => 'power_avg' }, { name => 'display' } ],
                output_template => 'power avg: %.0f W',
                perfdatas => [
                    { value => 'power_avg', template => '%.0f', unit => 'W', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # --- Ambient temperature ---
        { label => 'temperature', nlabel => 'server.temperature.celsius', display_ok => 0, set => {
                key_values => [ { name => 'temperature' }, { name => 'display' } ],
                output_template => 'temperature: %.1f C',
                perfdatas => [
                    { value => 'temperature', template => '%.1f', unit => 'C',
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
        'filter-name:s'                 => { name => 'filter_name' },
        'filter-model:s'                => { name => 'filter_model' },
        'filter-enclosure:s'            => { name => 'filter_enclosure' },
        'filter-server-hardware-type:s' => { name => 'filter_server_hardware_type' },
        'filter-power-state:s'          => { name => 'filter_power_state' },
        'no-utilization'        => { name => 'no_utilization' },
        'unknown-status:s'      => { name => 'unknown_status',  default => '%{status} =~ /unknown/i' },
        'warning-status:s'      => { name => 'warning_status',  default => '%{status} =~ /warning/i' },
        'critical-status:s'     => { name => 'critical_status', default => '%{status} =~ /critical/i' },
        'unknown-power-state:s' => { name => 'unknown_power_state',  default => '%{power_state} =~ /unknown/i' },
        'warning-power-state:s' => { name => 'warning_power_state',  default => '' },
        'critical-power-state:s'=> { name => 'critical_power_state', default => '' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_status', 'critical_status', 'unknown_status',
        'warning_power_state', 'critical_power_state', 'unknown_power_state',
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
        # Take the most recent sample (last element of metricSamples)
        if (defined($metric->{metricSamples}) && scalar(@{$metric->{metricSamples}}) > 0) {
            my $last_sample = $metric->{metricSamples}->[-1];
            # Each sample is [timestamp, value]
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

    my $results = $options{custom}->request_api_all(url_path => '/rest/server-hardware');

    $self->{servers} = {};

    foreach my $server (@{$results->{members}}) {
        # Resolve display name: prefer serverName, fall back to name, then uri
        my $name = defined($server->{serverName}) && $server->{serverName} ne ''
            ? $server->{serverName}
            : (defined($server->{name}) ? $server->{name} : $server->{uri});

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(
                long_msg => "skipping server '$name': no matching filter.", debug => 1
            );
            next;
        }

        my $model = defined($server->{model}) ? $server->{model} : '';
        if (defined($self->{option_results}->{filter_model}) && $self->{option_results}->{filter_model} ne '' &&
            $model !~ /$self->{option_results}->{filter_model}/i) {
            $self->{output}->output_add(
                long_msg => "skipping server '$name': model '$model' no matching filter.", debug => 1
            );
            next;
        }

        my $enclosure_name = '';
        if (defined($server->{locationUri}) && $server->{locationUri} ne '') {
            ($enclosure_name) = $server->{locationUri} =~ m{/([^/]+)$};
            $enclosure_name //= $server->{locationUri};
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

        my $power_state = defined($server->{powerState}) ? lc($server->{powerState}) : 'unknown';
        if (defined($self->{option_results}->{filter_power_state}) && $self->{option_results}->{filter_power_state} ne '' &&
            $power_state !~ /$self->{option_results}->{filter_power_state}/i) {
            $self->{output}->output_add(long_msg => "skipping server '$name': power state '$power_state' no matching filter.", debug => 1);
            next;
        }

        my $processor_count = defined($server->{processorCount})     ? $server->{processorCount}     : 0;
        my $core_count      = defined($server->{processorCoreCount}) ? $server->{processorCoreCount} : 0;

        $self->{servers}->{$name} = {
            display         => $name,
            status          => defined($server->{status})     ? lc($server->{status})     : 'unknown',
            power_state     => defined($server->{powerState}) ? lc($server->{powerState}) : 'unknown',
            processor_count => $processor_count,
            total_cores     => $processor_count * $core_count,
            memory_mb       => defined($server->{memoryMb})   ? $server->{memoryMb}       : 0,
            # utilization fields — populated unless --no-utilization
            cpu_utilization => undef,
            power_avg       => undef,
            temperature     => undef,
        };

        # Per-server utilization call (active by default, disable with --no-utilization)
        if (!defined($self->{option_results}->{no_utilization}) && defined($server->{uri}) && $server->{uri} ne '') {
            my $util_data = $options{custom}->request_api(
                url_path      => $server->{uri} . '/utilization?fields=CpuUtilization,AveragePower,AmbientTemperature&view=native',
                ignore_errors => 1
            );
            if (defined($util_data)) {
                my %metrics = $self->_parse_utilization(data => $util_data);
                $self->{servers}->{$name}->{cpu_utilization} = $metrics{CpuUtilization}    if (defined($metrics{CpuUtilization}));
                $self->{servers}->{$name}->{power_avg}       = $metrics{AveragePower}       if (defined($metrics{AveragePower}));
                $self->{servers}->{$name}->{temperature}     = $metrics{AmbientTemperature} if (defined($metrics{AmbientTemperature}));
            }
        }
    }

    if (scalar(keys %{$self->{servers}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No server hardware found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView server hardware status and performance metrics.

Per-server perfdata: cpu count, total cores, memory (MB),
CPU utilization (%), power avg (W), ambient temperature (°C).
Use B<--no-utilization> to skip the extra utilization API call per server.

=over 8

=item B<--filter-name>

Filter server by name (can be a regexp).

=item B<--filter-model>

Filter servers by hardware model (can be a regexp).
Example: --filter-model='ProLiant BL460c'

=item B<--filter-enclosure>

Filter servers by their parent enclosure name (can be a regexp).

=item B<--filter-server-hardware-type>

Filter servers by their hardware type name (can be a regexp).
Example: --filter-server-hardware-type='BL460c Gen10'.

=item B<--filter-power-state>

Filter servers by power state before reporting (can be a regexp).
Common values: On, Off, Standby.
Example: --filter-power-state='On' to only monitor powered-on servers.

=item B<--no-utilization>

Disable real-time utilization data per server (CPU %, power W, temperature °C).
By default the plugin fetches utilization for each server — use this flag in large
environments where the extra API calls are undesirable.

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN
(default: '%{status} =~ /unknown/i').
Variables available: %{status}, %{power_state}, %{display}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING
(default: '%{status} =~ /warning/i').
Variables available: %{status}, %{power_state}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{status} =~ /critical/i').
Variables available: %{status}, %{power_state}, %{display}

=item B<--unknown-power-state>

Define the conditions to match for the power state to be UNKNOWN
(default: '%{power_state} =~ /unknown/i').
Variables available: %{status}, %{power_state}, %{display}

=item B<--warning-power-state>

Define the conditions to match for the power state to be WARNING (default: '').
Example to warn when a server is off: --warning-power-state='%{power_state} =~ /off/i'

=item B<--critical-power-state>

Define the conditions to match for the power state to be CRITICAL (default: '').

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'cpu-count', 'cpu-cores', 'memory' (MB),
'cpu-utilization' (%), 'power-average' (W, metric: AveragePower), 'temperature' (C).

=back

=cut
