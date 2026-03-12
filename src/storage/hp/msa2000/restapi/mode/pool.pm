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

package storage::hp::msa2000::restapi::mode::pool;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state}
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

sub prefix_pool_output {
    my ($self, %options) = @_;

    return sprintf(
        "Pool '%s' [Controller: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{controller}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'pools', type => 1, cb_prefix_output => 'prefix_pool_output', message_multiple => 'All pools are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'pools-total', nlabel => 'pools.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total pools: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{pools} = [
        {
            label => 'pool-status',
            type => 2,
            warning_default => '%{health} =~ /warning|degraded/i',
            critical_default => '%{health} =~ /critical/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'controller' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'pool-space-usage-bytes', nlabel => 'pool.space.usage.bytes', set => {
                key_values => [ { name => 'used_space' }, { name => 'free_space' }, { name => 'used_prct' }, { name => 'total_space' }, { name => 'name' } ],
                closure_custom_output => $self->can('custom_space_usage_output'),
                perfdatas => [
                    { template => '%s', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'pool-space-free-bytes', nlabel => 'pool.space.free.bytes', display_ok => 0, set => {
                key_values => [ { name => 'free_space' }, { name => 'total_space' }, { name => 'name' } ],
                output_template => 'free: %s B',
                perfdatas => [
                    { template => '%s', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'pool-space-usage-percentage', nlabel => 'pool.space.usage.percentage', display_ok => 0, set => {
                key_values => [ { name => 'used_prct' }, { name => 'name' } ],
                output_template => 'used: %.2f%%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'pool-remaining-capacity', nlabel => 'pool.space.remaining.percentage', set => {
                key_values => [ { name => 'remaining_percent' }, { name => 'name' } ],
                output_template => 'remaining capacity: %d%%',
                perfdatas => [
                    { template => '%d', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'pool-allocated', nlabel => 'pool.space.allocated.bytes', display_ok => 0, set => {
                key_values => [ { name => 'allocated_bytes' }, { name => 'name' } ],
                output_template => 'allocated: %s B',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'pool-consumed', nlabel => 'pool.space.consumed.bytes', display_ok => 0, set => {
                key_values => [ { name => 'consumed_bytes' }, { name => 'name' } ],
                output_template => 'consumed: %s B',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'pool-read-iops', nlabel => 'pool.io.read.requests.count', display_ok => 0, set => {
                key_values => [ { name => 'read_io_requests' }, { name => 'name' } ],
                output_template => 'read IO requests: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'pool-write-iops', nlabel => 'pool.io.write.requests.count', display_ok => 0, set => {
                key_values => [ { name => 'write_io_requests' }, { name => 'name' } ],
                output_template => 'write IO requests: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'pool-read-throughput', nlabel => 'pool.io.read.bytes', display_ok => 0, set => {
                key_values => [ { name => 'read_io_bytes' }, { name => 'name' } ],
                output_template => 'read throughput: %s B',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'pool-write-throughput', nlabel => 'pool.io.write.bytes', display_ok => 0, set => {
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
        'filter-pool-id:s'       => { name => 'filter_pool_id' },
        'filter-pool-name:s'     => { name => 'filter_pool_name' },
        'filter-controller-id:s' => { name => 'filter_controller_id' },
        'exclude-controller-id:s' => { name => 'exclude_controller_id' },
        'exclude-pool-id:s' => { name => 'exclude_pool_id' },
        'exclude-pool-name:s' => { name => 'exclude_pool_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0 };
    $self->{pools} = {};

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
            
            # Skip disk groups (they have 'dg' in the path)
            next if ($pool_ref->{'@odata.id'} =~ /\/dg[A-Z0-9]+$/i);
            
            my $pool_data = $options{custom}->request_api(
                url_path => $pool_ref->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($pool_data));

            my $pool_id;
            if (defined($pool_data->{Id})) {
                $pool_id = $pool_data->{Id};
            } elsif ($pool_ref->{'@odata.id'} =~ /\/StoragePools\/([^\/]+)/) {
                $pool_id = $1;
            } else {
                next;
            }

            my $pool_name = defined($pool_data->{Name}) ? $pool_data->{Name} : $pool_id;
            my $pool_full_id = $controller_id . '_' . $pool_id;

            if (defined($self->{option_results}->{filter_pool_id}) && $self->{option_results}->{filter_pool_id} ne '' &&
                $pool_id !~ /$self->{option_results}->{filter_pool_id}/) {
                next;
            }


            if (defined($self->{option_results}->{exclude_pool_id}) && $self->{option_results}->{exclude_pool_id} ne '' &&
                $pool_id =~ /$self->{option_results}->{exclude_pool_id}/) {
                next;
            }

            if (defined($self->{option_results}->{filter_pool_name}) && $self->{option_results}->{filter_pool_name} ne '' &&
                $pool_name !~ /$self->{option_results}->{filter_pool_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_pool_name}) && $self->{option_results}->{exclude_pool_name} ne '' &&
                $pool_name =~ /$self->{option_results}->{exclude_pool_name}/) {
                next;
            }

            my $health = 'n/a';
            my $state = 'n/a';
            if (defined($pool_data->{Status})) {
                $health = defined($pool_data->{Status}->{Health}) ? $pool_data->{Status}->{Health} : 'n/a';
                $state = defined($pool_data->{Status}->{State}) ? $pool_data->{Status}->{State} : 'n/a';
            }
            next if ($state =~ /^Absent$/i);

            my $total_space = 0;
            my $used_space = 0;
            my $free_space = 0;
            my $remaining_percent = defined($pool_data->{RemainingCapacityPercent}) ? $pool_data->{RemainingCapacityPercent} : undef;

            if (defined($pool_data->{Capacity}) && defined($pool_data->{Capacity}->{Data})) {
                $total_space = $pool_data->{Capacity}->{Data}->{AllocatedBytes} || 0;
                $used_space = $pool_data->{Capacity}->{Data}->{ConsumedBytes} || 0;
                $free_space = $total_space - $used_space;
            }

            my $used_prct = ($total_space > 0) ? ($used_space * 100 / $total_space) : 0;

            # Get IOStatistics
            my $read_io_requests = undef;
            my $write_io_requests = undef;
            my $read_io_bytes = undef;
            my $write_io_bytes = undef;
            if (defined($pool_data->{IOStatistics})) {
                $read_io_requests = $pool_data->{IOStatistics}->{ReadHitIORequests};
                $write_io_requests = $pool_data->{IOStatistics}->{WriteHitIORequests};
                $read_io_bytes = defined($pool_data->{IOStatistics}->{ReadIOKiBytes}) 
                    ? $pool_data->{IOStatistics}->{ReadIOKiBytes} * 1024 : undef;
                $write_io_bytes = defined($pool_data->{IOStatistics}->{WriteIOKiBytes}) 
                    ? $pool_data->{IOStatistics}->{WriteIOKiBytes} * 1024 : undef;
            }

            $self->{pools}->{$pool_full_id} = {
                name              => $pool_name,
                controller        => $controller_id,
                health            => $health,
                state             => $state,
                total_space       => $total_space,
                used_space        => $used_space,
                free_space        => $free_space,
                used_prct         => $used_prct,
                remaining_percent => $remaining_percent,
                allocated_bytes   => $total_space,
                consumed_bytes    => $used_space,
                read_io_requests  => $read_io_requests,
                write_io_requests => $write_io_requests,
                read_io_bytes     => $read_io_bytes,
                write_io_bytes    => $write_io_bytes,
            };
            
            $self->{global}->{total}++;
        }
    }

    if (scalar(keys %{$self->{pools}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No pools found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA storage pools status via Redfish API.

=over 8

=item B<--filter-controller-id>

Filter by controller id (can be a regexp).

=item B<--filter-pool-id>

Filter by pool id (can be a regexp).

=item B<--filter-pool-name>

Filter by pool name (can be a regexp).

=item B<--exclude-controller-id>

Exclude by controller id (can be a regexp).

=item B<--exclude-pool-id>

Exclude by pool id (can be a regexp).

=item B<--exclude-pool-name>

Exclude by pool name (can be a regexp).

=item B<--warning-pool-status> B<--critical-pool-status>

Set warning/critical threshold for pool status.
Default warning: '%{health} =~ /warning|degraded/i'
Default critical: '%{health} =~ /critical/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'pool-allocated', 'pool-consumed', 'pool-read-iops', 'pool-read-throughput', 'pool-remaining-capacity', 'pool-space-free-bytes', 'pool-space-usage-bytes', 'pool-space-usage-percentage', 'pool-write-iops', 'pool-write-throughput', 'pools-total'.

=back

=cut
