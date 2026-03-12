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

package network::paloalto::snmp::mode::interfaceutilization;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_interface_output {
    my ($self, %options) = @_;
    return "Interface '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'interfaces', type => 1, cb_prefix_output => 'prefix_interface_output',
          message_multiple => 'All interface utilization metrics are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{interfaces} = [
        { label => 'in-octets', nlabel => 'interface.utilization.in.bytespersecond', set => {
                key_values => [ { name => 'in_octets' }, { name => 'display' } ],
                output_template => 'In: %s B/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'out-octets', nlabel => 'interface.utilization.out.bytespersecond', set => {
                key_values => [ { name => 'out_octets' }, { name => 'display' } ],
                output_template => 'Out: %s B/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'in-unicast-pkts', nlabel => 'interface.utilization.in.unicast.packetspersecond', display_ok => 0, set => {
                key_values => [ { name => 'in_ucast_pkts' }, { name => 'display' } ],
                output_template => 'In Unicast: %s pkt/s',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'pkt/s', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'out-unicast-pkts', nlabel => 'interface.utilization.out.unicast.packetspersecond', display_ok => 0, set => {
                key_values => [ { name => 'out_ucast_pkts' }, { name => 'display' } ],
                output_template => 'Out Unicast: %s pkt/s',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'pkt/s', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'in-multicast-pkts', nlabel => 'interface.utilization.in.multicast.packetspersecond', display_ok => 0, set => {
                key_values => [ { name => 'in_mcast_pkts' }, { name => 'display' } ],
                output_template => 'In Multicast: %s pkt/s',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'pkt/s', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'out-multicast-pkts', nlabel => 'interface.utilization.out.multicast.packetspersecond', display_ok => 0, set => {
                key_values => [ { name => 'out_mcast_pkts' }, { name => 'display' } ],
                output_template => 'Out Multicast: %s pkt/s',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'pkt/s', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'in-broadcast-pkts', nlabel => 'interface.utilization.in.broadcast.packetspersecond', display_ok => 0, set => {
                key_values => [ { name => 'in_bcast_pkts' }, { name => 'display' } ],
                output_template => 'In Broadcast: %s pkt/s',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'pkt/s', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'out-broadcast-pkts', nlabel => 'interface.utilization.out.broadcast.packetspersecond', display_ok => 0, set => {
                key_values => [ { name => 'out_bcast_pkts' }, { name => 'display' } ],
                output_template => 'Out Broadcast: %s pkt/s',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'pkt/s', label_extra_instance => 1 }
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
        'filter-interface-name:s' => { name => 'filter_interface_name' },
        'use-hc'                  => { name => 'use_hc' }
    });

    return $self;
}

# panInterfaceUtilization = .1.3.6.1.4.1.25461.2.1.2.14
my $mapping_32 = {
    display        => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.2' },  # ifName
    in_octets      => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.3' },  # ifInOctetsUtilization
    in_ucast_pkts  => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.4' },  # ifInUcastPktsUtilization
    out_octets     => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.5' },  # ifOutOctetsUtilization
    out_ucast_pkts => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.6' },  # ifOutUcastPktsUtilization
    in_mcast_pkts  => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.7' },  # ifInMulticastPktsUtilization
    in_bcast_pkts  => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.8' },  # ifInBroadcastPktsUtilization
    out_mcast_pkts => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.9' },  # ifOutMulticastPktsUtilization
    out_bcast_pkts => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.10' }  # ifOutBroadcastPktsUtilization
};

my $mapping_hc = {
    display        => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.2' },  # ifName
    in_octets      => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.11' }, # ifHCInOctetsUtilization
    in_ucast_pkts  => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.12' }, # ifHCInUcastPktsUtilization
    out_octets     => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.13' }, # ifHCOutOctetsUtilization
    out_ucast_pkts => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.14' }, # ifHCOutUcastPktsUtilization
    in_mcast_pkts  => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.15' }, # ifHCInMulticastPktsUtilization
    in_bcast_pkts  => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.16' }, # ifHCInBroadcastPktsUtilization
    out_mcast_pkts => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.17' }, # ifHCOutMulticastPktsUtilization
    out_bcast_pkts => { oid => '.1.3.6.1.4.1.25461.2.1.2.14.1.1.18' }  # ifHCOutBroadcastPktsUtilization
};

sub manage_selection {
    my ($self, %options) = @_;

    my $oid_table = '.1.3.6.1.4.1.25461.2.1.2.14.1.1';
    my $snmp_result = $options{snmp}->get_table(
        oid => $oid_table,
        nothing_quit => 1
    );

    my $mapping = defined($self->{option_results}->{use_hc}) ? $mapping_hc : $mapping_32;

    $self->{interfaces} = {};
    foreach my $oid (keys %$snmp_result) {
        next if ($oid !~ /^$mapping->{display}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => $instance);

        if (defined($self->{option_results}->{filter_interface_name}) && $self->{option_results}->{filter_interface_name} ne '' &&
            $result->{display} !~ /$self->{option_results}->{filter_interface_name}/) {
            $self->{output}->output_add(long_msg => "skipping interface '" . $result->{display} . "'.", debug => 1);
            next;
        }

        $self->{interfaces}->{$result->{display}} = $result;
    }

    if (scalar(keys %{$self->{interfaces}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No interfaces found (PAN-OS 12.1+ required for panInterfaceUtilization).');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check interface bandwidth utilization using PAN-OS native pre-calculated rates
(panInterfaceUtilization table, available from PAN-OS 12.1+).

No delta/cache needed - PAN-OS provides real-time bytes/sec and packets/sec values.

=over 8

=item B<--filter-interface-name>

Filter interfaces by name (can be a regexp).

=item B<--use-hc>

Use 64-bit high-capacity counters (recommended for 10G+ interfaces).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'in-octets' (B/s), 'out-octets' (B/s), 'in-unicast-pkts' (pkt/s),
'out-unicast-pkts' (pkt/s), 'in-multicast-pkts', 'out-multicast-pkts',
'in-broadcast-pkts', 'out-broadcast-pkts'.

=back

=cut
