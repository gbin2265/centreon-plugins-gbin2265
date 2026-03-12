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

package network::f5::bigip::snmp::mode::vlanstatistics;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_vlan_output {
    my ($self, %options) = @_;

    return "VLAN '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'vlans', type => 1, cb_prefix_output => 'prefix_vlan_output',
          message_multiple => 'All VLANs are ok' }
    ];

    $self->{maps_counters}->{vlans} = [
        { label => 'traffic-in', nlabel => 'vlan.traffic.in.bytespersecond', set => {
                key_values => [ { name => 'bytes_in', diff => 1 }, { name => 'display' } ],
                output_template => 'traffic in: %s %s/s',
                output_change_bytes => 1,
                per_second => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'traffic-out', nlabel => 'vlan.traffic.out.bytespersecond', set => {
                key_values => [ { name => 'bytes_out', diff => 1 }, { name => 'display' } ],
                output_template => 'traffic out: %s %s/s',
                output_change_bytes => 1,
                per_second => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'packets-in', nlabel => 'vlan.packets.in.persecond', display_ok => 0, set => {
                key_values => [ { name => 'pkts_in', diff => 1 }, { name => 'display' } ],
                output_template => 'packets in: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'packets-out', nlabel => 'vlan.packets.out.persecond', display_ok => 0, set => {
                key_values => [ { name => 'pkts_out', diff => 1 }, { name => 'display' } ],
                output_template => 'packets out: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'errors-in', nlabel => 'vlan.errors.in.persecond', set => {
                key_values => [ { name => 'errors_in', diff => 1 }, { name => 'display' } ],
                output_template => 'errors in: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'errors-out', nlabel => 'vlan.errors.out.persecond', set => {
                key_values => [ { name => 'errors_out', diff => 1 }, { name => 'display' } ],
                output_template => 'errors out: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'drops-in', nlabel => 'vlan.drops.in.persecond', set => {
                key_values => [ { name => 'drops_in', diff => 1 }, { name => 'display' } ],
                output_template => 'drops in: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'drops-out', nlabel => 'vlan.drops.out.persecond', set => {
                key_values => [ { name => 'drops_out', diff => 1 }, { name => 'display' } ],
                output_template => 'drops out: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s' => { name => 'filter_name' }
    });

    return $self;
}

# F5-BIGIP-SYSTEM-MIB::sysVlanStatTable
my $mapping = {
    sysVlanStatPktsIn    => { oid => '.1.3.6.1.4.1.3375.2.1.2.13.6.2.1.2' },
    sysVlanStatBytesIn   => { oid => '.1.3.6.1.4.1.3375.2.1.2.13.6.2.1.3' },
    sysVlanStatPktsOut   => { oid => '.1.3.6.1.4.1.3375.2.1.2.13.6.2.1.4' },
    sysVlanStatBytesOut  => { oid => '.1.3.6.1.4.1.3375.2.1.2.13.6.2.1.5' },
    sysVlanStatErrorsIn  => { oid => '.1.3.6.1.4.1.3375.2.1.2.13.6.2.1.8' },
    sysVlanStatErrorsOut => { oid => '.1.3.6.1.4.1.3375.2.1.2.13.6.2.1.9' },
    sysVlanStatDropsIn   => { oid => '.1.3.6.1.4.1.3375.2.1.2.13.6.2.1.10' },
    sysVlanStatDropsOut  => { oid => '.1.3.6.1.4.1.3375.2.1.2.13.6.2.1.11' },
};
my $oid_sysVlanStatEntry = '.1.3.6.1.4.1.3375.2.1.2.13.6.2.1';

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_table(
        oid          => $oid_sysVlanStatEntry,
        nothing_quit => 1
    );

    $self->{vlans} = {};
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result})) {
        next if ($oid !~ /^$mapping->{sysVlanStatPktsIn}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping,
            results  => $snmp_result,
            instance => $instance
        );

        # Decode VLAN name from length-prefixed string index
        my @indexes = split(/\./, $instance);
        my $name_length = shift(@indexes);
        my $name = join('', map(chr($_), splice(@indexes, 0, $name_length)));

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping VLAN '" . $name . "'.", debug => 1);
            next;
        }

        $self->{vlans}->{$name} = {
            display    => $name,
            bytes_in   => $result->{sysVlanStatBytesIn},
            bytes_out  => $result->{sysVlanStatBytesOut},
            pkts_in    => $result->{sysVlanStatPktsIn},
            pkts_out   => $result->{sysVlanStatPktsOut},
            errors_in  => $result->{sysVlanStatErrorsIn},
            errors_out => $result->{sysVlanStatErrorsOut},
            drops_in   => $result->{sysVlanStatDropsIn},
            drops_out  => $result->{sysVlanStatDropsOut}
        };
    }

    if (scalar(keys %{$self->{vlans}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No VLANs found.');
        $self->{output}->option_exit();
    }

    $self->{cache_name} = 'f5_bigip_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_name}) ? md5_hex($self->{option_results}->{filter_name}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check VLAN statistics on F5 BIG-IP devices.

Monitors per-VLAN traffic throughput, errors, and drops.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).

=item B<--filter-name>

Filter VLAN name (can be a regexp).

=item B<--warning-traffic-in>

Warning threshold for incoming traffic (bytes/s).

=item B<--critical-traffic-in>

Critical threshold for incoming traffic (bytes/s).

=item B<--warning-traffic-out>

Warning threshold for outgoing traffic (bytes/s).

=item B<--critical-traffic-out>

Critical threshold for outgoing traffic (bytes/s).

=item B<--warning-errors-in>

Warning threshold for incoming errors per second.

=item B<--critical-errors-in>

Critical threshold for incoming errors per second.

=item B<--warning-drops-in>

Warning threshold for incoming drops per second.

=item B<--critical-drops-in>

Critical threshold for incoming drops per second.

=back

=cut
