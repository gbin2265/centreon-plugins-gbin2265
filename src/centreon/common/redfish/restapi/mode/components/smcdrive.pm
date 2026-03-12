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

package centreon::common::redfish::restapi::mode::components::smcdrive;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking smartstorage physical drives');
    $self->{components}->{smcdrive} = { name => 'smcdrive', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'smcdrive'));

    $self->get_smartstorage_controllers() if (!defined($self->{smartstorage_controllers}));
    return if (!defined($self->{smartstorage_controllers}) || scalar(@{$self->{smartstorage_controllers}}) == 0);

    foreach my $controller (@{$self->{smartstorage_controllers}}) {
        my $ctrl_name = defined($controller->{Model}) ? $controller->{Model} : 
                        defined($controller->{Name}) ? $controller->{Name} : 'unknown';
        
        my $drives = $self->get_smartstorage_diskdrives(controller => $controller);
        
        foreach my $drive (@$drives) {
            my $drive_id = defined($drive->{Id}) ? $drive->{Id} : 'unknown';
            my $name = defined($drive->{Name}) ? $drive->{Name} : 'Drive' . $drive_id;
            my $location = defined($drive->{Location}) ? $drive->{Location} : '';
            my $serial = defined($drive->{SerialNumber}) ? $drive->{SerialNumber} : '';
            my $model = defined($drive->{Model}) ? $drive->{Model} : '';
            my $media_type = defined($drive->{MediaType}) ? $drive->{MediaType} : '';
            my $interface_type = defined($drive->{InterfaceType}) ? $drive->{InterfaceType} : '';
            my $capacity_gb = defined($drive->{CapacityGB}) ? $drive->{CapacityGB} : 
                              defined($drive->{CapacityMiB}) ? sprintf("%.0f", $drive->{CapacityMiB} / 1024) : '';
            
            my $state = defined($drive->{Status}->{State}) ? $drive->{Status}->{State} : 'n/a';
            my $health = defined($drive->{Status}->{Health}) ? $drive->{Status}->{Health} : 'n/a';
            
            my $instance = $ctrl_name . '.' . $drive_id;
            my $perf_instance = $location ne '' ? $location : $drive_id;
            
            next if ($self->check_filter(section => 'smcdrive', instance => $instance));
            $self->{components}->{smcdrive}->{total}++;

            $self->{output}->output_add(
                long_msg => sprintf(
                    "physical drive '%s/%s' status is '%s' [instance: %s, state: %s, location: %s, type: %s/%s, capacity: %s GB]",
                    $ctrl_name, $name, $health, $instance, $state, $location, $media_type, $interface_type, $capacity_gb
                )
            );
            
            my $exit = $self->get_severity(label => 'state', section => 'smcdrive.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Physical drive '%s/%s' state is '%s'", $ctrl_name, $name, $state)
                );
            }
            
            $exit = $self->get_severity(label => 'status', section => 'smcdrive.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Physical drive '%s/%s' status is '%s'", $ctrl_name, $name, $health)
                );
            }
            
            # Temperature perfdata
            if (defined($drive->{CurrentTemperatureCelsius}) && $drive->{CurrentTemperatureCelsius} =~ /\d/) {
                my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(
                    section => 'smcdrive.temperature',
                    instance => $perf_instance,
                    value => $drive->{CurrentTemperatureCelsius}
                );
                if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
                    $self->{output}->output_add(
                        severity => $exit2,
                        short_msg => sprintf("Drive '%s' temperature is %s C", $perf_instance, $drive->{CurrentTemperatureCelsius})
                    );
                }
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.smcdrive.temperature.celsius',
                    unit => 'C',
                    instances => $perf_instance,
                    value => $drive->{CurrentTemperatureCelsius},
                    warning => $warn,
                    critical => $crit,
                    min => 0,
                    max => $drive->{MaximumTemperatureCelsius}
                );
            }
            
            # SSD Endurance/Wear Level perfdata (only for SSDs)
            if (defined($drive->{SSDEnduranceUtilizationPercentage}) && 
                $drive->{SSDEnduranceUtilizationPercentage} =~ /\d/) {
                my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(
                    section => 'smcdrive.endurance',
                    instance => $perf_instance,
                    value => $drive->{SSDEnduranceUtilizationPercentage}
                );
                if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
                    $self->{output}->output_add(
                        severity => $exit2,
                        short_msg => sprintf("SSD '%s' endurance used is %s%%", $perf_instance, $drive->{SSDEnduranceUtilizationPercentage})
                    );
                }
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.smcdrive.ssd.endurance.percentage',
                    unit => '%',
                    instances => $perf_instance,
                    value => $drive->{SSDEnduranceUtilizationPercentage},
                    warning => $warn,
                    critical => $crit,
                    min => 0,
                    max => 100
                );
            }
            
            # Power On Hours perfdata
            if (defined($drive->{PowerOnHours}) && $drive->{PowerOnHours} =~ /\d/) {
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.smcdrive.power.hours',
                    unit => 'h',
                    instances => $perf_instance,
                    value => $drive->{PowerOnHours},
                    min => 0
                );
            }
            
            # Capacity perfdata (in bytes for consistency)
            if (defined($drive->{CapacityGB}) && $drive->{CapacityGB} =~ /\d/) {
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.smcdrive.capacity.bytes',
                    unit => 'B',
                    instances => $perf_instance,
                    value => $drive->{CapacityGB} * 1000 * 1000 * 1000,
                    min => 0
                );
            }
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check HPE SmartStorage physical disk drives.
Monitors physical drives connected to HPE SmartStorage controllers.
Reports drive state, health, capacity, temperature, power-on hours
and SSD endurance for solid-state drives.

=head2 Redfish Endpoint

/redfish/v1/Systems/1/SmartStorage/ArrayControllers/{ControllerId}/DiskDrives/{DriveId}

=head2 Perfdata

hardware.smcdrive.capacity.bytes : Drive capacity in bytes
hardware.smcdrive.temperature.celsius : Drive temperature in Celsius
hardware.smcdrive.power.hours : Power-on hours
hardware.smcdrive.ssd.endurance.percentage : SSD endurance remaining percentage

=cut
