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

package hardware::server::dell::idrac::restapi::mode::components::voltage;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking voltages');
    $self->{components}->{voltage} = { name => 'voltages', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'voltage'));

    my $sensors = $self->get_sensors();

    foreach my $sensor (@$sensors) {
        next if (!defined($sensor->{ReadingType}) || $sensor->{ReadingType} ne 'Voltage');

        my $sensor_name = $sensor->{Name} // 'unknown';
        my $instance = $sensor->{Id} // $sensor_name;

        $sensor->{Status}->{Health} = defined($sensor->{Status}->{Health}) ? $sensor->{Status}->{Health} : 'n/a';
        $sensor->{Status}->{State} = defined($sensor->{Status}->{State}) ? $sensor->{Status}->{State} : 'n/a';
        next if ($self->check_filter(section => 'voltage', instance => $instance));
        $self->{components}->{voltage}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "voltage '%s' status is '%s' [instance: %s, state: %s, value: %s V]",
                $sensor_name, $sensor->{Status}->{Health}, $instance, $sensor->{Status}->{State},
                $sensor->{Reading}
            )
        );

        my $exit = $self->get_severity(label => 'state', section => 'voltage.state', value => $sensor->{Status}->{State});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Voltage '%s' state is '%s'", $sensor_name, $sensor->{Status}->{State})
            );
        }

        $exit = $self->get_severity(label => 'status', section => 'voltage.status', value => $sensor->{Status}->{Health});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Voltage '%s' status is '%s'", $sensor_name, $sensor->{Status}->{Health})
            );
        }

        next if (!defined($sensor->{Reading}));

        my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(section => 'voltage', instance => $instance, value => $sensor->{Reading});
        if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit2,
                short_msg => sprintf("Voltage '%s' is %s V", $sensor_name, $sensor->{Reading})
            );
        }
        $self->{output}->perfdata_add(
            unit => 'V',
            nlabel => 'hardware.voltage.volt',
            instances => [$sensor_name],
            value => $sensor->{Reading},
            warning => $warn,
            critical => $crit
        );
    }
}

1;
