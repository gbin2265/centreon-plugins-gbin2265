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

package apps::backup::commvault::commserve::restapi::mode::agentstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf(
        'status: %s [installed: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{installed}
    );
}

sub prefix_agent_output {
    my ($self, %options) = @_;
    return "Client '" . $options{instance_value}->{client_name} . "' agent '" . $options{instance_value}->{display} . "' ";
}

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Agents ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'agents', type => 1, cb_prefix_output => 'prefix_agent_output', message_multiple => 'All agents are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'agents-total', nlabel => 'agents.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'agents-online', nlabel => 'agents.online.count', display_ok => 0, set => {
                key_values => [ { name => 'online' }, { name => 'total' } ],
                output_template => 'online: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        },
        { label => 'agents-offline', nlabel => 'agents.offline.count', display_ok => 0, set => {
                key_values => [ { name => 'offline' }, { name => 'total' } ],
                output_template => 'offline: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        }
    ];

    $self->{maps_counters}->{agents} = [
        {
            label => 'status', type => 2,
            critical_default => '%{status} =~ /offline/i',
            set => {
                key_values => [
                    { name => 'display' }, { name => 'agent_id' },
                    { name => 'client_name' }, { name => 'client_id' },
                    { name => 'status' }, { name => 'installed' }
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
        'filter-client-name:s' => { name => 'filter_client_name' },
        'filter-agent-name:s'  => { name => 'filter_agent_name' }
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

    $self->{global} = { total => 0, online => 0, offline => 0 };
    $self->{agents} = {};

    # Step 2: per client, fetch /Agent?clientId=X
    foreach my $client (@client_list) {
        $self->{output}->output_add(
            long_msg => "Fetching agents for client '" . $client->{name} . "' (id: " . $client->{id} . ")",
            debug => 1
        );

        my $agent_result;
        eval {
            $agent_result = $options{custom}->request_internal(
                endpoint => '/Agent',
                get_param => [ 'clientId=' . $client->{id} ]
            );
        };
        if ($@) {
            $self->{output}->output_add(
                long_msg => "Could not fetch agents for client '" . $client->{name} . "': " . $@,
                debug => 1
            );
            next;
        }

        my $entries = $agent_result->{agentProperties} // [];
        foreach my $entry (@{$entries}) {
            my $ida = $entry->{idaEntity} // {};
            my $agent_name = $ida->{appName}       // '';
            my $agent_id   = $ida->{applicationId} // $ida->{appId} // '';
            next if ($agent_name eq '');

            if (defined($self->{option_results}->{filter_agent_name}) && $self->{option_results}->{filter_agent_name} ne '' &&
                $agent_name !~ /$self->{option_results}->{filter_agent_name}/) {
                next;
            }

            my $status = 'online';
            if (defined($entry->{idaStatus})) {
                # 0 = not installed, 1 = installed/online, 2 = deconfigured
                if ($entry->{idaStatus} == 0) {
                    $status = 'not_installed';
                } elsif ($entry->{idaStatus} == 2) {
                    $status = 'deconfigured';
                }
            }

            my $installed = 'yes';
            if (defined($entry->{idaStatus}) && $entry->{idaStatus} == 0) {
                $installed = 'no';
            }

            # Check activity control
            if (defined($entry->{idaActivityControl})) {
                my $ac = $entry->{idaActivityControl};
                if (ref($ac) eq 'HASH' && defined($ac->{activityControlOptions})) {
                    my $opts = $ac->{activityControlOptions};
                    $opts = [$opts] if (ref($opts) eq 'HASH');
                    foreach my $opt (@{$opts}) {
                        if (defined($opt->{activityType}) && defined($opt->{enableActivityType})) {
                            if (!$opt->{enableActivityType}) {
                                $status = 'offline';
                            }
                        }
                    }
                }
            }

            my $key = $client->{name} . '/' . $agent_name;
            $self->{agents}->{$key} = {
                display     => $agent_name,
                agent_id    => $agent_id,
                client_name => $client->{name},
                client_id   => $client->{id},
                status      => $status,
                installed   => $installed
            };

            my $counted_status = ($status eq 'online') ? 'online' : 'offline';
            $self->{global}->{$counted_status}++;
            $self->{global}->{total}++;
        }
    }

    if (scalar(keys %{$self->{agents}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No agents found");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check agent status per client.

Fetches the client list via /Client, then for each client retrieves agents
via /Agent?clientId=X. The curl backend reuses the TCP+SSL connection.

Possible agent status values: 'online', 'offline', 'not_installed', 'deconfigured'.
By default only 'offline' triggers CRITICAL. Agents that are 'not_installed' or
'deconfigured' do not trigger alerts unless you override --critical-status or
--warning-status (e.g. --warning-status='%{status} !~ /online/i').

For the global counters, any status other than 'online' is counted as 'offline'.

=over 8

=item B<--filter-client-name>

Filter by client name (can be a regexp).

=item B<--filter-agent-name>

Filter by agent name (can be a regexp, e.g. 'File System', 'SQL Server', 'Oracle').

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{display}, %{agent_id}, %{client_name}, %{client_id}, %{status}, %{installed}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} =~ /offline/i').
You can use the following variables: %{display}, %{agent_id}, %{client_name}, %{client_id}, %{status}, %{installed}

=item B<--warning-agents-total>

Thresholds.

=item B<--critical-agents-total>

Thresholds.

=item B<--warning-agents-online>

Thresholds.

=item B<--critical-agents-online>

Thresholds.

=item B<--warning-agents-offline>

Thresholds.

=item B<--critical-agents-offline>

Thresholds.

=back

=cut
