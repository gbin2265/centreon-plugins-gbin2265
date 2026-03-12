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

package centreon::common::redfish::restapi::mode::components::smcstorage;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking smartstorage controllers');
    $self->{components}->{smcstorage} = { name => 'smcstorage', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'smcstorage'));

    $self->get_smartstorage_controllers() if (!defined($self->{smartstorage_controllers}));
    return if (!defined($self->{smartstorage_controllers}) || scalar(@{$self->{smartstorage_controllers}}) == 0);

    foreach my $controller (@{$self->{smartstorage_controllers}}) {
        my $instance = defined($controller->{Id}) ? $controller->{Id} : 'unknown';
        my $name = defined($controller->{Model}) ? $controller->{Model} : 
                   defined($controller->{Name}) ? $controller->{Name} : 'Controller' . $instance;
        my $serial = defined($controller->{SerialNumber}) ? $controller->{SerialNumber} : '';
        my $cache_size = defined($controller->{CacheMemorySizeMiB}) ? $controller->{CacheMemorySizeMiB} : '';
        my $mode = defined($controller->{CurrentOperatingMode}) ? $controller->{CurrentOperatingMode} : '';
        my $backup_power = defined($controller->{BackupPowerSourceStatus}) ? $controller->{BackupPowerSourceStatus} : '';
        my $cache_status = '';
        if (defined($controller->{CacheModuleStatus}) && defined($controller->{CacheModuleStatus}->{Health})) {
            $cache_status = $controller->{CacheModuleStatus}->{Health};
        }
        
        my $state = defined($controller->{Status}->{State}) ? $controller->{Status}->{State} : 'n/a';
        my $health = defined($controller->{Status}->{Health}) ? $controller->{Status}->{Health} : 'n/a';
        
        next if ($self->check_filter(section => 'smcstorage', instance => $instance));
        $self->{components}->{smcstorage}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "storage controller '%s' status is '%s' [instance: %s, state: %s, serial: %s, cache: %s MiB, mode: %s, backup: %s, cache_status: %s]",
                $name, $health, $instance, $state, $serial, $cache_size, $mode, $backup_power, $cache_status
            )
        );
        
        my $exit = $self->get_severity(label => 'state', section => 'smcstorage.state', value => $state);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Storage controller '%s' state is '%s'", $name, $state)
            );
        }
        
        $exit = $self->get_severity(label => 'status', section => 'smcstorage.status', value => $health);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Storage controller '%s' status is '%s'", $name, $health)
            );
        }
        
        # Check cache module status
        if ($cache_status ne '' && $cache_status ne 'OK') {
            $self->{output}->output_add(
                severity => 'WARNING',
                short_msg => sprintf("Storage controller '%s' cache module status is '%s'", $name, $cache_status)
            );
        }
        
        # Check backup power source
        if ($backup_power ne '' && $backup_power ne 'Present' && $backup_power ne 'OK') {
            $self->{output}->output_add(
                severity => 'WARNING',
                short_msg => sprintf("Storage controller '%s' backup power status is '%s'", $name, $backup_power)
            );
        }
        
        # Cache size perfdata
        if (defined($controller->{CacheMemorySizeMiB}) && $controller->{CacheMemorySizeMiB} =~ /\d/) {
            my $cache_bytes = $controller->{CacheMemorySizeMiB} * 1024 * 1024;
            $self->{output}->perfdata_add(
                nlabel => 'hardware.smcstorage.cache.bytes',
                unit => 'B',
                instances => $instance,
                value => $cache_bytes,
                min => 0
            );
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check HPE SmartStorage array controllers.
Monitors HPE SmartStorage controllers via the iLO OEM endpoint.
Checks controller state, health, cache module status, backup power
source status and cache memory size.

=head2 Redfish Endpoint

/redfish/v1/Systems/1/SmartStorage/ArrayControllers/{ControllerId}

=head2 Perfdata

hardware.smcstorage.cache.bytes : Controller cache size in bytes

=cut
