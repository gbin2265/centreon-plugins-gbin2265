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

package apps::backup::commvault::commserve::restapi::mode::listschedules;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-schedule-name:s' => { name => 'filter_schedule_name' }
    });
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

my $map_task_type = {
    1 => 'Immediate', 2 => 'Schedule', 3 => 'SchedulePolicy'
};

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_internal(
        endpoint => '/Schedules'
    );

    my $schedules = [];
    my $entries = $results->{taskDetail} // [];
    foreach my $entry (@{$entries}) {
        my $task = $entry->{task} // {};
        my $task_name = $task->{taskName} // '';
        my $task_id   = $task->{taskId}   // '';

        next if ($task_name eq '');
        next if (defined($self->{option_results}->{filter_schedule_name}) && $self->{option_results}->{filter_schedule_name} ne '' &&
            $task_name !~ /$self->{option_results}->{filter_schedule_name}/);

        my $status = 'enabled';
        if (defined($task->{taskFlags}) && ref($task->{taskFlags}) eq 'HASH') {
            $status = 'disabled' if ($task->{taskFlags}->{disabled});
        }

        my $task_type = $map_task_type->{ $task->{taskType} // 0 } // $task->{taskType} // '-';

        push @{$schedules}, {
            id     => $task_id,
            name   => $task_name,
            type   => $task_type,
            status => $status
        };
    }
    return $schedules;
}

sub run {
    my ($self, %options) = @_;

    my $schedules = $self->manage_selection(%options);
    foreach (@{$schedules}) {
        $self->{output}->output_add(
            long_msg => sprintf(
                '[id: %s][name: %s][type: %s][status: %s]',
                $_->{id}, $_->{name}, $_->{type}, $_->{status}
            )
        );
    }

    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List schedules:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;
    $self->{output}->add_disco_format(elements => ['id', 'name', 'type', 'status']);
}

sub disco_show {
    my ($self, %options) = @_;

    my $schedules = $self->manage_selection(%options);
    foreach (@{$schedules}) {
        $self->{output}->add_disco_entry(
            id     => $_->{id},
            name   => $_->{name},
            type   => $_->{type},
            status => $_->{status}
        );
    }
}

1;

__END__

=head1 MODE

List schedules (for Centreon auto-discovery).

=over 8

=item B<--filter-schedule-name>

Filter schedules by name (can be a regexp).

=back

=cut
