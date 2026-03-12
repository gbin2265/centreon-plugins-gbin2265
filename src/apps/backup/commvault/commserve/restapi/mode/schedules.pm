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

package apps::backup::commvault::commserve::restapi::mode::schedules;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf(
        'status: %s [type: %s][frequency: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{task_type},
        $self->{result_values}->{frequency}
    );
}

sub prefix_schedule_output {
    my ($self, %options) = @_;
    return "Schedule '" . $options{instance_value}->{display} . "' [policy: " . $options{instance_value}->{policy_name} . "] ";
}

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Schedules ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'schedules', type => 1, cb_prefix_output => 'prefix_schedule_output', message_multiple => 'All schedules are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'schedules-total', nlabel => 'schedules.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'schedules-enabled', nlabel => 'schedules.enabled.count', display_ok => 0, set => {
                key_values => [ { name => 'enabled' }, { name => 'total' } ],
                output_template => 'enabled: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        },
        { label => 'schedules-disabled', nlabel => 'schedules.disabled.count', display_ok => 0, set => {
                key_values => [ { name => 'disabled' }, { name => 'total' } ],
                output_template => 'disabled: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        }
    ];

    $self->{maps_counters}->{schedules} = [
        {
            label => 'status', type => 2,
            warning_default => '%{status} =~ /disabled/i',
            set => {
                key_values => [
                    { name => 'display' }, { name => 'status' },
                    { name => 'task_type' }, { name => 'policy_name' },
                    { name => 'frequency' }, { name => 'schedule_id' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-schedule-name:s' => { name => 'filter_schedule_name' },
        'filter-policy-name:s'   => { name => 'filter_policy_name' }
    });
    return $self;
}

my $map_task_type = {
    1 => 'Immediate', 2 => 'Schedule', 3 => 'SchedulePolicy'
};

my $map_freq_type = {
    1 => 'Daily', 2 => 'Weekly', 3 => 'Monthly', 4 => 'Yearly',
    5 => 'OneTime', 6 => 'Automatic', 1024 => 'Continuous'
};

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_internal(
        endpoint => '/Schedules'
    );

    $self->{global} = { total => 0, enabled => 0, disabled => 0 };
    $self->{schedules} = {};

    my $entries = $results->{taskDetail} // [];
    foreach my $entry (@{$entries}) {
        my $task = $entry->{task} // {};
        my $task_name = $task->{taskName} // '';
        my $task_id   = $task->{taskId}   // '';
        next if ($task_name eq '');

        if (defined($self->{option_results}->{filter_schedule_name}) && $self->{option_results}->{filter_schedule_name} ne '' &&
            $task_name !~ /$self->{option_results}->{filter_schedule_name}/) {
            next;
        }

        my $policy_name = '-';
        my $assoc = $entry->{appGroup} // $entry->{association} // {};
        if (ref($assoc) eq 'HASH') {
            $policy_name = $assoc->{subclientName} // $assoc->{clientName} // $assoc->{storagePolicyName} // '-';
        }

        if (defined($self->{option_results}->{filter_policy_name}) && $self->{option_results}->{filter_policy_name} ne '' &&
            $policy_name !~ /$self->{option_results}->{filter_policy_name}/) {
            next;
        }

        my $task_type = $map_task_type->{ $task->{taskType} // 0 } // $task->{taskType} // '-';

        my $status = 'enabled';
        if (defined($task->{taskFlags}) && ref($task->{taskFlags}) eq 'HASH') {
            $status = 'disabled' if ($task->{taskFlags}->{disabled});
        }

        my $frequency = '-';
        my $sub_tasks = $entry->{subTasks} // [];
        if (ref($sub_tasks) eq 'ARRAY' && scalar(@{$sub_tasks}) > 0) {
            my $pattern = $sub_tasks->[0]->{pattern} // {};
            $frequency = $map_freq_type->{ $pattern->{freq_type} // 0 } // $pattern->{freq_type} // '-';
        }

        $self->{schedules}->{$task_name} = {
            display     => $task_name,
            schedule_id => $task_id,
            status      => $status,
            task_type   => $task_type,
            policy_name => $policy_name,
            frequency   => $frequency
        };

        $self->{global}->{$status}++ if defined($self->{global}->{$status});
        $self->{global}->{total}++;
    }

    if (scalar(keys %{$self->{schedules}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No schedules found");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check schedule status.

=over 8

=item B<--filter-schedule-name>

Filter schedules by name (can be a regexp).

=item B<--filter-policy-name>

Filter by associated policy/client name (can be a regexp).

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{status} =~ /disabled/i').
You can use the following variables: %{display}, %{status}, %{task_type}, %{policy_name}, %{frequency}, %{schedule_id}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{display}, %{status}, %{task_type}, %{policy_name}, %{frequency}, %{schedule_id}

=item B<--warning-schedules-total>

Thresholds.

=item B<--critical-schedules-total>

Thresholds.

=item B<--warning-schedules-enabled>

Thresholds.

=item B<--critical-schedules-enabled>

Thresholds.

=item B<--warning-schedules-disabled>

Thresholds.

=item B<--critical-schedules-disabled>

Thresholds.

=back

=cut
