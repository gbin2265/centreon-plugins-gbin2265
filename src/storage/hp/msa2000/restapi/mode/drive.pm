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

package storage::hp::msa2000::restapi::mode::drive;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    my $output = sprintf(
        "status: %s [state: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state}
    );

    # Add hotspare type if not None
    if (defined($self->{result_values}->{hotspare_type}) && $self->{result_values}->{hotspare_type} !~ /^(None|n\/a)$/i) {
        $output .= sprintf(" [hotspare: %s]", $self->{result_values}->{hotspare_type});
    }

    # Add failure prediction if available
    if (defined($self->{result_values}->{failure_predicted}) && $self->{result_values}->{failure_predicted} eq 'true') {
        $output .= " [FAILURE PREDICTED]";
    }
    
    return $output;
}

sub custom_capacity_output {
    my ($self, %options) = @_;

    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{capacity});
    return sprintf("capacity: %s", $total_size_value . " " . $total_size_unit);
}

sub prefix_drive_output {
    my ($self, %options) = @_;

    return sprintf(
        "Drive '%s' [Controller: %s, Type: %s, Location: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{controller},
        $options{instance_value}->{media_type},
        $options{instance_value}->{location}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'drives', type => 1, cb_prefix_output => 'prefix_drive_output', message_multiple => 'All drives are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'drives-total', nlabel => 'drives.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total drives: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'drives-ok', nlabel => 'drives.ok.count', display_ok => 0, set => {
                key_values => [ { name => 'ok' } ],
                output_template => 'drives ok: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'drives-failed', nlabel => 'drives.failed.count', display_ok => 0, set => {
                key_values => [ { name => 'failed' } ],
                output_template => 'drives failed: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'drives-rebuilding', nlabel => 'drives.rebuilding.count', display_ok => 0, set => {
                key_values => [ { name => 'rebuilding' } ],
                output_template => 'drives rebuilding: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'drives-spare', nlabel => 'drives.spare.count', display_ok => 0, set => {
                key_values => [ { name => 'spare' } ],
                output_template => 'drives spare: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{drives} = [
        {
            label => 'drive-status',
            type => 2,
            warning_default => '%{health} =~ /warning|degraded/i',
            critical_default => '%{health} =~ /critical/i || %{failure_predicted} eq "true"',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'controller' }, { name => 'media_type' }, { name => 'location' },
                    { name => 'failure_predicted' }, { name => 'hotspare_type' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'drive-capacity', nlabel => 'drive.capacity.bytes', set => {
                key_values => [ { name => 'capacity' }, { name => 'name' } ],
                closure_custom_output => $self->can('custom_capacity_output'),
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'drive-temperature', nlabel => 'drive.temperature.celsius', set => {
                key_values => [ { name => 'temperature' }, { name => 'name' } ],
                output_template => 'temperature: %s C',
                perfdatas => [
                    { template => '%s', unit => 'C', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'drive-rotation-speed', nlabel => 'drive.rotation.speed.rpm', display_ok => 0, set => {
                key_values => [ { name => 'rotation_speed_rpm' }, { name => 'name' } ],
                output_template => 'rotation speed: %s RPM',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'rpm', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'drive-negotiated-speed', nlabel => 'drive.negotiated.speed.gbps', display_ok => 0, set => {
                key_values => [ { name => 'negotiated_speed_gbs' }, { name => 'name' } ],
                output_template => 'negotiated speed: %.1f Gb/s',
                perfdatas => [
                    { template => '%.1f', min => 0, unit => 'Gbps', label_extra_instance => 1, instance_use => 'name' }
                ]
            }
        },
        { label => 'drive-operation-progress', nlabel => 'drive.operation.progress.percentage', display_ok => 0, set => {
                key_values => [ { name => 'operation_progress' }, { name => 'operation_type' }, { name => 'name' } ],
                output_template => 'operation progress: %d%%',
                perfdatas => [
                    { template => '%d', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'name' }
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
        'filter-drive-id:s'      => { name => 'filter_drive_id' },
        'filter-drive-name:s'    => { name => 'filter_drive_name' },
        'filter-controller-id:s' => { name => 'filter_controller_id' },
        'filter-enclosure-id:s'  => { name => 'filter_enclosure_id' },
        'exclude-controller-id:s' => { name => 'exclude_controller_id' },
        'exclude-drive-id:s' => { name => 'exclude_drive_id' },
        'exclude-drive-name:s' => { name => 'exclude_drive_name' },
        'exclude-enclosure-id:s' => { name => 'exclude_enclosure_id' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0, ok => 0, failed => 0, rebuilding => 0, spare => 0 };
    $self->{drives} = {};

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

        next if (!defined($storage_data->{Drives}) || ref($storage_data->{Drives}) ne 'ARRAY');

        foreach my $drive_ref (@{$storage_data->{Drives}}) {
            next if (!defined($drive_ref->{'@odata.id'}));
            
            my $drive_data = $options{custom}->request_api(
                url_path => $drive_ref->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($drive_data));

            my $drive_id;
            if (defined($drive_data->{Id})) {
                $drive_id = $drive_data->{Id};
            } elsif ($drive_ref->{'@odata.id'} =~ /\/Drives\/([^\/]+)/) {
                $drive_id = $1;
            } else {
                next;
            }

            my $drive_name = defined($drive_data->{Name}) ? $drive_data->{Name} : $drive_id;
            my $drive_full_id = $controller_id . '_' . $drive_id;

            # Extract location (enclosure.slot format like "1.1")
            my $location = $drive_id;
            my $enclosure_id = '';
            if ($drive_id =~ /^(\d+)\.(\d+)$/) {
                $enclosure_id = $1;
                $location = $drive_id;
            }

            if (defined($self->{option_results}->{filter_drive_id}) && $self->{option_results}->{filter_drive_id} ne '' &&
                $drive_id !~ /$self->{option_results}->{filter_drive_id}/) {
                next;
            }


            if (defined($self->{option_results}->{exclude_drive_id}) && $self->{option_results}->{exclude_drive_id} ne '' &&
                $drive_id =~ /$self->{option_results}->{exclude_drive_id}/) {
                next;
            }

            if (defined($self->{option_results}->{filter_drive_name}) && $self->{option_results}->{filter_drive_name} ne '' &&
                $drive_name !~ /$self->{option_results}->{filter_drive_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_drive_name}) && $self->{option_results}->{exclude_drive_name} ne '' &&
                $drive_name =~ /$self->{option_results}->{exclude_drive_name}/) {
                next;
            }

            if (defined($self->{option_results}->{filter_enclosure_id}) && $self->{option_results}->{filter_enclosure_id} ne '' &&
                $enclosure_id !~ /$self->{option_results}->{filter_enclosure_id}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_enclosure_id}) && $self->{option_results}->{exclude_enclosure_id} ne '' &&
                $enclosure_id =~ /$self->{option_results}->{exclude_enclosure_id}/) {
                next;
            }

            my $health = 'n/a';
            my $state = 'n/a';
            if (defined($drive_data->{Status})) {
                $health = defined($drive_data->{Status}->{Health}) ? $drive_data->{Status}->{Health} : 'n/a';
                $state = defined($drive_data->{Status}->{State}) ? $drive_data->{Status}->{State} : 'n/a';
            }
            next if ($state =~ /^Absent$/i);

            my $media_type = defined($drive_data->{MediaType}) ? $drive_data->{MediaType} : 'n/a';
            my $capacity = defined($drive_data->{CapacityBytes}) ? $drive_data->{CapacityBytes} : 0;
            
            # Get temperature from Oem.Seagate or standard location
            my $temperature = undef;
            if (defined($drive_data->{Oem}) && defined($drive_data->{Oem}->{Seagate}) && 
                defined($drive_data->{Oem}->{Seagate}->{Temperature})) {
                $temperature = $drive_data->{Oem}->{Seagate}->{Temperature};
            }

            # Get rotation speed
            my $rotation_speed_rpm = defined($drive_data->{RotationSpeedRPM}) ? $drive_data->{RotationSpeedRPM} : undef;

            # Get negotiated speed
            my $negotiated_speed_gbs = defined($drive_data->{NegotiatedSpeedGbs}) ? $drive_data->{NegotiatedSpeedGbs} : undef;

            # Get failure prediction
            my $failure_predicted = 'false';
            if (defined($drive_data->{FailurePredicted}) && $drive_data->{FailurePredicted}) {
                $failure_predicted = 'true';
            }

            # Get hotspare type (None, Global, Dedicated, Chassis)
            my $hotspare_type = 'None';
            if (defined($drive_data->{HotspareType})) {
                $hotspare_type = $drive_data->{HotspareType};
            } elsif (defined($drive_data->{StatusIndicator}) && $drive_data->{StatusIndicator} =~ /Hotspare/i) {
                $hotspare_type = 'Global';
            }

            # Get operation progress (VRSC, rebuild, etc.)
            my $operation_progress = undef;
            my $operation_type = undef;
            if (defined($drive_data->{Operations}) && ref($drive_data->{Operations}) eq 'ARRAY' && scalar(@{$drive_data->{Operations}}) > 0) {
                my $op = $drive_data->{Operations}->[0];
                if (defined($op->{PercentageComplete})) {
                    $operation_progress = $op->{PercentageComplete};
                    $operation_type = defined($op->{OperationName}) ? $op->{OperationName} : 'unknown';
                }
            }

            $self->{drives}->{$drive_full_id} = {
                name                 => $drive_name,
                controller           => $controller_id,
                health               => $health,
                state                => $state,
                media_type           => $media_type,
                location             => $location,
                capacity             => $capacity,
                temperature          => $temperature,
                rotation_speed_rpm   => $rotation_speed_rpm,
                negotiated_speed_gbs => $negotiated_speed_gbs,
                failure_predicted    => $failure_predicted,
                hotspare_type        => $hotspare_type,
                operation_progress   => $operation_progress,
                operation_type       => $operation_type,
            };
            
            $self->{global}->{total}++;
            if ($health =~ /^OK$/i) {
                $self->{global}->{ok}++;
            } elsif ($health =~ /fault|failed|critical/i) {
                $self->{global}->{failed}++;
            }
            if ($state =~ /rebuilding/i || (defined($operation_type) && $operation_type =~ /rebuild/i)) {
                $self->{global}->{rebuilding}++;
            }
            if ($hotspare_type !~ /^None$/i) {
                $self->{global}->{spare}++;
            }
        }
    }

    if (scalar(keys %{$self->{drives}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No drives found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA drives status via Redfish API.

=over 8

=item B<--filter-controller-id>

Filter by controller id (can be a regexp).

=item B<--filter-drive-id>

Filter by drive id (can be a regexp).

=item B<--filter-drive-name>

Filter by drive name (can be a regexp).

=item B<--filter-enclosure-id>

Filter by enclosure id (can be a regexp).

=item B<--exclude-controller-id>

Exclude by controller id (can be a regexp).

=item B<--exclude-drive-id>

Exclude by drive id (can be a regexp).

=item B<--exclude-drive-name>

Exclude by drive name (can be a regexp).

=item B<--exclude-enclosure-id>

Exclude by enclosure id (can be a regexp).

=item B<--warning-drive-status> B<--critical-drive-status>

Set warning/critical threshold for drive status.
Available macros: %{health}, %{state}, %{hotspare_type}, %{failure_predicted}, %{media_type}, %{controller}, %{location}.
Default warning: '%{health} =~ /warning|degraded/i'
Default critical: '%{health} =~ /critical/i || %{failure_predicted} eq "true"'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'drive-capacity', 'drive-negotiated-speed', 'drive-operation-progress', 'drive-rotation-speed', 'drive-temperature', 'drives-failed', 'drives-ok', 'drives-rebuilding', 'drives-spare', 'drives-total'.

=back

=cut
