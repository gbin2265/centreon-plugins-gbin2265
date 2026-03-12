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

package hardware::server::dell::idrac::restapi::mode::usage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'usage', type => 0, skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{usage} = [
        { label => 'cpu-usage', nlabel => 'system.cpu.usage.percentage', set => {
                key_values => [ { name => 'cpu_usage' } ],
                output_template => 'CPU usage: %.2f%%',
                perfdatas => [ { template => '%.2f', unit => '%', min => 0, max => 100 } ]
            }
        },
        { label => 'memory-usage', nlabel => 'system.memory.usage.percentage', set => {
                key_values => [ { name => 'memory_usage' } ],
                output_template => 'memory usage: %.2f%%',
                perfdatas => [ { template => '%.2f', unit => '%', min => 0, max => 100 } ]
            }
        },
        { label => 'io-usage', nlabel => 'system.io.usage.percentage', set => {
                key_values => [ { name => 'io_usage' } ],
                output_template => 'I/O usage: %.2f%%',
                perfdatas => [ { template => '%.2f', unit => '%', min => 0, max => 100 } ]
            }
        },
        { label => 'system-usage', nlabel => 'system.overall.usage.percentage', set => {
                key_values => [ { name => 'sys_usage' } ],
                output_template => 'system usage: %.2f%%',
                perfdatas => [ { template => '%.2f', unit => '%', min => 0, max => 100 } ]
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

    my $result = $options{custom}->request_api(endpoint => '/redfish/v1/Chassis/System.Embedded.1/Sensors');

    $self->{usage} = {};

    return if (!defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        
        my $sensor = $options{custom}->request_api(endpoint => $member->{'@odata.id'}, ignore_error => 1);
        next if (!defined($sensor));
        next if (!defined($sensor->{ReadingType}) || $sensor->{ReadingType} ne 'Percent');
        
        my $name = $sensor->{Name} // '';
        my $reading = $sensor->{Reading};
        next if (!defined($reading));

        if ($name =~ /CPU\s*Usage/i) { $self->{usage}->{cpu_usage} = $reading; }
        elsif ($name =~ /MEM\s*Usage/i) { $self->{usage}->{memory_usage} = $reading; }
        elsif ($name =~ /IO\s*Usage/i) { $self->{usage}->{io_usage} = $reading; }
        elsif ($name =~ /SYS\s*Usage/i) { $self->{usage}->{sys_usage} = $reading; }
    }

    if (!defined($self->{usage}->{cpu_usage}) && !defined($self->{usage}->{memory_usage})) {
        $self->{output}->add_option_msg(short_msg => "No usage metrics found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check system usage metrics (CPU, memory, I/O).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='cpu-usage'

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'cpu-usage', 'memory-usage', 'io-usage', 'system-usage'.

=back

=cut
