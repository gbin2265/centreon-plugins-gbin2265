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

package hardware::server::hp::oneview::restapi::mode::appliancetasks;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
    ];

    $self->{maps_counters}->{global} = [
        { label => 'tasks-total', nlabel => 'appliance.tasks.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total tasks: %d',
                perfdatas       => [ { value => 'total', template => '%d', min => 0 } ],
            }
        },
        { label => 'tasks-running', nlabel => 'appliance.tasks.running.count', set => {
                key_values      => [ { name => 'running' } ],
                output_template => 'running: %d',
                perfdatas       => [ { value => 'running', template => '%d', min => 0 } ],
            }
        },
        { label => 'tasks-pending', nlabel => 'appliance.tasks.pending.count', set => {
                key_values      => [ { name => 'pending' } ],
                output_template => 'pending: %d',
                perfdatas       => [ { value => 'pending', template => '%d', min => 0 } ],
            }
        },
        { label => 'tasks-completed', nlabel => 'appliance.tasks.completed.count', display_ok => 0, set => {
                key_values      => [ { name => 'completed' } ],
                output_template => 'completed: %d',
                perfdatas       => [ { value => 'completed', template => '%d', min => 0 } ],
            }
        },
        { label => 'tasks-error', nlabel => 'appliance.tasks.error.count', set => {
                key_values      => [ { name => 'error' } ],
                output_template => 'error: %d',
                perfdatas       => [ { value => 'error', template => '%d', min => 0 } ],
            }
        },
        { label => 'tasks-warning', nlabel => 'appliance.tasks.warning.count', set => {
                key_values      => [ { name => 'warning' } ],
                output_template => 'warning: %d',
                perfdatas       => [ { value => 'warning', template => '%d', min => 0 } ],
            }
        },
        { label => 'tasks-terminated', nlabel => 'appliance.tasks.terminated.count', display_ok => 0, set => {
                key_values      => [ { name => 'terminated' } ],
                output_template => 'terminated: %d',
                perfdatas       => [ { value => 'terminated', template => '%d', min => 0 } ],
            }
        },
        { label => 'tasks-killed', nlabel => 'appliance.tasks.killed.count', display_ok => 0, set => {
                key_values      => [ { name => 'killed' } ],
                output_template => 'killed: %d',
                perfdatas       => [ { value => 'killed', template => '%d', min => 0 } ],
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-state:s'       => { name => 'filter_state' },
        'filter-type:s'        => { name => 'filter_type' },
        'filter-resource:s'    => { name => 'filter_resource' },
        'filter-owner:s'       => { name => 'filter_owner' },
        # How far back to look (in seconds). Default: last 3600 s
        'lookback-seconds:s'   => { name => 'lookback_seconds', default => 3600 },
        # Max tasks to fetch (most recent first). Default: 20
        'max-tasks:s'          => { name => 'max_tasks', default => 20 },
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # Fetch only the most recent tasks to avoid timeout on large environments.
    # OneView keeps thousands of historical tasks — we limit via count + sort.
    # The lookback filter is applied client-side after fetching.
    my $max_tasks = $self->{option_results}->{max_tasks} // 20;
    my $page = $options{custom}->request_api(
        url_path => "/rest/tasks?start=0&count=${max_tasks}&sort=modified:desc"
    );
    my $results = { members => (defined($page) && defined($page->{members})) ? $page->{members} : [] };

    my $now = time();

    $self->{global} = {
        total       => 0,
        running     => 0,
        pending     => 0,
        completed   => 0,
        error       => 0,
        warning     => 0,
        terminated  => 0,
        killed      => 0,
    };

    foreach my $task (@{$results->{members}}) {
        # Apply lookback window if set
        if (defined($self->{option_results}->{lookback_seconds}) && $self->{option_results}->{lookback_seconds} > 0) {
            my $created = $task->{created} // '';
            # createdString format: 2024-01-15T10:30:00.000Z
            if ($created =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/) {
                require POSIX;
                my $epoch = eval {
                    use Time::Local;
                    Time::Local::timegm($6, $5, $4, $3, $2 - 1, $1 - 1900);
                };
                next if (!$@ && defined($epoch) && ($now - $epoch) > $self->{option_results}->{lookback_seconds});
            }
        }

        my $task_state    = lc($task->{taskState}    // 'unknown');
        my $task_type     = $task->{type}             // '';
        my $resource_name = $task->{associatedResourceName} // $task->{name} // '';
        my $owner         = $task->{owner}            // $task->{submittedBy} // '';

        if (defined($self->{option_results}->{filter_state}) && $self->{option_results}->{filter_state} ne '' &&
            $task_state !~ /$self->{option_results}->{filter_state}/i) {
            next;
        }
        if (defined($self->{option_results}->{filter_type}) && $self->{option_results}->{filter_type} ne '' &&
            $task_type !~ /$self->{option_results}->{filter_type}/i) {
            next;
        }
        if (defined($self->{option_results}->{filter_resource}) && $self->{option_results}->{filter_resource} ne '' &&
            $resource_name !~ /$self->{option_results}->{filter_resource}/i) {
            next;
        }
        if (defined($self->{option_results}->{filter_owner}) && $self->{option_results}->{filter_owner} ne '' &&
            $owner !~ /$self->{option_results}->{filter_owner}/i) {
            next;
        }

        $self->{global}->{total}++;

        if    ($task_state =~ /^running$/)    { $self->{global}->{running}++; }
        elsif ($task_state =~ /^pending|waiting/)  { $self->{global}->{pending}++; }
        elsif ($task_state =~ /^completed$/)  { $self->{global}->{completed}++; }
        elsif ($task_state =~ /^error$/)      { $self->{global}->{error}++; }
        elsif ($task_state =~ /^warning$/)    { $self->{global}->{warning}++; }
        elsif ($task_state =~ /^terminated$/) { $self->{global}->{terminated}++; }
        elsif ($task_state =~ /^killed$/)     { $self->{global}->{killed}++; }
    }
}

1;

__END__

=head1 MODE

Check HPE OneView appliance task queue status.

Counts tasks by state (running, pending, completed, error, warning,
terminated, killed) across the task list. By default only tasks created
in the last 3600 seconds are counted (configurable with B<--lookback-seconds>).

=over 8

=item B<--lookback-seconds>

Only count tasks created within the last N seconds (default: 3600).
Set to 0 to count all tasks.

=item B<--filter-state>

Filter tasks by state (can be a regexp).
Example: --filter-state='running|pending'

=item B<--filter-type>

Filter tasks by task type (can be a regexp).

=item B<--filter-resource>

Filter tasks by associated resource name (can be a regexp).

=item B<--filter-owner>

Filter tasks by owner or submitter account (can be a regexp).
Example: --filter-owner='administrator' to only count administrator tasks.

=item B<--warning-*> B<--critical-*>

Thresholds for:
'tasks-total', 'tasks-running', 'tasks-pending', 'tasks-completed',
'tasks-error', 'tasks-warning', 'tasks-terminated', 'tasks-killed'.

Example: --critical-tasks-error=1 to alert on any task in error state.

=back

=cut
