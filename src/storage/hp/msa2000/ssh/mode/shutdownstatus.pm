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

package storage::hp::msa2000::ssh::mode::shutdownstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_controller_output {
    my ($self, %options) = @_;

    return sprintf('status: %s', $self->{result_values}->{status});
}

sub custom_mc_output {
    my ($self, %options) = @_;

    return sprintf('other MC status: %s', $self->{result_values}->{mc_status});
}

sub prefix_controller_output {
    my ($self, %options) = @_;

    return "Controller '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'controller', type => 1, cb_prefix_output => 'prefix_controller_output', message_multiple => 'All controllers are up' },
        { name => 'mc', type => 0 }
    ];

    $self->{maps_counters}->{controller} = [
        {
            label => 'controller-status',
            type => 2,
            critical_default => '%{status} !~ /up/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_controller_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{mc} = [
        {
            label => 'mc-status',
            type => 2,
            critical_default => '%{mc_status} !~ /operational/i',
            set => {
                key_values => [ { name => 'mc_status' } ],
                closure_custom_output => $self->can('custom_mc_output'),
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

    # Get controller shutdown status
    my ($result) = $options{custom}->get_infos(
        cmd => 'show shutdown-status',
        base_type => 'shutdown-status',
        properties_name => '^(?:controller|status|status-numeric)$'
    );

    $self->{controller} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $ctrl (@items) {
        my $name = defined($ctrl->{'controller'}) ? $ctrl->{'controller'} : 'unknown';
        my $status = defined($ctrl->{'status'}) ? $ctrl->{'status'} : 'unknown';

        $self->{controller}->{$name} = {
            display => $name,
            status => $status,
        };
    }

    # Get other MC status
    my ($mc_result) = $options{custom}->get_infos(
        cmd => 'show shutdown-status',
        base_type => 'show-other-MC-status',
        properties_name => '^(?:other-MC|other-MC-status|other-MC-status-numeric)$',
        no_quit => 1
    );

    my $mc_status = 'unknown';
    if (defined($mc_result)) {
        my @mc_items = ref($mc_result) eq 'ARRAY' ? @$mc_result : values %$mc_result;
        if (scalar(@mc_items) > 0) {
            $mc_status = defined($mc_items[0]->{'other-MC-status'}) ? $mc_items[0]->{'other-MC-status'} : 'unknown';
        }
    }

    $self->{mc} = {
        mc_status => $mc_status,
    };

    if (scalar(keys %{$self->{controller}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No shutdown status information found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check controller shutdown status and management controller status.

=over 8

=item B<--warning-controller-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{display}

=item B<--critical-controller-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{status} !~ /up/i').
You can use the following variables: %{status}, %{display}

=item B<--warning-mc-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{mc_status}

=item B<--critical-mc-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{mc_status} !~ /operational/i').
You can use the following variables: %{mc_status}

=back

=cut
