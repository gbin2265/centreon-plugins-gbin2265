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

package hardware::server::dell::idrac::restapi::mode::components::battery;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking batteries');
    $self->{components}->{battery} = { name => 'batteries', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'battery'));

    my $storages = $self->get_storages();

    foreach my $storage (@$storages) {
        my $storage_id = $storage->{Id};
        next if (!defined($storage_id));
        next if ($storage_id !~ /RAID/i);

        my $battery = $self->{custom}->request_api(
            endpoint => "/redfish/v1/Systems/System.Embedded.1/Storage/$storage_id/Oem/Dell/DellControllerBattery/Battery.Integrated.1:$storage_id",
            ignore_error => 1
        );
        next if (!defined($battery) || !defined($battery->{Id}));

        my $battery_name = $battery->{Name} // $battery->{Id} // 'unknown';
        my $instance = $storage_id . '.' . ($battery->{Id} // $battery_name);

        my $health = $battery->{PrimaryStatus} // $battery->{Status}->{Health} // 'n/a';
        my $state = $battery->{RAIDState} // $battery->{Status}->{State} // 'n/a';
        next if ($self->check_filter(section => 'battery', instance => $instance));
        $self->{components}->{battery}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "battery '%s/%s' status is '%s' [instance: %s, state: %s]",
                $storage_id, $battery_name, $health, $instance, $state
            )
        );

        my $exit = $self->get_severity(label => 'state', section => 'battery.state', value => $state);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Battery '%s/%s' state is '%s'", $storage_id, $battery_name, $state)
            );
        }

        $exit = $self->get_severity(label => 'status', section => 'battery.status', value => $health);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Battery '%s/%s' status is '%s'", $storage_id, $battery_name, $health)
            );
        }
    }
}

1;
