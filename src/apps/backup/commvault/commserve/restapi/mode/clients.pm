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

package apps::backup::commvault::commserve::restapi::mode::clients;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'status: %s [activity: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{activity}
    );
}

sub prefix_client_output {
    my ($self, %options) = @_;

    return "Client '" . $options{instance_value}->{name} . "' [id: " . $options{instance_value}->{id} . "] ";
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Clients ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'clients', type => 1, cb_prefix_output => 'prefix_client_output', message_multiple => 'All clients are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'clients-total', nlabel => 'clients.total.count', display_ok => 0, set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'clients-online', nlabel => 'clients.online.count', display_ok => 0, set => {
                key_values => [ { name => 'online' }, { name => 'total' } ],
                output_template => 'online: %s',
                perfdatas => [
                    { template => '%s', min => 0, max => 'total' }
                ]
            }
        },
        { label => 'clients-offline', nlabel => 'clients.offline.count', display_ok => 0, set => {
                key_values => [ { name => 'offline' }, { name => 'total' } ],
                output_template => 'offline: %s',
                perfdatas => [
                    { template => '%s', min => 0, max => 'total' }
                ]
            }
        }
    ];

    $self->{maps_counters}->{clients} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{status} eq "offline"',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'name' },
                    { name => 'id' }, { name => 'activity' },
                    { name => 'hostname' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
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
        'filter-client-id:s'   => { name => 'filter_client_id' },
        'filter-client-name:s' => { name => 'filter_client_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # GET /Client — works on both /webconsole/api and /commandcenter/api
    my $results = $options{custom}->request(
        type => 'client',
        endpoint => '/Client'
    );

    $self->{global} = { total => 0, online => 0, offline => 0 };
    $self->{clients} = {};

    my $entries = $results->{clientProperties};
    if (!defined($entries)) {
        $self->{output}->add_option_msg(short_msg => "No 'clientProperties' key in API response (use --debug to inspect raw response)");
        $self->{output}->option_exit();
    }

    foreach my $entry (@{$entries}) {
        my $client_entity = ($entry->{client} // {})->{clientEntity} // {};

        my $client_id   = $client_entity->{clientId}   // '';
        my $client_name = $client_entity->{clientName}  // '';
        my $hostname    = $client_entity->{hostName}    // '';

        next if ($client_name eq '');

        if (defined($self->{option_results}->{filter_client_id}) && $self->{option_results}->{filter_client_id} ne '' &&
            $client_id !~ /$self->{option_results}->{filter_client_id}/) {
            $self->{output}->output_add(long_msg => "skipping client '" . $client_name . "' (id: " . $client_id . "): no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{filter_client_name}) && $self->{option_results}->{filter_client_name} ne '' &&
            $client_name !~ /$self->{option_results}->{filter_client_name}/) {
            $self->{output}->output_add(long_msg => "skipping client '" . $client_name . "' (id: " . $client_id . "): no matching filter.", debug => 1);
            next;
        }

        my $status = 'online';
        if (defined($entry->{status})) {
            if ($entry->{status} =~ /^\d+$/) {
                $status = $entry->{status} == 0 ? 'online' : 'offline';
            } else {
                $status = lc($entry->{status});
            }
        }

        my $activity = 'enabled';
        my $client_props = $entry->{clientProps} // {};
        if (defined($client_props->{activityControl})) {
            my $ac = $client_props->{activityControl};
            if (defined($ac->{enableBackup})) {
                $activity = $ac->{enableBackup} =~ /True|1/i ? 'enabled' : 'disabled';
            }
            if (defined($ac->{activityControlOptions}) && ref($ac->{activityControlOptions}) eq 'ARRAY') {
                foreach my $opt (@{$ac->{activityControlOptions}}) {
                    if (defined($opt->{activityType}) && $opt->{activityType} == 1) {
                        $activity = (defined($opt->{enableActivityType}) && $opt->{enableActivityType} =~ /True|1/i) ? 'enabled' : 'disabled';
                        last;
                    }
                }
            }
        }

        $self->{clients}->{$client_name} = {
            name     => $client_name,
            id       => $client_id,
            hostname => $hostname,
            status   => $status,
            activity => $activity
        };

        $self->{global}->{$status}++ if defined($self->{global}->{$status});
        $self->{global}->{total}++;
    }

    if (scalar(keys %{$self->{clients}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No client found");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check client status.

Compatible with both /webconsole/api (default) and /commandcenter/api (via --url-path).

=over 8

=item B<--filter-client-id>

Filter clients by ID (can be a regexp).

=item B<--filter-client-name>

Filter clients by name (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{activity}, %{name}, %{id}, %{hostname}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{activity}, %{name}, %{id}, %{hostname}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} eq "offline"').
You can use the following variables: %{status}, %{activity}, %{name}, %{id}, %{hostname}

=item B<--warning-clients-total>

Thresholds.

=item B<--critical-clients-total>

Thresholds.

=item B<--warning-clients-online>

Thresholds.

=item B<--critical-clients-online>

Thresholds.

=item B<--warning-clients-offline>

Thresholds.

=item B<--critical-clients-offline>

Thresholds.

=back

=cut
