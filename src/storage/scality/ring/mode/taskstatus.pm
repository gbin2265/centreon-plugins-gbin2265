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

package storage::scality::ring::mode::taskstatus;
use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;

sub set_counters {
    my ($self, %options) = @_;
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ', ' },
        { name => 'nodes',  type => 1, cb_prefix_output => 'prefix_node_output',
          message_multiple => 'All storenode task queues are OK', skipped_code => { -10 => 1 } },
    ];
    $self->{maps_counters}->{global} = [
        { label => 'total-tasks', nlabel => 'cluster.tasks.total.count', set => {
            key_values      => [ { name => 'total_tasks' } ],
            output_template => '%d task(s) total across cluster',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'total-tasks-blocked', nlabel => 'cluster.tasks.blocked.total.count',
          warning_default => '1', critical_default => '5',
          set => {
            key_values      => [ { name => 'total_blocked' } ],
            output_template => '%d blocked task(s) across cluster',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'nodes-with-blocked-tasks', nlabel => 'cluster.nodes.with.blocked.tasks.count',
          set => {
            key_values      => [ { name => 'nodes_with_blocked' } ],
            output_template => '%d node(s) with blocked tasks',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
    ];
    $self->{maps_counters}->{nodes} = [
        { label => 'node-tasks', nlabel => 'storenode.tasks.count', set => {
            key_values      => [ { name => 'nb_tasks' }, { name => 'name' } ],
            output_template => '%d pending task(s)',
            perfdatas       => [ { template => '%d', min => 0,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
        { label => 'node-tasks-blocked', nlabel => 'storenode.tasks.blocked.count',
          warning_default => '1', critical_default => '5',
          set => {
            key_values      => [ { name => 'tasks_blocked' }, { name => 'name' } ],
            output_template => '%d blocked task(s)',
            perfdatas       => [ { template => '%d', min => 0,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
    ];
}

sub prefix_node_output {
    my ($self, %options) = @_;
    return "Storenode '" . $options{instance_value}->{name} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        'filter-name:s'    => { name => 'filter_name'    },
        'filter-ring:s'    => { name => 'filter_ring'    },
        'filter-server:s'  => { name => 'filter_server'  },
        'filter-state:s'   => { name => 'filter_state'   },
        'exclude-name:s'   => { name => 'exclude_name'   },
        'exclude-ring:s'   => { name => 'exclude_ring'   },
        'exclude-server:s' => { name => 'exclude_server' },
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;
    my $data  = $options{custom}->get_storenodes();
    my $items = ref($data) eq 'ARRAY' ? $data : [];

    $self->{global} = { total_tasks => 0, total_blocked => 0, nodes_with_blocked => 0 };
    $self->{nodes}  = {};

    foreach my $node (@{$items}) {
        my $name   = $node->{name}   // $node->{id} // 'unknown';
        my $ring   = $node->{ring}   // 'n/a';
        my $server = $node->{server} // 'n/a';

        # Filters
        next if (defined($self->{option_results}->{filter_name})   && $self->{option_results}->{filter_name}   ne '' && $name   !~ /$self->{option_results}->{filter_name}/);
        next if (defined($self->{option_results}->{filter_ring})   && $self->{option_results}->{filter_ring}   ne '' && $ring   !~ /$self->{option_results}->{filter_ring}/);
                next if (defined($self->{option_results}->{filter_state}) && $self->{option_results}->{filter_state} ne '' && ($node->{state} // '') !~ /$self->{option_results}->{filter_state}/i);

        next if (defined($self->{option_results}->{exclude_name})   && $self->{option_results}->{exclude_name}   ne '' && $name   =~ /$self->{option_results}->{exclude_name}/);
        next if (defined($self->{option_results}->{exclude_ring})   && $self->{option_results}->{exclude_ring}   ne '' && $ring   =~ /$self->{option_results}->{exclude_ring}/);
        next if (defined($self->{option_results}->{exclude_server}) && $self->{option_results}->{exclude_server} ne '' && $server =~ /$self->{option_results}->{exclude_server}/);

        my $nb_tasks      = $node->{nb_tasks}      // 0 || 0;
        my $tasks_blocked = $node->{tasks_blocked} // 0 || 0;

        $self->{global}->{total_tasks}        += $nb_tasks;
        $self->{global}->{total_blocked}      += $tasks_blocked;
        $self->{global}->{nodes_with_blocked}++ if ($tasks_blocked > 0);

        $self->{nodes}->{$name} = {
            name          => $name,
            nb_tasks      => $nb_tasks,
            tasks_blocked => $tasks_blocked,
        };
    }

    if (scalar(keys %{$self->{nodes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No storenodes found.");
        $self->{output}->option_exit();
    }
}
1;

__END__

=head1 MODE

Check Scality RING storenode task queue metrics.

=over 8

=item B<--filter-name>

Filter storenodes by name (regexp).

=item B<--filter-ring>

Filter storenodes by ring name (regexp).

=item B<--filter-server>

Filter storenodes by server (regexp).

=item B<--filter-state>

Filter storenodes by state (regexp).

=item B<--exclude-name>

Exclude storenodes by name (regexp).

=item B<--exclude-ring>

Exclude storenodes by ring (regexp).

=item B<--exclude-server>

Exclude storenodes by server (regexp).

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'total-tasks', 'total-tasks-blocked' (default warning: 1, critical: 5),
'nodes-with-blocked-tasks', 'node-tasks', 'node-tasks-blocked' (default warning: 1, critical: 5).

=back

=cut
