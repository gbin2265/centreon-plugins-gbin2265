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

package centreon::common::redfish::restapi::mode::components::system;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking system');
    $self->{components}->{system} = { name => 'system', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'system'));

    $self->get_systems() if (!defined($self->{systems}));
    return if (!defined($self->{systems}) || scalar(@{$self->{systems}}) == 0);

    foreach my $system (@{$self->{systems}}) {
        my $instance = defined($system->{Id}) ? $system->{Id} : 'unknown';
        my $name = defined($system->{Name}) ? $system->{Name} : 'System' . $instance;

        my $state = defined($system->{Status}->{State}) ? $system->{Status}->{State} : 'n/a';
        my $health = defined($system->{Status}->{Health}) ? $system->{Status}->{Health} : 'n/a';

        next if ($self->check_filter(section => 'system', instance => $instance));
        $self->{components}->{system}->{total}++;

        my $manufacturer = defined($system->{Manufacturer}) ? $system->{Manufacturer} : '';
        my $model = defined($system->{Model}) ? $system->{Model} : '';
        my $serial = defined($system->{SerialNumber}) ? $system->{SerialNumber} : '';
        my $sku = defined($system->{SKU}) ? $system->{SKU} : '';
        my $bios = defined($system->{BiosVersion}) ? $system->{BiosVersion} : '';
        my $hostname = defined($system->{HostName}) ? $system->{HostName} : '';
        my $power_state = defined($system->{PowerState}) ? $system->{PowerState} : '';
        my $uuid = defined($system->{UUID}) ? $system->{UUID} : '';
        my $indicator_led = defined($system->{IndicatorLED}) ? $system->{IndicatorLED} : '';
        my $asset_tag = defined($system->{AssetTag}) ? $system->{AssetTag} : '';

        # Memory and processor summary from Systems resource
        my $total_memory_gib = '';
        if (defined($system->{MemorySummary}) && defined($system->{MemorySummary}->{TotalSystemMemoryGiB})) {
            $total_memory_gib = $system->{MemorySummary}->{TotalSystemMemoryGiB};
        }
        my $processor_count = '';
        my $processor_model = '';
        if (defined($system->{ProcessorSummary})) {
            $processor_count = $system->{ProcessorSummary}->{Count} if defined($system->{ProcessorSummary}->{Count});
            $processor_model = $system->{ProcessorSummary}->{Model} if defined($system->{ProcessorSummary}->{Model});
        }

        # HPE OEM: Host OS info (requires AMS/Agentless Management Service)
        my $os_name = '';
        my $os_version = '';
        my $os_description = '';
        if (defined($system->{Oem}) && defined($system->{Oem}->{Hpe}) && defined($system->{Oem}->{Hpe}->{HostOS})) {
            my $host_os = $system->{Oem}->{Hpe}->{HostOS};
            $os_name = $host_os->{OsName} if defined($host_os->{OsName});
            $os_version = $host_os->{OsVersion} if defined($host_os->{OsVersion});
            $os_description = $host_os->{OsSysDescription} if defined($host_os->{OsSysDescription});
        }

        $self->{output}->output_add(
            long_msg => sprintf(
                "system '%s' status is '%s' [instance: %s, state: %s, manufacturer: %s, model: %s, serial: %s, bios: %s, hostname: %s, power: %s]",
                $name, $health, $instance, $state, $manufacturer, $model, $serial, $bios, $hostname, $power_state
            )
        );

        if ($os_name ne '') {
            $self->{output}->output_add(
                long_msg => sprintf(
                    "  host os: %s %s [%s]",
                    $os_name, $os_version, $os_description
                )
            );
        }

        if ($processor_model ne '') {
            $self->{output}->output_add(
                long_msg => sprintf(
                    "  processor summary: %sx %s, memory: %s GiB",
                    $processor_count, $processor_model, $total_memory_gib
                )
            );
        }

        my $exit = $self->get_severity(label => 'state', section => 'system.state', value => $state);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("System '%s' state is '%s'", $name, $state)
            );
        }

        $exit = $self->get_severity(label => 'status', section => 'system.status', value => $health);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("System '%s' status is '%s'", $name, $health)
            );
        }

        # Memory summary perfdata
        if ($total_memory_gib ne '' && $total_memory_gib =~ /\d/) {
            my $total_bytes = $total_memory_gib * 1073741824;
            $self->{output}->perfdata_add(
                nlabel => 'hardware.system.memory.total.bytes',
                unit => 'B',
                instances => $instance,
                value => $total_bytes,
                min => 0
            );
        }

        # Processor count perfdata
        if ($processor_count ne '' && $processor_count =~ /\d/) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.system.processors.count',
                instances => $instance,
                value => $processor_count,
                min => 0
            );
        }
    }
}

1;

__END__

=head1 DESCRIPTION

Check system information, status and host OS details.
Monitors the Redfish Systems resource for overall system status,
hardware identification (manufacturer, model, serial, BIOS version),
host OS information (via HPE OEM Agentless Management Service),
and processor/memory summary data.

=head2 Redfish Endpoint

/redfish/v1/Systems/{SystemId}

=head2 Perfdata

hardware.system.memory.total.bytes : Total system memory from MemorySummary in bytes
hardware.system.processors.count : Processor count from ProcessorSummary

=cut
