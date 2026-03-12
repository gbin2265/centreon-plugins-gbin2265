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

package centreon::common::redfish::restapi::mode::components::smcldrive;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking smartstorage logical drives');
    $self->{components}->{smcldrive} = { name => 'smcldrive', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'smcldrive'));

    $self->get_smartstorage_controllers() if (!defined($self->{smartstorage_controllers}));
    return if (!defined($self->{smartstorage_controllers}) || scalar(@{$self->{smartstorage_controllers}}) == 0);

    foreach my $controller (@{$self->{smartstorage_controllers}}) {
        my $ctrl_name = defined($controller->{Model}) ? $controller->{Model} : 
                        defined($controller->{Name}) ? $controller->{Name} : 'unknown';
        
        my $logicaldrives = $self->get_smartstorage_logicaldrives(controller => $controller);
        
        foreach my $ld (@$logicaldrives) {
            my $ld_id = defined($ld->{Id}) ? $ld->{Id} : 'unknown';
            my $name = defined($ld->{LogicalDriveName}) ? $ld->{LogicalDriveName} : 
                      defined($ld->{Name}) ? $ld->{Name} : 'LD' . $ld_id;
            my $raid = defined($ld->{Raid}) ? $ld->{Raid} : '';
            my $media_type = defined($ld->{MediaType}) ? $ld->{MediaType} : '';
            my $capacity_mib = defined($ld->{CapacityMiB}) ? $ld->{CapacityMiB} : '';
            my $capacity_gb = $capacity_mib ne '' ? sprintf("%.0f", $capacity_mib / 1024) : '';
            
            my $state = defined($ld->{Status}->{State}) ? $ld->{Status}->{State} : 'n/a';
            my $health = defined($ld->{Status}->{Health}) ? $ld->{Status}->{Health} : 'n/a';
            
            my $instance = $ctrl_name . '.' . $ld_id;
            
            next if ($self->check_filter(section => 'smcldrive', instance => $instance));
            $self->{components}->{smcldrive}->{total}++;

            $self->{output}->output_add(
                long_msg => sprintf(
                    "logical drive '%s/%s' status is '%s' [instance: %s, state: %s, raid: %s, type: %s, capacity: %s GB]",
                    $ctrl_name, $name, $health, $instance, $state, $raid, $media_type, $capacity_gb
                )
            );
            
            my $exit = $self->get_severity(label => 'state', section => 'smcldrive.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Logical drive '%s/%s' state is '%s'", $ctrl_name, $name, $state)
                );
            }
            
            $exit = $self->get_severity(label => 'status', section => 'smcldrive.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Logical drive '%s/%s' status is '%s'", $ctrl_name, $name, $health)
                );
            }
            
            # Capacity perfdata
            if (defined($ld->{CapacityMiB}) && $ld->{CapacityMiB} =~ /\d/) {
                my $capacity_bytes = $ld->{CapacityMiB} * 1024 * 1024;
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.smcldrive.capacity.bytes',
                    unit => 'B',
                    instances => $name,
                    value => $capacity_bytes,
                    min => 0
                );
            }
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check HPE SmartStorage logical drives (RAID volumes).
Monitors logical drives on HPE SmartStorage controllers.
Reports RAID level, state, health and capacity.

=head2 Redfish Endpoint

/redfish/v1/Systems/1/SmartStorage/ArrayControllers/{ControllerId}/LogicalDrives/{LogicalDriveId}

=head2 Perfdata

hardware.smcldrive.capacity.bytes : Logical drive capacity in bytes

=cut
