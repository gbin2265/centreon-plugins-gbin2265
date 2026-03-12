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

package network::brocade::restapi::mode::memory;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_usage_output {
    my ($self, %options) = @_;

    return sprintf(
        "memory used: %s %s (%.2f%%) free: %s %s (%.2f%%)",
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{used}),
        $self->{result_values}->{prct_used},
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{free}),
        $self->{result_values}->{prct_free}
    );
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
        { label => 'memory-usage', nlabel => 'memory.usage.bytes', set => {
                key_values => [ { name => 'used' }, { name => 'total' }, { name => 'display' } ],
                output_template => 'used: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, max => 'total', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-usage-prct', nlabel => 'memory.usage.percentage', set => {
                key_values => [ { name => 'prct_used' }, { name => 'display' } ],
                output_template => 'used: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-free', nlabel => 'memory.free.bytes', display_ok => 0, set => {
                key_values => [ { name => 'free' }, { name => 'total' }, { name => 'display' } ],
                output_template => 'free: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, max => 'total', label_extra_instance => 1 }
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
        'filter-memory:s' => { name => 'filter_memory' },
        'exclude-memory:s' => { name => 'exclude_memory' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $chassis_data = $options{custom}->get_chassis_info();
    
    $self->{memory} = {};

    # Parse chassis for memory usage
    my $chassis_info = $chassis_data->{'Response'}->{'chassis'} // $chassis_data->{'brocade-chassis'}->{'chassis'} // {};
    $chassis_info = $chassis_info->[0] if (ref($chassis_info) eq 'ARRAY');

    # Try different possible field names (API returns: total-memory, used-memory, free-memory in KB)
    my $mem_usage = $chassis_info->{'memory-usage'};
    my $memory_total = $chassis_info->{'total-memory'} // 
                       $chassis_info->{'memory-capacity'} //
                       (defined($mem_usage) ? $mem_usage->{'total-memory'} : undef) // 0;
    my $memory_used = $chassis_info->{'used-memory'} // 
                      $chassis_info->{'memory-used'} //
                      (defined($mem_usage) ? $mem_usage->{'usage'} : undef) // 0;
    my $memory_free = $chassis_info->{'free-memory'} //
                      $chassis_info->{'available-memory'} // 0;
    
    # Brocade FOS REST API returns memory values in KB — always convert to bytes
    $memory_total = $memory_total * 1024 if ($memory_total > 0);
    $memory_used = $memory_used * 1024 if ($memory_used > 0);
    $memory_free = $memory_free * 1024 if ($memory_free > 0);
    
    if ($memory_total > 0) {
        # Calculate free if not provided
        if ($memory_free == 0 && $memory_used > 0) {
            $memory_free = $memory_total - $memory_used;
        }
        
        my $prct_used = ($memory_total > 0) ? ($memory_used / $memory_total * 100) : 0;
        my $prct_free = 100 - $prct_used;
        
        $self->{memory}->{'system'} = {
            display => 'system',
            used => $memory_used,
            free => $memory_free,
            total => $memory_total,
            prct_used => $prct_used,
            prct_free => $prct_free
        };
    }

    # Try to get per-blade memory for Directors
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
            my $blade_mem_total = $blade->{'memory-capacity'} // $blade->{'total-memory'} // 0;
            my $blade_mem_used = $blade->{'memory-usage'} // $blade->{'memory-used'} // 0;
            
            next if ($blade_mem_total == 0 && $blade_mem_used == 0);
            
            my $mem_name = 'blade_' . $slot;
            
            if (defined($self->{option_results}->{filter_memory}) && $self->{option_results}->{filter_memory} ne '' &&
                $mem_name !~ /$self->{option_results}->{filter_memory}/) {
                next;
            }

            # Apply excludes
            if (defined($self->{option_results}->{exclude_memory}) && $self->{option_results}->{exclude_memory} ne '' &&
                $mem_name =~ /$self->{option_results}->{exclude_memory}/) {
                next;
            }
            
            my $blade_mem_free = $blade_mem_total - $blade_mem_used;
            my $blade_prct_used = ($blade_mem_total > 0) ? ($blade_mem_used / $blade_mem_total * 100) : $blade_mem_used;
            
            $self->{memory}->{$mem_name} = {
                display => $mem_name,
                used => $blade_mem_used,
                free => $blade_mem_free,
                total => $blade_mem_total,
                prct_used => $blade_prct_used,
                prct_free => 100 - $blade_prct_used
            };
        }
    }

    if (scalar(keys %{$self->{memory}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No memory information found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check memory usage.

=over 8

=item B<--filter-memory>

Filter memory by name (can be a regexp).

=item B<--exclude-memory>

Exclude memory by name (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'memory-usage', 'memory-usage-prct', 'memory-free'.

=back

=cut
