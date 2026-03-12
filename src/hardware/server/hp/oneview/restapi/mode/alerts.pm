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

package hardware::server::hp::oneview::restapi::mode::alerts;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
    ];

    $self->{maps_counters}->{global} = [
        { label => 'alerts-total', nlabel => 'alerts.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total alerts: %d',
                perfdatas => [
                    { value => 'total', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'alerts-critical', nlabel => 'alerts.severity.critical.count', set => {
                key_values => [ { name => 'critical' } ],
                output_template => 'critical: %d',
                perfdatas => [
                    { value => 'critical', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'alerts-warning', nlabel => 'alerts.severity.warning.count', set => {
                key_values => [ { name => 'warning' } ],
                output_template => 'warning: %d',
                perfdatas => [
                    { value => 'warning', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'alerts-ok', nlabel => 'alerts.severity.ok.count', display_ok => 0, set => {
                key_values => [ { name => 'ok' } ],
                output_template => 'ok: %d',
                perfdatas => [
                    { value => 'ok', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'alerts-info', nlabel => 'alerts.severity.info.count', display_ok => 0, set => {
                key_values => [ { name => 'info' } ],
                output_template => 'info: %d',
                perfdatas => [
                    { value => 'info', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'alerts-unknown', nlabel => 'alerts.severity.unknown.count', display_ok => 0, set => {
                key_values => [ { name => 'unknown' } ],
                output_template => 'unknown: %d',
                perfdatas => [
                    { value => 'unknown', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'alerts-disabled', nlabel => 'alerts.severity.disabled.count', display_ok => 0, set => {
                key_values => [ { name => 'disabled' } ],
                output_template => 'disabled: %d',
                perfdatas => [
                    { value => 'disabled', template => '%d', min => 0 },
                ],
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-state:s'    => { name => 'filter_state', default => 'Active' },
        'filter-resource:s' => { name => 'filter_resource' },
        'filter-severity:s' => { name => 'filter_severity' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $url_path = '/rest/alerts?start=0&count=-1';
    if (defined($self->{option_results}->{filter_state}) && $self->{option_results}->{filter_state} ne '') {
        $url_path = "/rest/alerts?filter=alertState='" . $self->{option_results}->{filter_state} . "'&start=0&count=-1";
    }

    my $results = $options{custom}->request_api(url_path => $url_path);

    $self->{global} = {
        total    => 0,
        critical => 0,
        warning  => 0,
        ok       => 0,
        info     => 0,
        unknown  => 0,
        disabled => 0,
    };

    foreach my $alert (@{$results->{members}}) {
        if (defined($self->{option_results}->{filter_resource}) && $self->{option_results}->{filter_resource} ne '' &&
            defined($alert->{resourceName}) &&
            $alert->{resourceName} !~ /$self->{option_results}->{filter_resource}/) {
            next;
        }

        my $severity = lc($alert->{severity});
        if (defined($self->{option_results}->{filter_severity}) && $self->{option_results}->{filter_severity} ne '' &&
            $severity !~ /$self->{option_results}->{filter_severity}/i) {
            next;
        }

        $self->{global}->{total}++;
        $self->{global}->{$severity}++ if (exists $self->{global}->{$severity});

        $self->{output}->output_add(
            long_msg => sprintf(
                "alert [resource: %s] [severity: %s] [state: %s] %s",
                defined($alert->{resourceName}) ? $alert->{resourceName} : 'n/a',
                $severity,
                defined($alert->{alertState}) ? $alert->{alertState} : 'n/a',
                defined($alert->{description}) ? $alert->{description} : '',
            )
        );
    }
}

1;

__END__

=head1 MODE

Check HPE OneView alerts count by severity.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='critical'

=item B<--filter-state>

Filter alerts by state (default: 'Active').
Possible values: Active, Cleared, Locked.
Use empty string to retrieve all alerts: --filter-state=''

=item B<--filter-resource>

Filter alerts by resource name (can be a regexp).

=item B<--filter-severity>

Filter alerts by severity before counting (can be a regexp).
Example: --filter-severity='critical|warning'

=item B<--warning-alerts-total>

Warning threshold for total number of alerts.

=item B<--critical-alerts-total>

Critical threshold for total number of alerts.

=item B<--warning-alerts-critical>

Warning threshold for number of critical severity alerts.

=item B<--critical-alerts-critical>

Critical threshold for number of critical severity alerts.

=item B<--warning-alerts-warning>

Warning threshold for number of warning severity alerts.

=item B<--critical-alerts-warning>

Critical threshold for number of warning severity alerts.

=item B<--warning-alerts-ok>

Warning threshold for number of ok severity alerts.

=item B<--critical-alerts-ok>

Critical threshold for number of ok severity alerts.

=item B<--warning-alerts-info>

Warning threshold for number of info severity alerts.

=item B<--critical-alerts-info>

Critical threshold for number of info severity alerts.

=item B<--warning-alerts-unknown>

Warning threshold for number of unknown severity alerts.

=item B<--critical-alerts-unknown>

Critical threshold for number of unknown severity alerts.

=item B<--warning-alerts-disabled>

Warning threshold for number of disabled severity alerts.

=item B<--critical-alerts-disabled>

Critical threshold for number of disabled severity alerts.

=back

=cut
