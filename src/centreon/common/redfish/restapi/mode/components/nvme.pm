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

package centreon::common::redfish::restapi::mode::components::nvme;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking NVMe drives');
    $self->{components}->{nvme} = { name => 'nvme', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'nvme'));

    # Get NVMe drives with metrics
    $self->get_nvme_drives() if (!defined($self->{nvme_drives}));
    return if (!defined($self->{nvme_drives}) || scalar(@{$self->{nvme_drives}}) == 0);

    foreach my $drive (@{$self->{nvme_drives}}) {
        my $drive_id = defined($drive->{Id}) ? $drive->{Id} : 'unknown';
        my $drive_name = defined($drive->{Name}) ? $drive->{Name} : 'NVMe' . $drive_id;
        my $model = defined($drive->{Model}) ? $drive->{Model} : '';
        my $serial = defined($drive->{SerialNumber}) ? $drive->{SerialNumber} : '';
        
        my $state = defined($drive->{Status}->{State}) ? $drive->{Status}->{State} : 'n/a';
        my $health = defined($drive->{Status}->{Health}) ? $drive->{Status}->{Health} : 'n/a';
        
        my $instance = $drive_id;
        next if ($self->check_filter(section => 'nvme', instance => $instance));
        $self->{components}->{nvme}->{total}++;
        
        # Get metrics if available
        my $metrics = $drive->{_metrics} || {};
        my $nvme_smart = $metrics->{NVMeSMART} || {};
        
        my $spare_pct = defined($nvme_smart->{AvailableSparePercent}) ? $nvme_smart->{AvailableSparePercent} : '';
        my $used_pct = defined($nvme_smart->{PercentageUsed}) ? $nvme_smart->{PercentageUsed} : '';
        my $power_hours = defined($nvme_smart->{PowerOnHours}) ? $nvme_smart->{PowerOnHours} : 
                         defined($metrics->{PowerOnHours}) ? $metrics->{PowerOnHours} : '';
        my $power_cycles = defined($nvme_smart->{PowerCycles}) ? $nvme_smart->{PowerCycles} : '';
        my $unsafe_shutdowns = defined($nvme_smart->{UnsafeShutdowns}) ? $nvme_smart->{UnsafeShutdowns} : '';
        my $media_errors = defined($nvme_smart->{MediaAndDataIntegrityErrors}) ? $nvme_smart->{MediaAndDataIntegrityErrors} : '';
        
        $self->{output}->output_add(
            long_msg => sprintf(
                "NVMe drive '%s' status is '%s' [instance: %s, state: %s, model: %s, spare: %s%%, used: %s%%, power_hours: %s]",
                $drive_name, $health, $instance, $state, $model, $spare_pct, $used_pct, $power_hours
            )
        );
        
        my $exit = $self->get_severity(label => 'state', section => 'nvme.state', value => $state);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("NVMe drive '%s' state is '%s'", $drive_name, $state)
            );
        }
        
        $exit = $self->get_severity(label => 'status', section => 'nvme.status', value => $health);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("NVMe drive '%s' status is '%s'", $drive_name, $health)
            );
        }
        
        # Available spare percentage
        if ($spare_pct ne '' && $spare_pct =~ /\d/) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.available.spare.percentage',
                unit => '%',
                instances => $drive_name,
                value => $spare_pct,
                warning => '20:',
                critical => '10:',
                min => 0,
                max => 100
            );
        }
        
        # Percentage used (SSD wear)
        if ($used_pct ne '' && $used_pct =~ /\d/) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.percentage.used',
                unit => '%',
                instances => $drive_name,
                value => $used_pct,
                warning => '0:80',
                critical => '0:90',
                min => 0,
                max => 100
            );
        }
        
        # Power on hours
        if ($power_hours ne '' && $power_hours =~ /\d/) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.power.hours',
                unit => 'h',
                instances => $drive_name,
                value => $power_hours,
                min => 0
            );
        }
        
        # Power cycles
        if ($power_cycles ne '' && $power_cycles =~ /\d/) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.power.cycles.count',
                instances => $drive_name,
                value => $power_cycles,
                min => 0
            );
        }
        
        # Unsafe shutdowns
        if ($unsafe_shutdowns ne '' && $unsafe_shutdowns =~ /\d/) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.unsafe.shutdowns.count',
                instances => $drive_name,
                value => $unsafe_shutdowns,
                min => 0
            );
        }
        
        # Media and data integrity errors
        if ($media_errors ne '' && $media_errors =~ /\d/) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.media.errors.count',
                instances => $drive_name,
                value => $media_errors,
                warning => '0:0',
                critical => '1:',
                min => 0
            );
        }
        
        # I/O error counts from metrics
        if (defined($metrics->{CorrectableIOReadErrorCount})) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.errors.read.correctable.count',
                instances => $drive_name,
                value => $metrics->{CorrectableIOReadErrorCount},
                min => 0
            );
        }
        
        if (defined($metrics->{CorrectableIOWriteErrorCount})) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.errors.write.correctable.count',
                instances => $drive_name,
                value => $metrics->{CorrectableIOWriteErrorCount},
                min => 0
            );
        }
        
        if (defined($metrics->{UncorrectableIOReadErrorCount})) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.errors.read.uncorrectable.count',
                instances => $drive_name,
                value => $metrics->{UncorrectableIOReadErrorCount},
                warning => '0:0',
                critical => '1:',
                min => 0
            );
        }
        
        if (defined($metrics->{UncorrectableIOWriteErrorCount})) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.errors.write.uncorrectable.count',
                instances => $drive_name,
                value => $metrics->{UncorrectableIOWriteErrorCount},
                warning => '0:0',
                critical => '1:',
                min => 0
            );
        }
        
        # Read/Write IO KiBytes
        if (defined($metrics->{ReadIOKiBytes})) {
            my $read_bytes = $metrics->{ReadIOKiBytes} * 1024;
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.io.read.bytes',
                unit => 'B',
                instances => $drive_name,
                value => $read_bytes,
                min => 0
            );
        }
        
        if (defined($metrics->{WriteIOKiBytes})) {
            my $write_bytes = $metrics->{WriteIOKiBytes} * 1024;
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.io.write.bytes',
                unit => 'B',
                instances => $drive_name,
                value => $write_bytes,
                min => 0
            );
        }
        
        # Host commands
        if (defined($nvme_smart->{HostReadCommands})) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.commands.read.count',
                instances => $drive_name,
                value => $nvme_smart->{HostReadCommands},
                min => 0
            );
        }
        
        if (defined($nvme_smart->{HostWriteCommands})) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.commands.write.count',
                instances => $drive_name,
                value => $nvme_smart->{HostWriteCommands},
                min => 0
            );
        }
        
        # Temperature from NVMe SMART
        if (defined($nvme_smart->{CompositeTemperatureCelsius})) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nvme.temperature.celsius',
                unit => 'C',
                instances => $drive_name,
                value => $nvme_smart->{CompositeTemperatureCelsius},
                min => 0
            );
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check NVMe drive status, health and SMART metrics.
Monitors NVMe drives from the Storage endpoint with detailed
SMART/health data including spare capacity, wear level,
temperature, media errors, and I/O statistics.

=head2 Redfish Endpoint

/redfish/v1/Systems/{SystemId}/Storage/{StorageId}/Drives/{DriveId} (NVMe protocol)

=head2 Perfdata

hardware.nvme.temperature.celsius : Drive temperature in Celsius
hardware.nvme.available.spare.percentage : Available spare capacity percentage
hardware.nvme.percentage.used : Percentage of life used
hardware.nvme.media.errors.count : Media and integrity error count
hardware.nvme.power.hours : Power-on hours
hardware.nvme.power.cycles.count : Power cycle count
hardware.nvme.unsafe.shutdowns.count : Unsafe shutdown count
hardware.nvme.commands.read.count : Read command count
hardware.nvme.commands.write.count : Write command count
hardware.nvme.io.read.bytes : Data read in bytes
hardware.nvme.io.write.bytes : Data written in bytes
hardware.nvme.errors.read.correctable.count : Correctable read errors
hardware.nvme.errors.read.uncorrectable.count : Uncorrectable read errors
hardware.nvme.errors.write.correctable.count : Correctable write errors
hardware.nvme.errors.write.uncorrectable.count : Uncorrectable write errors

=cut
