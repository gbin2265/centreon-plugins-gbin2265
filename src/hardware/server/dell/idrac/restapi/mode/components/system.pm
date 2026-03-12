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

package hardware::server::dell::idrac::restapi::mode::components::system;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking system');
    $self->{components}->{system} = { name => 'system', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'system'));

    my $system = $self->get_system_info();
    return if (!defined($system));

    my $instance = 'System.Embedded.1';
    return if ($self->check_filter(section => 'system', instance => $instance));
    $self->{components}->{system}->{total}++;

    my $hostname     = $system->{HostName} // 'N/A';
    my $model        = $system->{Model} // 'N/A';
    my $manufacturer = $system->{Manufacturer} // 'N/A';
    my $serial       = $system->{SerialNumber} // 'N/A';
    my $sku          = $system->{SKU} // 'N/A';
    my $bios_version = $system->{BiosVersion} // 'N/A';
    my $power_state  = $system->{PowerState} // 'N/A';
    my $service_tag  = 'N/A';
    my $generation   = 'N/A';
    my $os_name      = 'N/A';
    my $os_version   = 'N/A';

    if (defined($system->{Oem}) && defined($system->{Oem}->{Dell}) && defined($system->{Oem}->{Dell}->{DellSystem})) {
        my $dell = $system->{Oem}->{Dell}->{DellSystem};
        $service_tag = $dell->{NodeID} // $service_tag;
        $generation  = $dell->{SystemGeneration} // $generation;
    }

    if (defined($system->{Oem}) && defined($system->{Oem}->{Dell}) && defined($system->{Oem}->{Dell}->{DellOSInformation})) {
        my $os_info = $system->{Oem}->{Dell}->{DellOSInformation};
        $os_name    = $os_info->{OSName} // $os_name;
        $os_version = $os_info->{OSVersion} // $os_version;
    }

    # Fetch iDRAC manager info
    my $manager = $self->get_manager_info();
    my $idrac_version = 'N/A';
    my $idrac_model   = 'N/A';
    if (defined($manager)) {
        $idrac_version = $manager->{FirmwareVersion} // 'N/A';
        $idrac_model   = $manager->{Model} // 'N/A';
    }

    $system->{Status}->{Health} = defined($system->{Status}->{Health}) ? $system->{Status}->{Health} : 'n/a';
    $system->{Status}->{State} = defined($system->{Status}->{State}) ? $system->{Status}->{State} : 'n/a';

    $self->{output}->output_add(
        long_msg => sprintf(
            "system '%s' status is '%s' [instance: %s, state: %s, hostname: %s, model: %s %s, serial: %s, service tag: %s, generation: %s, bios: %s, idrac: %s %s, power: %s, os: %s %s]",
            $instance, $system->{Status}->{Health}, $instance, $system->{Status}->{State},
            $hostname, $manufacturer, $model, $serial, $service_tag, $generation,
            $bios_version, $idrac_model, $idrac_version, $power_state,
            $os_name, $os_version
        )
    );

    my $exit = $self->get_severity(label => 'state', section => 'system.state', value => $system->{Status}->{State});
    if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
        $self->{output}->output_add(
            severity => $exit,
            short_msg => sprintf("System '%s' state is '%s'", $instance, $system->{Status}->{State})
        );
    }

    $exit = $self->get_severity(label => 'status', section => 'system.status', value => $system->{Status}->{Health});
    if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
        $self->{output}->output_add(
            severity => $exit,
            short_msg => sprintf("System '%s' status is '%s'", $instance, $system->{Status}->{Health})
        );
    }
}

1;
