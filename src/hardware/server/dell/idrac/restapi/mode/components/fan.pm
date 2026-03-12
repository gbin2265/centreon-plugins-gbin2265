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

package hardware::server::dell::idrac::restapi::mode::components::fan;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking fans');
    $self->{components}->{fan} = { name => 'fans', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'fan'));

    my $thermal = $self->get_thermal();
    return if (!defined($thermal->{Fans}));

    foreach my $fan (@{$thermal->{Fans}}) {
        my $fan_name = $fan->{Name} // $fan->{FanName} // 'unknown';
        my $instance = $fan->{MemberId} // $fan_name;

        $fan->{Status}->{Health} = defined($fan->{Status}->{Health}) ? $fan->{Status}->{Health} : 'n/a';
        $fan->{Status}->{State} = defined($fan->{Status}->{State}) ? $fan->{Status}->{State} : 'n/a';
        next if ($self->check_filter(section => 'fan', instance => $instance));
        $self->{components}->{fan}->{total}++;

        my $reading = $fan->{Reading} // $fan->{ReadingRPM};
        my $reading_units = defined($fan->{ReadingUnits}) ? $fan->{ReadingUnits} : 'RPM';

        $self->{output}->output_add(
            long_msg => sprintf(
                "fan '%s' status is '%s' [instance: %s, state: %s, speed: %s %s]",
                $fan_name, $fan->{Status}->{Health}, $instance, $fan->{Status}->{State},
                $reading, $reading_units
            )
        );

        my $exit = $self->get_severity(label => 'state', section => 'fan.state', value => $fan->{Status}->{State});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Fan '%s' state is '%s'", $fan_name, $fan->{Status}->{State})
            );
        }

        $exit = $self->get_severity(label => 'status', section => 'fan.status', value => $fan->{Status}->{Health});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Fan '%s' status is '%s'", $fan_name, $fan->{Status}->{Health})
            );
        }

        next if (!defined($reading));

        my $perf_unit = lc($reading_units) eq 'percent' ? '%' : 'rpm';
        my $perf_nlabel = lc($reading_units) eq 'percent' ? 'hardware.fan.speed.percentage' : 'hardware.fan.speed.rpm';

        my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(section => 'fan', instance => $instance, value => $reading);
        if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit2,
                short_msg => sprintf("Fan '%s' speed is %s %s", $fan_name, $reading, $perf_unit)
            );
        }
        $self->{output}->perfdata_add(
            unit => $perf_unit,
            nlabel => $perf_nlabel,
            instances => [$fan_name],
            value => $reading,
            warning => $warn,
            critical => $crit,
            min => 0,
            max => lc($reading_units) eq 'percent' ? 100 : undef
        );
    }
}

1;
