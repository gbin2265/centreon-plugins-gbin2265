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

package apps::backup::commvault::commserve::restapi::mode::commcellinfo;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf(
        'status: %s [version: %s SP%s][clients: %s][media agents: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{version},
        $self->{result_values}->{service_pack},
        $self->{result_values}->{registered_clients},
        $self->{result_values}->{registered_media_agents}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'commcell', type => 0 }
    ];

    $self->{maps_counters}->{commcell} = [
        {
            label => 'status', type => 2,
            set => {
                key_values => [
                    { name => 'status' }, { name => 'version' },
                    { name => 'service_pack' }, { name => 'hostname' },
                    { name => 'registered_clients' }, { name => 'registered_media_agents' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'registered-clients', nlabel => 'commcell.clients.registered.count', set => {
                key_values => [ { name => 'registered_clients' } ],
                output_template => 'registered clients: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'registered-media-agents', nlabel => 'commcell.mediaagents.registered.count', set => {
                key_values => [ { name => 'registered_media_agents' } ],
                output_template => 'registered media agents: %s',
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

    my $results = $options{custom}->request_internal(
        endpoint => '/CommServ'
    );

    my $commcell = $results->{commcell} // $results->{commCell} // {};
    my $cs_info  = $results->{csInfo}   // {};

    my $hostname    = $commcell->{commCellName} // $commcell->{csHostName} // '-';
    my $version     = '-';
    my $sp          = '-';
    my $clients     = 0;
    my $media_agents = 0;

    if (defined($cs_info->{versionInfo})) {
        $version = $cs_info->{versionInfo}->{version}     // $version;
        $sp      = $cs_info->{versionInfo}->{servicePack} // $sp;
    }
    if (defined($results->{csVersion})) {
        $version = $results->{csVersion} // $version;
    }
    if (defined($results->{csSPVersion})) {
        $sp = $results->{csSPVersion} // $sp;
    }
    if (defined($results->{registeredClients})) {
        $clients = $results->{registeredClients};
    }
    if (defined($results->{registeredMediaAgents})) {
        $media_agents = $results->{registeredMediaAgents};
    }

    # Derive status from the API response: if we got a hostname and a version,
    # the CommServe is reachable and considered online.  If critical fields are
    # missing the response is likely incomplete → degraded.
    my $status = 'online';
    if ($hostname eq '-' && $version eq '-') {
        $status = 'degraded';
    }

    $self->{commcell} = {
        status                  => $status,
        hostname                => $hostname,
        version                 => $version,
        service_pack            => $sp,
        registered_clients      => $clients,
        registered_media_agents => $media_agents
    };
}

1;

__END__

=head1 MODE

Check CommCell / CommServe information and status.

Status is derived from the API response: if the CommServe returns a valid
hostname and version, the status is 'online'. If critical fields are missing,
the status is 'degraded'.

=over 8

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{version}, %{service_pack}, %{hostname}, %{registered_clients}, %{registered_media_agents}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{status}, %{version}, %{service_pack}, %{hostname}, %{registered_clients}, %{registered_media_agents}

=item B<--warning-registered-clients>

Warning threshold for the number of registered clients.

=item B<--critical-registered-clients>

Critical threshold for the number of registered clients.

=item B<--warning-registered-media-agents>

Warning threshold for the number of registered media agents.

=item B<--critical-registered-media-agents>

Critical threshold for the number of registered media agents.

=back

=cut
