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

package network::f5::bigip::snmp::mode::poolmemberusage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use Digest::MD5 qw(md5_hex);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s] [reason: %s]",
        $self->{result_values}->{status},
        $self->{result_values}->{state},
        $self->{result_values}->{reason}
    );
}

sub prefix_member_output {
    my ($self, %options) = @_;

    return sprintf(
        "Pool member '%s' [%s:%s] ",
        $options{instance_value}->{display},
        $options{instance_value}->{addr},
        $options{instance_value}->{port}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'members', type => 1, cb_prefix_output => 'prefix_member_output', message_multiple => 'All pool members are ok' }
    ];

    $self->{maps_counters}->{members} = [
        {
            label => 'status',
            type  => 2,
            warning_default  => '%{state} eq "enabled" and %{status} eq "yellow"',
            critical_default => '%{state} eq "enabled" and %{status} eq "red"',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'state' },
                    { name => 'reason' }, { name => 'display' }
                ],
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'current-connections', nlabel => 'poolmember.connections.server.current.count', set => {
                key_values => [ { name => 'cur_conns' }, { name => 'display' } ],
                output_template => 'current connections: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'total-connections', nlabel => 'poolmember.connections.server.total.count', set => {
                key_values => [ { name => 'tot_conns', diff => 1 }, { name => 'display' } ],
                output_template => 'total connections: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'total-requests', nlabel => 'poolmember.requests.total.count', set => {
                key_values => [ { name => 'tot_requests', diff => 1 }, { name => 'display' } ],
                output_template => 'total requests: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'traffic-in', nlabel => 'poolmember.traffic.server.in.bytespersecond', set => {
                key_values => [ { name => 'bytes_in', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic in: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'traffic-out', nlabel => 'poolmember.traffic.server.out.bytespersecond', set => {
                key_values => [ { name => 'bytes_out', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic out: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'connection-queue-depth', nlabel => 'poolmember.connectionqueue.depth.count', set => {
                key_values => [ { name => 'connq_depth' }, { name => 'display' } ],
                output_template => 'connection queue depth: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'connection-queue-age-head', nlabel => 'poolmember.connectionqueue.age.head.milliseconds', display_ok => 0, set => {
                key_values => [ { name => 'connq_age_head' }, { name => 'display' } ],
                output_template => 'queue head age: %s ms',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'ms', label_extra_instance => 1, instance_use => 'display' }
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
        'filter-pool:s'   => { name => 'filter_pool' },
        'filter-member:s' => { name => 'filter_member' }
    });

    return $self;
}

my $map_avail_state = {
    0 => 'none',
    1 => 'green',
    2 => 'yellow',
    3 => 'red',
    4 => 'blue',
    5 => 'gray',
};

my $map_enabled_state = {
    0 => 'none',
    1 => 'enabled',
    2 => 'disabled',
    3 => 'disabledbyparent',
};

# F5-BIGIP-LOCAL-MIB::ltmPoolMbrStatusTable (status)
my $mapping_status = {
    ltmPoolMbrStatusAvailState   => { oid => '.1.3.6.1.4.1.3375.2.2.5.6.2.1.5', map => $map_avail_state },
    ltmPoolMbrStatusEnabledState => { oid => '.1.3.6.1.4.1.3375.2.2.5.6.2.1.6', map => $map_enabled_state },
    ltmPoolMbrStatusDetailReason => { oid => '.1.3.6.1.4.1.3375.2.2.5.6.2.1.8' },
    ltmPoolMbrStatusNodeName     => { oid => '.1.3.6.1.4.1.3375.2.2.5.6.2.1.9' },
};
my $oid_ltmPoolMbrStatusEntry = '.1.3.6.1.4.1.3375.2.2.5.6.2.1';

# F5-BIGIP-LOCAL-MIB::ltmPoolMemberStatTable (statistics)
my $mapping_stats = {
    ltmPoolMemberStatServerBytesIn   => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.6' },
    ltmPoolMemberStatServerBytesOut  => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.8' },
    ltmPoolMemberStatServerTotConns  => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.10' },
    ltmPoolMemberStatServerCurConns  => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.11' },
    ltmPoolMemberStatTotRequests     => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.19' },
    ltmPoolMemberStatConnqDepth      => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.22' },
    ltmPoolMemberStatConnqAgeHead    => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.23' },
};
my $oid_ltmPoolMemberStatEntry = '.1.3.6.1.4.1.3375.2.2.5.4.3.1';

sub decode_member_index {
    my ($self, %options) = @_;

    # Index format: pool_name_len.pool_name.addr_type.addr_bytes.port
    my @indexes = split(/\./, $options{index});

    # Pool name (length-prefixed)
    my $pool_name_len = shift(@indexes);
    my $pool_name = join('', map(chr($_), splice(@indexes, 0, $pool_name_len)));

    # Address type (1=ipv4, 2=ipv6)
    my $addr_type = shift(@indexes);

    # Address
    my $addr;
    if ($addr_type == 1) {
        # IPv4: 4 bytes
        $addr = join('.', splice(@indexes, 0, 4));
    } elsif ($addr_type == 2) {
        # IPv6: 16 bytes
        my @bytes = splice(@indexes, 0, 16);
        $addr = join(':', map { sprintf('%02x%02x', $bytes[$_*2], $bytes[$_*2+1]) } 0..7);
        $addr =~ s/(^|:)0{1,3}/$1/g; # compress zeros
    } else {
        # Fallback: read remaining as address
        $addr = join('.', splice(@indexes, 0, scalar(@indexes) - 1));
    }

    # Port
    my $port = shift(@indexes) || 0;

    return ($pool_name, $addr, $port);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_multiple_table(
        oids => [
            { oid => $oid_ltmPoolMbrStatusEntry },
            { oid => $oid_ltmPoolMemberStatEntry }
        ],
        nothing_quit => 1
    );

    $self->{members} = {};

    # Parse status table first
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result->{$oid_ltmPoolMbrStatusEntry}})) {
        next if ($oid !~ /^$mapping_status->{ltmPoolMbrStatusAvailState}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping_status,
            results  => $snmp_result->{$oid_ltmPoolMbrStatusEntry},
            instance => $instance
        );

        my ($pool_name, $addr, $port) = $self->decode_member_index(index => $instance);

        if (defined($self->{option_results}->{filter_pool}) && $self->{option_results}->{filter_pool} ne '' &&
            $pool_name !~ /$self->{option_results}->{filter_pool}/) {
            $self->{output}->output_add(long_msg => "skipping pool '" . $pool_name . "'.", debug => 1);
            next;
        }

        my $node_name = defined($result->{ltmPoolMbrStatusNodeName}) ? $result->{ltmPoolMbrStatusNodeName} : $addr;
        my $display_name = $pool_name . '/' . $node_name . ':' . $port;

        if (defined($self->{option_results}->{filter_member}) && $self->{option_results}->{filter_member} ne '' &&
            $display_name !~ /$self->{option_results}->{filter_member}/) {
            $self->{output}->output_add(long_msg => "skipping member '" . $display_name . "'.", debug => 1);
            next;
        }

        $self->{members}->{$display_name} = {
            display => $display_name,
            addr    => $addr,
            port    => $port,
            status  => $result->{ltmPoolMbrStatusAvailState},
            state   => $result->{ltmPoolMbrStatusEnabledState},
            reason  => defined($result->{ltmPoolMbrStatusDetailReason}) ? $result->{ltmPoolMbrStatusDetailReason} : '-',
            # stats will be merged below
            cur_conns      => 0,
            tot_conns      => 0,
            tot_requests   => 0,
            bytes_in       => 0,
            bytes_out      => 0,
            connq_depth    => 0,
            connq_age_head => 0
        };
    }

    # Merge stats table
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result->{$oid_ltmPoolMemberStatEntry}})) {
        next if ($oid !~ /^$mapping_stats->{ltmPoolMemberStatServerCurConns}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping_stats,
            results  => $snmp_result->{$oid_ltmPoolMemberStatEntry},
            instance => $instance
        );

        my ($pool_name, $addr, $port) = $self->decode_member_index(index => $instance);

        # Find the matching member from status table
        foreach my $key (keys %{$self->{members}}) {
            if ($key =~ /^\Q$pool_name\E\// && $self->{members}->{$key}->{addr} eq $addr && $self->{members}->{$key}->{port} == $port) {
                $self->{members}->{$key}->{cur_conns}      = $result->{ltmPoolMemberStatServerCurConns};
                $self->{members}->{$key}->{tot_conns}      = $result->{ltmPoolMemberStatServerTotConns};
                $self->{members}->{$key}->{tot_requests}   = $result->{ltmPoolMemberStatTotRequests};
                $self->{members}->{$key}->{bytes_in}       = $result->{ltmPoolMemberStatServerBytesIn};
                $self->{members}->{$key}->{bytes_out}      = $result->{ltmPoolMemberStatServerBytesOut};
                $self->{members}->{$key}->{connq_depth}    = $result->{ltmPoolMemberStatConnqDepth};
                $self->{members}->{$key}->{connq_age_head} = $result->{ltmPoolMemberStatConnqAgeHead};
                last;
            }
        }
    }

    if (scalar(keys %{$self->{members}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No pool members found.');
        $self->{output}->option_exit();
    }

    $self->{cache_name} = 'f5_bigip_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_pool}) ? md5_hex($self->{option_results}->{filter_pool}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_member}) ? md5_hex($self->{option_results}->{filter_member}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check individual LTM pool member status and usage statistics on F5 BIG-IP devices.

Monitors per-member: status, current/total connections, requests, traffic (bytes),
and connection queue depth. Traffic and total counters use delta calculation
(requires two checks).

Complements the existing 'pool-status' mode which only shows aggregate pool-level
stats and member status without per-member traffic/connection details.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='current-connections|traffic'

=item B<--filter-pool>

Filter pool name (can be a regexp).
Example: --filter-pool='myapp_pool'

=item B<--filter-member>

Filter member name (can be a regexp, matches pool/node:port).
Example: --filter-member='web-server-01'

=item B<--warning-status>

Define the conditions to match for the status to be WARNING
(default: '%{state} eq "enabled" and %{status} eq "yellow"').
You can use the following variables: %{status}, %{state}, %{reason}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{state} eq "enabled" and %{status} eq "red"').
You can use the following variables: %{status}, %{state}, %{reason}, %{display}

=item B<--warning-current-connections>

Warning threshold for current connections per member.

=item B<--critical-current-connections>

Critical threshold for current connections per member.

=item B<--warning-total-connections>

Warning threshold for total connections per member (delta).

=item B<--critical-total-connections>

Critical threshold for total connections per member (delta).

=item B<--warning-total-requests>

Warning threshold for total requests per member (delta).

=item B<--critical-total-requests>

Critical threshold for total requests per member (delta).

=item B<--warning-traffic-in>

Warning threshold for inbound traffic per member (B/s).

=item B<--critical-traffic-in>

Critical threshold for inbound traffic per member (B/s).

=item B<--warning-traffic-out>

Warning threshold for outbound traffic per member (B/s).

=item B<--critical-traffic-out>

Critical threshold for outbound traffic per member (B/s).

=item B<--warning-connection-queue-depth>

Warning threshold for connection queue depth.

=item B<--critical-connection-queue-depth>

Critical threshold for connection queue depth.

=back

=cut
