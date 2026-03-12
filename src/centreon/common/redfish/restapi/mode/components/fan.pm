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

package centreon::common::redfish::restapi::mode::components::fan;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking fans');
    $self->{components}->{fan} = { name => 'fan', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'fan'));

    $self->get_chassis() if (!defined($self->{chassis}));
    return if (!defined($self->{chassis}));

    foreach my $chassis (@{$self->{chassis}}) {
        $chassis->{Thermal}->{result} = $self->get_thermal(chassis => $chassis) if (!defined($chassis->{Thermal}->{result}));
        next if (!defined($chassis->{Thermal}->{result}->{Fans}));

        foreach my $fan (@{$chassis->{Thermal}->{result}->{Fans}}) {
            my $instance = defined($fan->{MemberId}) ? $fan->{MemberId} : 
                          defined($fan->{Id}) ? $fan->{Id} : 'unknown';
            my $name = defined($fan->{Name}) ? $fan->{Name} : 'Fan' . $instance;
            
            my $state = defined($fan->{Status}->{State}) ? $fan->{Status}->{State} : 'n/a';
            my $health = defined($fan->{Status}->{Health}) ? $fan->{Status}->{Health} : 'n/a';
            
            next if ($self->check_filter(section => 'fan', instance => $instance));
            $self->{components}->{fan}->{total}++;

            my $reading = defined($fan->{Reading}) ? $fan->{Reading} : '';
            my $reading_units = defined($fan->{ReadingUnits}) ? $fan->{ReadingUnits} : 'Percent';

            $self->{output}->output_add(
                long_msg => sprintf(
                    "fan '%s' status is '%s' [instance: %s, state: %s, reading: %s %s]",
                    $name, $health, $instance, $state, $reading, $reading_units
                )
            );
            
            my $exit = $self->get_severity(label => 'state', section => 'fan.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Fan '%s' state is '%s'", $name, $state)
                );
            }
            
            $exit = $self->get_severity(label => 'status', section => 'fan.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Fan '%s' status is '%s'", $name, $health)
                );
            }
            
            # Fan speed perfdata
            if (defined($fan->{Reading}) && $fan->{Reading} =~ /\d/) {
                my $unit = '';
                my $nlabel = '';
                my $max = undef;
                
                if ($reading_units =~ /percent/i) {
                    $unit = '%';
                    $nlabel = 'hardware.fan.speed.percentage';
                    $max = 100;
                } elsif ($reading_units =~ /rpm/i) {
                    $unit = 'rpm';
                    $nlabel = 'hardware.fan.speed.rpm';
                } else {
                    # Default to percentage
                    $unit = '%';
                    $nlabel = 'hardware.fan.speed.percentage';
                    $max = 100;
                }
                
                my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(
                    section => 'fan',
                    instance => $instance,
                    value => $fan->{Reading}
                );
                if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
                    $self->{output}->output_add(
                        severity => $exit2,
                        short_msg => sprintf("Fan '%s' speed is %s %s", $name, $fan->{Reading}, $unit)
                    );
                }
                
                $self->{output}->perfdata_add(
                    nlabel => $nlabel,
                    unit => $unit,
                    instances => $instance,
                    value => $fan->{Reading},
                    warning => $warn,
                    critical => $crit,
                    min => 0,
                    max => $max
                );
            }
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check fan status, health and speed.
Monitors fan state, health and reading from the Thermal endpoint.
Supports both RPM and percentage-based fan speed readings.

=head2 Redfish Endpoint

/redfish/v1/Chassis/{ChassisId}/Thermal (Fans array)

=head2 Perfdata

hardware.fan.speed.percentage : Fan speed in percent (when ReadingUnits is Percent)
hardware.fan.speed.rpm : Fan speed in RPM (when ReadingUnits is RPM)

=cut
