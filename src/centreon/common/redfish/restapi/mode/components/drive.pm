#
# Copyright 2026-Present Centreon (http://www.centreon.com/)
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

package centreon::common::redfish::restapi::mode::components::drive;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking drives');
    $self->{components}->{drive} = { name => 'drive', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'drive'));

    $self->get_storages() if (!defined($self->{storages}));
    return if (!defined($self->{storages}));

    foreach my $storage (@{$self->{storages}}) {
        my $storage_name = defined($storage->{Name}) ? $storage->{Name} : 
                          defined($storage->{Id}) ? $storage->{Id} : 'unknown';
        
        next if (!defined($storage->{Drives}));
        
        foreach my $drive_ref (@{$storage->{Drives}}) {
            my $drive = $self->get_drive(drive => $drive_ref);
            next if (!defined($drive) || !defined($drive->{Id}));
            
            my $instance = $storage_name . '.' . $drive->{Id};
            my $name = defined($drive->{Name}) ? $drive->{Name} : 'Drive' . $drive->{Id};
            
            my $state = defined($drive->{Status}->{State}) ? $drive->{Status}->{State} : 'n/a';
            my $health = defined($drive->{Status}->{Health}) ? $drive->{Status}->{Health} : 'n/a';
            
            next if ($self->check_filter(section => 'drive', instance => $instance));
            $self->{components}->{drive}->{total}++;

            my $model = defined($drive->{Model}) ? $drive->{Model} : '';
            my $serial = defined($drive->{SerialNumber}) ? $drive->{SerialNumber} : '';
            my $media_type = defined($drive->{MediaType}) ? $drive->{MediaType} : '';
            my $capacity_bytes = defined($drive->{CapacityBytes}) ? $drive->{CapacityBytes} : '';
            my $capacity_gb = $capacity_bytes ne '' ? sprintf("%.0f", $capacity_bytes / 1000000000) : '';
            my $protocol = defined($drive->{Protocol}) ? $drive->{Protocol} : '';
            my $location = '';
            if (defined($drive->{PhysicalLocation}) && defined($drive->{PhysicalLocation}->{PartLocation})) {
                $location = $drive->{PhysicalLocation}->{PartLocation}->{ServiceLabel} || '';
            }

            $self->{output}->output_add(
                long_msg => sprintf(
                    "drive '%s' status is '%s' [instance: %s, state: %s, model: %s, type: %s/%s, capacity: %s GB, location: %s]",
                    $name, $health, $instance, $state, $model, $media_type, $protocol, $capacity_gb, $location
                )
            );
            
            my $exit = $self->get_severity(label => 'state', section => 'drive.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Drive '%s' state is '%s'", $name, $state)
                );
            }
            
            $exit = $self->get_severity(label => 'status', section => 'drive.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Drive '%s' status is '%s'", $name, $health)
                );
            }
            
            # Failure Predicted warning
            if (defined($drive->{FailurePredicted}) && $drive->{FailurePredicted}) {
                $self->{output}->output_add(
                    severity => 'WARNING',
                    short_msg => sprintf("Drive '%s' failure predicted!", $name)
                );
            }
            
            # Create a clean instance name for perfdata
            my $perf_instance = $drive->{Id};
            if ($location ne '') {
                $perf_instance = $location;
                $perf_instance =~ s/[^a-zA-Z0-9\-_:]/_/g;
            }
            
            # Capacity perfdata
            if (defined($drive->{CapacityBytes}) && $drive->{CapacityBytes} =~ /\d/) {
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.drive.capacity.bytes',
                    unit => 'B',
                    instances => $perf_instance,
                    value => $drive->{CapacityBytes},
                    min => 0
                );
            }
            
            # SSD Life Left (PredictedMediaLifeLeftPercent)
            if (defined($drive->{PredictedMediaLifeLeftPercent}) && 
                $drive->{PredictedMediaLifeLeftPercent} =~ /\d/) {
                my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(
                    section => 'drive.lifeleft',
                    instance => $perf_instance,
                    value => $drive->{PredictedMediaLifeLeftPercent}
                );
                if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
                    $self->{output}->output_add(
                        severity => $exit2,
                        short_msg => sprintf("Drive '%s' life left is %s%%", $name, $drive->{PredictedMediaLifeLeftPercent})
                    );
                }
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.drive.lifeleft.percentage',
                    unit => '%',
                    instances => $perf_instance,
                    value => $drive->{PredictedMediaLifeLeftPercent},
                    warning => $warn,
                    critical => $crit,
                    min => 0,
                    max => 100
                );
            }
            
            # Try to get DriveMetrics if available
            my $metrics = $self->get_drive_metrics(drive => $drive);
            if (defined($metrics)) {
                # Power On Hours
                if (defined($metrics->{PowerOnHours}) && $metrics->{PowerOnHours} =~ /\d/) {
                    $self->{output}->perfdata_add(
                        nlabel => 'hardware.drive.power.hours',
                        unit => 'h',
                        instances => $perf_instance,
                        value => $metrics->{PowerOnHours},
                        min => 0
                    );
                }
                
                # Bad Block Count
                if (defined($metrics->{BadBlockCount}) && $metrics->{BadBlockCount} =~ /\d/) {
                    $self->{output}->perfdata_add(
                        nlabel => 'hardware.drive.badblocks.count',
                        instances => $perf_instance,
                        value => $metrics->{BadBlockCount},
                        min => 0
                    );
                }
                
                # Uncorrectable Read Errors
                if (defined($metrics->{UncorrectableIOReadErrorCount}) && 
                    $metrics->{UncorrectableIOReadErrorCount} =~ /\d/) {
                    $self->{output}->perfdata_add(
                        nlabel => 'hardware.drive.errors.read.uncorrectable.count',
                        instances => $perf_instance,
                        value => $metrics->{UncorrectableIOReadErrorCount},
                        min => 0
                    );
                }
                
                # Uncorrectable Write Errors
                if (defined($metrics->{UncorrectableIOWriteErrorCount}) && 
                    $metrics->{UncorrectableIOWriteErrorCount} =~ /\d/) {
                    $self->{output}->perfdata_add(
                        nlabel => 'hardware.drive.errors.write.uncorrectable.count',
                        instances => $perf_instance,
                        value => $metrics->{UncorrectableIOWriteErrorCount},
                        min => 0
                    );
                }
            }
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check physical drive status, health and metrics.
Monitors drive state, health, failure prediction, capacity,
life remaining, and drive metrics (power-on hours, bad blocks,
uncorrectable errors) from Redfish Storage endpoints.

=head2 Redfish Endpoint

/redfish/v1/Systems/{SystemId}/Storage/{StorageId}/Drives/{DriveId}

=head2 Perfdata

hardware.drive.capacity.bytes : Drive capacity in bytes
hardware.drive.lifeleft.percentage : Predicted life remaining percentage
hardware.drive.power.hours : Power-on hours (from DriveMetrics)
hardware.drive.badblocks.count : Bad block count (from DriveMetrics)
hardware.drive.errors.read.uncorrectable.count : Uncorrectable read errors
hardware.drive.errors.write.uncorrectable.count : Uncorrectable write errors

=cut
