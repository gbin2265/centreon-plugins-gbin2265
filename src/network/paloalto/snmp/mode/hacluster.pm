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

package network::paloalto::snmp::mode::hacluster;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_device_output {
    my ($self, %options) = @_;
    return sprintf(
        "Device '%s' [%s] - HA mode '%s' [local: %s] [peer: %s]",
        $self->{result_values}->{hostname},
        $self->{result_values}->{serial},
        $self->{result_values}->{ha_mode},
        $self->{result_values}->{ha_state},
        $self->{result_values}->{ha_peer_state}
    );
}

sub custom_cache_output {
    my ($self, %options) = @_;
    return sprintf(
        'cache: %s / %s (%.1f%%)',
        $self->{result_values}->{cache_current},
        $self->{result_values}->{cache_max},
        $self->{result_values}->{cache_max} > 0 ?
            $self->{result_values}->{cache_current} * 100 / $self->{result_values}->{cache_max} : 0
    );
}

sub custom_table_output {
    my ($self, %options) = @_;
    return sprintf(
        'table active: %s / %s (%.1f%%)',
        $self->{result_values}->{table_active},
        $self->{result_values}->{table_max},
        $self->{result_values}->{table_max} > 0 ?
            $self->{result_values}->{table_active} * 100 / $self->{result_values}->{table_max} : 0
    );
}

sub prefix_local_output {
    my ($self, %options) = @_;
    return "Local node '" . $options{instance_value}->{display} . "' ";
}

