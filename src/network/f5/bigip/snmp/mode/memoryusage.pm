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

package network::f5::bigip::snmp::mode::memoryusage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_usage_output {
    my ($self, %options) = @_;

    return sprintf(
        '%s memory usage: Total: %s Used: %s (%.2f%%) Free: %s (%.2f%%)',
        $self->{result_values}->{display},
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{total}),
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{used}),
        $self->{result_values}->{prct_used},
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{free}),
        $self->{result_values}->{prct_free}
    );
}

sub custom_usage_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    $self->{result_values}->{total} = $options{new_datas}->{$self->{instance} . '_total'};
    $self->{result_values}->{used} = $options{new_datas}->{$self->{instance} . '_used'};

    if ($self->{result_values}->{total} == 0) {
        $self->{error_msg} = 'total memory is 0';
        return -10;
    }

    $self->{result_values}->{free} = $self->{result_values}->{total} - $self->{result_values}->{used};
    $self->{result_values}->{prct_used} = $self->{result_values}->{used} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{prct_free} = 100 - $self->{result_values}->{prct_used};

    return 0;
}

sub prefix_memory_output {
    my ($self, %options) = @_;

    return "Memory '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'memory', type => 1, cb_prefix_output => 'prefix_memory_output', message_multiple => 'All memory usages are ok' }
    ];

    $self->{maps_counters}->{memory} = [
        { label => 'usage', nlabel => 'memory.usage.bytes', set => {
                key_values => [ { name => 'display' }, { name => 'total' }, { name => 'used' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                threshold_use => 'prct_used',
                perfdatas => [
                    { value => 'used', template => '%s', min => 0, max => 'total',
                      unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'usage-percentage', display_ok => 0, nlabel => 'memory.usage.percentage', set => {
                key_values => [ { name => 'display' }, { name => 'total' }, { name => 'used' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                output_template => 'used: %.2f%%',
                output_use => 'prct_used',
                threshold_use => 'prct_used',
                perfdatas => [
                    { value => 'prct_used', template => '%.2f', min => 0, max => 100,
                      unit => '%', label_extra_instance => 1, instance_use => 'display' }
                ]
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

    # F5-BIGIP-SYSTEM-MIB
    my $oid_sysStatMemoryTotal = '.1.3.6.1.4.1.3375.2.1.1.2.1.44.0'; # sysStatMemoryTotalKb
    my $oid_sysStatMemoryUsed  = '.1.3.6.1.4.1.3375.2.1.1.2.1.45.0'; # sysStatMemoryUsedKb
    my $oid_sysHostMemoryTotal = '.1.3.6.1.4.1.3375.2.1.7.1.1.0';    # sysHostMemoryTotal (KB)
    my $oid_sysHostMemoryUsed  = '.1.3.6.1.4.1.3375.2.1.7.1.2.0';    # sysHostMemoryUsed (KB)

    my $result = $options{snmp}->get_leef(
        oids => [
            $oid_sysStatMemoryTotal, $oid_sysStatMemoryUsed,
            $oid_sysHostMemoryTotal, $oid_sysHostMemoryUsed
        ],
        nothing_quit => 1
    );

    $self->{memory} = {};

    # TMM memory (data-plane memory used by traffic processing)
    if (defined($result->{$oid_sysStatMemoryTotal}) && $result->{$oid_sysStatMemoryTotal} > 0) {
        $self->{memory}->{tmm} = {
            display => 'TMM',
            total   => $result->{$oid_sysStatMemoryTotal} * 1024,
            used    => $result->{$oid_sysStatMemoryUsed} * 1024
        };
    }

    # Host memory (control-plane / OS-level memory)
    if (defined($result->{$oid_sysHostMemoryTotal}) && $result->{$oid_sysHostMemoryTotal} > 0) {
        $self->{memory}->{host} = {
            display => 'Host',
            total   => $result->{$oid_sysHostMemoryTotal} * 1024,
            used    => $result->{$oid_sysHostMemoryUsed} * 1024
        };
    }

    if (scalar(keys %{$self->{memory}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No memory information found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check system-wide memory usage on F5 BIG-IP devices.

Reports both TMM (Traffic Management Microkernel) memory and Host (control-plane) memory usage.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='usage-percentage'

=item B<--warning-usage>

Warning threshold for memory usage (in bytes).

=item B<--critical-usage>

Critical threshold for memory usage (in bytes).

=item B<--warning-usage-percentage>

Warning threshold for memory usage (in percent).

=item B<--critical-usage-percentage>

Critical threshold for memory usage (in percent).

=back

=cut
