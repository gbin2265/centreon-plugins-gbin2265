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

package network::f5::bigip::snmp::mode::snatusage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_snatpool_output {
    my ($self, %options) = @_;

    return "SNAT pool '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'snatpools', type => 1, cb_prefix_output => 'prefix_snatpool_output',
          message_multiple => 'All SNAT pools are ok' }
    ];

    $self->{maps_counters}->{snatpools} = [
        { label => 'current-connections', nlabel => 'snatpool.connections.server.current.count', set => {
                key_values => [ { name => 'cur_conns' }, { name => 'display' } ],
                output_template => 'current server connections: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'total-connections', nlabel => 'snatpool.connections.server.total.persecond', set => {
                key_values => [ { name => 'tot_conns', diff => 1 }, { name => 'display' } ],
                output_template => 'total server connections: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'bytes-in', nlabel => 'snatpool.traffic.in.bytespersecond', set => {
                key_values => [ { name => 'bytes_in', diff => 1 }, { name => 'display' } ],
                output_template => 'traffic in: %s %s/s',
                output_change_bytes => 1,
                per_second => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'bytes-out', nlabel => 'snatpool.traffic.out.bytespersecond', set => {
                key_values => [ { name => 'bytes_out', diff => 1 }, { name => 'display' } ],
                output_template => 'traffic out: %s %s/s',
                output_change_bytes => 1,
                per_second => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'packets-in', nlabel => 'snatpool.packets.in.persecond', set => {
                key_values => [ { name => 'pkts_in', diff => 1 }, { name => 'display' } ],
                output_template => 'packets in: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'packets-out', nlabel => 'snatpool.packets.out.persecond', set => {
                key_values => [ { name => 'pkts_out', diff => 1 }, { name => 'display' } ],
                output_template => 'packets out: %.2f/s',
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

# F5-BIGIP-LOCAL-MIB::ltmSnatPoolStatTable
my $mapping = {
    ltmSnatPoolStatServerTotConns  => { oid => '.1.3.6.1.4.1.3375.2.2.9.7.2.1.2' },
    ltmSnatPoolStatServerCurConns  => { oid => '.1.3.6.1.4.1.3375.2.2.9.7.2.1.3' },
    ltmSnatPoolStatServerPktsIn    => { oid => '.1.3.6.1.4.1.3375.2.2.9.7.2.1.4' },
    ltmSnatPoolStatServerBytesIn   => { oid => '.1.3.6.1.4.1.3375.2.2.9.7.2.1.5' },
    ltmSnatPoolStatServerPktsOut   => { oid => '.1.3.6.1.4.1.3375.2.2.9.7.2.1.6' },
    ltmSnatPoolStatServerBytesOut  => { oid => '.1.3.6.1.4.1.3375.2.2.9.7.2.1.7' },
};
my $oid_ltmSnatPoolStatEntry = '.1.3.6.1.4.1.3375.2.2.9.7.2.1';

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_table(
        oid          => $oid_ltmSnatPoolStatEntry,
        nothing_quit => 1
    );

    $self->{snatpools} = {};
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result})) {
        next if ($oid !~ /^$mapping->{ltmSnatPoolStatServerCurConns}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping,
            results  => $snmp_result,
            instance => $instance
        );

        # Decode SNAT pool name from index
        my @indexes = split(/\./, $instance);
        my $name_length = shift(@indexes);
        my $name = join('', map(chr($_), splice(@indexes, 0, $name_length)));

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping SNAT pool '" . $name . "'.", debug => 1);
            next;
        }

        $self->{snatpools}->{$name} = {
            display   => $name,
            cur_conns => $result->{ltmSnatPoolStatServerCurConns},
            tot_conns => $result->{ltmSnatPoolStatServerTotConns},
            bytes_in  => $result->{ltmSnatPoolStatServerBytesIn},
            bytes_out => $result->{ltmSnatPoolStatServerBytesOut},
            pkts_in   => $result->{ltmSnatPoolStatServerPktsIn},
            pkts_out  => $result->{ltmSnatPoolStatServerPktsOut}
        };
    }

    if (scalar(keys %{$self->{snatpools}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No SNAT pools found.');
        $self->{output}->option_exit();
    }

    $self->{cache_name} = 'f5_bigip_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_name}) ? md5_hex($self->{option_results}->{filter_name}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check SNAT pool usage on F5 BIG-IP devices.

Monitors current and total connections, traffic throughput (bytes/packets)
per SNAT pool.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).

=item B<--filter-name>

Filter SNAT pool name (can be a regexp).

=item B<--warning-current-connections>

Warning threshold for current server connections.

=item B<--critical-current-connections>

Critical threshold for current server connections.

=item B<--warning-total-connections>

Warning threshold for total server connections per second.

=item B<--critical-total-connections>

Critical threshold for total server connections per second.

=item B<--warning-bytes-in>

Warning threshold for incoming traffic (bytes/s).

=item B<--critical-bytes-in>

Critical threshold for incoming traffic (bytes/s).

=item B<--warning-bytes-out>

Warning threshold for outgoing traffic (bytes/s).

=item B<--critical-bytes-out>

Critical threshold for outgoing traffic (bytes/s).

=back

=cut
