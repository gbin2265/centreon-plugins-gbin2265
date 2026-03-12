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

package network::brocade::restapi::mode::cpu;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_cpu_output {
    my ($self, %options) = @_;

    return "CPU '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ' },
        { name => 'cpu', type => 1, cb_prefix_output => 'prefix_cpu_output', message_multiple => 'All CPUs are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'load-1m', nlabel => 'system.load.1m.count', set => {
                key_values => [ { name => 'load_1m' } ],
                output_template => 'load 1min: %.2f',
                perfdatas => [
                    { template => '%.2f', min => 0 }
                ]
            }
        },
        { label => 'load-5m', nlabel => 'system.load.5m.count', set => {
                key_values => [ { name => 'load_5m' } ],
                output_template => 'load 5min: %.2f',
                perfdatas => [
                    { template => '%.2f', min => 0 }
                ]
            }
        },
        { label => 'load-15m', nlabel => 'system.load.15m.count', set => {
                key_values => [ { name => 'load_15m' } ],
                output_template => 'load 15min: %.2f',
                perfdatas => [
                    { template => '%.2f', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{cpu} = [
        { label => 'cpu-utilization', nlabel => 'cpu.utilization.percentage', set => {
                key_values => [ { name => 'cpu_usage' }, { name => 'display' } ],
                output_template => 'usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
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
        'filter-cpu:s' => { name => 'filter_cpu' },
        'exclude-cpu:s' => { name => 'exclude_cpu' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $chassis_data = $options{custom}->get_chassis_info();
    
    $self->{global} = {};
    $self->{cpu} = {};

    # Parse chassis for load averages and CPU usage
    my $chassis_info = $chassis_data->{'Response'}->{'chassis'} // $chassis_data->{'brocade-chassis'}->{'chassis'} // {};
    $chassis_info = $chassis_info->[0] if (ref($chassis_info) eq 'ARRAY');

    # Get load averages (available on FOS 9.2.0+)
    my $load_1m = $chassis_info->{'one-minute-load-average'};
    my $load_5m = $chassis_info->{'five-minutes-load-average'};
    my $load_15m = $chassis_info->{'fifteen-minutes-load-average'};

    if (defined($load_1m) || defined($load_5m) || defined($load_15m)) {
        $self->{global} = {
            load_1m => $load_1m,
            load_5m => $load_5m,
            load_15m => $load_15m
        };
    }

    # Try to get CPU percentage from MAPS system-resources (available since v8.2.1)
    my $maps_data;
    eval {
        $maps_data = $options{custom}->get_maps_system_resources();
    };
    
    if (!$@ && defined($maps_data)) {
        my $resources = $maps_data->{'Response'}->{'system-resources'} // 
                        $maps_data->{'brocade-maps'}->{'system-resources'} // {};
        $resources = $resources->[0] if (ref($resources) eq 'ARRAY');
        
        my $cpu_usage = $resources->{'cpu-usage'};
        if (defined($cpu_usage)) {
            $self->{cpu}->{'system'} = {
                display => 'system',
                cpu_usage => $cpu_usage
            };
        }
    }

    # Fallback: Try chassis cpu-usage field
    if (scalar(keys %{$self->{cpu}}) == 0) {
        my $cpu_usage = $chassis_info->{'cpu-usage'} // 
                        $chassis_info->{'cpu-usage-percentage'} //
                        $chassis_info->{'cpu-utilization'};
        
        if (defined($cpu_usage)) {
            $self->{cpu}->{'system'} = {
                display => 'system',
                cpu_usage => $cpu_usage
            };
        }
    }

    # Try to get per-blade CPU for Directors
    my $blade_data;
    eval {
        $blade_data = $options{custom}->get_blade_info();
    };
    
    if (!$@ && defined($blade_data)) {
        my $blades = $blade_data->{'Response'}->{'blade'} // $blade_data->{'brocade-fru'}->{'blade'} // [];
        $blades = [$blades] if (ref($blades) ne 'ARRAY');
        
        foreach my $blade (@{$blades}) {
            next if (!defined($blade->{'slot-number'}));
            
            my $slot = $blade->{'slot-number'};
            my $blade_cpu = $blade->{'cpu-usage'} // 
                           $blade->{'cpu-usage-percentage'} //
                           $blade->{'cpu-utilization'};
            
            next if (!defined($blade_cpu));
            
            my $cpu_name = 'blade_' . $slot;
            
            if (defined($self->{option_results}->{filter_cpu}) && $self->{option_results}->{filter_cpu} ne '' &&
                $cpu_name !~ /$self->{option_results}->{filter_cpu}/) {
                next;
            }

            # Apply excludes
            if (defined($self->{option_results}->{exclude_cpu}) && $self->{option_results}->{exclude_cpu} ne '' &&
                $cpu_name =~ /$self->{option_results}->{exclude_cpu}/) {
                next;
            }
            
            $self->{cpu}->{$cpu_name} = {
                display => $cpu_name,
                cpu_usage => $blade_cpu
            };
        }
    }

    # If no CPU data found, try the switch endpoint
    if (scalar(keys %{$self->{cpu}}) == 0) {
        my $switch_data = $options{custom}->get_switch_info();
        my $switches = $switch_data->{'Response'}->{'fibrechannel-switch'} // 
                       $switch_data->{'brocade-fibrechannel-switch'}->{'fibrechannel-switch'} // [];
        $switches = [$switches] if (ref($switches) ne 'ARRAY');
        
        foreach my $switch (@{$switches}) {
            my $switch_cpu = $switch->{'cpu-usage'} //
                            $switch->{'cpu-usage-percentage'} //
                            $switch->{'cpu-utilization'};
            if (defined($switch_cpu)) {
                $self->{cpu}->{'switch'} = {
                    display => 'switch',
                    cpu_usage => $switch_cpu
                };
                last;
            }
        }
    }

    # Check if we have any data at all
    if (scalar(keys %{$self->{global}}) == 0 && scalar(keys %{$self->{cpu}}) == 0) {
        $self->{output}->add_option_msg(short_msg => "No CPU or load average information found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check CPU usage and system load averages.

=over 8

=item B<--filter-cpu>

Filter CPUs by name (can be a regexp).

=item B<--exclude-cpu>

Exclude CPUs by name (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'cpu-utilization', 'load-1m', 'load-5m', 'load-15m'.

=back

=cut
