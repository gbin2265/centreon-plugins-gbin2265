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

package network::brocade::restapi::mode::hastatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_ha_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "HA status: %s, heartbeat: %s, active CP: %s, standby CP: %s",
        $self->{result_values}->{ha_enabled},
        $self->{result_values}->{heartbeat_status},
        $self->{result_values}->{active_cp},
        $self->{result_values}->{standby_cp}
    );
}

sub custom_cp_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "state: %s [role: %s]",
        $self->{result_values}->{state},
        $self->{result_values}->{role}
    );
}

sub prefix_cp_output {
    my ($self, %options) = @_;

    return "CP slot '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'cp', type => 1, cb_prefix_output => 'prefix_cp_output', message_multiple => 'All CPs are ok' }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'ha-status',
            type => 2,
            critical_default => '%{ha_enabled} eq "true" and %{heartbeat_status} !~ /healthy|up/i',
            set => {
                key_values => [ { name => 'ha_enabled' }, { name => 'heartbeat_status' }, 
                               { name => 'active_cp' }, { name => 'standby_cp' } ],
                closure_custom_output => $self->can('custom_ha_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'ha-recovery-time', nlabel => 'ha.recovery.time.seconds', set => {
                key_values => [ { name => 'recovery_time' } ],
                output_template => 'recovery time: %s s',
                perfdatas => [
                    { template => '%s', unit => 's', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{cp} = [
        {
            label => 'cp-status',
            type => 2,
            critical_default => '%{role} eq "active" and %{state} !~ /healthy|online/i',
            set => {
                key_values => [ { name => 'state' }, { name => 'role' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_cp_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $ha_data = $options{custom}->get_ha_status();

    $self->{global} = {};
    $self->{cp} = {};

    # Parse HA status - correct path is brocade-chassis/ha-status
    my $ha_info = $ha_data->{'Response'}->{'ha-status'} // $ha_data->{'brocade-chassis'}->{'ha-status'} // {};
    $ha_info = $ha_info->[0] if (ref($ha_info) eq 'ARRAY');

    # Global HA status - correct field names from FOS REST API
    my $ha_enabled = $ha_info->{'ha-enabled'} // 'false';
    $ha_enabled = $ha_enabled ? 'true' : 'false' if ($ha_enabled =~ /^[01]$/);
    
    my $heartbeat = $ha_info->{'heartbeat-up'} // 'unknown';
    $heartbeat = $heartbeat ? 'up' : 'down' if ($heartbeat =~ /^[01]$/);
    
    my $active_cp = $ha_info->{'active-cp'} // 'unknown';
    my $active_slot = $ha_info->{'active-slot'} // '';
    my $standby_cp = $ha_info->{'standby-cp'} // 'unknown';
    my $standby_slot = $ha_info->{'standby-slot'} // '';
    my $standby_health = $ha_info->{'standby-health'} // 'unknown';
    my $ha_sync = $ha_info->{'ha-synchronized'} // 'unknown';
    $ha_sync = $ha_sync ? 'true' : 'false' if ($ha_sync =~ /^[01]$/);
    my $recovery_type = $ha_info->{'recovery-type'} // 'unknown';

    $self->{global} = {
        ha_enabled => $ha_enabled,
        heartbeat_status => lc($heartbeat),
        active_cp => $active_cp,
        standby_cp => $standby_cp,
        recovery_time => undef  # Not directly available, could derive from sync time
    };

    # Per-CP status using slot numbers
    if ($active_slot ne '') {
        $self->{cp}->{'slot' . $active_slot} = {
            display => 'slot' . $active_slot,
            state => 'healthy',
            role => 'active'
        };
    }
    
    if ($standby_slot ne '') {
        $self->{cp}->{'slot' . $standby_slot} = {
            display => 'slot' . $standby_slot,
            state => lc($standby_health),
            role => 'standby'
        };
    }

    # Alternative: check blade data for CP blades if HA status didn't give us slot info
    if (scalar(keys %{$self->{cp}}) == 0) {
        my $blade_data = $options{custom}->get_blade_info();
        my $blades = $blade_data->{'Response'}->{'blade'} // $blade_data->{'brocade-fru'}->{'blade'} // [];
        $blades = [$blades] if (ref($blades) ne 'ARRAY');
        
        foreach my $blade (@{$blades}) {
            my $blade_type = $blade->{'blade-type'} // '';
            next if ($blade_type !~ /CP/i);
            
            my $slot = $blade->{'slot-number'};
            my $state = $blade->{'blade-state'} // 'unknown';
            my $role = $blade->{'ha-role'} // ($blade->{'is-active-cp'} ? 'active' : 'standby');
            
            $self->{cp}->{'slot' . $slot} = {
                display => 'slot' . $slot,
                state => lc($state),
                role => lc($role)
            };
        }
    }
}

1;

__END__

=head1 MODE

Check High Availability (HA) status for director-class switches.

=over 8

=item B<--unknown-ha-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{ha_enabled}, %{heartbeat_status}, %{active_cp}, %{standby_cp}

=item B<--warning-ha-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{ha_enabled}, %{heartbeat_status}, %{active_cp}, %{standby_cp}

=item B<--critical-ha-status>

Define the conditions to match for the status to be CRITICAL 
(default: '%{ha_enabled} eq "true" and %{heartbeat_status} !~ /healthy|up/i').
You can use the following variables: %{ha_enabled}, %{heartbeat_status}, %{active_cp}, %{standby_cp}

=item B<--unknown-cp-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{role}, %{display}

=item B<--warning-cp-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{state}, %{role}, %{display}

=item B<--critical-cp-status>

Define the conditions to match for the status to be CRITICAL 
(default: '%{role} eq "active" and %{state} !~ /healthy|online/i').
You can use the following variables: %{state}, %{role}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'ha-recovery-time'.

=back

=cut
