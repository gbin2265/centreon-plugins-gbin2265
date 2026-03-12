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

package centreon::common::redfish::restapi::mode::components::smcraid;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking smartstorage raid volumes');
    $self->{components}->{smcraid} = { name => 'smcraid', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'smcraid'));

    $self->get_smartstorage_controllers() if (!defined($self->{smartstorage_controllers}));
    return if (!defined($self->{smartstorage_controllers}) || scalar(@{$self->{smartstorage_controllers}}) == 0);

    foreach my $controller (@{$self->{smartstorage_controllers}}) {
        my $ctrl_name = defined($controller->{Model}) ? $controller->{Model} : 
                        defined($controller->{Name}) ? $controller->{Name} : 'unknown';
        
        my $ldrives = $self->get_smartstorage_logicaldrives(controller => $controller);
        
        foreach my $ldrive (@$ldrives) {
            my $ldrive_id = defined($ldrive->{Id}) ? $ldrive->{Id} : 'unknown';
            my $name = defined($ldrive->{LogicalDriveName}) ? $ldrive->{LogicalDriveName} : 
                       defined($ldrive->{Name}) ? $ldrive->{Name} : 'Volume' . $ldrive_id;
            my $raid = defined($ldrive->{Raid}) ? $ldrive->{Raid} : '';
            my $capacity_mib = defined($ldrive->{CapacityMiB}) ? $ldrive->{CapacityMiB} : 0;
            my $capacity_gb = $capacity_mib > 0 ? sprintf("%.2f", $capacity_mib / 1024) : '';
            
            my $state = defined($ldrive->{Status}->{State}) ? $ldrive->{Status}->{State} : 'n/a';
            my $health = defined($ldrive->{Status}->{Health}) ? $ldrive->{Status}->{Health} : 'n/a';
            
            # Get DataDrives count
            my $datadrives = $self->get_smartstorage_datadrives(logicaldrive => $ldrive);
            my $datadrives_count = scalar(@$datadrives);
            
            my $instance = $ctrl_name . '.' . $ldrive_id;
            
            next if ($self->check_filter(section => 'smcraid', instance => $instance));
            $self->{components}->{smcraid}->{total}++;

            $self->{output}->output_add(
                long_msg => sprintf(
                    "raid volume '%s/%s' status is '%s' [instance: %s, state: %s, raid: %s, capacity: %s GB, drives: %s]",
                    $ctrl_name, $name, $health, $instance, $state, $raid, $capacity_gb, $datadrives_count
                )
            );
            
            my $exit = $self->get_severity(label => 'state', section => 'smcraid.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("RAID volume '%s/%s' state is '%s'", $ctrl_name, $name, $state)
                );
            }
            
            $exit = $self->get_severity(label => 'status', section => 'smcraid.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("RAID volume '%s/%s' status is '%s'", $ctrl_name, $name, $health)
                );
            }
            
            # Capacity perfdata (in bytes for consistency)
            if ($capacity_mib > 0) {
                my $capacity_bytes = $capacity_mib * 1024 * 1024;
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.smcraid.capacity.bytes',
                    unit => 'B',
                    instances => $name,
                    value => $capacity_bytes,
                    min => 0
                );
            }
            
            # Drive count perfdata
            if ($datadrives_count > 0) {
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.smcraid.drives.count',
                    instances => $name,
                    value => $datadrives_count,
                    min => 0
                );
            }
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check HPE SmartStorage RAID configuration from data drives.
Monitors data drives (physical drives assigned to logical drives)
on HPE SmartStorage controllers. Reports drive state, health,
capacity and drive count per logical drive.

=head2 Redfish Endpoint

/redfish/v1/Systems/1/SmartStorage/ArrayControllers/{ControllerId}/LogicalDrives/{LogicalDriveId}/DataDrives

=head2 Perfdata

hardware.smcraid.capacity.bytes : Drive capacity in bytes
hardware.smcraid.drives.count : Number of data drives per logical drive

=cut
