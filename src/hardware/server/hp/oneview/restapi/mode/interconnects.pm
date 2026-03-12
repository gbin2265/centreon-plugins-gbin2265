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

package hardware::server::hp::oneview::restapi::mode::interconnects;

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

sub custom_port_status_output {
    my ($self, %options) = @_;
    return sprintf('link: %s [enabled: %s] [type: %s]',
        $self->{result_values}->{port_status},
        $self->{result_values}->{enabled},
        $self->{result_values}->{port_type}
    );
}

sub custom_traffic_in_output {
    my ($self, %options) = @_;
    my ($value, $unit) = $self->{perfdata}->change_bytes(
        value => $self->{result_values}->{traffic_in} * 1000 / 8,
        network => 1
    );
    return sprintf('traffic in: %s/s', $value . ' ' . $unit);
}

sub custom_traffic_out_output {
    my ($self, %options) = @_;
    my ($value, $unit) = $self->{perfdata}->change_bytes(
        value => $self->{result_values}->{traffic_out} * 1000 / 8,
        network => 1
    );
    return sprintf('traffic out: %s/s', $value . ' ' . $unit);
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'interconnects', type => 1, cb_prefix_output => 'prefix_interconnect_output',
          message_multiple => 'All interconnects are ok', skipped_code => { -10 => 1 } },
        { name => 'ports', type => 2,
          cb_prefix_output => 'prefix_port_output',
          cb_long_output   => 'port_long_output',
          message_multiple => 'All ports are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'interconnects-total', nlabel => 'interconnects.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total: %d',
                perfdatas       => [
                    { value => 'total', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'interconnects-status-ok', nlabel => 'interconnects.status.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_ok' } ],
                output_template => 'health ok: %d',
                perfdatas       => [
                    { value => 'status_ok', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'interconnects-status-warning', nlabel => 'interconnects.status.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_warning' } ],
                output_template => 'health warning: %d',
                perfdatas       => [
                    { value => 'status_warning', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'interconnects-status-critical', nlabel => 'interconnects.status.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_critical' } ],
                output_template => 'health critical: %d',
                perfdatas       => [
                    { value => 'status_critical', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'ports-total', nlabel => 'interconnects.ports.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_total' } ],
                output_template => 'ports total: %d',
                perfdatas       => [
                    { value => 'ports_total', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'ports-linked', nlabel => 'interconnects.ports.linked.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_linked' } ],
                output_template => 'ports linked: %d',
                perfdatas       => [
                    { value => 'ports_linked', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'ports-unlinked', nlabel => 'interconnects.ports.unlinked.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_unlinked' } ],
                output_template => 'ports unlinked: %d',
                perfdatas       => [
                    { value => 'ports_unlinked', template => '%d', min => 0 },
                ],
            }
        },
    ];

    # ---- Per-interconnect module ----
    $self->{maps_counters}->{interconnects} = [
        { label => 'interconnect-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'power_state' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'interconnect-ports-enabled', nlabel => 'interconnect.ports.enabled.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_enabled' }, { name => 'display' } ],
                output_template => 'ports enabled: %d',
                perfdatas       => [
                    { value => 'ports_enabled', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'interconnect-ports-linked', nlabel => 'interconnect.ports.linked.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_linked' }, { name => 'display' } ],
                output_template => 'ports linked: %d',
                perfdatas       => [
                    { value => 'ports_linked', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'interconnect-temperature', nlabel => 'interconnect.temperature.celsius', display_ok => 0, set => {
                key_values      => [ { name => 'temperature' }, { name => 'display' } ],
                output_template => 'temperature: %.1f C',
                perfdatas       => [
                    { value => 'temperature', template => '%.1f', unit => 'C',
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'interconnect-power', nlabel => 'interconnect.power.usage.watts', display_ok => 0, set => {
                key_values      => [ { name => 'power_avg' }, { name => 'display' } ],
                output_template => 'power: %.0f W',
                perfdatas       => [
                    { value => 'power_avg', template => '%.0f', unit => 'W', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'interconnect-cpu-utilization', nlabel => 'interconnect.cpu.utilization.percentage', display_ok => 0, set => {
                key_values      => [ { name => 'cpu_utilization' }, { name => 'display' } ],
                output_template => 'cpu utilization: %.1f %%',
                perfdatas       => [
                    { value => 'cpu_utilization', template => '%.1f', unit => '%', min => 0, max => 100,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'interconnect-traffic-in', nlabel => 'interconnect.traffic.in.kilobits.second', display_ok => 0, set => {
                key_values            => [ { name => 'traffic_in' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_traffic_in_output'),
                perfdatas             => [
                    { value => 'traffic_in', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'interconnect-traffic-out', nlabel => 'interconnect.traffic.out.kilobits.second', display_ok => 0, set => {
                key_values            => [ { name => 'traffic_out' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_traffic_out_output'),
                perfdatas             => [
                    { value => 'traffic_out', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];

    # ---- Per-port ----
    $self->{maps_counters}->{ports} = [
        { label => 'port-status', threshold => 0, set => {
                key_values => [
                    { name => 'port_status' },
                    { name => 'enabled' },
                    { name => 'port_type' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_port_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'port-traffic-in', nlabel => 'port.traffic.in.kilobits.second', display_ok => 0, set => {
                key_values            => [ { name => 'traffic_in' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_traffic_in_output'),
                perfdatas             => [
                    { value => 'traffic_in', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-traffic-out', nlabel => 'port.traffic.out.kilobits.second', display_ok => 0, set => {
                key_values            => [ { name => 'traffic_out' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_traffic_out_output'),
                perfdatas             => [
                    { value => 'traffic_out', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-packets-in', nlabel => 'port.packets.in.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'packets_in' }, { name => 'display' } ],
                output_template => 'packets in: %.2f /s',
                perfdatas       => [
                    { value => 'packets_in', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-packets-out', nlabel => 'port.packets.out.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'packets_out' }, { name => 'display' } ],
                output_template => 'packets out: %.2f /s',
                perfdatas       => [
                    { value => 'packets_out', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-errors-in', nlabel => 'port.errors.in.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'errors_in' }, { name => 'display' } ],
                output_template => 'errors in: %.2f /s',
                perfdatas       => [
                    { value => 'errors_in', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-errors-out', nlabel => 'port.errors.out.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'errors_out' }, { name => 'display' } ],
                output_template => 'errors out: %.2f /s',
                perfdatas       => [
                    { value => 'errors_out', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-drops-in', nlabel => 'port.drops.in.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'drops_in' }, { name => 'display' } ],
                output_template => 'drops in: %.2f /s',
                perfdatas       => [
                    { value => 'drops_in', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-drops-out', nlabel => 'port.drops.out.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'drops_out' }, { name => 'display' } ],
                output_template => 'drops out: %.2f /s',
                perfdatas       => [
                    { value => 'drops_out', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

# -------------------------------------------------------------------------
# Prefix / long output callbacks
# -------------------------------------------------------------------------

sub prefix_interconnect_output {
    my ($self, %options) = @_;
    return "Interconnect '" . $options{instance_value}->{display} . "' ";
}

sub prefix_port_output {
    my ($self, %options) = @_;
    return "Port '" . $options{instance_value}->{display} . "' ";
}

sub port_long_output {
    my ($self, %options) = @_;
    return "checking port '" . $options{instance_value}->{display} . "'";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'              => { name => 'filter_name' },
        'filter-enclosure:s'         => { name => 'filter_enclosure' },
        'filter-port-name:s'         => { name => 'filter_port_name' },
        'filter-port-type:s'         => { name => 'filter_port_type' },
        'skip-disabled-ports'        => { name => 'skip_disabled_ports' },
        'no-statistics'              => { name => 'no_statistics' },
        'no-utilization'             => { name => 'no_utilization' },
        'unknown-interconnect-status:s'  => { name => 'unknown_interconnect_status',  default => '%{status} =~ /unknown/i' },
        'warning-interconnect-status:s'  => { name => 'warning_interconnect_status',  default => '%{status} =~ /warning/i' },
        'critical-interconnect-status:s' => { name => 'critical_interconnect_status', default => '%{status} =~ /critical/i' },
        'unknown-port-status:s'          => { name => 'unknown_port_status',  default => '' },
        'warning-port-status:s'          => { name => 'warning_port_status',  default => '' },
        'critical-port-status:s'         => { name => 'critical_port_status',
            default => '%{enabled} eq "true" && %{port_status} =~ /unlinked/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_interconnect_status', 'critical_interconnect_status', 'unknown_interconnect_status',
        'warning_port_status',         'critical_port_status',         'unknown_port_status',
    ]);
}

# -------------------------------------------------------------------------
# Utility: parse utilization metricList
# -------------------------------------------------------------------------

sub _parse_utilization {
    my ($self, %options) = @_;
    my %metrics;
    return %metrics unless (defined($options{data}) && defined($options{data}->{metricList}));
    foreach my $metric (@{$options{data}->{metricList}}) {
        my $name = $metric->{metricName};
        if (defined($metric->{metricSamples}) && scalar(@{$metric->{metricSamples}}) > 0) {
            my $last = $metric->{metricSamples}->[-1];
            $metrics{$name} = $last->[1] if (defined($last->[1]));
        }
    }
    return %metrics;
}

# -------------------------------------------------------------------------
# Utility: parse port statistics response
# Each portStatistics entry has portName + commonStatistics / advancedStatistics
# -------------------------------------------------------------------------

sub _parse_port_statistics {
    my ($self, %options) = @_;
    # Returns hashref: portName => { traffic_in, traffic_out, packets_in, ... }
    my %port_stats;
    return %port_stats unless (defined($options{data}) && defined($options{data}->{portStatistics}));

    foreach my $pstat (@{$options{data}->{portStatistics}}) {
        my $pname = $pstat->{portName};
        my $cs    = $pstat->{commonStatistics}  // {};
        my $as    = $pstat->{advancedStatistics} // {};

        $port_stats{$pname} = {
            # Kilobits/s
            traffic_in   => $cs->{receiveKilobitsPerSec}   // undef,
            traffic_out  => $cs->{transmitKilobitsPerSec}  // undef,
            # Packets/s
            packets_in   => $cs->{receivePacketsPerSecond}  // undef,
            packets_out  => $cs->{transmitPacketsPerSecond} // undef,
            # Errors/s
            errors_in    => $as->{receiveFrameErrors}   // undef,
            errors_out   => $as->{transmitFrameErrors}  // undef,
            # Drops/s (FCS / congestion)
            drops_in     => $as->{receiveFrameDiscards} // undef,
            drops_out    => $as->{transmitFrameDiscards}// undef,
        };
    }
    return %port_stats;
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/interconnects');

    $self->{global} = {
        total            => 0,
        status_ok        => 0,
        status_warning   => 0,
        status_critical  => 0,
        ports_total      => 0,
        ports_linked     => 0,
        ports_unlinked   => 0,
    };
    $self->{interconnects} = {};
    $self->{ports}         = {};

    $self->{output}->output_add(
        long_msg => sprintf("api returned %d interconnect(s)", scalar(@{$results->{members} // []})),
        debug => 1
    );

    foreach my $ic (@{$results->{members}}) {
        # Use URI as unique key, display name comes directly from API
        my $key  = $ic->{uri} // $ic->{name} // 'unknown';
        my $name = $ic->{name} // $key;

        $self->{output}->output_add(
            long_msg => sprintf("api ic: uri=%s name=%s status=%s",
                $ic->{uri} // 'undef', $ic->{name} // 'undef', $ic->{status} // 'undef'),
            debug => 1
        );

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(
                long_msg => "skipping interconnect '$name': no matching filter.", debug => 1
            );
            next;
        }

        my $enclosure_name = '';
        if (defined($ic->{enclosureName}) && $ic->{enclosureName} ne '') {
            $enclosure_name = $ic->{enclosureName};
        } elsif (defined($ic->{enclosureUri}) && $ic->{enclosureUri} ne '') {
            ($enclosure_name) = $ic->{enclosureUri} =~ m{/([^/]+)$};
            $enclosure_name //= $ic->{enclosureUri};
        }
        if (defined($self->{option_results}->{filter_enclosure}) && $self->{option_results}->{filter_enclosure} ne '' &&
            $enclosure_name !~ /$self->{option_results}->{filter_enclosure}/) {
            $self->{output}->output_add(
                long_msg => "skipping interconnect '$name': enclosure '$enclosure_name' no matching filter.", debug => 1
            );
            next;
        }

        my $status      = defined($ic->{status})     ? lc($ic->{status})     : 'unknown';
        my $power_state = defined($ic->{powerState}) ? lc($ic->{powerState}) : 'unknown';

        # Global health counters
        $self->{global}->{total}++;
        $self->{global}->{'status_' . $status}++
            if (exists $self->{global}->{'status_' . $status});

        # Count ports from ports array in the IC object
        my $ports_enabled = 0;
        my $ports_linked  = 0;
        foreach my $port (@{$ic->{ports} // []}) {
            $ports_enabled++ if (defined($port->{enabled}) && $port->{enabled});
            $ports_linked++  if (defined($port->{portStatus}) && lc($port->{portStatus}) eq 'linked');
        }

        $self->{interconnects}->{$key} = {
            display         => $name,
            status          => $status,
            power_state     => $power_state,
            ports_enabled   => $ports_enabled,
            ports_linked    => $ports_linked,
            # Utilization fields — populated below
            temperature     => undef,
            power_avg       => undef,
            cpu_utilization => undef,
            traffic_in      => undef,
            traffic_out     => undef,
        };

        # ---- Optional utilization (temperature, power, CPU) ----
        if (!defined($self->{option_results}->{no_utilization}) && defined($ic->{uri})) {
            my $util = $options{custom}->request_api(
                url_path      => $ic->{uri} . '/statistics',
                ignore_errors => 1
            );
            if (defined($util)) {
                # Module-level utilization lives in interconnectStatistics
                my $module_stats = $util->{interconnectStatistics} // {};
                $self->{interconnects}->{$key}->{traffic_in}  =
                    $module_stats->{receiveKilobitsPerSec}  if (defined($module_stats->{receiveKilobitsPerSec}));
                $self->{interconnects}->{$key}->{traffic_out} =
                    $module_stats->{transmitKilobitsPerSec} if (defined($module_stats->{transmitKilobitsPerSec}));
            }

            my $util2 = $options{custom}->request_api(
                url_path      => $ic->{uri} . '/utilization?fields=AmbientTemperature,PowerAverage,CpuAvgUtilization&view=native',
                ignore_errors => 1
            );
            if (defined($util2)) {
                my %metrics = $self->_parse_utilization(data => $util2);
                $self->{interconnects}->{$key}->{temperature}     = $metrics{AmbientTemperature}  if (defined($metrics{AmbientTemperature}));
                $self->{interconnects}->{$key}->{power_avg}       = $metrics{PowerAverage}         if (defined($metrics{PowerAverage}));
                $self->{interconnects}->{$key}->{cpu_utilization} = $metrics{CpuAvgUtilization}   if (defined($metrics{CpuAvgUtilization}));
            }
        }

        # ---- Optional per-port statistics ----
        if (!defined($self->{option_results}->{no_statistics}) && defined($ic->{uri})) {
            my $stat_data = $options{custom}->request_api(
                url_path      => $ic->{uri} . '/statistics',
                ignore_errors => 1
            );
            my %port_stats = defined($stat_data) ? $self->_parse_port_statistics(data => $stat_data) : ();

            foreach my $port (@{$ic->{ports} // []}) {
                my $port_name = $port->{portName};
                my $port_type = defined($port->{portType}) ? $port->{portType} : 'Unknown';
                my $enabled   = defined($port->{enabled})  ? ($port->{enabled} ? 'true' : 'false') : 'false';
                my $pstatus   = defined($port->{portStatus}) ? lc($port->{portStatus}) : 'unknown';

                # Filters
                if (defined($self->{option_results}->{filter_port_name}) && $self->{option_results}->{filter_port_name} ne '' &&
                    $port_name !~ /$self->{option_results}->{filter_port_name}/) {
                    next;
                }
                if (defined($self->{option_results}->{filter_port_type}) && $self->{option_results}->{filter_port_type} ne '' &&
                    $port_type !~ /$self->{option_results}->{filter_port_type}/i) {
                    next;
                }
                if (defined($self->{option_results}->{skip_disabled_ports}) && $enabled eq 'false') {
                    next;
                }

                # Global port counters
                $self->{global}->{ports_total}++;
                if ($pstatus eq 'linked') {
                    $self->{global}->{ports_linked}++;
                } else {
                    $self->{global}->{ports_unlinked}++;
                }

                my $port_key  = $name . ':' . $port_name;
                my $ps        = $port_stats{$port_name} // {};

                $self->{ports}->{$port_key} = {
                    display      => $port_key,
                    port_status  => $pstatus,
                    enabled      => $enabled,
                    port_type    => $port_type,
                    traffic_in   => $ps->{traffic_in},
                    traffic_out  => $ps->{traffic_out},
                    packets_in   => $ps->{packets_in},
                    packets_out  => $ps->{packets_out},
                    errors_in    => $ps->{errors_in},
                    errors_out   => $ps->{errors_out},
                    drops_in     => $ps->{drops_in},
                    drops_out    => $ps->{drops_out},
                };
            }
        }
    }

    if (scalar(keys %{$self->{interconnects}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No interconnects found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView interconnect modules and port statistics.

Module-level perfdata: port counts, health status counts.
By default also fetches utilization (temperature, power, CPU, traffic) and per-port statistics.
Use B<--no-utilization> or B<--no-statistics> to disable those extra API calls.

=over 8

=item B<--filter-name>

Filter interconnect module by name (can be a regexp).

=item B<--filter-enclosure>

Filter interconnects by their parent enclosure name (can be a regexp).

=item B<--filter-port-name>

Filter port by name (can be a regexp). Ignored when B<--no-statistics> is set.

=item B<--filter-port-type>

Filter port by type, e.g. Ethernet, FibreChannel (can be a regexp).
Ignored when B<--no-statistics> is set.

=item B<--skip-disabled-ports>

Skip ports where enabled is false.
Ignored when B<--no-statistics> is set.

=item B<--no-utilization>

Disable real-time utilization data per interconnect module (temperature, power, CPU, traffic).
By default the plugin fetches utilization for each module.

=item B<--no-statistics>

Disable per-port statistics (traffic, packets, errors, drops).
By default the plugin fetches statistics for each module.

=item B<--unknown-interconnect-status>

Conditions for UNKNOWN module status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{power_state}, %{display}

=item B<--warning-interconnect-status>

Conditions for WARNING module status (default: '%{status} =~ /warning/i').

=item B<--critical-interconnect-status>

Conditions for CRITICAL module status (default: '%{status} =~ /critical/i').

=item B<--unknown-port-status>

Conditions for UNKNOWN port status (default: '').
Variables: %{port_status}, %{enabled}, %{port_type}, %{display}

=item B<--warning-port-status>

Conditions for WARNING port status (default: '').

=item B<--critical-port-status>

Conditions for CRITICAL port status
(default: '%{enabled} eq "true" && %{port_status} =~ /unlinked/i').
Only enabled ports that are unlinked trigger a critical by default.

=item B<--warning-*> B<--critical-*>

Global thresholds:
'interconnects-total', 'interconnects-status-ok/warning/critical',
'ports-total', 'ports-linked', 'ports-unlinked'.

Per-module thresholds:
'interconnect-ports-enabled', 'interconnect-ports-linked',
'interconnect-temperature' (C), 'interconnect-power' (W),
'interconnect-cpu-utilization' (%), 'interconnect-traffic-in/out' (Kb/s).

Per-port thresholds:
'port-traffic-in/out' (Kb/s), 'port-packets-in/out' (/s),
'port-errors-in/out' (/s), 'port-drops-in/out' (/s).

=back

=cut
