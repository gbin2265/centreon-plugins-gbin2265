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

package centreon::common::redfish::restapi::mode::components::health;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking system health');
    $self->{components}->{health} = { name => 'health', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'health'));

    $self->get_systems() if (!defined($self->{systems}));
    return if (!defined($self->{systems}));

    foreach my $system (@{$self->{systems}}) {
        my $system_id = defined($system->{Id}) ? $system->{Id} : 'unknown';
        my $system_name = defined($system->{Name}) ? $system->{Name} : 'System' . $system_id;
        
        # Check standard Redfish System Status
        if (defined($system->{Status})) {
            my $health = defined($system->{Status}->{Health}) ? $system->{Status}->{Health} : 
                        defined($system->{Status}->{HealthRollup}) ? $system->{Status}->{HealthRollup} : 'n/a';
            my $state = defined($system->{Status}->{State}) ? $system->{Status}->{State} : 'n/a';
            
            my $instance = $system_id . '.system';
            next if ($self->check_filter(section => 'health', instance => $instance));
            $self->{components}->{health}->{total}++;
            
            $self->{output}->output_add(
                long_msg => sprintf(
                    "system '%s' overall health is '%s' [state: %s]",
                    $system_name, $health, $state
                )
            );
            
            my $exit = $self->get_severity(label => 'status', section => 'health.status', value => $health);
            if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                $self->{output}->output_add(
                    severity => $exit,
                    short_msg => sprintf("System '%s' overall health is '%s'", $system_name, $health)
                );
            }
        }
        
        # Check HPE Aggregate Health Status (only fields with Status.Health)
        if (defined($system->{Oem}) && defined($system->{Oem}->{Hpe}) && 
            defined($system->{Oem}->{Hpe}->{AggregateHealthStatus})) {
            my $agg = $system->{Oem}->{Hpe}->{AggregateHealthStatus};
            
            # AggregateServerHealth (direct OK value)
            if (defined($agg->{AggregateServerHealth})) {
                my $health = $agg->{AggregateServerHealth};
                my $instance = $system_id . '.aggregate';
                
                if (!$self->check_filter(section => 'health', instance => $instance)) {
                    $self->{components}->{health}->{total}++;
                    
                    $self->{output}->output_add(
                        long_msg => sprintf(
                            "system '%s' aggregate server health is '%s'",
                            $system_name, $health
                        )
                    );
                    
                    my $exit = $self->get_severity(label => 'status', section => 'health.status', value => $health);
                    if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                        $self->{output}->output_add(
                            severity => $exit,
                            short_msg => sprintf("System '%s' aggregate server health is '%s'", $system_name, $health)
                        );
                    }
                }
            }
            
            # Components with Status.Health (only OK-type values)
            my @health_components = (
                'BiosOrHardwareHealth',
                'Fans',
                'Memory',
                'Network',
                'PowerSupplies',
                'Processors',
                'SmartStorageBattery',
                'Storage',
                'Temperatures'
            );
            
            foreach my $comp (@health_components) {
                next if (!defined($agg->{$comp}));
                next if (ref($agg->{$comp}) ne 'HASH');
                next if (!defined($agg->{$comp}->{Status}));
                next if (!defined($agg->{$comp}->{Status}->{Health}));
                
                my $health = $agg->{$comp}->{Status}->{Health};
                my $instance = $system_id . '.' . lc($comp);
                
                next if ($self->check_filter(section => 'health', instance => $instance));
                $self->{components}->{health}->{total}++;
                
                $self->{output}->output_add(
                    long_msg => sprintf(
                        "system '%s' %s health is '%s'",
                        $system_name, $comp, $health
                    )
                );
                
                my $exit = $self->get_severity(label => 'status', section => 'health.status', value => $health);
                if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
                    $self->{output}->output_add(
                        severity => $exit,
                        short_msg => sprintf("System '%s' %s health is '%s'", $system_name, $comp, $health)
                    );
                }
            }
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check overall system health from the Systems resource.
Monitors the top-level health status reported by the Redfish Systems
resource, including ProcessorSummary, MemorySummary and overall Status.

=head2 Redfish Endpoint

/redfish/v1/Systems/{SystemId}

=head2 Perfdata

No additional perfdata. Status-only checks via get_severity.

=cut
