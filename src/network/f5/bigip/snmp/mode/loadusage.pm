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

package network::f5::bigip::snmp::mode::loadusage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_load_output {
    my ($self, %options) = @_;

    return 'System ';
}

sub custom_tmm_calc {
    my ($self, %options) = @_;

    my $delta_total = $options{new_datas}->{$self->{instance} . '_tmm_total_cycles'} - $options{old_datas}->{$self->{instance} . '_tmm_total_cycles'};
    my $delta_idle  = $options{new_datas}->{$self->{instance} . '_tmm_idle_cycles'}  - $options{old_datas}->{$self->{instance} . '_tmm_idle_cycles'};
    my $delta_sleep = $options{new_datas}->{$self->{instance} . '_tmm_sleep_cycles'} - $options{old_datas}->{$self->{instance} . '_tmm_sleep_cycles'};

    if ($delta_total == 0) {
        $self->{result_values}->{tmm_usage} = 0;
    } else {
        my $delta_used = $delta_total - ($delta_idle + $delta_sleep);
        $self->{result_values}->{tmm_usage} = ($delta_used / $delta_total) * 100;
    }

    return 0;
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_load_output' }
    ];

    $self->{maps_counters}->{global} = [
        # Classic Linux load average (1m/5m/15m) via UCD-SNMP-MIB
        { label => 'load-1m', nlabel => 'load.1m.count', set => {
                key_values => [ { name => 'load_1m' } ],
                output_template => 'load average: %.2f (1m)',
                perfdatas => [
                    { template => '%.2f', min => 0 }
                ]
            }
        },
        { label => 'load-5m', nlabel => 'load.5m.count', set => {
                key_values => [ { name => 'load_5m' } ],
                output_template => '%.2f (5m)',
                perfdatas => [
                    { template => '%.2f', min => 0 }
                ]
            }
        },
        { label => 'load-15m', nlabel => 'load.15m.count', set => {
                key_values => [ { name => 'load_15m' } ],
                output_template => '%.2f (15m)',
                perfdatas => [
                    { template => '%.2f', min => 0 }
                ]
            }
        },
        # F5-native TMM data-plane CPU usage (calculated from cycle counters)
        { label => 'tmm-usage', nlabel => 'cpu.tmm.usage.percentage', set => {
                key_values => [
                    { name => 'tmm_total_cycles', diff => 1 },
                    { name => 'tmm_idle_cycles', diff => 1 },
                    { name => 'tmm_sleep_cycles', diff => 1 }
                ],
                closure_custom_calc => $self->can('custom_tmm_calc'),
                output_template => 'TMM CPU usage: %.2f%%',
                output_use => 'tmm_usage',
                threshold_use => 'tmm_usage',
                perfdatas => [
                    { value => 'tmm_usage', template => '%.2f', min => 0, max => 100, unit => '%' }
                ]
            }
        },
        # F5-native Host control-plane CPU usage ratio
        { label => 'host-cpu-usage', nlabel => 'cpu.host.usage.percentage', set => {
                key_values => [ { name => 'host_cpu_usage' } ],
                output_template => 'Host CPU usage: %s%%',
                perfdatas => [
                    { template => '%s', min => 0, max => 100, unit => '%' }
                ]
            }
        },
        # CPU count info
        { label => 'cpu-count', nlabel => 'cpu.count', display_ok => 0, set => {
                key_values => [ { name => 'cpu_count' } ],
                output_template => 'CPUs: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # UCD-SNMP-MIB load averages (standard Linux)
    my $oid_CpuLoad1m  = '.1.3.6.1.4.1.2021.10.1.3.1';
    my $oid_CpuLoad5m  = '.1.3.6.1.4.1.2021.10.1.3.2';
    my $oid_CpuLoad15m = '.1.3.6.1.4.1.2021.10.1.3.3';

    # F5-BIGIP-SYSTEM-MIB: TMM cycle counters (data-plane)
    my $oid_sysStatTmTotalCycles = '.1.3.6.1.4.1.3375.2.1.1.2.1.41.0';
    my $oid_sysStatTmIdleCycles  = '.1.3.6.1.4.1.3375.2.1.1.2.1.42.0';
    my $oid_sysStatTmSleepCycles = '.1.3.6.1.4.1.3375.2.1.1.2.1.43.0';

    # F5-BIGIP-SYSTEM-MIB: Global host CPU (control-plane)
    my $oid_sysGlobalHostCpuCount      = '.1.3.6.1.4.1.3375.2.1.1.2.20.4.0';
    my $oid_sysGlobalHostCpuUsageRatio = '.1.3.6.1.4.1.3375.2.1.1.2.20.13.0';

    my $result = $options{snmp}->get_leef(
        oids => [
            $oid_CpuLoad1m, $oid_CpuLoad5m, $oid_CpuLoad15m,
            $oid_sysStatTmTotalCycles, $oid_sysStatTmIdleCycles, $oid_sysStatTmSleepCycles,
            $oid_sysGlobalHostCpuCount, $oid_sysGlobalHostCpuUsageRatio
        ],
        nothing_quit => 1
    );

    # Normalize load values (some locales use comma as decimal separator)
    my $load_1m  = $result->{$oid_CpuLoad1m};
    my $load_5m  = $result->{$oid_CpuLoad5m};
    my $load_15m = $result->{$oid_CpuLoad15m};
    $load_1m  =~ s/,/./g if defined($load_1m);
    $load_5m  =~ s/,/./g if defined($load_5m);
    $load_15m =~ s/,/./g if defined($load_15m);

    $self->{global} = {
        load_1m          => $load_1m,
        load_5m          => $load_5m,
        load_15m         => $load_15m,
        tmm_total_cycles => $result->{$oid_sysStatTmTotalCycles},
        tmm_idle_cycles  => $result->{$oid_sysStatTmIdleCycles},
        tmm_sleep_cycles => $result->{$oid_sysStatTmSleepCycles},
        host_cpu_usage   => $result->{$oid_sysGlobalHostCpuUsageRatio},
        cpu_count        => $result->{$oid_sysGlobalHostCpuCount}
    };

    $self->{cache_name} = 'f5_bigip_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check system load on F5 BIG-IP devices.

Combines three perspectives into a single check:
  - Classic Linux load average (1m/5m/15m) from UCD-SNMP-MIB
  - TMM data-plane CPU usage calculated from cycle counters (F5-BIGIP-SYSTEM-MIB)
  - Host control-plane CPU usage ratio (F5-BIGIP-SYSTEM-MIB sysGlobalHost)

The TMM CPU usage requires two consecutive checks for delta calculation.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='load' (only load average)
Example: --filter-counters='tmm' (only TMM usage)

=item B<--warning-load-1m>

Warning threshold for 1-minute load average.

=item B<--critical-load-1m>

Critical threshold for 1-minute load average.

=item B<--warning-load-5m>

Warning threshold for 5-minute load average.

=item B<--critical-load-5m>

Critical threshold for 5-minute load average.

=item B<--warning-load-15m>

Warning threshold for 15-minute load average.

=item B<--critical-load-15m>

Critical threshold for 15-minute load average.

=item B<--warning-tmm-usage>

Warning threshold for TMM data-plane CPU usage (%).

=item B<--critical-tmm-usage>

Critical threshold for TMM data-plane CPU usage (%).

=item B<--warning-host-cpu-usage>

Warning threshold for Host control-plane CPU usage (%).

=item B<--critical-host-cpu-usage>

Critical threshold for Host control-plane CPU usage (%).

=back

=cut