sub prefix_remote_output {
    my ($self, %options) = @_;
    return "Remote node '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'device_info', type => 0, skipped_code => { -10 => 1 } },
        { name => 'local', type => 1, cb_prefix_output => 'prefix_local_output', message_multiple => 'All local HA nodes are ok', skipped_code => { -10 => 1 } },
        { name => 'remote', type => 1, cb_prefix_output => 'prefix_remote_output', message_multiple => 'All remote HA nodes are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{device_info} = [
        { label => 'device-status', threshold => 0, set => {
                key_values => [
                    { name => 'hostname' }, { name => 'serial' },
                    { name => 'ha_mode' }, { name => 'ha_state' },
                    { name => 'ha_peer_state' }
                ],
                closure_custom_output => $self->can('custom_device_output'),
                closure_custom_perfdata => sub { return 0; }
            }
        }
    ];

    $self->{maps_counters}->{local} = [
        { label => 'local-cache-usage', nlabel => 'hacluster.local.cache.usage.count', set => {
                key_values => [ { name => 'cache_current' }, { name => 'cache_max' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_cache_output'),
                perfdatas => [
                    { template => '%s', min => 0, max => 'cache_max', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'local-table-active', nlabel => 'hacluster.local.table.active.count', set => {
                key_values => [ { name => 'table_active' }, { name => 'table_max' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_table_output'),
                perfdatas => [
                    { template => '%s', min => 0, max => 'table_max', label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{remote} = [
        { label => 'remote-cache-current', nlabel => 'hacluster.remote.cache.current.count', set => {
                key_values => [ { name => 'cache_current' }, { name => 'display' } ],
                output_template => 'current sessions: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'remote-promoted-current', nlabel => 'hacluster.remote.promoted.current.count', set => {
                key_values => [ { name => 'promoted_current' }, { name => 'display' } ],
                output_template => 'promoted sessions: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {});
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # Device identity
    my $oid_sysName       = '.1.3.6.1.2.1.1.5.0';
    my $oid_serial        = '.1.3.6.1.4.1.25461.2.1.2.1.3.0';  # panSysSerialNumber
    my $oid_ha_state      = '.1.3.6.1.4.1.25461.2.1.2.1.11.0'; # panSysHAState
    my $oid_ha_peer_state = '.1.3.6.1.4.1.25461.2.1.2.1.12.0'; # panSysHAPeerState
    my $oid_ha_mode       = '.1.3.6.1.4.1.25461.2.1.2.1.13.0'; # panSysHAMode

    my $snmp_device = $options{snmp}->get_leef(
        oids => [$oid_sysName, $oid_serial, $oid_ha_state, $oid_ha_peer_state, $oid_ha_mode]
    );

    $self->{device_info} = {
        hostname      => defined($snmp_device->{$oid_sysName}) ? $snmp_device->{$oid_sysName} : 'unknown',
        serial        => defined($snmp_device->{$oid_serial}) ? $snmp_device->{$oid_serial} : 'unknown',
        ha_mode       => defined($snmp_device->{$oid_ha_mode}) ? $snmp_device->{$oid_ha_mode} : 'unknown',
        ha_state      => defined($snmp_device->{$oid_ha_state}) ? $snmp_device->{$oid_ha_state} : 'unknown',
        ha_peer_state => defined($snmp_device->{$oid_ha_peer_state}) ? $snmp_device->{$oid_ha_peer_state} : 'unknown'
    };

    # panHACluster = .1.3.6.1.4.1.25461.2.1.2.9
    my $oid_local_table  = '.1.3.6.1.4.1.25461.2.1.2.9.1'; # panHAClusterLocalSessStatsTable
    my $oid_remote_table = '.1.3.6.1.4.1.25461.2.1.2.9.2'; # panHAClusterSessStatsTable

    my $snmp_local = $options{snmp}->get_table(oid => $oid_local_table);
    my $snmp_remote = $options{snmp}->get_table(oid => $oid_remote_table);

    my $mapping_local = {
        display       => { oid => '.1.3.6.1.4.1.25461.2.1.2.9.1.1.2' }, # serialNumber
        cache_current => { oid => '.1.3.6.1.4.1.25461.2.1.2.9.1.1.3' }, # cacheCurrentTotal
        cache_max     => { oid => '.1.3.6.1.4.1.25461.2.1.2.9.1.1.4' }, # cacheMax
        table_active  => { oid => '.1.3.6.1.4.1.25461.2.1.2.9.1.1.5' }, # tableActive
        table_max     => { oid => '.1.3.6.1.4.1.25461.2.1.2.9.1.1.6' }  # tableMax
    };

    my $mapping_remote = {
        display          => { oid => '.1.3.6.1.4.1.25461.2.1.2.9.2.1.2' }, # serialNumber
        cache_current    => { oid => '.1.3.6.1.4.1.25461.2.1.2.9.2.1.3' }, # cacheCurrent
        promoted_current => { oid => '.1.3.6.1.4.1.25461.2.1.2.9.2.1.5' }  # cacheCurrentPromoted
    };

    $self->{local} = {};
    if (defined($snmp_local) && scalar(keys %$snmp_local) > 0) {
        foreach my $oid (keys %$snmp_local) {
            next if ($oid !~ /^$mapping_local->{display}->{oid}\.(.*)$/);
            my $instance = $1;
            my $result = $options{snmp}->map_instance(mapping => $mapping_local, results => $snmp_local, instance => $instance);
            $self->{local}->{$result->{display}} = $result;
        }
    }

    $self->{remote} = {};
    if (defined($snmp_remote) && scalar(keys %$snmp_remote) > 0) {
        foreach my $oid (keys %$snmp_remote) {
            next if ($oid !~ /^$mapping_remote->{display}->{oid}\.(.*)$/);
            my $instance = $1;
            my $result = $options{snmp}->map_instance(mapping => $mapping_remote, results => $snmp_remote, instance => $instance);
            $self->{remote}->{$result->{display}} = $result;
        }
    }

    if (scalar(keys %{$self->{local}}) <= 0 && scalar(keys %{$self->{remote}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No HA cluster data found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HA cluster session statistics (panHACluster).
Monitors local session cache/table usage and remote node sessions.

=over 8

=item B<--warning-*> B<--critical-*>

Thresholds.
Local: 'local-cache-usage', 'local-table-active'.
Remote: 'remote-cache-current', 'remote-promoted-current'.

=back

=cut
