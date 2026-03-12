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

package hardware::server::dell::idrac::restapi::mode::components::sc;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking storage controllers');
    $self->{components}->{sc} = { name => 'sc', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'sc'));

    my $storages = $self->get_storages();

    foreach my $storage (@$storages) {
        my $storage_name = $storage->{Id} // 'unknown';
        my $instance = $storage_name;

        $storage->{Status}->{Health} = defined($storage->{Status}->{HealthRollup}) ? $storage->{Status}->{HealthRollup} :
                                       defined($storage->{Status}->{Health}) ? $storage->{Status}->{Health} : 'n/a';
        $storage->{Status}->{State} = defined($storage->{Status}->{State}) ? $storage->{Status}->{State} : 'n/a';
        next if ($self->check_filter(section => 'sc', instance => $instance));
        $self->{components}->{sc}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "storage controller '%s' status is '%s' [instance: %s, state: %s]",
                $storage_name, $storage->{Status}->{Health}, $instance, $storage->{Status}->{State}
            )
        );

        my $exit = $self->get_severity(label => 'state', section => 'sc.state', value => $storage->{Status}->{State});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Storage controller '%s' state is '%s'", $storage_name, $storage->{Status}->{State})
            );
        }

        $exit = $self->get_severity(label => 'status', section => 'sc.status', value => $storage->{Status}->{Health});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Storage controller '%s' status is '%s'", $storage_name, $storage->{Status}->{Health})
            );
        }
    }
}

1;
