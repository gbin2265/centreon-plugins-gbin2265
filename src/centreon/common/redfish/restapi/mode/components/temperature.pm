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

package centreon::common::redfish::restapi::mode::components::temperature;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking temperatures');
    $self->{components}->{temperature} = { name => 'temperature', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'temperature'));

    $self->get_chassis() if (!defined($self->{chassis}));
    return if (!defined($self->{chassis}));

    foreach my $chassis (@{$self->{chassis}}) {
        $chassis->{Thermal}->{result} = $self->get_thermal(chassis => $chassis) if (!defined($chassis->{Thermal}->{result}));
        next if (!defined($chassis->{Thermal}->{result}->{Temperatures}));

        foreach my $temp (@{$chassis->{Thermal}->{result}->{Temperatures}}) {
            my $instance = defined($temp->{MemberId}) ? $temp->{MemberId} : 
                          defined($temp->{Id}) ? $temp->{Id} : 'unknown';
            my $name = defined($temp->{Name}) ? $temp->{Name} : 'Sensor' . $instance;
            
            my $state = defined($temp->{Status}->{State}) ? $temp->{Status}->{State} : 'n/a';
            my $health = defined($temp->{Status}->{Health}) ? $temp->{Status}->{Health} : 'n/a';
            
            next if ($self->check_filter(section => 'temperature', instance => $instance));
            $self->{components}->{temperature}->{total}++;

            my $reading = defined($temp->{ReadingCelsius}) ? $temp->{ReadingCelsius} : '';
            my $context = defined($temp->{PhysicalContext}) ? $temp->{PhysicalContext} : '';
            my $critical = defined($temp->{UpperThresholdCritical}) ? $temp->{UpperThresholdCritical} : '';
            my $fatal = defined($temp->{UpperThresholdFatal}) ? $temp->{UpperThresholdFatal} : '';

            $self->{output}->output_add(
                long_msg => sprintf(
                    "temperature '%s' is %s C [instance: %s, state: %s, context: %s, critical: %s, fatal: %s]",
                    $name, $reading, $instance, $state, $context, $critical, $fatal
                )
            );
            
            my $exit = $self->get_severity(label => 'state', section => 'temperature.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Temperature '%s' state is '%s'", $name, $state)
                );
            }
            
            $exit = $self->get_severity(label => 'status', section => 'temperature.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Temperature '%s' status is '%s'", $name, $health)
                );
            }
            
            # Temperature perfdata
            if (defined($temp->{ReadingCelsius}) && $temp->{ReadingCelsius} =~ /\d/) {
                # Determine thresholds from sensor data
                my $warn_threshold = undef;
                my $crit_threshold = undef;
                
                # Use UpperThresholdCritical as critical threshold if available
                if (defined($temp->{UpperThresholdCritical}) && $temp->{UpperThresholdCritical} =~ /\d/) {
                    $crit_threshold = $temp->{UpperThresholdCritical};
                }
                
                # Check for user-defined thresholds
                my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(
                    section => 'temperature',
                    instance => $instance,
                    value => $temp->{ReadingCelsius}
                );
                
                if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
                    $self->{output}->output_add(
                        severity => $exit2,
                        short_msg => sprintf("Temperature '%s' is %s C", $name, $temp->{ReadingCelsius})
                    );
                }
                
                # Clean instance name for perfdata (remove special chars)
                my $perf_instance = $name;
                $perf_instance =~ s/[^a-zA-Z0-9\-_]/_/g;
                
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.temperature.celsius',
                    unit => 'C',
                    instances => $perf_instance,
                    value => $temp->{ReadingCelsius},
                    warning => $warn,
                    critical => $crit,
                    min => 0,
                    max => $temp->{UpperThresholdFatal}
                );
            }
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check temperature sensor status, health and readings.
Monitors temperature sensors from the Thermal endpoint with
PhysicalContext information and sensor thresholds.

=head2 Redfish Endpoint

/redfish/v1/Chassis/{ChassisId}/Thermal (Temperatures array)

=head2 Perfdata

hardware.temperature.celsius : Temperature reading in Celsius

=cut
