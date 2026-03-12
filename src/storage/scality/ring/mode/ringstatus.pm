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

package storage::scality::ring::mode::ringstatus;
use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("status is '%s' [state: %s, nodes: %d]",
        $self->{result_values}->{status},
        $self->{result_values}->{state},
        $self->{result_values}->{number_of_nodes});
}

sub custom_diskspace_output {
    my ($self, %options) = @_;
    my ($used_v,  $used_u)  = $self->{perfdata}->change_bytes(value => $self->{result_values}->{diskspace_used});
    my ($free_v,  $free_u)  = $self->{perfdata}->change_bytes(value => $self->{result_values}->{diskspace_available});
    my ($total_v, $total_u) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{diskspace_total});
    return sprintf("disk: used %s%s / free %s%s / total %s%s (%.1f%%)",
        $used_v,  $used_u,
        $free_v,  $free_u,
        $total_v, $total_u,
        $self->{result_values}->{diskspace_used_prct});
}

sub set_counters {
    my ($self, %options) = @_;
    $self->{maps_counters_type} = [
        { name => 'rings', type => 1, cb_prefix_output => 'prefix_ring_output',
          message_multiple => 'All rings are OK', skipped_code => { -10 => 1 } },
    ];
    $self->{maps_counters}->{rings} = [

        # --- Status ---
        { label => 'status', type => 2,
          critical_default => '%{status} !~ /^ok$/i',
          set => {
            key_values => [ { name => 'status' }, { name => 'state' },
                            { name => 'number_of_nodes' }, { name => 'name' } ],
            closure_custom_output           => $self->can('custom_status_output'),
            closure_custom_perfdata         => sub { return 0; },
            closure_custom_threshold_check  => \&catalog_status_threshold_ng,
          }
        },

        # --- Nodes ---
        { label => 'nodes', nlabel => 'ring.nodes.count', set => {
            key_values      => [ { name => 'number_of_nodes' }, { name => 'name' } ],
            output_template => '%d node(s)',
            perfdatas       => [ { template => '%d', min => 0,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },

        # --- Raw diskspace ---
        { label => 'diskspace-usage', nlabel => 'ring.diskspace.usage.bytes', set => {
            key_values => [ { name => 'diskspace_used' }, { name => 'diskspace_available' },
                            { name => 'diskspace_total' }, { name => 'diskspace_used_prct' },
                            { name => 'name' } ],
            closure_custom_output => $self->can('custom_diskspace_output'),
            perfdatas => [ { template => '%d', unit => 'B', min => 0, max => 'diskspace_total',
                label_extra_instance => 1, instance_use => 'name', cast_int => 1 } ],
          }
        },
        { label => 'diskspace-usage-prct', nlabel => 'ring.diskspace.usage.percentage', display_ok => 0, set => {
            key_values      => [ { name => 'diskspace_used_prct' }, { name => 'name' } ],
            output_template => 'disk used: %.2f %%',
            perfdatas       => [ { template => '%.2f', unit => '%', min => 0, max => 100,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
        { label => 'diskspace-stored', nlabel => 'ring.diskspace.stored.bytes', display_ok => 0, set => {
            key_values      => [ { name => 'diskspace_stored' }, { name => 'name' } ],
            output_template => 'stored: %s B',
            perfdatas       => [ { template => '%d', unit => 'B', min => 0,
                label_extra_instance => 1, instance_use => 'name', cast_int => 1 } ],
          }
        },

        # --- Net (deduplicated) diskspace ---
        { label => 'diskspace-net', nlabel => 'ring.diskspace.net.bytes', display_ok => 0, set => {
            key_values      => [ { name => 'diskspace_net' }, { name => 'name' } ],
            output_template => 'net used: %s B',
            perfdatas       => [ { template => '%d', unit => 'B', min => 0,
                label_extra_instance => 1, instance_use => 'name', cast_int => 1 } ],
          }
        },
        { label => 'diskspace-net-available', nlabel => 'ring.diskspace.net.available.bytes', display_ok => 0, set => {
            key_values      => [ { name => 'diskspace_est_net_available' }, { name => 'name' } ],
            output_template => 'estimated net available: %s B',
            perfdatas       => [ { template => '%d', unit => 'B', min => 0,
                label_extra_instance => 1, instance_use => 'name', cast_int => 1 } ],
          }
        },

        # --- Objects ---
        { label => 'objects-unique', nlabel => 'ring.objects.unique.count', set => {
            key_values      => [ { name => 'unique_number_of_objects' }, { name => 'name' } ],
            output_template => '%d unique object(s)',
            perfdatas       => [ { template => '%d', min => 0,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
        { label => 'objects-total', nlabel => 'ring.objects.total.count', display_ok => 0, set => {
            key_values      => [ { name => 'number_of_objects' }, { name => 'name' } ],
            output_template => '%d total object(s) (with replicas)',
            perfdatas       => [ { template => '%d', min => 0,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
        { label => 'object-avg-unique-size', nlabel => 'ring.object.average.unique.size.bytes', display_ok => 0, set => {
            key_values      => [ { name => 'object_average_unique_size' }, { name => 'name' } ],
            output_template => 'avg unique object size: %s B',
            perfdatas       => [ { template => '%d', unit => 'B', min => 0,
                label_extra_instance => 1, instance_use => 'name', cast_int => 1 } ],
          }
        },
        { label => 'object-avg-size', nlabel => 'ring.object.average.size.bytes', display_ok => 0, set => {
            key_values      => [ { name => 'object_average_size' }, { name => 'name' } ],
            output_template => 'avg object size (with replicas): %s B',
            perfdatas       => [ { template => '%d', unit => 'B', min => 0,
                label_extra_instance => 1, instance_use => 'name', cast_int => 1 } ],
          }
        },

        # --- Capacity planning ---
        { label => 'planning-days-before-threshold', nlabel => 'ring.planning.days.before.threshold.count', set => {
            key_values      => [ { name => 'planning_days_before_threshold' }, { name => 'name' } ],
            output_template => '%d day(s) before capacity threshold',
            perfdatas       => [ { template => '%d', min => 0,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
        { label => 'planning-daily-growth', nlabel => 'ring.planning.daily.growth.bytes', display_ok => 0, set => {
            key_values      => [ { name => 'planning_daily_capacity_growth' }, { name => 'name' } ],
            output_template => 'daily growth: %s B',
            perfdatas       => [ { template => '%d', unit => 'B', min => 0,
                label_extra_instance => 1, instance_use => 'name', cast_int => 1 } ],
          }
        },
        { label => 'planning-usage-growth', nlabel => 'ring.planning.usage.growth.bytes', display_ok => 0, set => {
            key_values      => [ { name => 'planning_usage_growth' }, { name => 'name' } ],
            output_template => 'usage growth: %s B',
            perfdatas       => [ { template => '%d', unit => 'B', min => 0,
                label_extra_instance => 1, instance_use => 'name', cast_int => 1 } ],
          }
        },
    ];
}

sub prefix_ring_output {
    my ($self, %options) = @_;
    return "Ring '" . $options{instance_value}->{name} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        'filter-name:s'   => { name => 'filter_name'   },
        'filter-status:s' => { name => 'filter_status' },
        'filter-type:s'   => { name => 'filter_type'   },
        'exclude-name:s'   => { name => 'exclude_name'   },
        'exclude-type:s'   => { name => 'exclude_type'   },
        'filter-state:s'   => { name => 'filter_state'   },
        'exclude-status:s' => { name => 'exclude_status' },
        'exclude-state:s'  => { name => 'exclude_state'  },
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;
    my $items = $options{custom}->get_rings();

    $self->{rings} = {};
    foreach my $ring (@{$items}) {
        my $name = $ring->{name} // $ring->{id} // 'unknown';
        # Filters
        next if (defined($self->{option_results}->{filter_name})   && $self->{option_results}->{filter_name}   ne '' && $name                     !~ /$self->{option_results}->{filter_name}/);
        next if (defined($self->{option_results}->{filter_status}) && $self->{option_results}->{filter_status} ne '' && ($ring->{status} // '')    !~ /$self->{option_results}->{filter_status}/i);
        next if (defined($self->{option_results}->{filter_type})   && $self->{option_results}->{filter_type}   ne '' && ($ring->{type}   // $name) !~ /$self->{option_results}->{filter_type}/i);
        next if (defined($self->{option_results}->{filter_state})  && $self->{option_results}->{filter_state}  ne '' && ($ring->{state} // '')     !~ /$self->{option_results}->{filter_state}/i);
        # Excludes
        next if (defined($self->{option_results}->{exclude_name})   && $self->{option_results}->{exclude_name}   ne '' && $name                     =~ /$self->{option_results}->{exclude_name}/);
        next if (defined($self->{option_results}->{exclude_type})   && $self->{option_results}->{exclude_type}   ne '' && ($ring->{type} // $name)   =~ /$self->{option_results}->{exclude_type}/i);
        next if (defined($self->{option_results}->{exclude_status}) && $self->{option_results}->{exclude_status} ne '' && ($ring->{status} // '')     =~ /$self->{option_results}->{exclude_status}/i);
        next if (defined($self->{option_results}->{exclude_state})  && $self->{option_results}->{exclude_state}  ne '' && ($ring->{state} // '')      =~ /$self->{option_results}->{exclude_state}/i);
        my $state = ref($ring->{state}) eq 'ARRAY'
                  ? join(',', @{$ring->{state}}) : ($ring->{state} // 'unknown');
        my $total = $ring->{diskspace_total}     // 0 || 0;
        my $used  = $ring->{diskspace_used}      // 0 || 0;
        my $prct  = $total > 0 ? ($used / $total * 100) : 0;

        $self->{rings}->{$name} = {
            name                        => $name,
            status                      => $ring->{status}                                    // 'unknown',
            state                       => $state,
            number_of_nodes             => ($ring->{number_of_nodes}                          // 0) || 0,
            diskspace_total             => $total,
            diskspace_used              => $used,
            diskspace_available         => ($ring->{diskspace_available}                      // 0) || 0,
            diskspace_used_prct         => $prct,
            diskspace_stored            => ($ring->{diskspace_stored}                         // 0) || 0,
            diskspace_net               => ($ring->{diskspace_net}                            // 0) || 0,
            diskspace_est_net_available => ($ring->{diskspace_est_net_available}              // 0) || 0,
            unique_number_of_objects    => ($ring->{unique_number_of_objects}                 // 0) || 0,
            number_of_objects           => ($ring->{number_of_objects}                        // 0) || 0,
            object_average_unique_size  => ($ring->{object_average_unique_size}               // 0) || 0,
            object_average_size         => ($ring->{object_average_size}                      // 0) || 0,
            planning_daily_capacity_growth  => ($ring->{planning_daily_capacity_growth}       // 0) || 0,
            planning_days_before_threshold  => ($ring->{planning_days_before_threshold}       // 0) || 0,
            planning_usage_growth           => ($ring->{planning_usage_growth}                // 0) || 0,
        };
    }
    if (scalar(keys %{$self->{rings}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No rings found.");
        $self->{output}->option_exit();
    }
}
1;

__END__

=head1 MODE

Check Scality RING ring status and storage metrics.

=over 8

=item B<--filter-name>

Filter rings by name (regexp).

=item B<--filter-status>

Filter rings by status (regexp).

=item B<--filter-type>

Filter rings by type (regexp, e.g. DATA, META).

=item B<--filter-state>

Filter rings by state (regexp).

=item B<--exclude-name>

Exclude rings by name (regexp).

=item B<--exclude-type>

Exclude rings by type (regexp).

=item B<--exclude-status>

Exclude rings by status (regexp).

=item B<--exclude-state>

Exclude rings by state (regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{state}, %{name}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{state}, %{name}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{status} !~ /^ok$/i').
You can use the following variables: %{status}, %{state}, %{name}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'nodes', 'diskspace-usage', 'diskspace-usage-prct',
'diskspace-stored', 'diskspace-net', 'diskspace-net-available',
'objects-unique', 'objects-total', 'object-avg-unique-size', 'object-avg-size',
'planning-days-before-threshold', 'planning-daily-growth', 'planning-usage-growth'.

=back

=cut
