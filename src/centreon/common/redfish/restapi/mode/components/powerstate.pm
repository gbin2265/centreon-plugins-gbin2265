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

package centreon::common::redfish::restapi::mode::components::powerstate;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking powerstate');
    $self->{components}->{powerstate} = { name => 'powerstate', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'powerstate'));

    $self->get_systems() if (!defined($self->{systems}));
    return if (!defined($self->{systems}) || scalar(@{$self->{systems}}) == 0);

    foreach my $system (@{$self->{systems}}) {
        my $instance = defined($system->{Id}) ? $system->{Id} : 'unknown';
        my $name = defined($system->{Name}) ? $system->{Name} : 'System' . $instance;
        my $powerstate = defined($system->{PowerState}) ? $system->{PowerState} : 'unknown';
        
        next if ($self->check_filter(section => 'powerstate', instance => $instance));
        $self->{components}->{powerstate}->{total}++;

        $self->{output}->output_add(
            long_msg => sprintf(
                "system '%s' powerstate is '%s' [instance: %s]",
                $name, $powerstate, $instance
            )
        );
        
        my $exit = $self->get_severity(label => 'default.powerstate', section => 'powerstate', value => $powerstate);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("System '%s' powerstate is '%s'", $name, $powerstate)
            );
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check system power state.
Monitors the PowerState field from the Systems resource.
Default threshold: 'On' = OK, anything else = CRITICAL.

=head2 Redfish Endpoint

/redfish/v1/Systems/{SystemId} (PowerState field)

=head2 Perfdata

No additional perfdata. Status check only via get_severity with label 'default.powerstate'.

=cut
