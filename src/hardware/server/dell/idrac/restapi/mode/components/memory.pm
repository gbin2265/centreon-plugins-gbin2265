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

package hardware::server::dell::idrac::restapi::mode::components::memory;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking memory modules');
    $self->{components}->{memory} = { name => 'memory', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'memory'));

    my $dimms = $self->get_memory();

    foreach my $dimm (@$dimms) {
        my $dimm_name = $dimm->{Id} // $dimm->{Name} // 'unknown';
        my $instance = $dimm_name;

        $dimm->{Status}->{Health} = defined($dimm->{Status}->{Health}) ? $dimm->{Status}->{Health} : 'n/a';
        $dimm->{Status}->{State} = defined($dimm->{Status}->{State}) ? $dimm->{Status}->{State} : 'n/a';
        next if ($self->check_filter(section => 'memory', instance => $instance));
        $self->{components}->{memory}->{total}++;

        my $capacity = $dimm->{CapacityMiB} // 'N/A';
        my $speed = $dimm->{OperatingSpeedMhz} // 'N/A';

        $self->{output}->output_add(
            long_msg => sprintf(
                "memory '%s' status is '%s' [instance: %s, state: %s, capacity: %s MiB, speed: %s MHz]",
                $dimm_name, $dimm->{Status}->{Health}, $instance, $dimm->{Status}->{State},
                $capacity, $speed
            )
        );

        my $exit = $self->get_severity(label => 'state', section => 'memory.state', value => $dimm->{Status}->{State});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Memory '%s' state is '%s'", $dimm_name, $dimm->{Status}->{State})
            );
        }

        $exit = $self->get_severity(label => 'status', section => 'memory.status', value => $dimm->{Status}->{Health});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Memory '%s' status is '%s'", $dimm_name, $dimm->{Status}->{Health})
            );
        }
    }
}

1;
