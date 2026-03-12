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

package network::f5::bigip::snmp::mode::virtualservertree;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use Digest::MD5 qw(md5_hex);
use Time::HiRes qw(time);

# --- Custom output subs ---

sub custom_vs_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s] [reason: %s] [pool: %s]",
        $self->{result_values}->{status},
        $self->{result_values}->{state},
        $self->{result_values}->{reason},
        $self->{result_values}->{default_pool}
    );
}

sub custom_pool_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s] [reason: %s]",
        $self->{result_values}->{status},
        $self->{result_values}->{state},
        $self->{result_values}->{reason}
    );
}

sub custom_member_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s] [reason: %s]",
        $self->{result_values}->{status},
        $self->{result_values}->{state},
        $self->{result_values}->{reason}
    );
}

# --- Prefix subs ---

sub prefix_vs_output {
    my ($self, %options) = @_;

    return "Virtual server '" . $options{instance_value}->{display} . "' ";
}

sub vs_long_output {
    my ($self, %options) = @_;

    return "checking virtual server '" . $options{instance_value}->{display} . "'";
}

sub prefix_pool_output {
    my ($self, %options) = @_;

    return "  pool '" . $options{instance_value}->{display} . "' ";
}

sub pool_long_output {
    my ($self, %options) = @_;

    return "  checking pool '" . $options{instance_value}->{display} . "'";
}

sub prefix_member_output {
    my ($self, %options) = @_;

    return "    member '" . $options{instance_value}->{display} . "' ";
}

