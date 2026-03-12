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

package storage::hp::msa2000::ssh::mode::diskgroups;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf('status: %s [raid: %s]', $self->{result_values}->{health}, $self->{result_values}->{raidtype});
}

sub custom_usage_output {
    my ($self, %options) = @_;

    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total_space});
    my ($total_used_value, $total_used_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used_space});
    my ($total_free_value, $total_free_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{free_space});
    return sprintf(
        "space usage total: %s used: %s (%.2f%%) free: %s (%.2f%%)",
        $total_size_value . " " . $total_size_unit,
        $total_used_value . " " . $total_used_unit, $self->{result_values}->{prct_used_space},
        $total_free_value . " " . $total_free_unit, $self->{result_values}->{prct_free_space}
    );
}

sub prefix_dg_output {
    my ($self, %options) = @_;

    return "Disk group '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'disk_group', type => 1, cb_prefix_output => 'prefix_dg_output', message_multiple => 'All disk groups are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{disk_group} = [
        {
            label => 'status',
            type => 2,
            unknown_default => '%{health} =~ /unknown/i',
            warning_default => '',
            critical_default => '%{health} =~ /degraded|fault|failed/i',
            set => {
                key_values => [ { name => 'health' }, { name => 'display' }, { name => 'raidtype' }, { name => 'reason' }, { name => 'recommendation' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'usage', nlabel => 'disk_group.space.usage.bytes', set => {
                key_values => [ { name => 'used_space' }, { name => 'free_space' }, { name => 'prct_used_space' }, { name => 'prct_free_space' }, { name => 'total_space' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'usage-free', display_ok => 0, nlabel => 'disk_group.space.free.bytes', set => {
                key_values => [ { name => 'free_space' }, { name => 'used_space' }, { name => 'prct_used_space' }, { name => 'prct_free_space' }, { name => 'total_space' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'usage-prct', display_ok => 0, nlabel => 'disk_group.space.usage.percentage', set => {
                key_values => [ { name => 'prct_used_space' }, { name => 'display' } ],
                output_template => 'used: %.2f %%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'iops', nlabel => 'disk_group.io.persecond', display_ok => 0, set => {
                key_values => [ { name => 'iops' }, { name => 'display' } ],
                output_template => 'IOPS: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'read-iops', nlabel => 'disk_group.io.read.count', display_ok => 0, set => {
                key_values => [ { name => 'reads' }, { name => 'display' } ],
                output_template => 'reads: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'write-iops', nlabel => 'disk_group.io.write.count', display_ok => 0, set => {
                key_values => [ { name => 'writes' }, { name => 'display' } ],
                output_template => 'writes: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'data-read', nlabel => 'disk_group.data.read.bytes', display_ok => 0, set => {
                key_values => [ { name => 'data_read' }, { name => 'display' } ],
                output_template => 'data read: %s B',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'data-written', nlabel => 'disk_group.data.written.bytes', display_ok => 0, set => {
                key_values => [ { name => 'data_written' }, { name => 'display' } ],
                output_template => 'data written: %s B',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'throughput', nlabel => 'disk_group.throughput.bytespersecond', display_ok => 0, set => {
                key_values => [ { name => 'bps' }, { name => 'display' } ],
                output_template => 'throughput: %s B/s',
                perfdatas => [
                    { template => '%s', unit => 'B/s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'avg-response-time', nlabel => 'disk_group.io.response.time.microseconds', display_ok => 0, set => {
                key_values => [ { name => 'avg_rsp' }, { name => 'display' } ],
                output_template => 'avg response time: %s us',
                perfdatas => [
                    { template => '%s', unit => 'us', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'avg-read-response-time', nlabel => 'disk_group.io.read.response.time.microseconds', display_ok => 0, set => {
                key_values => [ { name => 'avg_read_rsp' }, { name => 'display' } ],
                output_template => 'avg read response time: %s us',
                perfdatas => [
                    { template => '%s', unit => 'us', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'avg-write-response-time', nlabel => 'disk_group.io.write.response.time.microseconds', display_ok => 0, set => {
                key_values => [ { name => 'avg_write_rsp' }, { name => 'display' } ],
                output_template => 'avg write response time: %s us',
                perfdatas => [
                    { template => '%s', unit => 'us', min => 0, label_extra_instance => 1, instance_use => 'display' }
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
        'filter-name:s' => { name => 'filter_name' },
        'exclude-name:s' => { name => 'exclude_name' }
    });

    return $self;
}

my $map_health = {
    0 => 'ok', 1 => 'degraded',
    2 => 'fault', 3 => 'unknown',
    4 => 'not available',
};

sub manage_selection {
    my ($self, %options) = @_;

    my ($result, $code) = $options{custom}->get_infos(
        cmd => 'show disk-groups',
        base_type => 'disk-groups',
        properties_name => '^(?:name|size|size-numeric|freespace|freespace-numeric|health|health-numeric|health-reason|health-recommendation|raidtype|status|diskcount|pool|owner|serial-number)$',
        no_quit => 1
    );

    # Fallback to vdisks if disk-groups not supported
    if ($code == 0 || (ref($result) eq 'ARRAY' && scalar(@$result) == 0) || (ref($result) eq 'HASH' && scalar(keys %$result) == 0)) {
        ($result) = $options{custom}->get_infos(
            cmd => 'show vdisks',
            base_type => 'virtual-disks',
            properties_name => '^(?:name|size|size-numeric|freespace|freespace-numeric|health|health-numeric|health-reason|raidtype|status|diskcount|owner)$',
        );
    }

    $self->{disk_group} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $dg (@items) {
        my $name = defined($dg->{'name'}) ? $dg->{'name'} : 'unknown';

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping disk group '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_name}) && $self->{option_results}->{exclude_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_name}/) {
            $self->{output}->output_add(long_msg => "skipping disk group '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $health = defined($dg->{'health-numeric'}) ?
            ($map_health->{ $dg->{'health-numeric'} } // 'unknown') :
            (defined($dg->{'health'}) ? lc($dg->{'health'}) : 'unknown');

        # Size in the MSA XML is in 512-byte blocks (numeric fields)
        my $total = defined($dg->{'size-numeric'}) ? $dg->{'size-numeric'} * 512 : 0;
        my $free = defined($dg->{'freespace-numeric'}) ? $dg->{'freespace-numeric'} * 512 : 0;
        my $used = $total - $free;

        $self->{disk_group}->{$name} = {
            display => $name,
            health => $health,
            raidtype => defined($dg->{'raidtype'}) ? $dg->{'raidtype'} : '-',
            reason => defined($dg->{'health-reason'}) ? $dg->{'health-reason'} : '',
            recommendation => defined($dg->{'health-recommendation'}) ? $dg->{'health-recommendation'} : '',
            total_space => $total,
            used_space => $used > 0 ? $used : 0,
            free_space => $free,
            prct_used_space => $total > 0 ? ($used * 100 / $total) : 0,
            prct_free_space => $total > 0 ? ($free * 100 / $total) : 0,
            iops => undef,
            reads => undef,
            writes => undef,
            data_read => undef,
            data_written => undef,
            bps => undef,
            avg_rsp => undef,
            avg_read_rsp => undef,
            avg_write_rsp => undef,
        };

        # Verbose: show reason/recommendation
        my $reason = defined($dg->{'health-reason'}) ? $dg->{'health-reason'} : '';
        my $recommendation = defined($dg->{'health-recommendation'}) ? $dg->{'health-recommendation'} : '';
        my $long = sprintf("disk group '%s' [raid: %s, health: %s]", $name, defined($dg->{'raidtype'}) ? $dg->{'raidtype'} : '-', $health);
        $long .= ' [reason: ' . $reason . ']' if ($reason ne '');
        $long .= ' [recommendation: ' . $recommendation . ']' if ($recommendation ne '');
        $self->{output}->output_add(long_msg => $long);
    }

    # Fetch disk-group-statistics
    my ($stats_result) = $options{custom}->get_infos(
        cmd => 'show disk-group-statistics',
        base_type => 'disk-group-statistics',
        properties_name => '^(?:name|serial-number|number-of-reads|number-of-writes|data-read-numeric|data-written-numeric|bytes-per-second-numeric|iops|avg-rsp-time|avg-read-rsp-time|avg-write-rsp-time)$',
        no_quit => 1
    );

    if (defined($stats_result)) {
        my @stat_items = ref($stats_result) eq 'ARRAY' ? @$stats_result : values %$stats_result;

        foreach my $stat (@stat_items) {
            my $name = defined($stat->{'name'}) ? $stat->{'name'} : next;
            next if (!defined($self->{disk_group}->{$name}));

            $self->{disk_group}->{$name}->{iops} = defined($stat->{'iops'}) ? $stat->{'iops'} : undef;
            $self->{disk_group}->{$name}->{reads} = defined($stat->{'number-of-reads'}) ? $stat->{'number-of-reads'} : undef;
            $self->{disk_group}->{$name}->{writes} = defined($stat->{'number-of-writes'}) ? $stat->{'number-of-writes'} : undef;
            $self->{disk_group}->{$name}->{data_read} = defined($stat->{'data-read-numeric'}) ? $stat->{'data-read-numeric'} * 512 : undef;
            $self->{disk_group}->{$name}->{data_written} = defined($stat->{'data-written-numeric'}) ? $stat->{'data-written-numeric'} * 512 : undef;
            $self->{disk_group}->{$name}->{bps} = defined($stat->{'bytes-per-second-numeric'}) ? $stat->{'bytes-per-second-numeric'} : undef;
            $self->{disk_group}->{$name}->{avg_rsp} = defined($stat->{'avg-rsp-time'}) ? $stat->{'avg-rsp-time'} : undef;
            $self->{disk_group}->{$name}->{avg_read_rsp} = defined($stat->{'avg-read-rsp-time'}) ? $stat->{'avg-read-rsp-time'} : undef;
            $self->{disk_group}->{$name}->{avg_write_rsp} = defined($stat->{'avg-write-rsp-time'}) ? $stat->{'avg-write-rsp-time'} : undef;
        }
    }

    if (scalar(keys %{$self->{disk_group}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No disk group found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check disk groups (virtual disks) health and space usage.

=over 8

=item B<--filter-name>

Filter disk group name (can be a regexp).

=item B<--exclude-name>

Exclude disk group name (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{health} =~ /unknown/i').
You can use the following variables: %{health}, %{display}, %{raidtype}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{health} =~ /degraded/i').
You can use the following variables: %{health}, %{display}, %{raidtype}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{health} =~ /fault|failed/i').
You can use the following variables: %{health}, %{display}, %{raidtype}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'usage' (B), 'usage-free' (B), 'usage-prct' (%),
'iops', 'read-iops', 'write-iops',
'data-read' (B), 'data-written' (B), 'throughput' (B/s),
'avg-response-time' (us), 'avg-read-response-time' (us), 'avg-write-response-time' (us).

=back

=cut
