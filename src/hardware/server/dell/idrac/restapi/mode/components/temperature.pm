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

package hardware::server::dell::idrac::restapi::mode::components::temperature;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking temperatures');
    $self->{components}->{temperature} = { name => 'temperatures', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'temperature'));

    my $thermal = $self->get_thermal();
    return if (!defined($thermal->{Temperatures}));

    foreach my $temp (@{$thermal->{Temperatures}}) {
        my $temp_name = $temp->{Name} // 'unknown';
        my $instance = $temp->{MemberId} // $temp_name;

        $temp->{Status}->{Health} = defined($temp->{Status}->{Health}) ? $temp->{Status}->{Health} : 'n/a';
        $temp->{Status}->{State} = defined($temp->{Status}->{State}) ? $temp->{Status}->{State} : 'n/a';
        next if ($self->check_filter(section => 'temperature', instance => $instance));
        $self->{components}->{temperature}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "temperature '%s' status is '%s' [instance: %s, state: %s, value: %s]",
                $temp_name, $temp->{Status}->{Health}, $instance, $temp->{Status}->{State},
                $temp->{ReadingCelsius}
            )
        );

        my $exit = $self->get_severity(label => 'state', section => 'temperature.state', value => $temp->{Status}->{State});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Temperature '%s' state is '%s'", $temp_name, $temp->{Status}->{State})
            );
        }

        $exit = $self->get_severity(label => 'status', section => 'temperature.status', value => $temp->{Status}->{Health});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Temperature '%s' status is '%s'", $temp_name, $temp->{Status}->{Health})
            );
        }

        next if (!defined($temp->{ReadingCelsius}) || $temp->{ReadingCelsius} == 0);

        my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(section => 'temperature', instance => $instance, value => $temp->{ReadingCelsius});
        if ($checked == 0) {
            my $warn_th = defined($temp->{UpperThresholdNonCritical}) ? ':' . $temp->{UpperThresholdNonCritical} : '';
            my $crit_th = defined($temp->{UpperThresholdCritical}) ? ':' . $temp->{UpperThresholdCritical} : '';
            $self->{perfdata}->threshold_validate(label => 'warning-temperature-instance-' . $instance, value => $warn_th);
            $self->{perfdata}->threshold_validate(label => 'critical-temperature-instance-' . $instance, value => $crit_th);
            $warn = $self->{perfdata}->get_perfdata_for_output(label => 'warning-temperature-instance-' . $instance);
            $crit = $self->{perfdata}->get_perfdata_for_output(label => 'critical-temperature-instance-' . $instance);
        }

        if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit2,
                short_msg => sprintf("Temperature '%s' is %s C", $temp_name, $temp->{ReadingCelsius})
            );
        }
        $self->{output}->perfdata_add(
            unit => 'C',
            nlabel => 'hardware.temperature.celsius',
            instances => [$temp_name],
            value => $temp->{ReadingCelsius},
            warning => $warn,
            critical => $crit
        );
    }
}

1;