# --- Counter definitions ---

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'vs', type => 3, cb_prefix_output => 'prefix_vs_output',
          cb_long_output => 'vs_long_output', indent_long_output => '    ',
          message_multiple => 'All virtual servers are ok',
            group => [
                { name => 'vs_status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'vs_stats', type => 0, skipped_code => { -10 => 1 } },
                { name => 'pools', type => 3, cb_prefix_output => 'prefix_pool_output',
                  cb_long_output => 'pool_long_output', indent_long_output => '        ',
                  message_multiple => 'pools are ok',
                    group => [
                        { name => 'pool_status', type => 0, skipped_code => { -10 => 1 } },
                        { name => 'pool_counts', type => 0, skipped_code => { -10 => 1 } },
                        { name => 'members', display_long => 1, cb_prefix_output => 'prefix_member_output',
                          message_multiple => 'members are ok', type => 1, skipped_code => { -10 => 1 } }
                    ]
                }
            ]
        }
    ];

    # VS level: status
    $self->{maps_counters}->{vs_status} = [
        {
            label => 'vs-status',
            type  => 2,
            warning_default  => '%{state} eq "enabled" and %{status} eq "yellow"',
            critical_default => '%{state} eq "enabled" and %{status} eq "red"',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'state' },
                    { name => 'reason' }, { name => 'default_pool' }, { name => 'display' }
                ],
                closure_custom_output          => $self->can('custom_vs_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    # VS level: connections
    $self->{maps_counters}->{vs_stats} = [
        { label => 'vs-current-connections', nlabel => 'virtualserver.connections.client.current.count', set => {
                key_values => [ { name => 'cur_conns' }, { name => 'display' } ],
                output_template => 'current client connections: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'vs-total-connections', nlabel => 'virtualserver.connections.client.total.count', set => {
                key_values => [ { name => 'tot_conns', diff => 1 }, { name => 'display' } ],
                output_template => 'total connections: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'vs-traffic-in', nlabel => 'virtualserver.traffic.client.in.bytespersecond', display_ok => 0, set => {
                key_values => [ { name => 'bytes_in', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic in: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'vs-traffic-out', nlabel => 'virtualserver.traffic.client.out.bytespersecond', display_ok => 0, set => {
                key_values => [ { name => 'bytes_out', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic out: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];

    # Pool level: status
    $self->{maps_counters}->{pool_status} = [
        {
            label => 'pool-status',
            type  => 2,
            warning_default  => '%{state} eq "enabled" and %{status} eq "yellow"',
            critical_default => '%{state} eq "enabled" and %{status} eq "red"',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'state' },
                    { name => 'reason' }, { name => 'display' }
                ],
                closure_custom_output          => $self->can('custom_pool_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    # Pool level: member counts
    $self->{maps_counters}->{pool_counts} = [
        { label => 'pool-active-members', nlabel => 'pool.members.active.count', set => {
                key_values => [ { name => 'active_members' }, { name => 'total_members' }, { name => 'display' } ],
                output_template => 'active members: %s',
                perfdatas => [
                    { template => '%s', min => 0, max => 'total_members', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'pool-completeness', nlabel => 'pool.completeness.percentage', set => {
                key_values => [ { name => 'completeness' }, { name => 'display' } ],
                output_template => 'completeness: %.2f%%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%',
                      label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];

    # Member level
    $self->{maps_counters}->{members} = [
        {
            label => 'member-status',
            type  => 2,
            warning_default  => '%{state} eq "enabled" and %{status} eq "yellow"',
            critical_default => '%{state} eq "enabled" and %{status} eq "red"',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'state' },
                    { name => 'reason' }, { name => 'display' }
                ],
                closure_custom_output          => $self->can('custom_member_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'member-current-connections', nlabel => 'poolmember.connections.server.current.count', set => {
                key_values => [ { name => 'cur_conns' }, { name => 'display' } ],
                output_template => 'current connections: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'member-traffic-in', nlabel => 'poolmember.traffic.server.in.bytespersecond', display_ok => 0, set => {
                key_values => [ { name => 'bytes_in', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic in: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'member-traffic-out', nlabel => 'poolmember.traffic.server.out.bytespersecond', display_ok => 0, set => {
                key_values => [ { name => 'bytes_out', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic out: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B/s', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'member-connection-queue-depth', nlabel => 'poolmember.connectionqueue.depth.count', set => {
                key_values => [ { name => 'connq_depth' }, { name => 'display' } ],
                output_template => 'queue depth: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
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
        'filter-vs:s' => { name => 'filter_vs' }
    });

    return $self;
}

sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);

    # Let the counter framework process all counters
    $self->{new_datas} = undef;
    if (defined($self->{statefile_value})) {
        $self->{new_datas} = {};
        $self->{statefile_value}->read(statefile => $self->{cache_name}) if (defined($self->{cache_name}));
        $self->{new_datas}->{last_timestamp} = time();
    }

    foreach my $entry (@{$self->{maps_counters_type}}) {
        if ($entry->{type} == 0) {
            $self->run_global(config => $entry);
        } elsif ($entry->{type} == 1) {
            $self->run_instances(config => $entry);
        } elsif ($entry->{type} == 2) {
            $self->run_group(config => $entry);
        } elsif ($entry->{type} == 3) {
            $self->run_multiple(config => $entry);
        }
    }

    if (defined($self->{statefile_value})) {
        $self->{statefile_value}->write(data => $self->{new_datas});
    }

    # Override the OK message with a rich summary
    if (defined($self->{output}->{global_short_outputs}->{OK}) &&
        scalar(@{$self->{output}->{global_short_outputs}->{OK}}) > 0) {

        my $summary = $self->build_summary();
        $self->{output}->{global_short_outputs}->{OK} = [ $summary ];
        $self->{output}->{global_short_concat_outputs}->{OK} = $summary;
    }

    $self->{output}->display();
    $self->{output}->exit();
}

sub build_summary {
    my ($self, %options) = @_;

    my $total_vs = scalar(keys %{$self->{vs}});
    my $total_pools = 0;
    my $total_members = 0;

    foreach my $vs_name (keys %{$self->{vs}}) {
        my $vs = $self->{vs}->{$vs_name};
        $total_pools += scalar(keys %{$vs->{pools}});
        foreach my $pool_name (keys %{$vs->{pools}}) {
            $total_members += scalar(keys %{$vs->{pools}->{$pool_name}->{members}});
        }
    }

    # No filter or multiple VS: compact summary
    if (!defined($self->{option_results}->{filter_vs}) || $self->{option_results}->{filter_vs} eq '' || $total_vs > 1) {
        return sprintf(
            "All OK - %s virtual servers, %s pools, %s pool members",
            $total_vs, $total_pools, $total_members
        );
    }

    # Single VS with filter: detailed tree output
    my @parts;
    foreach my $vs_name (sort keys %{$self->{vs}}) {
        my $vs = $self->{vs}->{$vs_name};

        foreach my $pool_name (sort keys %{$vs->{pools}}) {
            my $pool = $vs->{pools}->{$pool_name};
            my $active = $pool->{pool_counts}->{active_members};
            my $total  = $pool->{pool_counts}->{total_members};

            my @member_parts;
            foreach my $mbr_name (sort keys %{$pool->{members}}) {
                my $mbr = $pool->{members}->{$mbr_name};
                my $mbr_status = $mbr->{status};
                if ($mbr_status eq 'green') {
                    push @member_parts, $mbr_name . ' (green)';
                } else {
                    push @member_parts, $mbr_name . ' (' . uc($mbr_status) . ')';
                }
            }

            my $member_info = scalar(@member_parts) > 0 ? join(', ', @member_parts) : 'no members';
            push @parts, sprintf(
                "Virtual server '%s' status: %s [pool: %s, %s/%s members active] - members: %s",
                $vs_name, lc($vs->{vs_status}->{status}), $pool_name, $active, $total, $member_info
            );
        }

        if (scalar(keys %{$vs->{pools}}) <= 0) {
            push @parts, sprintf(
                "Virtual server '%s' status: %s [no pool]",
                $vs_name, lc($vs->{vs_status}->{status})
            );
        }
    }

    return join(' / ', @parts);
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
}

my $map_avail_state = {
    0 => 'none',  1 => 'green',  2 => 'yellow',
    3 => 'red',   4 => 'blue',   5 => 'gray',
};

my $map_enabled_state = {
    0 => 'none',  1 => 'enabled',
    2 => 'disabled',  3 => 'disabledbyparent',
};

# --- OID definitions ---

# VS status (new table)
my $mapping_vs_status = {
    ltmVsStatusAvailState   => { oid => '.1.3.6.1.4.1.3375.2.2.10.13.2.1.2', map => $map_avail_state },
    ltmVsStatusEnabledState => { oid => '.1.3.6.1.4.1.3375.2.2.10.13.2.1.3', map => $map_enabled_state },
    ltmVsStatusDetailReason => { oid => '.1.3.6.1.4.1.3375.2.2.10.13.2.1.5' },
};
my $oid_ltmVsStatusEntry = '.1.3.6.1.4.1.3375.2.2.10.13.2.1';

# VS config (for default pool link)
my $oid_ltmVirtualServDefaultPool = '.1.3.6.1.4.1.3375.2.2.10.1.2.1.19';

# VS stats
my $mapping_vs_stats = {
    ltmVirtualServStatClientBytesIn  => { oid => '.1.3.6.1.4.1.3375.2.2.10.2.3.1.7' },
    ltmVirtualServStatClientBytesOut => { oid => '.1.3.6.1.4.1.3375.2.2.10.2.3.1.9' },
    ltmVirtualServStatClientTotConns => { oid => '.1.3.6.1.4.1.3375.2.2.10.2.3.1.11' },
    ltmVirtualServStatClientCurConns => { oid => '.1.3.6.1.4.1.3375.2.2.10.2.3.1.12' },
};
my $oid_ltmVirtualServStatEntry = '.1.3.6.1.4.1.3375.2.2.10.2.3.1';

# Pool status (new table)
my $mapping_pool_status = {
    ltmPoolStatusAvailState   => { oid => '.1.3.6.1.4.1.3375.2.2.5.5.2.1.2', map => $map_avail_state },
    ltmPoolStatusEnabledState => { oid => '.1.3.6.1.4.1.3375.2.2.5.5.2.1.3', map => $map_enabled_state },
    ltmPoolStatusDetailReason => { oid => '.1.3.6.1.4.1.3375.2.2.5.5.2.1.5' },
};
my $oid_ltmPoolStatusEntry = '.1.3.6.1.4.1.3375.2.2.5.5.2.1';

# Pool member/active counts
my $mapping_pool_counts = {
    ltmPoolActiveMemberCnt => { oid => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.8' },
    ltmPoolMemberCnt       => { oid => '.1.3.6.1.4.1.3375.2.2.5.1.2.1.23' },
};

# Pool member status (new table)
my $mapping_mbr_status = {
    ltmPoolMbrStatusAvailState   => { oid => '.1.3.6.1.4.1.3375.2.2.5.6.2.1.5', map => $map_avail_state },
    ltmPoolMbrStatusEnabledState => { oid => '.1.3.6.1.4.1.3375.2.2.5.6.2.1.6', map => $map_enabled_state },
    ltmPoolMbrStatusDetailReason => { oid => '.1.3.6.1.4.1.3375.2.2.5.6.2.1.8' },
    ltmPoolMbrStatusNodeName     => { oid => '.1.3.6.1.4.1.3375.2.2.5.6.2.1.9' },
};
my $oid_ltmPoolMbrStatusEntry = '.1.3.6.1.4.1.3375.2.2.5.6.2.1';

# Pool member stats
my $mapping_mbr_stats = {
    ltmPoolMemberStatServerBytesIn  => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.6' },
    ltmPoolMemberStatServerBytesOut => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.8' },
    ltmPoolMemberStatServerCurConns => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.11' },
    ltmPoolMemberStatConnqDepth     => { oid => '.1.3.6.1.4.1.3375.2.2.5.4.3.1.22' },
};
my $oid_ltmPoolMemberStatEntry = '.1.3.6.1.4.1.3375.2.2.5.4.3.1';

# --- Helper: decode length-prefixed string from SNMP index ---

sub decode_string_index {
    my ($self, %options) = @_;

    my @indexes = split(/\./, $options{index});
    my $length = shift(@indexes);
    my $name = join('', map(chr($_), splice(@indexes, 0, $length)));
    my $remaining = join('.', @indexes);

    return ($name, $remaining);
}

sub decode_member_index {
    my ($self, %options) = @_;

    my @indexes = split(/\./, $options{index});

    # Pool name
    my $pool_len = shift(@indexes);
    my $pool_name = join('', map(chr($_), splice(@indexes, 0, $pool_len)));

    # Address type + address
    my $addr_type = shift(@indexes);
    my $addr;
    if ($addr_type == 1) {
        $addr = join('.', splice(@indexes, 0, 4));
    } elsif ($addr_type == 2) {
        my @bytes = splice(@indexes, 0, 16);
        $addr = join(':', map { sprintf('%02x%02x', $bytes[$_*2], $bytes[$_*2+1]) } 0..7);
    } else {
        $addr = join('.', splice(@indexes, 0, scalar(@indexes) - 1));
    }

    my $port = shift(@indexes) || 0;

    return ($pool_name, $addr, $port);
}

sub manage_selection {
    my ($self, %options) = @_;

    # Step 1: Get all VS statuses + VS default pool links + VS stats
    my $snmp_result = $options{snmp}->get_multiple_table(
        oids => [
            { oid => $oid_ltmVsStatusEntry },
            { oid => $oid_ltmVirtualServDefaultPool },
            { oid => $oid_ltmVirtualServStatEntry },
            { oid => $oid_ltmPoolStatusEntry },
            { oid => $mapping_pool_counts->{ltmPoolActiveMemberCnt}->{oid} },
            { oid => $mapping_pool_counts->{ltmPoolMemberCnt}->{oid} },
            { oid => $oid_ltmPoolMbrStatusEntry },
            { oid => $oid_ltmPoolMemberStatEntry },
        ],
        nothing_quit => 1
    );

    # Step 2: Parse VS statuses and filter
    my %vs_instances;   # vs_instance => vs_name
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result->{$oid_ltmVsStatusEntry}})) {
        next if ($oid !~ /^$mapping_vs_status->{ltmVsStatusAvailState}->{oid}\.(.*)$/);
        my $instance = $1;

        my ($vs_name) = $self->decode_string_index(index => $instance);

        if (defined($self->{option_results}->{filter_vs}) && $self->{option_results}->{filter_vs} ne '' &&
            $vs_name !~ /$self->{option_results}->{filter_vs}/) {
            $self->{output}->output_add(long_msg => "skipping VS '" . $vs_name . "'.", debug => 1);
            next;
        }

        $vs_instances{$instance} = $vs_name;
    }

    if (scalar(keys %vs_instances) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No virtual servers found.');
        $self->{output}->option_exit();
    }

    # Step 3: Build VS tree
    $self->{vs} = {};
    foreach my $vs_instance (keys %vs_instances) {
        my $vs_name = $vs_instances{$vs_instance};

        my $vs_status_result = $options{snmp}->map_instance(
            mapping  => $mapping_vs_status,
            results  => $snmp_result->{$oid_ltmVsStatusEntry},
            instance => $vs_instance
        );

        # Get default pool name
        my $default_pool = $snmp_result->{$oid_ltmVirtualServDefaultPool}->{$oid_ltmVirtualServDefaultPool . '.' . $vs_instance};
        $default_pool = defined($default_pool) ? $default_pool : '-';

        # Get VS stats
        my $vs_stats_result = $options{snmp}->map_instance(
            mapping  => $mapping_vs_stats,
            results  => $snmp_result->{$oid_ltmVirtualServStatEntry},
            instance => $vs_instance
        );

        $self->{vs}->{$vs_name} = {
            display   => $vs_name,
            vs_status => {
                display      => $vs_name,
                status       => $vs_status_result->{ltmVsStatusAvailState},
                state        => $vs_status_result->{ltmVsStatusEnabledState},
                reason       => defined($vs_status_result->{ltmVsStatusDetailReason}) ? $vs_status_result->{ltmVsStatusDetailReason} : '-',
                default_pool => $default_pool
            },
            vs_stats => {
                display   => $vs_name,
                cur_conns => $vs_stats_result->{ltmVirtualServStatClientCurConns} || 0,
                tot_conns => $vs_stats_result->{ltmVirtualServStatClientTotConns} || 0,
                bytes_in  => $vs_stats_result->{ltmVirtualServStatClientBytesIn} || 0,
                bytes_out => $vs_stats_result->{ltmVirtualServStatClientBytesOut} || 0
            },
            pools => {}
        };

        # Step 4: Find and attach the pool
        next if ($default_pool eq '-' || $default_pool eq '');

        # Find pool status
        my $pool_instance;
        foreach my $oid (keys %{$snmp_result->{$oid_ltmPoolStatusEntry}}) {
            next if ($oid !~ /^$mapping_pool_status->{ltmPoolStatusAvailState}->{oid}\.(.*)$/);
            my $p_inst = $1;
            my ($p_name) = $self->decode_string_index(index => $p_inst);
            if ($p_name eq $default_pool) {
                $pool_instance = $p_inst;
                last;
            }
        }
        next if (!defined($pool_instance));

        my $pool_status_result = $options{snmp}->map_instance(
            mapping  => $mapping_pool_status,
            results  => $snmp_result->{$oid_ltmPoolStatusEntry},
            instance => $pool_instance
        );

        # Get member counts
        my $active = $snmp_result->{$mapping_pool_counts->{ltmPoolActiveMemberCnt}->{oid}}->{
            $mapping_pool_counts->{ltmPoolActiveMemberCnt}->{oid} . '.' . $pool_instance
        } || 0;
        my $total = $snmp_result->{$mapping_pool_counts->{ltmPoolMemberCnt}->{oid}}->{
            $mapping_pool_counts->{ltmPoolMemberCnt}->{oid} . '.' . $pool_instance
        } || 0;
        my $completeness = $total > 0 ? ($active / $total) * 100 : 0;

        $self->{vs}->{$vs_name}->{pools}->{$default_pool} = {
            display     => $default_pool,
            pool_status => {
                display => $default_pool,
                status  => $pool_status_result->{ltmPoolStatusAvailState},
                state   => $pool_status_result->{ltmPoolStatusEnabledState},
                reason  => defined($pool_status_result->{ltmPoolStatusDetailReason}) ? $pool_status_result->{ltmPoolStatusDetailReason} : '-'
            },
            pool_counts => {
                display        => $default_pool,
                active_members => $active,
                total_members  => $total,
                completeness   => $completeness
            },
            members => {}
        };

        # Step 5: Find and attach pool members
        foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result->{$oid_ltmPoolMbrStatusEntry}})) {
            next if ($oid !~ /^$mapping_mbr_status->{ltmPoolMbrStatusAvailState}->{oid}\.(.*)$/);
            my $mbr_instance = $1;

            my ($mbr_pool, $mbr_addr, $mbr_port) = $self->decode_member_index(index => $mbr_instance);
            next if ($mbr_pool ne $default_pool);

            my $mbr_status_result = $options{snmp}->map_instance(
                mapping  => $mapping_mbr_status,
                results  => $snmp_result->{$oid_ltmPoolMbrStatusEntry},
                instance => $mbr_instance
            );

            my $node_name = defined($mbr_status_result->{ltmPoolMbrStatusNodeName}) ?
                $mbr_status_result->{ltmPoolMbrStatusNodeName} : $mbr_addr;
            my $mbr_display = $node_name . ':' . $mbr_port;

            # Get member stats
            my $mbr_stats_result = $options{snmp}->map_instance(
                mapping  => $mapping_mbr_stats,
                results  => $snmp_result->{$oid_ltmPoolMemberStatEntry},
                instance => $mbr_instance
            );

            $self->{vs}->{$vs_name}->{pools}->{$default_pool}->{members}->{$mbr_display} = {
                display     => $mbr_display,
                status      => $mbr_status_result->{ltmPoolMbrStatusAvailState},
                state       => $mbr_status_result->{ltmPoolMbrStatusEnabledState},
                reason      => defined($mbr_status_result->{ltmPoolMbrStatusDetailReason}) ? $mbr_status_result->{ltmPoolMbrStatusDetailReason} : '-',
                cur_conns   => $mbr_stats_result->{ltmPoolMemberStatServerCurConns} || 0,
                bytes_in    => $mbr_stats_result->{ltmPoolMemberStatServerBytesIn} || 0,
                bytes_out   => $mbr_stats_result->{ltmPoolMemberStatServerBytesOut} || 0,
                connq_depth => $mbr_stats_result->{ltmPoolMemberStatConnqDepth} || 0
            };
        }
    }

    $self->{cache_name} = 'f5_bigip_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all')) . '_' .
        md5_hex($self->{option_results}->{filter_vs});
}

1;

__END__

=head1 MODE

Check complete virtual server tree: VS -> Pool -> Pool Members.

Provides a single check that validates the full LTM traffic path: virtual server
status, its default pool status and completeness, and each pool member's status
and statistics. Use --filter-vs to scope the check to specific virtual servers.

Output example:
  Virtual server 'myapp_vs' status: green [state: enabled] [pool: myapp_pool]
    current client connections: 142
    pool 'myapp_pool' status: green [state: enabled]
      active members: 3, completeness: 100.00%
      member 'web01:8080' status: green [state: enabled] current connections: 48
      member 'web02:8080' status: green [state: enabled] current connections: 51
      member 'web03:8080' status: green [state: enabled] current connections: 43

=over 8

=item B<--filter-vs>

Filter virtual server name (optional, can be a regexp).
Without this option, all virtual servers are checked.
Example: --filter-vs='myapp_vs'

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='status' (only status checks, no perfdata)

=item B<--warning-vs-status>

Define the conditions to match for the VS status to be WARNING
(default: '%{state} eq "enabled" and %{status} eq "yellow"').

=item B<--critical-vs-status>

Define the conditions to match for the VS status to be CRITICAL
(default: '%{state} eq "enabled" and %{status} eq "red"').

=item B<--warning-pool-status>

Define the conditions for pool status WARNING
(default: '%{state} eq "enabled" and %{status} eq "yellow"').

=item B<--critical-pool-status>

Define the conditions for pool status CRITICAL
(default: '%{state} eq "enabled" and %{status} eq "red"').

=item B<--warning-member-status>

Define the conditions for member status WARNING
(default: '%{state} eq "enabled" and %{status} eq "yellow"').

=item B<--critical-member-status>

Define the conditions for member status CRITICAL
(default: '%{state} eq "enabled" and %{status} eq "red"').

=item B<--warning-pool-active-members>

Warning threshold for number of active pool members.

=item B<--critical-pool-active-members>

Critical threshold for number of active pool members.

=item B<--warning-pool-completeness>

Warning threshold for pool completeness (%).

=item B<--critical-pool-completeness>

Critical threshold for pool completeness (%).

=item B<--warning-vs-current-connections>

Warning threshold for VS current client connections.

=item B<--critical-vs-current-connections>

Critical threshold for VS current client connections.

=item B<--warning-member-current-connections>

Warning threshold for member current connections.

=item B<--critical-member-current-connections>

Critical threshold for member current connections.

=item B<--warning-member-connection-queue-depth>

Warning threshold for member connection queue depth.

=item B<--critical-member-connection-queue-depth>

Critical threshold for member connection queue depth.

=back

=cut
