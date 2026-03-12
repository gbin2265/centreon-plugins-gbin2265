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

package network::paloalto::snmp::mode::pacluster;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

my $map_node_status = {
    0 => 'unknown', 1 => 'init', 2 => 'online',
    3 => 'degraded', 4 => 'failed', 5 => 'suspended'
};

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf(
        "status: %s, mode: %s, serial: %s",
        $self->{result_values}->{node_status},
        $self->{result_values}->{mode},
        $self->{result_values}->{serial}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'cluster', type => 0, skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{cluster} = [
        { label => 'node-status', threshold => 0, set => {
                key_values => [ { name => 'node_status' }, { name => 'mode' }, { name => 'serial' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'throughput', nlabel => 'cluster.throughput.bitspersecond', set => {
                key_values => [ { name => 'throughput' } ],
                output_template => 'throughput: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'connections-per-sec', nlabel => 'cluster.connections.persecond.count', set => {
                key_values => [ { name => 'conn_per_sec' } ],
                output_template => 'connections/s: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'cluster-sessions', nlabel => 'cluster.sessions.active.count', set => {
                key_values => [ { name => 'sessions' } ],
                output_template => 'sessions: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'logs-per-sec', nlabel => 'cluster.logs.persecond.count', set => {
                key_values => [ { name => 'lps' } ],
                output_template => 'logs/s: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'local-sessions-active', nlabel => 'cluster.local.sessions.active.count', set => {
                key_values => [ { name => 'local_active' }, { name => 'local_max' } ],
                output_template => 'local sessions active: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'local_max' } ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'warning-node-status:s'  => { name => 'warning_node_status', default => '%{node_status} =~ /degraded/i' },
        'critical-node-status:s' => { name => 'critical_node_status', default => '%{node_status} =~ /failed|suspended/i' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => ['warning_node_status', 'critical_node_status']);
}

# panpaCluster = .1.3.6.1.4.1.25461.2.1.2.13
my $mapping = {
    mode         => { oid => '.1.3.6.1.4.1.25461.2.1.2.13.2' },  # panPAClusterSummaryEntrymode
    serial       => { oid => '.1.3.6.1.4.1.25461.2.1.2.13.3' },  # panPAClusterSummaryEntrySerialNumber
    node_status  => { oid => '.1.3.6.1.4.1.25461.2.1.2.13.4', map => $map_node_status },
    throughput   => { oid => '.1.3.6.1.4.1.25461.2.1.2.13.5' },  # panPAClusterUtilizationEntrythroughput
    conn_per_sec => { oid => '.1.3.6.1.4.1.25461.2.1.2.13.6' },  # panPAClusterUtilizationEntryconnPerSec
    sessions     => { oid => '.1.3.6.1.4.1.25461.2.1.2.13.7' },  # panPAClusterUtilizationEntrysessions
    lps          => { oid => '.1.3.6.1.4.1.25461.2.1.2.13.8' },  # panPAClusterUtilizationEntryLPS
    local_active => { oid => '.1.3.6.1.4.1.25461.2.1.2.13.9' },  # panPAClusterLocalSessStatsEntryActive
    local_max    => { oid => '.1.3.6.1.4.1.25461.2.1.2.13.10' }  # panPAClusterLocalSessStatsEntryMax
};

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [ map($_->{oid} . '.0', values(%$mapping)) ],
        nothing_quit => 1
    );
    $self->{cluster} = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');
}

1;

__END__

=head1 MODE

Check PA cluster status and utilization (panpaCluster).
Monitors node status, throughput, CPS, sessions, and logs per second.
Available on PA-7000 series and similar BB cluster configurations.

=over 8

=item B<--warning-node-status>

Define the conditions to match for the status to be WARNING (default: '%{node_status} =~ /degraded/i').
You can use the following variables: %{node_status}, %{mode}, %{serial}

=item B<--critical-node-status>

Define the conditions to match for the status to be CRITICAL (default: '%{node_status} =~ /failed|suspended/i').
You can use the following variables: %{node_status}, %{mode}, %{serial}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'throughput', 'connections-per-sec', 'cluster-sessions', 'logs-per-sec', 'local-sessions-active'.

=back

=cut
