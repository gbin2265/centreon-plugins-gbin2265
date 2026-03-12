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

package hardware::server::dell::idrac::restapi::mode::manager;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("status: %s [state: %s]", $self->{result_values}->{health}, $self->{result_values}->{state});
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'manager', type => 0, skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{manager} = [
        {
            label => 'manager-status',
            type => 2,
            warning_default => '%{health} =~ /warning/i',
            critical_default => '%{health} =~ /critical/i',
            set => {
                key_values => [ { name => 'health' }, { name => 'state' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'graphical-console-sessions', nlabel => 'manager.graphical.console.sessions.count', set => {
                key_values => [ { name => 'graphical_sessions' } ],
                output_template => 'graphical console max sessions: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'serial-console-sessions', nlabel => 'manager.serial.console.sessions.count', set => {
                key_values => [ { name => 'serial_sessions' } ],
                output_template => 'serial console max sessions: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(endpoint => '/redfish/v1/Managers/iDRAC.Embedded.1');

    $self->{manager} = {
        health => $result->{Status}->{Health} // 'N/A',
        state => $result->{Status}->{State} // 'N/A',
        graphical_sessions => $result->{GraphicalConsole}->{MaxConcurrentSessions} // 0,
        serial_sessions => $result->{SerialConsole}->{MaxConcurrentSessions} // 0
    };
}

1;

__END__

=head1 MODE

Check iDRAC manager status.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='status'

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'graphical-console-sessions', 'serial-console-sessions'.

=back

=cut
