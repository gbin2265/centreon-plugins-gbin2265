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

package apps::backup::commvault::commserve::restapi::mode::events;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::misc;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_event_output {
    my ($self, %options) = @_;
    return sprintf(
        '[severity: %s][type: %s] %s (%s ago)',
        $self->{result_values}->{severity},
        $self->{result_values}->{event_type},
        $self->{result_values}->{description},
        $self->{result_values}->{time_ago}
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Events ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'events', type => 2, message_multiple => '0 problem event(s) detected',
          display_counter_problem => { nlabel => 'events.problems.current.count', min => 0 },
          group => [ { name => 'event', skipped_code => { -11 => 1 } } ]
        }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'events-total', nlabel => 'events.total.count', display_ok => 0, set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'events-critical', nlabel => 'events.critical.count', display_ok => 0, set => {
                key_values => [ { name => 'critical' }, { name => 'total' } ],
                output_template => 'critical: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        },
        { label => 'events-warning', nlabel => 'events.warning.count', display_ok => 0, set => {
                key_values => [ { name => 'warning' }, { name => 'total' } ],
                output_template => 'warning: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        },
        { label => 'events-info', nlabel => 'events.info.count', display_ok => 0, set => {
                key_values => [ { name => 'info' }, { name => 'total' } ],
                output_template => 'info: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        }
    ];

    $self->{maps_counters}->{event} = [
        {
            label => 'status', type => 2,
            warning_default => '%{severity} =~ /warning/i',
            critical_default => '%{severity} =~ /critical/i',
            set => {
                key_values => [
                    { name => 'event_type' }, { name => 'severity' },
                    { name => 'description' }, { name => 'client_name' },
                    { name => 'time_ago' }, { name => 'since' }
                ],
                closure_custom_output => $self->can('custom_event_output'),
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
        'filter-event-type:s' => { name => 'filter_event_type' },
        'filter-client-name:s' => { name => 'filter_client_name' },
        'timeframe:s'          => { name => 'timeframe', default => 86400 }
    });
    return $self;
}

my $map_severity = {
    0 => 'info', 1 => 'info', 2 => 'warning',
    3 => 'warning', 4 => 'warning', 5 => 'critical',
    6 => 'critical', 7 => 'critical'
};

sub manage_selection {
    my ($self, %options) = @_;

    my $timeframe = $self->{option_results}->{timeframe};
    if ($timeframe && $timeframe =~ /(\d+)/) {
        $timeframe = $1;
    } else {
        $timeframe = 86400;
    }

    my $from_time = time() - $timeframe;

    my $results = $options{custom}->request_internal(
        endpoint => '/Events',
        get_param => [ 'level=0', 'fromTime=' . $from_time ]
    );

    $self->{global} = { total => 0, critical => 0, warning => 0, info => 0 };
    $self->{events} = { global => { event => {} } };

    my $entries = $results->{commservEvents} // $results->{eventList} // [];
    my ($i, $current_time) = (1, time());

    foreach my $entry (@{$entries}) {
        my $event_type = $entry->{eventType}    // $entry->{eventCode} // '-';
        my $severity_id = $entry->{severity}    // 0;
        my $severity = $map_severity->{$severity_id} // 'info';
        my $description = $entry->{description} // $entry->{eventMessage} // '-';
        my $client_name = $entry->{clientName}  // $entry->{clientEntity}->{clientName} // '-';
        my $event_time  = $entry->{timeSource}  // $entry->{eventTime} // 0;

        if (defined($self->{option_results}->{filter_event_type}) && $self->{option_results}->{filter_event_type} ne '' &&
            $event_type !~ /$self->{option_results}->{filter_event_type}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_client_name}) && $self->{option_results}->{filter_client_name} ne '' &&
            $client_name !~ /$self->{option_results}->{filter_client_name}/) {
            next;
        }

        # Truncate long descriptions
        $description = substr($description, 0, 200) . '...' if (length($description) > 200);

        my $diff_time = $current_time - $event_time;
        $diff_time = 0 if $diff_time < 0;

        $self->{events}->{global}->{event}->{$i} = {
            event_type  => $event_type,
            severity    => $severity,
            description => $description,
            client_name => $client_name,
            since       => $diff_time,
            time_ago    => centreon::plugins::misc::change_seconds(value => $diff_time)
        };

        $self->{global}->{total}++;
        $self->{global}->{$severity}++ if defined($self->{global}->{$severity});
        $i++;
    }
}

1;

__END__

=head1 MODE

Check recent events.

Commvault severity IDs are mapped as follows:
0-1 = info, 2-4 = warning (includes 'minor'), 5-7 = critical (includes 'major').

=over 8

=item B<--filter-event-type>

Filter events by type (can be a regexp).

=item B<--filter-client-name>

Filter events by client name (can be a regexp).

=item B<--timeframe>

Set timeframe in seconds to look back for events (default: 86400 = 24 hours).

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{severity} =~ /warning/i').
You can use the following variables: %{event_type}, %{severity}, %{description}, %{client_name}, %{time_ago}, %{since}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{severity} =~ /critical/i').
You can use the following variables: %{event_type}, %{severity}, %{description}, %{client_name}, %{time_ago}, %{since}

=item B<--warning-events-total>

Thresholds.

=item B<--critical-events-total>

Thresholds.

=item B<--warning-events-critical>

Thresholds.

=item B<--critical-events-critical>

Thresholds.

=item B<--warning-events-warning>

Thresholds.

=item B<--critical-events-warning>

Thresholds.

=item B<--warning-events-info>

Thresholds.

=item B<--critical-events-info>

Thresholds.

=back

=cut
