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

package hardware::server::dell::idrac::restapi::mode::power;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'power', type => 0, skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{power} = [
        { label => 'power-consumed', nlabel => 'system.power.consumed.watt', set => {
                key_values => [ { name => 'power_consumed' } ],
                output_template => 'power consumed: %s W',
                perfdatas => [ { template => '%s', unit => 'W', min => 0 } ]
            }
        },
        { label => 'power-capacity', nlabel => 'system.power.capacity.watt', set => {
                key_values => [ { name => 'power_capacity' } ],
                output_template => 'capacity: %s W',
                perfdatas => [ { template => '%s', unit => 'W', min => 0 } ]
            }
        },
        { label => 'power-usage', nlabel => 'system.power.usage.percentage', set => {
                key_values => [ { name => 'power_usage' } ],
                output_template => 'usage: %.2f%%',
                perfdatas => [ { template => '%.2f', unit => '%', min => 0, max => 100 } ]
            }
        },
        { label => 'power-average', nlabel => 'system.power.average.watt', set => {
                key_values => [ { name => 'power_average' } ],
                output_template => 'average: %s W',
                perfdatas => [ { template => '%s', unit => 'W', min => 0 } ]
            }
        },
        { label => 'power-minimum', nlabel => 'system.power.minimum.watt', set => {
                key_values => [ { name => 'power_minimum' } ],
                output_template => 'minimum: %s W',
                perfdatas => [ { template => '%s', unit => 'W', min => 0 } ]
            }
        },
        { label => 'power-maximum', nlabel => 'system.power.maximum.watt', set => {
                key_values => [ { name => 'power_maximum' } ],
                output_template => 'maximum: %s W',
                perfdatas => [ { template => '%s', unit => 'W', min => 0 } ]
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

    my $result = $options{custom}->request_api(endpoint => '/redfish/v1/Chassis/System.Embedded.1/Power');

    if (!defined($result->{PowerControl}) || scalar(@{$result->{PowerControl}}) == 0) {
        $self->{output}->add_option_msg(short_msg => "No power control data found.");
        $self->{output}->option_exit();
    }

    my $power_control = $result->{PowerControl}->[0];

    my $power_consumed = $power_control->{PowerConsumedWatts};
    my $power_capacity = $power_control->{PowerCapacityWatts};

    my $power_usage;
    if (defined($power_consumed) && defined($power_capacity) && $power_capacity > 0) {
        $power_usage = ($power_consumed / $power_capacity) * 100;
    }

    my $power_metrics = $power_control->{PowerMetrics};

    $self->{power} = {
        power_consumed => $power_consumed,
        power_capacity => $power_capacity,
        power_usage    => $power_usage,
        power_average  => defined($power_metrics) ? $power_metrics->{AverageConsumedWatts} : undef,
        power_minimum  => defined($power_metrics) ? $power_metrics->{MinConsumedWatts} : undef,
        power_maximum  => defined($power_metrics) ? $power_metrics->{MaxConsumedWatts} : undef
    };
}

1;

__END__

=head1 MODE

Check system power consumption.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='consumed'

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'power-consumed', 'power-capacity', 'power-usage', 'power-average', 'power-minimum', 'power-maximum'.

=back

=cut
