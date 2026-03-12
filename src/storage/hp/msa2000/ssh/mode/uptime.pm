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

package storage::hp::msa2000::ssh::mode::uptime;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use POSIX;

sub custom_uptime_output {
    my ($self, %options) = @_;

    my $seconds = $self->{result_values}->{uptime_seconds};
    my $days = floor($seconds / 86400);
    my $hours = floor(($seconds % 86400) / 3600);
    my $minutes = floor(($seconds % 3600) / 60);
    my $secs = $seconds % 60;

    return sprintf('uptime: %dd %dh %dm %ds', $days, $hours, $minutes, $secs);
}

sub custom_total_output {
    my ($self, %options) = @_;

    my $hours = $self->{result_values}->{total_power_on_hours};
    my $days = floor($hours / 24);
    my $h = $hours - ($days * 24);

    return sprintf('total power-on time: %dd %.1fh', $days, $h);
}

sub prefix_controller_output {
    my ($self, %options) = @_;

    return "Controller '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'controller', type => 1, cb_prefix_output => 'prefix_controller_output', message_multiple => 'All controllers uptime ok' }
    ];

    $self->{maps_counters}->{controller} = [
        { label => 'uptime', nlabel => 'controller.uptime.seconds', set => {
                key_values => [ { name => 'uptime_seconds' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_uptime_output'),
                perfdatas => [
                    { template => '%d', unit => 's', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'total-power-on', nlabel => 'controller.total.power.on.seconds', display_ok => 0, set => {
                key_values => [ { name => 'total_power_on_seconds' }, { name => 'total_power_on_hours' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_total_output'),
                perfdatas => [
                    { value => 'total_power_on_seconds', template => '%d', unit => 's', min => 0, label_extra_instance => 1, instance_use => 'display' }
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
        'filter-controller-name:s' => { name => 'filter_controller_name' },
        'exclude-controller-name:s' => { name => 'exclude_controller_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($result) = $options{custom}->get_infos(
        cmd => 'show controller-statistics',
        base_type => 'controller-statistics',
        properties_name => '^(?:durable-id|power-on-time|total-power-on-hours)$'
    );

    $self->{controller} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $ctrl (@items) {
        my $durable_id = defined($ctrl->{'durable-id'}) ? $ctrl->{'durable-id'} : 'unknown';
        # controller_A -> A
        my $name = $durable_id;
        $name =~ s/^controller_//;

        if (defined($self->{option_results}->{filter_controller_name}) && $self->{option_results}->{filter_controller_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_controller_name}/) {
            $self->{output}->output_add(long_msg => "skipping controller '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_controller_name}) && $self->{option_results}->{exclude_controller_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_controller_name}/) {
            $self->{output}->output_add(long_msg => "skipping controller '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $uptime = defined($ctrl->{'power-on-time'}) ? $ctrl->{'power-on-time'} : undef;
        my $total_hours = defined($ctrl->{'total-power-on-hours'}) ? $ctrl->{'total-power-on-hours'} : undef;
        my $total_seconds = defined($total_hours) ? $total_hours * 3600 : undef;

        $self->{controller}->{$name} = {
            display => $name,
            uptime_seconds => $uptime,
            total_power_on_hours => $total_hours,
            total_power_on_seconds => defined($total_seconds) ? int($total_seconds) : undef,
        };
    }

    if (scalar(keys %{$self->{controller}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No controller found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check controller uptime and total power-on time.

Uses 'show controller-statistics' for power-on-time (uptime since last reboot)
and total-power-on-hours (lifetime).

=over 8

=item B<--filter-controller-name>

Filter controllers by name (can be a regexp, e.g. '^A$').

=item B<--exclude-controller-name>

Exclude controllers by name (can be a regexp).

=item B<--warning-uptime>

Warning threshold for uptime in seconds.

=item B<--critical-uptime>

Critical threshold for uptime in seconds.

=item B<--warning-total-power-on>

Warning threshold for total power-on time in seconds.

=item B<--critical-total-power-on>

Critical threshold for total power-on time in seconds.

=back

=cut
