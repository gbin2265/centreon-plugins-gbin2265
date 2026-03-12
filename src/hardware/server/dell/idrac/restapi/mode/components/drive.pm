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

package hardware::server::dell::idrac::restapi::mode::components::drive;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking drives');
    $self->{components}->{drive} = { name => 'drives', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'drive'));

    my $storages = $self->get_storages();

    foreach my $storage (@$storages) {
        my $storage_name = $storage->{Id} // 'unknown';

        next if (!defined($storage->{Drives}));

        foreach my $drive_ref (@{$storage->{Drives}}) {
            my $drive = $self->get_drive(drive => $drive_ref);

            my $drive_name = $drive->{Name} // $drive->{Id} // 'unknown';
            my $instance = $storage_name . '.' . ($drive->{Id} // $drive_name);

            $drive->{Status}->{Health} = defined($drive->{Status}->{Health}) ? $drive->{Status}->{Health} : 'n/a';
            $drive->{Status}->{State} = defined($drive->{Status}->{State}) ? $drive->{Status}->{State} : 'n/a';
            next if ($self->check_filter(section => 'drive', instance => $instance));
            $self->{components}->{drive}->{total}++;

            my $media_type = $drive->{MediaType} // 'N/A';

            $self->{output}->output_add(
                long_msg => sprintf(
                    "drive '%s/%s' status is '%s' [instance: %s, state: %s, media: %s]",
                    $storage_name, $drive_name, $drive->{Status}->{Health}, $instance,
                    $drive->{Status}->{State}, $media_type
                )
            );

            my $exit = $self->get_severity(label => 'state', section => 'drive.state', value => $drive->{Status}->{State});
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Drive '%s/%s' state is '%s'", $storage_name, $drive_name, $drive->{Status}->{State})
                );
            }

            $exit = $self->get_severity(label => 'status', section => 'drive.status', value => $drive->{Status}->{Health});
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Drive '%s/%s' status is '%s'", $storage_name, $drive_name, $drive->{Status}->{Health})
                );
            }

            if (defined($drive->{PredictedMediaLifeLeftPercent})) {
                my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(section => 'drive', instance => $instance, value => $drive->{PredictedMediaLifeLeftPercent});
                if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
                    $self->{output}->output_add(
                        severity => $exit2,
                        short_msg => sprintf("Drive '%s/%s' life left is %s%%", $storage_name, $drive_name, $drive->{PredictedMediaLifeLeftPercent})
                    );
                }
                $self->{output}->perfdata_add(
                    unit => '%',
                    nlabel => 'hardware.drive.lifeleft.percentage',
                    instances => [$storage_name, $drive_name],
                    value => $drive->{PredictedMediaLifeLeftPercent},
                    warning => $warn,
                    critical => $crit,
                    min => 0,
                    max => 100
                );
            }
        }
    }
}

1;
