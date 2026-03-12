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

package apps::backup::commvault::commserve::restapi::mode::subclientstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf(
        'backup activity: %s [agent: %s][policy: %s]',
        $self->{result_values}->{activity},
        $self->{result_values}->{agent_name},
        $self->{result_values}->{policy_name}
    );
}

sub prefix_subclient_output {
    my ($self, %options) = @_;
    return "Client '" . $options{instance_value}->{client_name} . "' subclient '" . $options{instance_value}->{display} . "' ";
}

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Subclients ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'subclients', type => 1, cb_prefix_output => 'prefix_subclient_output', message_multiple => 'All subclients are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'subclients-total', nlabel => 'subclients.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'subclients-enabled', nlabel => 'subclients.enabled.count', display_ok => 0, set => {
                key_values => [ { name => 'enabled' }, { name => 'total' } ],
                output_template => 'enabled: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        },
        { label => 'subclients-disabled', nlabel => 'subclients.disabled.count', display_ok => 0, set => {
                key_values => [ { name => 'disabled' }, { name => 'total' } ],
                output_template => 'disabled: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        }
    ];

    $self->{maps_counters}->{subclients} = [
        {
            label => 'status', type => 2,
            warning_default => '%{activity} =~ /disabled/i',
            set => {
                key_values => [
                    { name => 'display' }, { name => 'subclient_id' },
                    { name => 'client_name' }, { name => 'client_id' },
                    { name => 'agent_name' }, { name => 'activity' },
                    { name => 'policy_name' }
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
        'filter-client-name:s'    => { name => 'filter_client_name' },
        'filter-subclient-name:s' => { name => 'filter_subclient_name' },
        'filter-agent-name:s'     => { name => 'filter_agent_name' }
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # Step 1: get client list
    my $clients_result = $options{custom}->request(
        type => 'client',
        endpoint => '/Client'
    );

    my @client_list;
    foreach my $entry (@{$clients_result->{clientProperties} // []}) {
        my $ce = ($entry->{client} // {})->{clientEntity} // {};
        my $cid   = $ce->{clientId}   // '';
        my $cname = $ce->{clientName}  // '';
        next if ($cname eq '' || $cid eq '');

        if (defined($self->{option_results}->{filter_client_name}) && $self->{option_results}->{filter_client_name} ne '' &&
            $cname !~ /$self->{option_results}->{filter_client_name}/) {
            next;
        }
        push @client_list, { id => $cid, name => $cname };
    }

    if (scalar(@client_list) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No clients found (check --filter-client-name)");
        $self->{output}->option_exit();
    }

    $self->{global} = { total => 0, enabled => 0, disabled => 0 };
    $self->{subclients} = {};

    # Step 2: per client, fetch /Subclient?clientId=X
    foreach my $client (@client_list) {
        $self->{output}->output_add(
            long_msg => "Fetching subclients for client '" . $client->{name} . "' (id: " . $client->{id} . ")",
            debug => 1
        );

        my $sc_result;
        eval {
            $sc_result = $options{custom}->request_internal(
                endpoint => '/Subclient',
                get_param => [ 'clientId=' . $client->{id} ]
            );
        };
        if ($@) {
            $self->{output}->output_add(
                long_msg => "Could not fetch subclients for client '" . $client->{name} . "': " . $@,
                debug => 1
            );
            next;
        }

        my $entries = $sc_result->{subClientProperties} // [];
        foreach my $entry (@{$entries}) {
            my $sce = $entry->{subClientEntity} // {};

            my $sc_name    = $sce->{subclientName} // '';
            my $sc_id      = $sce->{subclientId}   // '';
            my $agent_name = $sce->{appName}       // '';
            next if ($sc_name eq '');

            if (defined($self->{option_results}->{filter_subclient_name}) && $self->{option_results}->{filter_subclient_name} ne '' &&
                $sc_name !~ /$self->{option_results}->{filter_subclient_name}/) {
                next;
            }
            if (defined($self->{option_results}->{filter_agent_name}) && $self->{option_results}->{filter_agent_name} ne '' &&
                $agent_name !~ /$self->{option_results}->{filter_agent_name}/) {
                next;
            }

            my $activity = 'enabled';
            my $common_props = $entry->{commonProperties} // {};

            # Check enableBackup flag
            if (defined($common_props->{enableBackup})) {
                $activity = 'disabled' if (!$common_props->{enableBackup});
            }

            # Check activity control
            if (defined($common_props->{activityControl})) {
                my $ac = $common_props->{activityControl};
                if (ref($ac) eq 'HASH') {
                    if (defined($ac->{enableBackup}) && !$ac->{enableBackup}) {
                        $activity = 'disabled';
                    }
                    if (defined($ac->{activityControlOptions})) {
                        my $opts = $ac->{activityControlOptions};
                        $opts = [$opts] if (ref($opts) eq 'HASH');
                        foreach my $opt (@{$opts}) {
                            if (defined($opt->{enableActivityType}) && !$opt->{enableActivityType}) {
                                $activity = 'disabled';
                            }
                        }
                    }
                }
            }

            my $policy_name = '-';
            if (defined($common_props->{storageDevice}) && ref($common_props->{storageDevice}) eq 'HASH') {
                my $sp = $common_props->{storageDevice}->{dataBackupStoragePolicy} // {};
                $policy_name = $sp->{storagePolicyName} // '-';
            }
            if ($policy_name eq '-' && defined($common_props->{planEntity})) {
                $policy_name = $common_props->{planEntity}->{planName} // '-';
            }

            my $key = $client->{name} . '/' . $sc_name . '/' . $agent_name;
            $self->{subclients}->{$key} = {
                display       => $sc_name,
                subclient_id  => $sc_id,
                client_name   => $client->{name},
                client_id     => $client->{id},
                agent_name    => $agent_name,
                activity      => $activity,
                policy_name   => $policy_name
            };

            $self->{global}->{$activity}++ if defined($self->{global}->{$activity});
            $self->{global}->{total}++;
        }
    }

    if (scalar(keys %{$self->{subclients}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No subclients found");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check subclient status.

Fetches the client list via /Client, then for each client retrieves subclients
via /Subclient?clientId=X. The curl backend reuses the TCP+SSL connection.

=over 8

=item B<--filter-client-name>

Filter by client name (can be a regexp).

=item B<--filter-subclient-name>

Filter by subclient name (can be a regexp).

=item B<--filter-agent-name>

Filter by agent/application name (can be a regexp, e.g. 'File System', 'SQL Server').

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{activity} =~ /disabled/i').
You can use the following variables: %{display}, %{subclient_id}, %{client_name}, %{client_id}, %{agent_name}, %{activity}, %{policy_name}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{display}, %{subclient_id}, %{client_name}, %{client_id}, %{agent_name}, %{activity}, %{policy_name}

=item B<--warning-subclients-total>

Thresholds.

=item B<--critical-subclients-total>

Thresholds.

=item B<--warning-subclients-enabled>

Thresholds.

=item B<--critical-subclients-enabled>

Thresholds.

=item B<--warning-subclients-disabled>

Thresholds.

=item B<--critical-subclients-disabled>

Thresholds.

=back

=cut
