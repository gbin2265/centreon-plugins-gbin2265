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

package hardware::server::dell::idrac::restapi::mode::components::processor;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking processors');
    $self->{components}->{processor} = { name => 'processors', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'processor'));

    my $cpus = $self->get_processors();

    foreach my $cpu (@$cpus) {
        my $cpu_name = $cpu->{Id} // $cpu->{Name} // 'unknown';
        my $instance = $cpu_name;

        $cpu->{Status}->{Health} = defined($cpu->{Status}->{Health}) ? $cpu->{Status}->{Health} : 'n/a';
        $cpu->{Status}->{State} = defined($cpu->{Status}->{State}) ? $cpu->{Status}->{State} : 'n/a';
        next if ($self->check_filter(section => 'processor', instance => $instance));
        $self->{components}->{processor}->{total}++;

        my $model = ($cpu->{Manufacturer} // '') . ' ' . ($cpu->{Model} // '');
        $model =~ s/^\s+|\s+$//g;
        $model = 'N/A' if ($model eq '');

        $self->{output}->output_add(
            long_msg => sprintf(
                "processor '%s' status is '%s' [instance: %s, state: %s, model: %s, cores: %s, threads: %s]",
                $cpu_name, $cpu->{Status}->{Health}, $instance, $cpu->{Status}->{State},
                $model, $cpu->{TotalCores} // 'N/A', $cpu->{TotalThreads} // 'N/A'
            )
        );

        my $exit = $self->get_severity(label => 'state', section => 'processor.state', value => $cpu->{Status}->{State});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Processor '%s' state is '%s'", $cpu_name, $cpu->{Status}->{State})
            );
        }

        $exit = $self->get_severity(label => 'status', section => 'processor.status', value => $cpu->{Status}->{Health});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Processor '%s' status is '%s'", $cpu_name, $cpu->{Status}->{Health})
            );
        }
    }
}

1;
