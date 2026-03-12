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

package storage::hp::msa2000::restapi::mode::volume;

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

sub custom_capacity_output {
    my ($self, %options) = @_;

    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{capacity});
    return sprintf("capacity: %s", $total_size_value . " " . $total_size_unit);
}

sub prefix_volume_output {
    my ($self, %options) = @_;

    return sprintf(
        "Volume '%s' [Controller: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{controller}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'volumes', type => 1, cb_prefix_output => 'prefix_volume_output', message_multiple => 'All volumes are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'volumes-total', nlabel => 'volumes.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total volumes: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{volumes} = [
        {
            label => 'volume-status',
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
        { label => 'volume-capacity', nlabel => 'volume.capacity.bytes', set => {
                key_values => [ { name => 'capacity' }, { name => 'name' } ],
                closure_custom_output => $self->can('custom_capacity_output'),
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'volume-remaining-capacity', nlabel => 'volume.space.remaining.percentage', set => {
                key_values => [ { name => 'remaining_percent' }, { name => 'name' } ],
                output_template => 'remaining capacity: %d%%',
                perfdatas => [
                    { template => '%d', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'volume-allocated', nlabel => 'volume.space.allocated.bytes', display_ok => 0, set => {
                key_values => [ { name => 'allocated_bytes' }, { name => 'name' } ],
                output_template => 'allocated: %s B',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'volume-consumed', nlabel => 'volume.space.consumed.bytes', display_ok => 0, set => {
                key_values => [ { name => 'consumed_bytes' }, { name => 'name' } ],
                output_template => 'consumed: %s B',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'volume-read-iops', nlabel => 'volume.io.read.requests.count', display_ok => 0, set => {
                key_values => [ { name => 'read_io_requests' }, { name => 'name' } ],
                output_template => 'read IO requests: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'volume-write-iops', nlabel => 'volume.io.write.requests.count', display_ok => 0, set => {
                key_values => [ { name => 'write_io_requests' }, { name => 'name' } ],
                output_template => 'write IO requests: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'volume-read-throughput', nlabel => 'volume.io.read.bytes', display_ok => 0, set => {
                key_values => [ { name => 'read_io_bytes' }, { name => 'name' } ],
                output_template => 'read throughput: %s B',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'volume-write-throughput', nlabel => 'volume.io.write.bytes', display_ok => 0, set => {
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
        'filter-volume-id:s'     => { name => 'filter_volume_id' },
        'filter-volume-name:s'   => { name => 'filter_volume_name' },
        'filter-controller-id:s' => { name => 'filter_controller_id' },
        'exclude-controller-id:s' => { name => 'exclude_controller_id' },
        'exclude-volume-id:s' => { name => 'exclude_volume_id' },
        'exclude-volume-name:s' => { name => 'exclude_volume_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0 };
    $self->{volumes} = {};

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

        next if (!defined($storage_data->{Volumes}) || !defined($storage_data->{Volumes}->{'@odata.id'}));

        my $volumes_result = $options{custom}->request_api(
            url_path => $storage_data->{Volumes}->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($volumes_result) || !defined($volumes_result->{Members}) || ref($volumes_result->{Members}) ne 'ARRAY');

        foreach my $volume_ref (@{$volumes_result->{Members}}) {
            next if (!defined($volume_ref->{'@odata.id'}));
            
            my $volume_data = $options{custom}->request_api(
                url_path => $volume_ref->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($volume_data));

            my $volume_id;
            if (defined($volume_data->{Id})) {
                $volume_id = $volume_data->{Id};
            } elsif ($volume_ref->{'@odata.id'} =~ /\/Volumes\/([^\/]+)/) {
                $volume_id = $1;
            } else {
                next;
            }

            my $volume_name = defined($volume_data->{Name}) ? $volume_data->{Name} : $volume_id;
            my $volume_full_id = $controller_id . '_' . $volume_id;

            if (defined($self->{option_results}->{filter_volume_id}) && $self->{option_results}->{filter_volume_id} ne '' &&
                $volume_id !~ /$self->{option_results}->{filter_volume_id}/) {
                next;
            }


            if (defined($self->{option_results}->{exclude_volume_id}) && $self->{option_results}->{exclude_volume_id} ne '' &&
                $volume_id =~ /$self->{option_results}->{exclude_volume_id}/) {
                next;
            }

            if (defined($self->{option_results}->{filter_volume_name}) && $self->{option_results}->{filter_volume_name} ne '' &&
                $volume_name !~ /$self->{option_results}->{filter_volume_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_volume_name}) && $self->{option_results}->{exclude_volume_name} ne '' &&
                $volume_name =~ /$self->{option_results}->{exclude_volume_name}/) {
                next;
            }

            my $health = 'n/a';
            my $state = 'n/a';
            if (defined($volume_data->{Status})) {
                $health = defined($volume_data->{Status}->{Health}) ? $volume_data->{Status}->{Health} : 'n/a';
                $state = defined($volume_data->{Status}->{State}) ? $volume_data->{Status}->{State} : 'n/a';
            }
            next if ($state =~ /^Absent$/i);

            my $raid_type = defined($volume_data->{RAIDType}) ? $volume_data->{RAIDType} : 'n/a';
            my $capacity = defined($volume_data->{CapacityBytes}) ? $volume_data->{CapacityBytes} : 0;
            my $remaining_percent = defined($volume_data->{RemainingCapacityPercent}) ? $volume_data->{RemainingCapacityPercent} : undef;

            # Get allocated and consumed bytes from Capacity.Data
            my $allocated_bytes = 0;
            my $consumed_bytes = 0;
            if (defined($volume_data->{Capacity}) && defined($volume_data->{Capacity}->{Data})) {
                $allocated_bytes = $volume_data->{Capacity}->{Data}->{AllocatedBytes} || 0;
                $consumed_bytes = $volume_data->{Capacity}->{Data}->{ConsumedBytes} || 0;
            }

            # Get IOStatistics
            my $read_io_requests = undef;
            my $write_io_requests = undef;
            my $read_io_bytes = undef;
            my $write_io_bytes = undef;
            if (defined($volume_data->{IOStatistics})) {
                $read_io_requests = $volume_data->{IOStatistics}->{ReadHitIORequests};
                $write_io_requests = $volume_data->{IOStatistics}->{WriteHitIORequests};
                # Convert KiBytes to Bytes
                $read_io_bytes = defined($volume_data->{IOStatistics}->{ReadIOKiBytes}) 
                    ? $volume_data->{IOStatistics}->{ReadIOKiBytes} * 1024 : undef;
                $write_io_bytes = defined($volume_data->{IOStatistics}->{WriteIOKiBytes}) 
                    ? $volume_data->{IOStatistics}->{WriteIOKiBytes} * 1024 : undef;
            }

            $self->{volumes}->{$volume_full_id} = {
                name              => $volume_name,
                controller        => $controller_id,
                health            => $health,
                state             => $state,
                raid_type         => $raid_type,
                capacity          => $capacity,
                remaining_percent => $remaining_percent,
                allocated_bytes   => $allocated_bytes,
                consumed_bytes    => $consumed_bytes,
                read_io_requests  => $read_io_requests,
                write_io_requests => $write_io_requests,
                read_io_bytes     => $read_io_bytes,
                write_io_bytes    => $write_io_bytes,
            };
            
            $self->{global}->{total}++;
        }
    }

    if (scalar(keys %{$self->{volumes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No volumes found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA volumes status via Redfish API.

=over 8

=item B<--filter-controller-id>

Filter by controller id (can be a regexp).

=item B<--filter-volume-id>

Filter by volume id (can be a regexp).

=item B<--filter-volume-name>

Filter by volume name (can be a regexp).

=item B<--exclude-controller-id>

Exclude by controller id (can be a regexp).

=item B<--exclude-volume-id>

Exclude by volume id (can be a regexp).

=item B<--exclude-volume-name>

Exclude by volume name (can be a regexp).

=item B<--warning-volume-status> B<--critical-volume-status>

Set warning/critical threshold for volume status.
Default warning: '%{health} =~ /warning|degraded/i'
Default critical: '%{health} =~ /critical/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'volume-allocated', 'volume-capacity', 'volume-consumed', 'volume-read-iops', 'volume-read-throughput', 'volume-remaining-capacity', 'volume-write-iops', 'volume-write-throughput', 'volumes-total'.

=back

=cut
