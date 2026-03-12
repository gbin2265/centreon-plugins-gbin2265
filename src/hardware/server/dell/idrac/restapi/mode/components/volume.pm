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

package hardware::server::dell::idrac::restapi::mode::components::volume;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking volumes');
    $self->{components}->{volume} = { name => 'volumes', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'volume'));

    my $storages = $self->get_storages();

    foreach my $storage (@$storages) {
        my $storage_name = $storage->{Id} // 'unknown';

        my $volumes = $self->get_volumes(storage => $storage);

        foreach my $volume (@$volumes) {
            my $volume_name = $volume->{Name} // $volume->{Id} // 'unknown';
            my $instance = $storage_name . '.' . ($volume->{Id} // $volume_name);

            $volume->{Status}->{Health} = defined($volume->{Status}->{Health}) ? $volume->{Status}->{Health} : 'n/a';
            $volume->{Status}->{State} = defined($volume->{Status}->{State}) ? $volume->{Status}->{State} : 'n/a';
            next if ($self->check_filter(section => 'volume', instance => $instance));
            $self->{components}->{volume}->{total}++;

            my $raid_type = $volume->{RAIDType} // $volume->{VolumeType} // 'N/A';

            $self->{output}->output_add(
                long_msg => sprintf(
                    "volume '%s/%s' status is '%s' [instance: %s, state: %s, raid: %s]",
                    $storage_name, $volume_name, $volume->{Status}->{Health}, $instance,
                    $volume->{Status}->{State}, $raid_type
                )
            );

            my $exit = $self->get_severity(label => 'state', section => 'volume.state', value => $volume->{Status}->{State});
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Volume '%s/%s' state is '%s'", $storage_name, $volume_name, $volume->{Status}->{State})
                );
            }

            $exit = $self->get_severity(label => 'status', section => 'volume.status', value => $volume->{Status}->{Health});
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Volume '%s/%s' status is '%s'", $storage_name, $volume_name, $volume->{Status}->{Health})
                );
            }
        }
    }
}

1;
