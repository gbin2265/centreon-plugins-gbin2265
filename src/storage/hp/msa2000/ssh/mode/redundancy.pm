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

package storage::hp::msa2000::ssh::mode::redundancy;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_redundancy_output {
    my ($self, %options) = @_;

    return sprintf('redundancy status: %s [mode: %s, system: %s]',
        $self->{result_values}->{redundancy_status},
        $self->{result_values}->{redundancy_mode},
        $self->{result_values}->{system_ready}
    );
}

sub custom_controller_output {
    my ($self, %options) = @_;

    my $msg = sprintf('status: %s [ready: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{ready}
    );
    if (defined($self->{result_values}->{reason}) && $self->{result_values}->{reason} ne '') {
        $msg .= ' [reason: ' . $self->{result_values}->{reason} . ']';
    }
    return $msg;
}

sub prefix_controller_output {
    my ($self, %options) = @_;

    return "Controller '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'redundancy', type => 0 },
        { name => 'controller', type => 1, cb_prefix_output => 'prefix_controller_output', message_multiple => 'All controllers are ok' }
    ];

    $self->{maps_counters}->{redundancy} = [
        {
            label => 'redundancy-status',
            type => 2,
            warning_default => '%{redundancy_status} !~ /redundant/i',
            set => {
                key_values => [
                    { name => 'redundancy_status' }, { name => 'redundancy_mode' },
                    { name => 'system_ready' }
                ],
                closure_custom_output => $self->can('custom_redundancy_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{controller} = [
        {
            label => 'controller-status',
            type => 2,
            critical_default => '%{status} !~ /operational/i',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'display' },
                    { name => 'ready' }, { name => 'reason' }
                ],
                closure_custom_output => $self->can('custom_controller_output'),
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

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($result) = $options{custom}->get_infos(
        cmd => 'show redundancy-mode',
        base_type => 'redundancy',
        properties_name => '^(?:redundancy-mode|redundancy-status|controller-a-status|controller-a-serial-number|controller-b-status|controller-b-serial-number|other-MC-status|system-ready|local-ready|local-reason|other-ready|other-reason)$'
    );

    my $info;
    if (ref($result) eq 'ARRAY') {
        $info = $result->[0] if (scalar(@$result) > 0);
    } elsif (ref($result) eq 'HASH' && scalar(keys %$result) > 0) {
        my @keys = keys %$result;
        $info = $result->{$keys[0]};
    }

    if (!defined($info)) {
        $self->{output}->add_option_msg(short_msg => 'No redundancy information found.');
        $self->{output}->option_exit();
    }

    $self->{redundancy} = {
        redundancy_status => defined($info->{'redundancy-status'}) ? $info->{'redundancy-status'} : 'unknown',
        redundancy_mode => defined($info->{'redundancy-mode'}) ? $info->{'redundancy-mode'} : '-',
        system_ready => defined($info->{'system-ready'}) ? $info->{'system-ready'} : '-',
    };

    $self->{controller} = {};

    # Controller A
    if (defined($info->{'controller-a-status'})) {
        $self->{controller}->{A} = {
            display => 'A',
            status => $info->{'controller-a-status'},
            ready => defined($info->{'local-ready'}) ? $info->{'local-ready'} : '-',
            reason => defined($info->{'local-reason'}) ? $info->{'local-reason'} : '',
        };
    }

    # Controller B
    if (defined($info->{'controller-b-status'})) {
        $self->{controller}->{B} = {
            display => 'B',
            status => $info->{'controller-b-status'},
            ready => defined($info->{'other-ready'}) ? $info->{'other-ready'} : '-',
            reason => defined($info->{'other-reason'}) ? $info->{'other-reason'} : '',
        };
    }

    $self->{output}->output_add(long_msg => sprintf(
        "redundancy mode: %s, status: %s, system ready: %s",
        $self->{redundancy}->{redundancy_mode},
        $self->{redundancy}->{redundancy_status},
        $self->{redundancy}->{system_ready}
    ));
    $self->{output}->output_add(long_msg => sprintf(
        "controller A: %s [serial: %s], controller B: %s [serial: %s]",
        defined($info->{'controller-a-status'}) ? $info->{'controller-a-status'} : '-',
        defined($info->{'controller-a-serial-number'}) ? $info->{'controller-a-serial-number'} : '-',
        defined($info->{'controller-b-status'}) ? $info->{'controller-b-status'} : '-',
        defined($info->{'controller-b-serial-number'}) ? $info->{'controller-b-serial-number'} : '-'
    ));
}

1;

__END__

=head1 MODE

Check controller redundancy status.

=over 8

=item B<--warning-redundancy-status>

Define the conditions to match for the status to be WARNING
(default: '%{redundancy_status} !~ /redundant/i').
You can use the following variables: %{redundancy_status}, %{redundancy_mode}, %{system_ready}

=item B<--critical-redundancy-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{redundancy_status}, %{redundancy_mode}, %{system_ready}

=item B<--warning-controller-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{display}, %{ready}, %{reason}

=item B<--critical-controller-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{status} !~ /operational/i').
You can use the following variables: %{status}, %{display}, %{ready}, %{reason}

=back

=cut
