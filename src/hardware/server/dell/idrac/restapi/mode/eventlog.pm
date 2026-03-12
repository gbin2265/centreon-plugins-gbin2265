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

package hardware::server::dell::idrac::restapi::mode::eventlog;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'eventlog', type => 0, skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{eventlog} = [
        { label => 'events-total', nlabel => 'eventlog.events.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total events: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'events-critical', nlabel => 'eventlog.events.critical.count', set => {
                key_values => [ { name => 'critical' } ],
                output_template => 'critical: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'events-warning', nlabel => 'eventlog.events.warning.count', set => {
                key_values => [ { name => 'warning' } ],
                output_template => 'warning: %s',
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

    my $result = $options{custom}->request_api(endpoint => '/redfish/v1/Managers/iDRAC.Embedded.1/LogServices/Sel/Entries');

    my $total = 0;
    my $critical = 0;
    my $warning = 0;

    if (defined($result->{Members})) {
        $total = scalar(@{$result->{Members}});
        foreach my $entry (@{$result->{Members}}) {
            my $severity = $entry->{Severity} // '';
            if ($severity =~ /critical/i) { $critical++; }
            elsif ($severity =~ /warning/i) { $warning++; }
        }
    }

    $self->{eventlog} = {
        total => $total,
        critical => $critical,
        warning => $warning
    };
}

1;

__END__

=head1 MODE

Check system event log.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='events'

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'events-total', 'events-critical', 'events-warning'.

=back

=cut
