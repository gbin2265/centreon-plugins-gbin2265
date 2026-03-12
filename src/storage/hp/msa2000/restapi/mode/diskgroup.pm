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

package storage::hp::msa2000::restapi::mode::diskgroup;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s, RAID: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state},
        $self->{result_values}->{raid_type}
    );
}

sub custom_space_usage_output {
    my ($self, %options) = @_;

    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total_space});
    my ($total_used_value, $total_used_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used_space});
    my ($total_free_value, $total_free_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{free_space});
    return sprintf(
        "space usage: %s used / %s total (%.2f%% used, %s free)",
        $total_used_value . " " . $total_used_unit,
        $total_size_value . " " . $total_size_unit,
        $self->{result_values}->{used_prct},
        $total_free_value . " " . $total_free_unit
    );
}

sub prefix_diskgroup_output {
    my ($self, %options) = @_;

    return sprintf(
        "Disk group '%s' [Controller: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{controller}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'diskgroups', type => 1, cb_prefix_output => 'prefix_diskgroup_output', message_multiple => 'All disk groups are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'diskgroups-total', nlabel => 'diskgroups.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total disk groups: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{diskgroups} = [
        {
            label => 'diskgroup-status',
            type => 2,
            warning_default => '%{health} =~ /warning|degraded/i',
            critical_default => '%{health} =~ /critical/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'controller' }, { name => 'raid_type' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'diskgroup-space-usage-bytes', nlabel => 'diskgroup.space.usage.bytes', set => {
                key_values => [ { name => 'used_space' }, { name => 'free_space' }, { name => 'used_prct' }, { name => 'total_space' }, { name => 'name' } ],
                closure_custom_output => $self->can('custom_space_usage_output'),
                perfdatas => [
                    { template => '%s', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'diskgroup-space-free-bytes', nlabel => 'diskgroup.space.free.bytes', display_ok => 0, set => {
                key_values => [ { name => 'free_space' }, { name => 'total_space' }, { name => 'name' } ],
                output_template => 'free: %s B',
                perfdatas => [
                    { template => '%s', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'diskgroup-space-usage-percentage', nlabel => 'diskgroup.space.usage.percentage', display_ok => 0, set => {
                key_values => [ { name => 'used_prct' }, { name => 'name' } ],
                output_template => 'used: %.2f%%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'diskgroup-remaining-capacity', nlabel => 'diskgroup.space.remaining.percentage', set => {
                key_values => [ { name => 'remaining_percent' }, { name => 'name' } ],
                output_template => 'remaining capacity: %d%%',
                perfdatas => [
                    { template => '%d', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'diskgroup-drives-count', nlabel => 'diskgroup.drives.count', set => {
                key_values => [ { name => 'drives_count' }, { name => 'name' } ],
                output_template => 'drives: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'diskgroup-read-iops', nlabel => 'diskgroup.io.read.requests.count', display_ok => 0, set => {
                key_values => [ { name => 'read_io_requests' }, { name => 'name' } ],
                output_template => 'read IO requests: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'diskgroup-write-iops', nlabel => 'diskgroup.io.write.requests.count', display_ok => 0, set => {
                key_values => [ { name => 'write_io_requests' }, { name => 'name' } ],
                output_template => 'write IO requests: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'diskgroup-read-throughput', nlabel => 'diskgroup.io.read.bytes', display_ok => 0, set => {
                key_values => [ { name => 'read_io_bytes' }, { name => 'name' } ],
                output_template => 'read throughput: %s B',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'diskgroup-write-throughput', nlabel => 'diskgroup.io.write.bytes', display_ok => 0, set => {
                key_values => [ { name => 'write_io_bytes' }, { name => 'name' } ],
                output_template => 'write throughput: %s B',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
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
        'filter-diskgroup-id:s'   => { name => 'filter_diskgroup_id' },
        'filter-diskgroup-name:s' => { name => 'filter_diskgroup_name' },
        'filter-controller-id:s'  => { name => 'filter_controller_id' },
        'exclude-controller-id:s' => { name => 'exclude_controller_id' },
        'exclude-diskgroup-id:s' => { name => 'exclude_diskgroup_id' },
        'exclude-diskgroup-name:s' => { name => 'exclude_diskgroup_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0 };
    $self->{diskgroups} = {};

    my $storage_result = $options{custom}->request_api(url_path => '/redfish/v1/Storage');
    return if (!defined($storage_result) || !defined($storage_result->{Members}));

    foreach my $storage (@{$storage_result->{Members}}) {
        next if (!defined($storage->{'@odata.id'}));
        
        my $storage_data = $options{custom}->request_api(
            url_path => $storage->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($storage_data));

        my $controller_id;
        if (defined($storage_data->{Id})) {
            $controller_id = $storage_data->{Id};
        } elsif ($storage->{'@odata.id'} =~ /\/Storage\/([^\/]+)/) {
            $controller_id = $1;
        } else {
            next;
        }

        if (defined($self->{option_results}->{filter_controller_id}) && $self->{option_results}->{filter_controller_id} ne '' &&
            $controller_id !~ /$self->{option_results}->{filter_controller_id}/) {
            next;
        }


        if (defined($self->{option_results}->{exclude_controller_id}) && $self->{option_results}->{exclude_controller_id} ne '' &&
            $controller_id =~ /$self->{option_results}->{exclude_controller_id}/) {
            next;
        }

        next if (!defined($storage_data->{StoragePools}) || !defined($storage_data->{StoragePools}->{'@odata.id'}));

        my $pools_result = $options{custom}->request_api(
            url_path => $storage_data->{StoragePools}->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($pools_result) || !defined($pools_result->{Members}) || ref($pools_result->{Members}) ne 'ARRAY');

        foreach my $pool_ref (@{$pools_result->{Members}}) {
            next if (!defined($pool_ref->{'@odata.id'}));
            
            # Only process disk groups (they have 'dg' in the path)
            next if ($pool_ref->{'@odata.id'} !~ /\/dg[A-Z0-9]+$/i);
            
            my $dg_data = $options{custom}->request_api(
                url_path => $pool_ref->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($dg_data));

            my $dg_id;
            if (defined($dg_data->{Id})) {
                $dg_id = $dg_data->{Id};
            } elsif ($pool_ref->{'@odata.id'} =~ /\/StoragePools\/([^\/]+)/) {
                $dg_id = $1;
            } else {
                next;
            }

            my $dg_name = defined($dg_data->{Name}) ? $dg_data->{Name} : $dg_id;
            my $dg_full_id = $controller_id . '_' . $dg_id;

            if (defined($self->{option_results}->{filter_diskgroup_id}) && $self->{option_results}->{filter_diskgroup_id} ne '' &&
                $dg_id !~ /$self->{option_results}->{filter_diskgroup_id}/) {
                next;
            }


            if (defined($self->{option_results}->{exclude_diskgroup_id}) && $self->{option_results}->{exclude_diskgroup_id} ne '' &&
                $dg_id =~ /$self->{option_results}->{exclude_diskgroup_id}/) {
                next;
            }

            if (defined($self->{option_results}->{filter_diskgroup_name}) && $self->{option_results}->{filter_diskgroup_name} ne '' &&
                $dg_name !~ /$self->{option_results}->{filter_diskgroup_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_diskgroup_name}) && $self->{option_results}->{exclude_diskgroup_name} ne '' &&
                $dg_name =~ /$self->{option_results}->{exclude_diskgroup_name}/) {
                next;
            }

            my $health = 'n/a';
            my $state = 'n/a';
            if (defined($dg_data->{Status})) {
                $health = defined($dg_data->{Status}->{Health}) ? $dg_data->{Status}->{Health} : 'n/a';
                $state = defined($dg_data->{Status}->{State}) ? $dg_data->{Status}->{State} : 'n/a';
            }
            next if ($state =~ /^Absent$/i);

            my $total_space = 0;
            my $used_space = 0;
            my $free_space = 0;
            my $remaining_percent = defined($dg_data->{RemainingCapacityPercent}) ? $dg_data->{RemainingCapacityPercent} : undef;

            if (defined($dg_data->{Capacity}) && defined($dg_data->{Capacity}->{Data})) {
                $total_space = $dg_data->{Capacity}->{Data}->{AllocatedBytes} || 0;
                $used_space = $dg_data->{Capacity}->{Data}->{ConsumedBytes} || 0;
                $free_space = $total_space - $used_space;
            }

            my $used_prct = ($total_space > 0) ? ($used_space * 100 / $total_space) : 0;

            # Get RAID type
            my $raid_type = 'n/a';
            if (defined($dg_data->{SupportedRAIDTypes}) && ref($dg_data->{SupportedRAIDTypes}) eq 'ARRAY' && scalar(@{$dg_data->{SupportedRAIDTypes}}) > 0) {
                $raid_type = $dg_data->{SupportedRAIDTypes}->[0];
            }

            # Get drives count from ProvidingDrives
            my $drives_count = 0;
            if (defined($dg_data->{ProvidingDrives}) && ref($dg_data->{ProvidingDrives}) eq 'ARRAY') {
                $drives_count = scalar(@{$dg_data->{ProvidingDrives}});
            }

            # Get IOStatistics
            my $read_io_requests = undef;
            my $write_io_requests = undef;
            my $read_io_bytes = undef;
            my $write_io_bytes = undef;
            if (defined($dg_data->{IOStatistics})) {
                $read_io_requests = $dg_data->{IOStatistics}->{ReadHitIORequests};
                $write_io_requests = $dg_data->{IOStatistics}->{WriteHitIORequests};
                $read_io_bytes = defined($dg_data->{IOStatistics}->{ReadIOKiBytes}) 
                    ? $dg_data->{IOStatistics}->{ReadIOKiBytes} * 1024 : undef;
                $write_io_bytes = defined($dg_data->{IOStatistics}->{WriteIOKiBytes}) 
                    ? $dg_data->{IOStatistics}->{WriteIOKiBytes} * 1024 : undef;
            }

            $self->{diskgroups}->{$dg_full_id} = {
                name              => $dg_name,
                controller        => $controller_id,
                health            => $health,
                state             => $state,
                raid_type         => $raid_type,
                total_space       => $total_space,
                used_space        => $used_space,
                free_space        => $free_space,
                used_prct         => $used_prct,
                remaining_percent => $remaining_percent,
                drives_count      => $drives_count,
                read_io_requests  => $read_io_requests,
                write_io_requests => $write_io_requests,
                read_io_bytes     => $read_io_bytes,
                write_io_bytes    => $write_io_bytes,
            };
            
            $self->{global}->{total}++;
        }
    }

    if (scalar(keys %{$self->{diskgroups}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No disk groups found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA disk groups status via Redfish API.

=over 8

=item B<--filter-controller-id>

Filter by controller id (can be a regexp).

=item B<--filter-diskgroup-id>

Filter by diskgroup id (can be a regexp).

=item B<--filter-diskgroup-name>

Filter by diskgroup name (can be a regexp).

=item B<--exclude-controller-id>

Exclude by controller id (can be a regexp).

=item B<--exclude-diskgroup-id>

Exclude by diskgroup id (can be a regexp).

=item B<--exclude-diskgroup-name>

Exclude by diskgroup name (can be a regexp).

=item B<--warning-diskgroup-status> B<--critical-diskgroup-status>

Set warning/critical threshold for diskgroup status.
Default warning: '%{health} =~ /warning|degraded/i'
Default critical: '%{health} =~ /critical/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'diskgroup-drives-count', 'diskgroup-read-iops', 'diskgroup-read-throughput', 'diskgroup-remaining-capacity', 'diskgroup-space-free-bytes', 'diskgroup-space-usage-bytes', 'diskgroup-space-usage-percentage', 'diskgroup-write-iops', 'diskgroup-write-throughput', 'diskgroups-total'.

=back

=cut
