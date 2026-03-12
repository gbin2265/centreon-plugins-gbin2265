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

package network::f5::bigip::snmp::mode::components::disk;

use strict;
use warnings;

# F5-BIGIP-SYSTEM-MIB::sysPhysicalDiskTable
my %map_array_status = (
    0 => 'undefined',
    1 => 'ok',
    2 => 'failed',
);

my %map_boolean = (
    0 => 'false',
    1 => 'true',
);

my $mapping = {
    sysPhysicalDiskName          => { oid => '.1.3.6.1.4.1.3375.2.1.3.6.1.2.1.2' },
    sysPhysicalDiskIsArrayMember => { oid => '.1.3.6.1.4.1.3375.2.1.3.6.1.2.1.4', map => \%map_boolean },
    sysPhysicalDiskArrayStatus   => { oid => '.1.3.6.1.4.1.3375.2.1.3.6.1.2.1.5', map => \%map_array_status },
};
my $oid_sysPhysicalDiskEntry = '.1.3.6.1.4.1.3375.2.1.3.6.1.2.1';

sub load {
    my ($self) = @_;

    push @{$self->{request}}, { oid => $oid_sysPhysicalDiskEntry };
}

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'Checking disks');
    $self->{components}->{disk} = { name => 'disks', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'disk'));

    foreach my $oid ($self->{snmp}->oid_lex_sort(keys %{$self->{results}->{$oid_sysPhysicalDiskEntry}})) {
        next if ($oid !~ /^$mapping->{sysPhysicalDiskName}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(
            mapping  => $mapping,
            results  => $self->{results}->{$oid_sysPhysicalDiskEntry},
            instance => $instance
        );

        next if ($self->check_filter(section => 'disk', instance => $instance));

        $self->{components}->{disk}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "disk '%s' array status is '%s' [array member: %s] [instance: %s].",
                $result->{sysPhysicalDiskName},
                $result->{sysPhysicalDiskArrayStatus},
                $result->{sysPhysicalDiskIsArrayMember},
                $instance
            )
        );

        my $exit = $self->get_severity(section => 'disk', value => $result->{sysPhysicalDiskArrayStatus});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity  => $exit,
                short_msg => sprintf(
                    "Disk '%s' array status is '%s'",
                    $result->{sysPhysicalDiskName},
                    $result->{sysPhysicalDiskArrayStatus}
                )
            );
        }
    }
}

1;
