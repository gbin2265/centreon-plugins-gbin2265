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

package network::brocade::restapi::mode::uptime;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use POSIX;

sub custom_uptime_output {
    my ($self, %options) = @_;

    my $uptime_seconds = $self->{result_values}->{uptime};
    
    # Convert to human readable
    my $days = floor($uptime_seconds / 86400);
    my $hours = floor(($uptime_seconds % 86400) / 3600);
    my $minutes = floor(($uptime_seconds % 3600) / 60);
    my $seconds = $uptime_seconds % 60;
    
    my $msg = 'uptime: ';
    if ($days > 0) {
        $msg .= sprintf("%dd %dh %dm %ds", $days, $hours, $minutes, $seconds);
    } elsif ($hours > 0) {
        $msg .= sprintf("%dh %dm %ds", $hours, $minutes, $seconds);
    } elsif ($minutes > 0) {
        $msg .= sprintf("%dm %ds", $minutes, $seconds);
    } else {
        $msg .= sprintf("%ds", $seconds);
    }
    
    return $msg;
}

sub prefix_switch_output {
    my ($self, %options) = @_;

    return "Switch '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'switches', type => 1, cb_prefix_output => 'prefix_switch_output', message_multiple => 'All switch uptimes are ok' }
    ];

    $self->{maps_counters}->{switches} = [
        { label => 'uptime', nlabel => 'switch.uptime.seconds', set => {
                key_values => [ { name => 'uptime' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_uptime_output'),
                perfdatas => [
                    { template => '%s', unit => 's', min => 0, label_extra_instance => 1 }
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
        'filter-switch-name:s' => { name => 'filter_switch_name' },
        'exclude-switch-name:s' => { name => 'exclude_switch_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $switches = $options{custom}->get_switch_info();

    $self->{switches} = {};

    my $switch_data = $switches->{'Response'}->{'fibrechannel-switch'} // $switches->{'brocade-fibrechannel-switch'}->{'fibrechannel-switch'} // [];
    $switch_data = [$switch_data] if (ref($switch_data) ne 'ARRAY');

    foreach my $switch (@{$switch_data}) {
        my $switch_name = $switch->{'name'} // $switch->{'switch-name'} // $switch->{'user-friendly-name'} // 'unknown';

        if (defined($self->{option_results}->{filter_switch_name}) && $self->{option_results}->{filter_switch_name} ne '' &&
            $switch_name !~ /$self->{option_results}->{filter_switch_name}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_switch_name}) && $self->{option_results}->{exclude_switch_name} ne '' &&
            $switch_name =~ /$self->{option_results}->{exclude_switch_name}/) {
            next;
        }

        my $uptime = $switch->{'up-time'} // 0;

        $self->{switches}->{$switch_name} = {
            display => $switch_name,
            uptime => $uptime
        };
    }

    if (scalar(keys %{$self->{switches}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No switch found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check switch uptime.

=over 8

=item B<--filter-switch-name>

Filter switches by name (can be a regexp).

=item B<--exclude-switch-name>

Exclude switches by name (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'uptime'.

Example: --critical-uptime='300:' to alert if uptime is less than 5 minutes (reboot detection).

=back

=cut
