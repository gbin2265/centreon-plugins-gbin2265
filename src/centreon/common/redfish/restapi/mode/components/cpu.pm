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

package centreon::common::redfish::restapi::mode::components::cpu;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking cpu');
    $self->{components}->{cpu} = { name => 'cpu', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'cpu'));

    $self->get_processors() if (!defined($self->{processors}));
    return if (!defined($self->{processors}) || scalar(@{$self->{processors}}) == 0);

    # Get thermal data for CPU temperatures
    my $cpu_temps = $self->get_cpu_temperatures();
    
    # Get power data for CPU power metrics
    my $cpu_power = $self->get_cpu_power_metrics();

    my $total_cores = 0;
    my $total_threads = 0;
    my $processors_present = 0;

    foreach my $processor (@{$self->{processors}}) {
        my $instance = defined($processor->{Id}) ? $processor->{Id} : 'unknown';
        my $name = defined($processor->{Name}) ? $processor->{Name} : 'CPU' . $instance;
        my $model = defined($processor->{Model}) ? $processor->{Model} : '';
        my $manufacturer = defined($processor->{Manufacturer}) ? $processor->{Manufacturer} : '';
        my $cores = defined($processor->{TotalCores}) ? $processor->{TotalCores} : 0;
        my $threads = defined($processor->{TotalThreads}) ? $processor->{TotalThreads} : 0;
        my $max_speed_mhz = defined($processor->{MaxSpeedMHz}) ? $processor->{MaxSpeedMHz} : 0;
        my $socket = defined($processor->{Socket}) ? $processor->{Socket} : '';
        
        my $state = defined($processor->{Status}->{State}) ? $processor->{Status}->{State} : 'n/a';
        my $health = defined($processor->{Status}->{Health}) ? $processor->{Status}->{Health} : 'n/a';
        
        $processors_present++ if ($state ne 'Absent');
        $total_cores += $cores if ($cores > 0);
        $total_threads += $threads if ($threads > 0);
        
        next if ($self->check_filter(section => 'cpu', instance => $instance));
        $self->{components}->{cpu}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "cpu '%s' status is '%s' [instance: %s, state: %s, model: %s, cores: %s, threads: %s, max_speed: %s MHz]",
                $name, $health, $instance, $state, $model, $cores, $threads, $max_speed_mhz
            )
        );
        
        my $exit = $self->get_severity(label => 'state', section => 'cpu.state', value => $state);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("CPU '%s' state is '%s'", $name, $state)
            );
        }
        
        $exit = $self->get_severity(label => 'status', section => 'cpu.status', value => $health);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("CPU '%s' status is '%s'", $name, $health)
            );
        }
        
        # CPU temperature perfdata if available
        if (defined($cpu_temps->{$instance})) {
            my $temp = $cpu_temps->{$instance};
            if (defined($temp->{reading}) && $temp->{reading} =~ /\d/) {
                my ($exit2, $warn, $crit, $checked) = $self->get_severity_numeric(
                    section => 'cpu.temperature',
                    instance => $instance,
                    value => $temp->{reading}
                );
                if (!$self->{output}->is_status(value => $exit2, compare => 'ok', litteral => 1)) {
                    $self->{output}->output_add(
                        severity => $exit2,
                        short_msg => sprintf("CPU '%s' temperature is %s C", $name, $temp->{reading})
                    );
                }
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.cpu.temperature.celsius',
                    unit => 'C',
                    instances => $instance,
                    value => $temp->{reading},
                    warning => $warn,
                    critical => $crit,
                    min => 0,
                    max => $temp->{critical}
                );
            }
        }
        
        # Cores perfdata
        if ($cores > 0) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.cpu.cores.count',
                instances => $name,
                value => $cores,
                min => 0
            );
        }
        
        # Threads perfdata
        if ($threads > 0) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.cpu.threads.count',
                instances => $name,
                value => $threads,
                min => 0
            );
        }
        
        # Max speed perfdata
        if ($max_speed_mhz > 0) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.cpu.speed.max.mhz',
                unit => 'MHz',
                instances => $name,
                value => $max_speed_mhz,
                min => 0
            );
        }
        
        # Cache sizes from HPE OEM data
        if (defined($processor->{Oem}) && defined($processor->{Oem}->{Hpe}) && 
            defined($processor->{Oem}->{Hpe}->{Cache})) {
            my $caches = $processor->{Oem}->{Hpe}->{Cache};
            foreach my $cache (@$caches) {
                my $cache_name = defined($cache->{Name}) ? $cache->{Name} : 'unknown';
                my $cache_size_kb = defined($cache->{InstalledSizeKB}) ? $cache->{InstalledSizeKB} : 0;
                
                if ($cache_size_kb > 0) {
                    my $cache_bytes = $cache_size_kb * 1024;
                    my $cache_label = lc($cache_name);
                    $cache_label =~ s/-//g;
                    $cache_label =~ s/cache//g;
                    $cache_label =~ s/\s+//g;
                    
                    $self->{output}->perfdata_add(
                        nlabel => 'hardware.cpu.cache.' . $cache_label . '.bytes',
                        unit => 'B',
                        instances => $name,
                        value => $cache_bytes,
                        min => 0
                    );
                    
                    $self->{output}->output_add(
                        long_msg => sprintf(
                            "  cache '%s' size: %s KB",
                            $cache_name, $cache_size_kb
                        )
                    );
                }
            }
        }
        
        # Standard Redfish cache info (ProcessorSummary)
        if (defined($processor->{ProcessorSummary}) && defined($processor->{ProcessorSummary}->{Cache})) {
            foreach my $cache (@{$processor->{ProcessorSummary}->{Cache}}) {
                my $cache_level = defined($cache->{Level}) ? $cache->{Level} : '';
                my $cache_size_kb = defined($cache->{InstalledCacheKiB}) ? $cache->{InstalledCacheKiB} : 0;
                
                if ($cache_size_kb > 0 && $cache_level ne '') {
                    my $cache_bytes = $cache_size_kb * 1024;
                    $self->{output}->perfdata_add(
                        nlabel => 'hardware.cpu.cache.' . lc($cache_level) . '.bytes',
                        unit => 'B',
                        instances => $name,
                        value => $cache_bytes,
                        min => 0
                    );
                }
            }
        }
    }
    
    # Total counts perfdata
    if ($processors_present > 0) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.cpu.present.count',
            value => $processors_present,
            min => 0
        );
    }
    
    if ($total_cores > 0) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.cpu.cores.total.count',
            value => $total_cores,
            min => 0
        );
    }
    
    if ($total_threads > 0) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.cpu.threads.total.count',
            value => $total_threads,
            min => 0
        );
    }
    
    # System-wide CPU power metrics if available
    if (defined($cpu_power->{cpu_watts}) && $cpu_power->{cpu_watts} =~ /\d/) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.cpu.power.watts',
            unit => 'W',
            value => $cpu_power->{cpu_watts},
            min => 0
        );
    }
    
    if (defined($cpu_power->{dimm_watts}) && $cpu_power->{dimm_watts} =~ /\d/) {
        $self->{output}->perfdata_add(
            nlabel => 'hardware.memory.power.watts',
            unit => 'W',
            value => $cpu_power->{dimm_watts},
            min => 0
        );
    }
}


1;

__END__

=head1 DESCRIPTION

Check CPU/processor status, health, temperature and power metrics.
Monitors processor state and health via Redfish, with optional HPE OEM
data for CPU temperatures (from Thermal endpoint), power consumption
(from PowerControl), and cache sizes.

=head2 Redfish Endpoint

/redfish/v1/Systems/{SystemId}/Processors/{ProcessorId}

=head2 Perfdata

hardware.cpu.temperature.celsius : CPU temperature in Celsius
hardware.cpu.cores.count : Number of cores per CPU
hardware.cpu.threads.count : Number of threads per CPU
hardware.cpu.speed.max.mhz : Maximum speed in MHz
hardware.cpu.cache.{level}.bytes : Cache size per level in bytes (HPE OEM)
hardware.cpu.present.count : Total present CPUs
hardware.cpu.cores.total.count : Total cores across all CPUs
hardware.cpu.threads.total.count : Total threads across all CPUs
hardware.cpu.power.watts : Total CPU power consumption (HPE OEM)
hardware.memory.power.watts : Total DIMM power consumption (HPE OEM)

=cut
