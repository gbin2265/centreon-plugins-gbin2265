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

package storage::hp::msa2000::restapi::mode::task;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "state: %s [status: %s, progress: %s%%]",
        $self->{result_values}->{task_state},
        $self->{result_values}->{task_status},
        $self->{result_values}->{percent_complete}
    );
}

sub prefix_task_output {
    my ($self, %options) = @_;

    return "Task '" . $options{instance_value}->{name} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'tasks', type => 1, cb_prefix_output => 'prefix_task_output', message_multiple => 'All tasks are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'tasks-total', nlabel => 'tasks.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'Total tasks: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'tasks-running', nlabel => 'tasks.running.count', set => {
                key_values => [ { name => 'running' } ],
                output_template => 'Running: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'tasks-completed', nlabel => 'tasks.completed.count', set => {
                key_values => [ { name => 'completed' } ],
                output_template => 'Completed: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{tasks} = [
        {
            label => 'task-status',
            type => 2,
            warning_default => '%{task_status} =~ /warning/i',
            critical_default => '%{task_status} =~ /critical|error|exception/i',
            set => {
                key_values => [
                    { name => 'task_state' }, { name => 'task_status' }, { name => 'name' },
                    { name => 'percent_complete' }, { name => 'description' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'task-progress', nlabel => 'task.progress.percentage', set => {
                key_values => [ { name => 'percent_complete' }, { name => 'name' } ],
                output_template => 'progress: %s%%',
                perfdatas => [
                    { template => '%s', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'name' }
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
        'filter-task-id:s'    => { name => 'filter_task_id' },
        'filter-task-state:s' => { name => 'filter_task_state' },
        'filter-task-name:s' => { name => 'filter_task_name' },
        'exclude-task-id:s' => { name => 'exclude_task_id' },
        'exclude-task-name:s' => { name => 'exclude_task_name' },
        'exclude-task-state:s' => { name => 'exclude_task_state' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0, running => 0, completed => 0 };
    $self->{tasks} = {};

    my $task_service = $options{custom}->request_api(
        url_path => '/redfish/v1/TaskService',
        ignore_codes => { 404 => 1 }
    );
    return if (!defined($task_service) || !defined($task_service->{Tasks}) || !defined($task_service->{Tasks}->{'@odata.id'}));

    my $tasks_result = $options{custom}->request_api(
        url_path => $task_service->{Tasks}->{'@odata.id'},
        ignore_codes => { 404 => 1 }
    );
    return if (!defined($tasks_result) || !defined($tasks_result->{Members}) || ref($tasks_result->{Members}) ne 'ARRAY');

    foreach my $task_ref (@{$tasks_result->{Members}}) {
        next if (!defined($task_ref->{'@odata.id'}));
        
        my $task_data = $options{custom}->request_api(
            url_path => $task_ref->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($task_data));

        my $task_id;
        if (defined($task_data->{Id})) {
            $task_id = $task_data->{Id};
        } elsif ($task_ref->{'@odata.id'} =~ /\/Tasks\/([^\/]+)/) {
            $task_id = $1;
        } else {
            next;
        }

        my $task_state = defined($task_data->{TaskState}) ? $task_data->{TaskState} : 'n/a';
        my $task_status = defined($task_data->{TaskStatus}) ? $task_data->{TaskStatus} : 'n/a';

        if (defined($self->{option_results}->{filter_task_id}) && $self->{option_results}->{filter_task_id} ne '' &&
            $task_id !~ /$self->{option_results}->{filter_task_id}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_task_id}) && $self->{option_results}->{exclude_task_id} ne '' &&
            $task_id =~ /$self->{option_results}->{exclude_task_id}/) {
            next;
        }

        my $task_name = defined($task_data->{Name}) ? $task_data->{Name} : $task_id;

        if (defined($self->{option_results}->{filter_task_name}) && $self->{option_results}->{filter_task_name} ne '' &&
            $task_name !~ /$self->{option_results}->{filter_task_name}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_task_name}) && $self->{option_results}->{exclude_task_name} ne '' &&
            $task_name =~ /$self->{option_results}->{exclude_task_name}/) {
            next;
        }

        if (defined($self->{option_results}->{filter_task_state}) && $self->{option_results}->{filter_task_state} ne '' &&
            $task_state !~ /$self->{option_results}->{filter_task_state}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_task_state}) && $self->{option_results}->{exclude_task_state} ne '' &&
            $task_state =~ /$self->{option_results}->{exclude_task_state}/) {
            next;
        }

        $self->{global}->{total}++;
        if ($task_state =~ /Running/i) {
            $self->{global}->{running}++;
        } elsif ($task_state =~ /Completed/i) {
            $self->{global}->{completed}++;
        }

        $self->{tasks}->{$task_id} = {
            name             => $task_name,
            description      => defined($task_data->{Description}) ? $task_data->{Description} : '',
            task_state       => $task_state,
            task_status      => $task_status,
            percent_complete => defined($task_data->{PercentComplete}) ? $task_data->{PercentComplete} : 0,
        };
    }

    if (scalar(keys %{$self->{tasks}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No tasks found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA running tasks status via Redfish API.

=over 8

=item B<--filter-task-id>

Filter by task id (can be a regexp).

=item B<--filter-task-name>

Filter by task name (can be a regexp).

=item B<--filter-task-state>

Filter by task state (can be a regexp).

=item B<--exclude-task-id>

Exclude by task id (can be a regexp).

=item B<--exclude-task-name>

Exclude by task name (can be a regexp).

=item B<--exclude-task-state>

Exclude by task state (can be a regexp).

=item B<--warning-task-status> B<--critical-task-status>

Set warning/critical threshold for task status.
Default warning: '%{task_status} =~ /warning/i'
Default critical: '%{task_status} =~ /critical|error|exception/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'task-progress', 'tasks-completed', 'tasks-running', 'tasks-total'.

=back

=cut
