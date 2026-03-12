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

package centreon::common::redfish::restapi::mode::components::firmware;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking firmware inventory');
    $self->{components}->{firmware} = { name => 'firmware', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'firmware'));

    # Get firmware inventory
    $self->get_firmware_inventory() if (!defined($self->{firmware_inventory}));
    return if (!defined($self->{firmware_inventory}) || scalar(@{$self->{firmware_inventory}}) == 0);

    my $fw_count = 0;
    my $fw_ok = 0;
    my $fw_warning = 0;
    my $fw_critical = 0;
    
    foreach my $firmware (@{$self->{firmware_inventory}}) {
        my $fw_id = defined($firmware->{Id}) ? $firmware->{Id} : 'unknown';
        my $fw_name = defined($firmware->{Name}) ? $firmware->{Name} : 'Firmware' . $fw_id;
        my $version = defined($firmware->{Version}) ? $firmware->{Version} : 'n/a';
        my $updateable = defined($firmware->{Updateable}) ? ($firmware->{Updateable} ? 'Yes' : 'No') : 'n/a';
        
        my $state = defined($firmware->{Status}->{State}) ? $firmware->{Status}->{State} : 'n/a';
        my $health = defined($firmware->{Status}->{Health}) ? $firmware->{Status}->{Health} : 'n/a';
        
        my $instance = $fw_id;
        next if ($self->check_filter(section => 'firmware', instance => $instance));
        $self->{components}->{firmware}->{total}++;
        $fw_count++;
        
        # Count by health status
        if ($health eq 'OK') {
            $fw_ok++;
        } elsif ($health eq 'Warning') {
            $fw_warning++;
        } elsif ($health eq 'Critical') {
            $fw_critical++;
        }
        
        # Get additional info
        my $manufacturer = defined($firmware->{Manufacturer}) ? $firmware->{Manufacturer} : '';
        my $description = defined($firmware->{Description}) ? $firmware->{Description} : '';
        my $release_date = defined($firmware->{ReleaseDate}) ? $firmware->{ReleaseDate} : '';
        
        $self->{output}->output_add(
            long_msg => sprintf(
                "firmware '%s' version '%s' [instance: %s, state: %s, health: %s, updateable: %s]",
                $fw_name, $version, $instance, $state, $health, $updateable
            )
        );
        
        # Only alert on non-OK health status
        if ($health ne 'n/a' && $health ne 'OK') {
            my $exit = $self->get_severity(label => 'status', section => 'firmware.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Firmware '%s' (version: %s) health is '%s'", $fw_name, $version, $health)
                );
            }
        }
        
        # Check for disabled/absent state
        if ($state ne 'n/a' && $state ne 'Enabled' && $state ne 'StandbyOffline') {
            my $exit = $self->get_severity(label => 'state', section => 'firmware.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Firmware '%s' state is '%s'", $fw_name, $state)
                );
            }
        }
    }
    
    # Summary perfdata
    if ($fw_count > 0) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.firmware.components.count',
            value => $fw_count,
            min => 0
        );
        
        $self->{output}->perfdata_add(
            nlabel => 'hardware.firmware.components.ok.count',
            value => $fw_ok,
            min => 0,
            max => $fw_count
        );
        
        if ($fw_warning > 0 || $fw_critical > 0) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.firmware.components.warning.count',
                value => $fw_warning,
                warning => '0:0',
                min => 0,
                max => $fw_count
            );
            
            $self->{output}->perfdata_add(
                nlabel => 'hardware.firmware.components.critical.count',
                value => $fw_critical,
                critical => '0:0',
                min => 0,
                max => $fw_count
            );
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check firmware inventory status and health.
Queries the Redfish UpdateService FirmwareInventory to check the state
and health of all firmware components. Reports counts of components
in OK, Warning and Critical states.

=head2 Redfish Endpoint

/redfish/v1/UpdateService/FirmwareInventory/{SoftwareInventoryId}

=head2 Perfdata

hardware.firmware.components.count : Total firmware components
hardware.firmware.components.ok.count : Components with OK status
hardware.firmware.components.warning.count : Components with Warning status
hardware.firmware.components.critical.count : Components with Critical status

=cut
