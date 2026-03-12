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

package network::paloalto::snmp::mode::cps;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Global ';
}

sub prefix_zone_output {
    my ($self, %options) = @_;
    return "Zone '" . $options{instance_value}->{display} . "' ";
}

sub prefix_interface_output {
    my ($self, %options) = @_;
    return "Interface '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'zone', type => 1, cb_prefix_output => 'prefix_zone_output', message_multiple => 'All zone CPS metrics are ok', skipped_code => { -10 => 1 } },
        { name => 'interface', type => 1, cb_prefix_output => 'prefix_interface_output', message_multiple => 'All interface CPS metrics are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'total-cps', nlabel => 'connections.persecond.count', set => {
                key_values => [ { name => 'cps' } ],
                output_template => 'connections per second: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{zone} = [
        { label => 'zone-tcp-cps', nlabel => 'zone.connections.tcp.persecond.count', set => {
                key_values => [ { name => 'tcp_cps' }, { name => 'display' } ],
                output_template => 'TCP CPS: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'zone-udp-cps', nlabel => 'zone.connections.udp.persecond.count', set => {
                key_values => [ { name => 'udp_cps' }, { name => 'display' } ],
                output_template => 'UDP CPS: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'zone-other-cps', nlabel => 'zone.connections.other.persecond.count', set => {
                key_values => [ { name => 'other_cps' }, { name => 'display' } ],
                output_template => 'Other CPS: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{interface} = [
        { label => 'interface-tcp-cps', nlabel => 'interface.connections.tcp.persecond.count', set => {
                key_values => [ { name => 'tcp_cps' }, { name => 'display' } ],
                output_template => 'TCP CPS: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'interface-udp-cps', nlabel => 'interface.connections.udp.persecond.count', set => {
                key_values => [ { name => 'udp_cps' }, { name => 'display' } ],
                output_template => 'UDP CPS: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'interface-other-cps', nlabel => 'interface.connections.other.persecond.count', set => {
                key_values => [ { name => 'other_cps' }, { name => 'display' } ],
                output_template => 'Other CPS: %s',
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

    $options{options}->add_options(arguments => {
        'add-zones'              => { name => 'add_zones' },
        'add-interfaces'         => { name => 'add_interfaces' },
        'filter-zone-name:s'     => { name => 'filter_zone_name' },
        'filter-interface-name:s' => { name => 'filter_interface_name' }
    });

    return $self;
}

my $mapping_zone = {
    display   => { oid => '.1.3.6.1.4.1.25461.2.1.2.3.10.1.1' }, # panZoneName
    tcp_cps   => { oid => '.1.3.6.1.4.1.25461.2.1.2.3.10.1.2' }, # panZoneActiveTcpCps
    udp_cps   => { oid => '.1.3.6.1.4.1.25461.2.1.2.3.10.1.3' }, # panZoneActiveUdpCps
    other_cps => { oid => '.1.3.6.1.4.1.25461.2.1.2.3.10.1.4' }  # panZoneActiveOtherIpCps
};

my $mapping_if = {
    display   => { oid => '.1.3.6.1.4.1.25461.2.1.2.3.11.1.2' }, # panIfDescr
    tcp_cps   => { oid => '.1.3.6.1.4.1.25461.2.1.2.3.11.1.3' }, # panIfActiveTcpCps
    udp_cps   => { oid => '.1.3.6.1.4.1.25461.2.1.2.3.11.1.4' }, # panIfActiveUdpCps
    other_cps => { oid => '.1.3.6.1.4.1.25461.2.1.2.3.11.1.5' }  # panIfActiveOtherIpCps
};

sub manage_selection {
    my ($self, %options) = @_;

    my $oid_panSessionCps = '.1.3.6.1.4.1.25461.2.1.2.3.12.0';
    my $snmp_result = $options{snmp}->get_leef(
        oids => [$oid_panSessionCps],
        nothing_quit => 1
    );
    $self->{global} = { cps => $snmp_result->{$oid_panSessionCps} };

    if (defined($self->{option_results}->{add_zones})) {
        my $oid_panZoneTable = '.1.3.6.1.4.1.25461.2.1.2.3.10.1';
        $snmp_result = $options{snmp}->get_table(oid => $oid_panZoneTable);

        $self->{zone} = {};
        foreach my $oid (keys %$snmp_result) {
            next if ($oid !~ /^$mapping_zone->{display}->{oid}\.(.*)$/);
            my $instance = $1;
            my $result = $options{snmp}->map_instance(mapping => $mapping_zone, results => $snmp_result, instance => $instance);
            if (defined($self->{option_results}->{filter_zone_name}) && $self->{option_results}->{filter_zone_name} ne '' &&
                $result->{display} !~ /$self->{option_results}->{filter_zone_name}/) {
                $self->{output}->output_add(long_msg => "skipping zone '" . $result->{display} . "'.", debug => 1);
                next;
            }
            $self->{zone}->{$result->{display}} = $result;
        }
    }

    if (defined($self->{option_results}->{add_interfaces})) {
        my $oid_panIfTable = '.1.3.6.1.4.1.25461.2.1.2.3.11.1';
        $snmp_result = $options{snmp}->get_table(oid => $oid_panIfTable);

        $self->{interface} = {};
        foreach my $oid (keys %$snmp_result) {
            next if ($oid !~ /^$mapping_if->{display}->{oid}\.(.*)$/);
            my $instance = $1;
            my $result = $options{snmp}->map_instance(mapping => $mapping_if, results => $snmp_result, instance => $instance);
            if (defined($self->{option_results}->{filter_interface_name}) && $self->{option_results}->{filter_interface_name} ne '' &&
                $result->{display} !~ /$self->{option_results}->{filter_interface_name}/) {
                $self->{output}->output_add(long_msg => "skipping interface '" . $result->{display} . "'.", debug => 1);
                next;
            }
            $self->{interface}->{$result->{display}} = $result;
        }
    }
}

1;

__END__

=head1 MODE

Check connections per second (global, per zone, per interface).

=over 8

=item B<--add-zones>

Monitor per-zone CPS statistics.

=item B<--add-interfaces>

Monitor per-interface CPS statistics.

=item B<--filter-zone-name>

Filter zones by name (can be a regexp).

=item B<--filter-interface-name>

Filter interfaces by name (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds.
Global: 'total-cps'.
Per zone: 'zone-tcp-cps', 'zone-udp-cps', 'zone-other-cps'.
Per interface: 'interface-tcp-cps', 'interface-udp-cps', 'interface-other-cps'.

=back

=cut
