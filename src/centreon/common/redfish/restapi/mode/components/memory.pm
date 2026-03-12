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

package centreon::common::redfish::restapi::mode::components::memory;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking memory');
    $self->{components}->{memory} = { name => 'memory', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'memory'));

    # Get memory summary from Systems
    $self->get_systems() if (!defined($self->{systems}));
    
    my $total_memory_gib = 0;
    my $dimms_present = 0;
    my $dimms_total = 0;
    
    foreach my $system (@{$self->{systems}}) {
        my $system_id = $system->{Id};
        my $system_name = defined($system->{Name}) ? $system->{Name} : 'System' . $system_id;
        
        # Get memory summary
        if (defined($system->{MemorySummary})) {
            my $mem_summary = $system->{MemorySummary};
            $total_memory_gib = $mem_summary->{TotalSystemMemoryGiB} if defined($mem_summary->{TotalSystemMemoryGiB});
            
            my $health = defined($mem_summary->{Status}->{HealthRollup}) ? $mem_summary->{Status}->{HealthRollup} : 
                        defined($mem_summary->{Status}->{Health}) ? $mem_summary->{Status}->{Health} : 'n/a';
            
            my $instance = $system_id . '.summary';
            next if ($self->check_filter(section => 'memory', instance => $instance));
            $self->{components}->{memory}->{total}++;
            
            $self->{output}->output_add(
                long_msg => sprintf(
                    "memory summary '%s' status is '%s' [total: %s GiB]",
                    $system_name, $health, $total_memory_gib
                )
            );
            
            my $exit = $self->get_severity(label => 'status', section => 'memory.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Memory summary '%s' status is '%s'", $system_name, $health)
                );
            }
            
            # Total memory perfdata
            if ($total_memory_gib > 0) {
                my $total_bytes = $total_memory_gib * 1024 * 1024 * 1024;
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.memory.total.bytes',
                    unit => 'B',
                    value => $total_bytes,
                    min => 0
                );
            }
        }
        
        # Get individual DIMMs
        my $dimms = $self->get_memory_dimms(system => $system);
        
        foreach my $dimm (@$dimms) {
            $dimms_total++;
            
            my $dimm_name = defined($dimm->{Name}) ? $dimm->{Name} : 
                           defined($dimm->{Id}) ? $dimm->{Id} : 'DIMM' . $dimms_total;
            my $state = defined($dimm->{Status}->{State}) ? $dimm->{Status}->{State} : 'n/a';
            my $health = defined($dimm->{Status}->{Health}) ? $dimm->{Status}->{Health} : 'n/a';
            
            $dimms_present++ if ($state ne 'Absent' && $state ne 'n/a');
            
            my $capacity_mib = defined($dimm->{CapacityMiB}) ? $dimm->{CapacityMiB} : 0;
            my $speed_mhz = defined($dimm->{OperatingSpeedMhz}) ? $dimm->{OperatingSpeedMhz} : 
                           defined($dimm->{OperatingSpeedMHz}) ? $dimm->{OperatingSpeedMHz} : 0;
            my $manufacturer = defined($dimm->{Manufacturer}) ? $dimm->{Manufacturer} : '';
            my $mem_type = defined($dimm->{MemoryDeviceType}) ? $dimm->{MemoryDeviceType} : '';
            
            my $instance = $system_id . '.' . $dimm_name;
            next if ($self->check_filter(section => 'memory', instance => $instance));
            $self->{components}->{memory}->{total}++;
            
            $self->{output}->output_add(
                long_msg => sprintf(
                    "memory dimm '%s' status is '%s' [instance: %s, state: %s, capacity: %s MiB, speed: %s MHz, type: %s]",
                    $dimm_name, $health, $instance, $state, $capacity_mib, $speed_mhz, $mem_type
                )
            );
            
            my $exit = $self->get_severity(label => 'state', section => 'memory.state', value => $state);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Memory DIMM '%s' state is '%s'", $dimm_name, $state)
                );
            }
            
            $exit = $self->get_severity(label => 'status', section => 'memory.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("Memory DIMM '%s' status is '%s'", $dimm_name, $health)
                );
            }
            
            # DIMM capacity perfdata
            if ($capacity_mib > 0) {
                my $capacity_bytes = $capacity_mib * 1024 * 1024;
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.memory.dimm.capacity.bytes',
                    unit => 'B',
                    instances => $dimm_name,
                    value => $capacity_bytes,
                    min => 0
                );
            }
            
            # DIMM speed perfdata
            if ($speed_mhz > 0) {
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.memory.dimm.speed.mhz',
                    unit => 'MHz',
                    instances => $dimm_name,
                    value => $speed_mhz,
                    min => 0
                );
            }
        }
    }
    
    # DIMM count perfdata
    if ($dimms_total > 0) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.memory.dimms.present.count',
            value => $dimms_present,
            min => 0,
            max => $dimms_total
        );
        $self->{output}->perfdata_add(
            nlabel => 'hardware.memory.dimms.total.count',
            value => $dimms_total,
            min => 0
        );
    }
}


1;

__END__

=head1 DESCRIPTION

Check system memory (DIMM) status, health and configuration.
Monitors memory DIMMs from the Systems Memory endpoint. Reports
individual DIMM status, capacity, speed, and total memory summary.

=head2 Redfish Endpoint

/redfish/v1/Systems/{SystemId}/Memory/{MemoryId}

=head2 Perfdata

hardware.memory.total.bytes : Total installed memory in bytes
hardware.memory.dimm.capacity.bytes : Per-DIMM capacity in bytes
hardware.memory.dimm.speed.mhz : Per-DIMM operating speed in MHz
hardware.memory.dimms.total.count : Total DIMM slots
hardware.memory.dimms.present.count : Present (non-absent) DIMMs

=cut
