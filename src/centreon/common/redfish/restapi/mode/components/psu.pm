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

package centreon::common::redfish::restapi::mode::components::psu;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking power supplies');
    $self->{components}->{psu} = { name => 'psu', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'psu'));

    $self->get_chassis() if (!defined($self->{chassis}));
    return if (!defined($self->{chassis}));

    # Collect system-wide power metrics from PowerControl
    my $system_power = {};
    
    foreach my $chassis (@{$self->{chassis}}) {
        $chassis->{Power}->{result} = $self->get_power(chassis => $chassis) if (!defined($chassis->{Power}->{result}));
        next if (!defined($chassis->{Power}->{result}));
        
        my $power = $chassis->{Power}->{result};
        
        # Get PowerControl data (system-wide power metrics)
        if (defined($power->{PowerControl}) && ref($power->{PowerControl}) eq 'ARRAY') {
            foreach my $pc (@{$power->{PowerControl}}) {
                if (defined($pc->{PowerConsumedWatts})) {
                    $system_power->{consumed} = $pc->{PowerConsumedWatts};
                }
                if (defined($pc->{PowerCapacityWatts})) {
                    $system_power->{capacity} = $pc->{PowerCapacityWatts};
                }
                if (defined($pc->{PowerMetrics})) {
                    $system_power->{average} = $pc->{PowerMetrics}->{AverageConsumedWatts}
                        if defined($pc->{PowerMetrics}->{AverageConsumedWatts});
                    $system_power->{max} = $pc->{PowerMetrics}->{MaxConsumedWatts}
                        if defined($pc->{PowerMetrics}->{MaxConsumedWatts});
                    $system_power->{min} = $pc->{PowerMetrics}->{MinConsumedWatts}
                        if defined($pc->{PowerMetrics}->{MinConsumedWatts});
                }
            }
        }
        
        # Get individual PSU data
        next if (!defined($power->{PowerSupplies}));
        
        foreach my $psu (@{$power->{PowerSupplies}}) {
            my $instance = defined($psu->{MemberId}) ? $psu->{MemberId} : 
                          defined($psu->{Id}) ? $psu->{Id} : 'unknown';
            my $name = defined($psu->{Name}) ? $psu->{Name} : 'PSU' . $instance;
            
            my $state = defined($psu->{Status}->{State}) ? $psu->{Status}->{State} : 'n/a';
            my $health = defined($psu->{Status}->{Health}) ? $psu->{Status}->{Health} : 'n/a';
            
            next if ($self->check_filter(section => 'psu', instance => $instance));
            $self->{components}->{psu}->{total}++;

            my $model = defined($psu->{Model}) ? $psu->{Model} : '';
            my $manufacturer = defined($psu->{Manufacturer}) ? $psu->{Manufacturer} : '';
            my $serial = defined($psu->{SerialNumber}) ? $psu->{SerialNumber} : '';
            my $capacity = defined($psu->{PowerCapacityWatts}) ? $psu->{PowerCapacityWatts} : '';
            my $output_watts = defined($psu->{LastPowerOutputWatts}) ? $psu->{LastPowerOutputWatts} : '';
            my $input_voltage = defined($psu->{LineInputVoltage}) ? $psu->{LineInputVoltage} : '';

            $self->{output}->output_add(
                long_msg => sprintf(
                    "power supply '%s' status is '%s' [instance: %s, state: %s, model: %s, capacity: %sW, output: %sW, input: %sV]",
                    $name, $health, $instance, $state, $model, $capacity, $output_watts, $input_voltage
                )
            );
            
            my $exit = $self->get_severity(label => 'state', section => 'psu.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Power supply '%s' state is '%s'", $name, $state)
                );
            }
            
            $exit = $self->get_severity(label => 'status', section => 'psu.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Power supply '%s' status is '%s'", $name, $health)
                );
            }
            
            # PSU Output Power perfdata
            if (defined($psu->{LastPowerOutputWatts}) && $psu->{LastPowerOutputWatts} =~ /\d/) {
                my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(
                    section => 'psu.power',
                    instance => $instance,
                    value => $psu->{LastPowerOutputWatts}
                );
                if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
                    $self->{output}->output_add(
                        severity => $exit2,
                        short_msg => sprintf("PSU '%s' power output is %s W", $name, $psu->{LastPowerOutputWatts})
                    );
                }
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.psu.power.output.watts',
                    unit => 'W',
                    instances => $instance,
                    value => $psu->{LastPowerOutputWatts},
                    warning => $warn,
                    critical => $crit,
                    min => 0,
                    max => $psu->{PowerCapacityWatts}
                );
            }
            
            # PSU Input Voltage perfdata
            if (defined($psu->{LineInputVoltage}) && $psu->{LineInputVoltage} =~ /\d/) {
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.psu.voltage.input.volt',
                    unit => 'V',
                    instances => $instance,
                    value => $psu->{LineInputVoltage},
                    min => 0
                );
            }
            
            # HPE OEM: Average and Max power output
            if (defined($psu->{Oem}) && defined($psu->{Oem}->{Hpe})) {
                my $hpe = $psu->{Oem}->{Hpe};
                
                if (defined($hpe->{AveragePowerOutputWatts}) && $hpe->{AveragePowerOutputWatts} =~ /\d/) {
                    $self->{output}->perfdata_add(
                        nlabel => 'hardware.psu.power.output.average.watts',
                        unit => 'W',
                        instances => $instance,
                        value => $hpe->{AveragePowerOutputWatts},
                        min => 0,
                        max => $psu->{PowerCapacityWatts}
                    );
                }
                
                if (defined($hpe->{MaxPowerOutputWatts}) && $hpe->{MaxPowerOutputWatts} =~ /\d/) {
                    $self->{output}->perfdata_add(
                        nlabel => 'hardware.psu.power.output.max.watts',
                        unit => 'W',
                        instances => $instance,
                        value => $hpe->{MaxPowerOutputWatts},
                        min => 0,
                        max => $psu->{PowerCapacityWatts}
                    );
                }
            }
        }
    }
    
    # Add system-wide power metrics
    if (defined($system_power->{consumed}) && $system_power->{consumed} =~ /\d/) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.power.consumed.watts',
            unit => 'W',
            value => $system_power->{consumed},
            min => 0,
            max => $system_power->{capacity}
        );
    }
    
    if (defined($system_power->{average}) && $system_power->{average} =~ /\d/) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.power.average.watts',
            unit => 'W',
            value => $system_power->{average},
            min => 0
        );
    }
    
    if (defined($system_power->{max}) && $system_power->{max} =~ /\d/) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.power.max.watts',
            unit => 'W',
            value => $system_power->{max},
            min => 0
        );
    }
    
    if (defined($system_power->{min}) && $system_power->{min} =~ /\d/) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.power.min.watts',
            unit => 'W',
            value => $system_power->{min},
            min => 0
        );
    }
}


1;

__END__

=head1 DESCRIPTION

Check power supply status, health and power metrics.
Monitors individual PSU state/health, output power, input voltage,
HPE OEM average/max output, and system-wide power consumption
from the Chassis Power endpoint (PowerControl).

=head2 Redfish Endpoint

/redfish/v1/Chassis/{ChassisId}/Power

=head2 Perfdata

hardware.psu.power.output.watts : Per-PSU last power output in watts
hardware.psu.voltage.input.volt : Per-PSU input voltage
hardware.psu.power.output.average.watts : Per-PSU average output (HPE OEM)
hardware.psu.power.output.max.watts : Per-PSU maximum output (HPE OEM)
hardware.power.consumed.watts : System total consumed power
hardware.power.average.watts : System average consumed power
hardware.power.max.watts : System maximum consumed power
hardware.power.min.watts : System minimum consumed power

=cut
