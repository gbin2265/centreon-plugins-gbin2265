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

package centreon::common::redfish::restapi::mode::components::smcenclosure;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking smartstorage enclosures');
    $self->{components}->{smcenclosure} = { name => 'smcenclosure', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'smcenclosure'));

    $self->get_smartstorage_controllers() if (!defined($self->{smartstorage_controllers}));
    return if (!defined($self->{smartstorage_controllers}) || scalar(@{$self->{smartstorage_controllers}}) == 0);

    foreach my $controller (@{$self->{smartstorage_controllers}}) {
        my $ctrl_name = defined($controller->{Model}) ? $controller->{Model} : 
                        defined($controller->{Name}) ? $controller->{Name} : 'unknown';
        
        my $enclosures = $self->get_smartstorage_enclosures(controller => $controller);
        
        foreach my $enc (@$enclosures) {
            my $enc_id = defined($enc->{Id}) ? $enc->{Id} : 'unknown';
            my $name = defined($enc->{Model}) ? $enc->{Model} : 
                      defined($enc->{Name}) ? $enc->{Name} : 'Enclosure' . $enc_id;
            my $serial = defined($enc->{SerialNumber}) ? $enc->{SerialNumber} : '';
            my $location = defined($enc->{Location}) ? $enc->{Location} : '';
            my $drive_bays = defined($enc->{DriveBayCount}) ? $enc->{DriveBayCount} : '';
            
            my $state = defined($enc->{Status}->{State}) ? $enc->{Status}->{State} : 'n/a';
            my $health = defined($enc->{Status}->{Health}) ? $enc->{Status}->{Health} : 'n/a';
            
            my $instance = $ctrl_name . '.' . $enc_id;
            
            next if ($self->check_filter(section => 'smcenclosure', instance => $instance));
            $self->{components}->{smcenclosure}->{total}++;

            $self->{output}->output_add(
                long_msg => sprintf(
                    "storage enclosure '%s/%s' status is '%s' [instance: %s, state: %s, location: %s, serial: %s, bays: %s]",
                    $ctrl_name, $name, $health, $instance, $state, $location, $serial, $drive_bays
                )
            );
            
            my $exit = $self->get_severity(label => 'state', section => 'smcenclosure.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Storage enclosure '%s/%s' state is '%s'", $ctrl_name, $name, $state)
                );
            }
            
            $exit = $self->get_severity(label => 'status', section => 'smcenclosure.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Storage enclosure '%s/%s' status is '%s'", $ctrl_name, $name, $health)
                );
            }
            
            # Drive bay count perfdata (informational)
            if (defined($enc->{DriveBayCount}) && $enc->{DriveBayCount} =~ /\d/) {
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.smcenclosure.drivebays.count',
                    instances => $location ne '' ? $location : $enc_id,
                    value => $enc->{DriveBayCount},
                    min => 0
                );
            }
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check HPE SmartStorage drive enclosures.
Monitors storage enclosures attached to HPE SmartStorage controllers.
Reports enclosure state, health and drive bay count.

=head2 Redfish Endpoint

/redfish/v1/Systems/1/SmartStorage/ArrayControllers/{ControllerId}/StorageEnclosures/{EnclosureId}

=head2 Perfdata

hardware.smcenclosure.drivebays.count : Number of drive bays in enclosure

=cut
