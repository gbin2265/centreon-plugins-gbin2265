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

package network::f5::bigip::snmp::mode::gtmpoolstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
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

sub prefix_pool_output {
    my ($self, %options) = @_;

    return "GTM Pool '" . $options{instance_value}->{display} . "' ";
}

sub pool_long_output {
    my ($self, %options) = @_;

    return "checking GTM pool '" . $options{instance_value}->{display} . "'";
}

sub prefix_member_output {
    my ($self, %options) = @_;

    return sprintf(
        "member '%s' [vs: %s] ",
        $options{instance_value}->{server_name},
        $options{instance_value}->{vs_name}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'pools', type => 3, cb_prefix_output => 'prefix_pool_output',
          cb_long_output => 'pool_long_output', indent_long_output => '    ',
          message_multiple => 'All GTM pools are ok',
            group => [
                { name => 'pool_status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'pool_counts', type => 0, skipped_code => { -10 => 1 } },
                { name => 'members', display_long => 1, cb_prefix_output => 'prefix_member_output',
                  message_multiple => 'members are ok', type => 1, skipped_code => { -10 => 1 } }
            ]
        }
    ];

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
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{pool_counts} = [
        { label => 'active-members', nlabel => 'gtmpool.members.active.count', set => {
                key_values => [ { name => 'active_members' }, { name => 'total_members' }, { name => 'display' } ],
                output_template => 'active members: %s',
                perfdatas => [
                    { template => '%s', min => 0, max => 'total_members', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'total-members', display_ok => 0, nlabel => 'gtmpool.members.total.count', set => {
                key_values => [ { name => 'total_members' }, { name => 'display' } ],
                output_template => 'total members: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'completeness', nlabel => 'gtmpool.completeness.percentage', set => {
                key_values => [ { name => 'completeness' }, { name => 'display' } ],
                output_template => 'completeness: %.2f%%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%',
                      label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];

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
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s' => { name => 'filter_name' }
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

# F5-BIGIP-GLOBAL-MIB::gtmPoolStatusTable
my $mapping_pool_status = {
    gtmPoolStatusAvailState   => { oid => '.1.3.6.1.4.1.3375.2.3.6.1.3.1.2', map => $map_avail_state },
    gtmPoolStatusEnabledState => { oid => '.1.3.6.1.4.1.3375.2.3.6.1.3.1.3', map => $map_enabled_state },
    gtmPoolStatusDetailReason => { oid => '.1.3.6.1.4.1.3375.2.3.6.1.3.1.5' },
};
my $oid_gtmPoolStatusEntry = '.1.3.6.1.4.1.3375.2.3.6.1.3.1';

# F5-BIGIP-GLOBAL-MIB::gtmPoolMbrStatusTable
my $mapping_member_status = {
    gtmPoolMbrStatusAvailState   => { oid => '.1.3.6.1.4.1.3375.2.3.6.2.3.1.4', map => $map_avail_state },
    gtmPoolMbrStatusEnabledState => { oid => '.1.3.6.1.4.1.3375.2.3.6.2.3.1.5', map => $map_enabled_state },
    gtmPoolMbrStatusDetailReason => { oid => '.1.3.6.1.4.1.3375.2.3.6.2.3.1.7' },
};
my $oid_gtmPoolMbrStatusEntry = '.1.3.6.1.4.1.3375.2.3.6.2.3.1';

sub decode_string_index {
    my ($self, %options) = @_;

    my @indexes = split(/\./, $options{index});
    my $length = shift(@indexes);
    my $name = join('', map(chr($_), splice(@indexes, 0, $length)));
    my $remaining = join('.', @indexes);

    return ($name, $remaining);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_multiple_table(
        oids => [
            { oid => $oid_gtmPoolStatusEntry },
            { oid => $oid_gtmPoolMbrStatusEntry }
        ],
        nothing_quit => 1
    );

    # Parse pool status
    $self->{pools} = {};
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result->{$oid_gtmPoolStatusEntry}})) {
        next if ($oid !~ /^$mapping_pool_status->{gtmPoolStatusAvailState}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping_pool_status,
            results  => $snmp_result->{$oid_gtmPoolStatusEntry},
            instance => $instance
        );

        my ($pool_name, $remaining) = $self->decode_string_index(index => $instance);

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $pool_name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping GTM pool '" . $pool_name . "'.", debug => 1);
            next;
        }

        $self->{pools}->{$pool_name} = {
            display     => $pool_name,
            pool_status => {
                display => $pool_name,
                status  => $result->{gtmPoolStatusAvailState},
                state   => $result->{gtmPoolStatusEnabledState},
                reason  => defined($result->{gtmPoolStatusDetailReason}) ? $result->{gtmPoolStatusDetailReason} : '-'
            },
            pool_counts => {
                display        => $pool_name,
                active_members => 0,
                total_members  => 0,
                completeness   => 0
            },
            members => {}
        };
    }

    # Parse pool member status
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result->{$oid_gtmPoolMbrStatusEntry}})) {
        next if ($oid !~ /^$mapping_member_status->{gtmPoolMbrStatusAvailState}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping_member_status,
            results  => $snmp_result->{$oid_gtmPoolMbrStatusEntry},
            instance => $instance
        );

        # Index format: pool_name_length.pool_name.server_name_length.server_name.vs_name_length.vs_name
        my ($pool_name, $remaining) = $self->decode_string_index(index => $instance);
        next if (!defined($self->{pools}->{$pool_name}));

        my ($server_name, $remaining2) = $self->decode_string_index(index => $remaining);
        my ($vs_name) = $self->decode_string_index(index => $remaining2);

        my $member_key = $server_name . '_' . $vs_name;

        $self->{pools}->{$pool_name}->{members}->{$member_key} = {
            display     => $member_key,
            server_name => $server_name,
            vs_name     => $vs_name,
            status      => $result->{gtmPoolMbrStatusAvailState},
            state       => $result->{gtmPoolMbrStatusEnabledState},
            reason      => defined($result->{gtmPoolMbrStatusDetailReason}) ? $result->{gtmPoolMbrStatusDetailReason} : '-'
        };

        $self->{pools}->{$pool_name}->{pool_counts}->{total_members}++;
        if ($result->{gtmPoolMbrStatusAvailState} eq 'green') {
            $self->{pools}->{$pool_name}->{pool_counts}->{active_members}++;
        }
    }

    # Calculate completeness for each pool
    foreach my $pool_name (keys %{$self->{pools}}) {
        my $counts = $self->{pools}->{$pool_name}->{pool_counts};
        $counts->{completeness} = $counts->{total_members} > 0
            ? ($counts->{active_members} / $counts->{total_members}) * 100
            : 0;
    }

    if (scalar(keys %{$self->{pools}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No GTM pools found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check GTM pool status on F5 BIG-IP devices.

Monitors the availability state of GTM pools and their members,
including pool completeness (percentage of active members).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='completeness'

=item B<--filter-name>

Filter GTM pool name (can be a regexp).

=item B<--warning-pool-status>

Define the conditions to match for the status to be WARNING
(default: '%{state} eq "enabled" and %{status} eq "yellow"').
You can use the following variables: %{status}, %{state}, %{reason}, %{display}

=item B<--critical-pool-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{state} eq "enabled" and %{status} eq "red"').
You can use the following variables: %{status}, %{state}, %{reason}, %{display}

=item B<--warning-member-status>

Define the conditions to match for the status to be WARNING
(default: '%{state} eq "enabled" and %{status} eq "yellow"').
You can use the following variables: %{status}, %{state}, %{reason}, %{display}

=item B<--critical-member-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{state} eq "enabled" and %{status} eq "red"').
You can use the following variables: %{status}, %{state}, %{reason}, %{display}

=item B<--warning-active-members>

Warning threshold for number of active members.

=item B<--critical-active-members>

Critical threshold for number of active members.

=item B<--warning-completeness>

Warning threshold for pool completeness (percentage of active members).

=item B<--critical-completeness>

Critical threshold for pool completeness (percentage of active members).

=back

=cut
