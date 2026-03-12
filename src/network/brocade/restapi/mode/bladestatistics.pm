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

package network::brocade::restapi::mode::bladestatistics;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_memory_output {
    my ($self, %options) = @_;

    if (defined($self->{result_values}->{memory_total}) && $self->{result_values}->{memory_total} > 0) {
        return sprintf(
            "memory used: %s %s (%.2f%%) free: %s %s (%.2f%%)",
            $self->{perfdata}->change_bytes(value => $self->{result_values}->{memory_used}),
            $self->{result_values}->{memory_prct},
            $self->{perfdata}->change_bytes(value => $self->{result_values}->{memory_free}),
            100 - $self->{result_values}->{memory_prct}
        );
    }
    return sprintf("memory used: %.2f%%", $self->{result_values}->{memory_prct});
}

sub prefix_blade_output {
    my ($self, %options) = @_;

    return "Blade slot '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'blades', type => 1, cb_prefix_output => 'prefix_blade_output', message_multiple => 'All blade statistics are ok' }
    ];

    $self->{maps_counters}->{blades} = [
        { label => 'cpu-utilization', nlabel => 'blade.cpu.utilization.percentage', set => {
                key_values => [ { name => 'cpu_usage' }, { name => 'display' } ],
                output_template => 'CPU usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-usage', nlabel => 'blade.memory.usage.bytes', set => {
                key_values => [ { name => 'memory_used' }, { name => 'memory_total' }, { name => 'display' } ],
                output_template => 'memory used: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, max => 'memory_total', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-usage-prct', nlabel => 'blade.memory.usage.percentage', set => {
                key_values => [ { name => 'memory_prct' }, { name => 'display' } ],
                output_template => 'memory usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-free', nlabel => 'blade.memory.free.bytes', display_ok => 0, set => {
                key_values => [ { name => 'memory_free' }, { name => 'memory_total' }, { name => 'display' } ],
                output_template => 'memory free: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, max => 'memory_total', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'temperature', nlabel => 'blade.temperature.celsius', set => {
                key_values => [ { name => 'temperature' }, { name => 'display' } ],
                output_template => 'temperature: %.1f C',
                perfdatas => [
                    { template => '%.1f', unit => 'C', label_extra_instance => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-slot:s'       => { name => 'filter_slot' },
        'filter-blade-type:s' => { name => 'filter_blade_type' },
        'exclude-slot:s'       => { name => 'exclude_slot' },
        'exclude-blade-type:s' => { name => 'exclude_blade_type' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $blade_data = $options{custom}->get_blade_info();

    # Also get sensor data for per-blade temperatures
    my $sensor_data;
    eval {
        $sensor_data = $options{custom}->get_sensor_info();
    };

    $self->{blades} = {};

    my $blades = $blade_data->{'Response'}->{'blade'} // $blade_data->{'brocade-fru'}->{'blade'} // [];
    $blades = [$blades] if (ref($blades) ne 'ARRAY');

    # Build per-slot temperature map from sensor data
    my %slot_temperatures;
    if (!$@ && defined($sensor_data)) {
        my $sensors = $sensor_data->{'Response'}->{'sensor'} // $sensor_data->{'brocade-fru'}->{'sensor'} // [];
        $sensors = [$sensors] if (ref($sensors) ne 'ARRAY');

        foreach my $sensor (@{$sensors}) {
            my $slot = $sensor->{'slot-number'};
            next if (!defined($slot));

            my $temp = $sensor->{'temperature'} // $sensor->{'value'};
            next if (!defined($temp));

            my $state = $sensor->{'state'} // 'ok';
            next if (lc($state) =~ /absent|not.?present/i);

            # Keep the highest temperature per slot (multiple sensors per blade)
            if (!defined($slot_temperatures{$slot}) || $temp > $slot_temperatures{$slot}) {
                $slot_temperatures{$slot} = $temp;
            }
        }
    }

    foreach my $blade (@{$blades}) {
        my $slot = $blade->{'slot-number'};
        next if (!defined($slot));

        my $blade_type = $blade->{'blade-type'} // '';
        my $blade_state = $blade->{'blade-state'} // $blade->{'power-state'} // '';

        # Skip blades that are absent or powered off — no stats available
        next if (lc($blade_state) =~ /absent|not.?present|powered.?off/i);

        # Apply filters
        if (defined($self->{option_results}->{filter_slot}) && $self->{option_results}->{filter_slot} ne '' &&
            $slot !~ /$self->{option_results}->{filter_slot}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_blade_type}) && $self->{option_results}->{filter_blade_type} ne '' &&
            $blade_type !~ /$self->{option_results}->{filter_blade_type}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_slot}) && $self->{option_results}->{exclude_slot} ne '' &&
            $slot =~ /$self->{option_results}->{exclude_slot}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_blade_type}) && $self->{option_results}->{exclude_blade_type} ne '' &&
            $blade_type =~ /$self->{option_results}->{exclude_blade_type}/) {
            next;
        }

        # Get CPU usage
        my $cpu_usage = $blade->{'cpu-usage'} //
                        $blade->{'cpu-usage-percentage'} //
                        $blade->{'cpu-utilization'};

        # Get memory info
        my $mem_total = $blade->{'memory-capacity'} // $blade->{'total-memory'} // 0;
        my $mem_used = $blade->{'memory-usage'} // $blade->{'memory-used'} // 0;

        # Skip blades with no performance data at all
        next if (!defined($cpu_usage) && $mem_total == 0 && $mem_used == 0 && !defined($slot_temperatures{$slot}));

        # Brocade FOS REST API returns memory in KB — convert to bytes
        $mem_total = $mem_total * 1024 if ($mem_total > 0);
        $mem_used = $mem_used * 1024 if ($mem_used > 0);
        my $mem_free = ($mem_total > 0 && $mem_used > 0) ? ($mem_total - $mem_used) : undef;
        my $mem_prct = ($mem_total > 0) ? ($mem_used / $mem_total * 100) : undef;

        # Get temperature from sensor map, or from blade data directly
        my $temperature = $slot_temperatures{$slot} //
                         $blade->{'temperature'} //
                         $blade->{'sensor-temperature'};

        my $display_name = $slot;
        if ($blade_type ne '') {
            $display_name = $slot . ' (' . $blade_type . ')';
        }

        $self->{blades}->{$slot} = {
            display => $display_name,
            cpu_usage => $cpu_usage,
            memory_used => ($mem_used > 0) ? $mem_used : undef,
            memory_total => ($mem_total > 0) ? $mem_total : undef,
            memory_free => $mem_free,
            memory_prct => $mem_prct,
            temperature => $temperature
        };
    }

    if (scalar(keys %{$self->{blades}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No blade statistics found. This mode is designed for Director-class switches with multiple blades.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check per-blade performance statistics (CPU, memory, temperature) on Brocade Director-class switches.

This mode is different from 'blade' which monitors hardware status, inventory, and firmware.
'blade-statistics' focuses on real-time performance metrics per blade slot.

Designed for X7 Directors and other multi-blade chassis. Standalone switches
may not return per-blade statistics and will produce a "no data" message.

=over 8

=item B<--filter-slot>

Filter blades by slot number (can be a regexp).

=item B<--filter-blade-type>

Filter blades by type (can be a regexp, e.g. 'CP' for control processors, 'FC' for port blades).

=item B<--exclude-slot>

Exclude blades by slot number (can be a regexp).

=item B<--exclude-blade-type>

Exclude blades by type (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'cpu-utilization', 'memory-usage', 'memory-usage-prct', 'memory-free',
'temperature'.

=back

=cut
