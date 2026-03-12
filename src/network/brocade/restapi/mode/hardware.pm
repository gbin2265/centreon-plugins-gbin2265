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

package network::brocade::restapi::mode::hardware;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s",
        $self->{result_values}->{status}
    );
}

sub custom_blade_status_output {
    my ($self, %options) = @_;

    my $msg = sprintf("status: %s", $self->{result_values}->{status});
    
    if (defined($self->{result_values}->{blade_type}) && $self->{result_values}->{blade_type} ne '') {
        $msg .= sprintf(" [type: %s]", $self->{result_values}->{blade_type});
    }
    if (defined($self->{result_values}->{firmware}) && $self->{result_values}->{firmware} ne '') {
        $msg .= sprintf(" [fw: %s]", $self->{result_values}->{firmware});
    }
    
    return $msg;
}

sub chassis_long_output {
    my ($self, %options) = @_;

    return "checking chassis '" . $options{instance_value}->{display} . "'";
}

sub prefix_chassis_output {
    my ($self, %options) = @_;

    return "Chassis '" . $options{instance_value}->{display} . "' ";
}

sub prefix_fan_output {
    my ($self, %options) = @_;

    return "fan '" . $options{instance_value}->{display} . "' ";
}

sub prefix_psu_output {
    my ($self, %options) = @_;

    return "power supply '" . $options{instance_value}->{display} . "' ";
}

sub prefix_blade_output {
    my ($self, %options) = @_;

    return "blade '" . $options{instance_value}->{display} . "' ";
}

sub prefix_sensor_output {
    my ($self, %options) = @_;

    return "sensor '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'chassis', type => 3, cb_prefix_output => 'prefix_chassis_output', cb_long_output => 'chassis_long_output', indent_long_output => '    ', message_multiple => 'All chassis are ok',
            group => [
                { name => 'fans', type => 1, cb_prefix_output => 'prefix_fan_output', message_multiple => 'fans are ok', skipped_code => { -10 => 1 } },
                { name => 'psus', type => 1, cb_prefix_output => 'prefix_psu_output', message_multiple => 'power supplies are ok', skipped_code => { -10 => 1 } },
                { name => 'blades', type => 1, cb_prefix_output => 'prefix_blade_output', message_multiple => 'blades are ok', skipped_code => { -10 => 1 } },
                { name => 'sensors', type => 1, cb_prefix_output => 'prefix_sensor_output', message_multiple => 'sensors are ok', skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{fans} = [
        {
            label => 'fan-status',
            type => 2,
            critical_default => '%{status} !~ /ok/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'fan-speed', nlabel => 'hardware.fan.speed.rpm', set => {
                key_values => [ { name => 'speed' }, { name => 'display' } ],
                output_template => 'speed: %s rpm',
                perfdatas => [
                    { template => '%s', unit => 'rpm', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{psus} = [
        {
            label => 'psu-status',
            type => 2,
            critical_default => '%{status} !~ /ok/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{blades} = [
        {
            label => 'blade-status',
            type => 2,
            critical_default => '%{status} !~ /enabled|on/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'blade_type' }, { name => 'firmware' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_blade_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'blade-power', nlabel => 'hardware.blade.power.watt', set => {
                key_values => [ { name => 'power_consumption' }, { name => 'display' } ],
                output_template => 'power: %s W',
                perfdatas => [
                    { template => '%s', unit => 'W', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{sensors} = [
        {
            label => 'sensor-status',
            type => 2,
            critical_default => '%{status} !~ /ok/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'sensor-temperature', nlabel => 'hardware.sensor.temperature.celsius', set => {
                key_values => [ { name => 'temperature' }, { name => 'display' } ],
                output_template => 'temperature: %.1f C',
                perfdatas => [
                    { template => '%.1f', unit => 'C', label_extra_instance => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-blade-id:s' => { name => 'filter_blade_id' },
        'exclude-blade-id:s' => { name => 'exclude_blade_id' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $chassis = $options{custom}->get_chassis_info();
    my $fans = $options{custom}->get_fan_info();
    my $psus = $options{custom}->get_ps_info();
    my $blades = $options{custom}->get_blade_info();
    my $sensors = $options{custom}->get_sensor_info();

    $self->{chassis} = {};

    # Process chassis info
    my $chassis_data = $chassis->{'Response'}->{'chassis'} // $chassis->{'brocade-chassis'}->{'chassis'} // [];
    $chassis_data = [$chassis_data] if (ref($chassis_data) ne 'ARRAY');
    
    foreach my $ch (@{$chassis_data}) {
        my $chassis_name = $ch->{'chassis-wwn'} // $ch->{'serial-number'} // 'chassis';
        $self->{chassis}->{$chassis_name} = {
            display => $chassis_name,
            fans => {},
            psus => {},
            blades => {},
            sensors => {}
        };
    }

    # If no chassis found, create default
    if (scalar(keys %{$self->{chassis}}) == 0) {
        $self->{chassis}->{'default'} = {
            display => 'default',
            fans => {},
            psus => {},
            blades => {},
            sensors => {}
        };
    }

    my $first_chassis = (keys %{$self->{chassis}})[0];

    # Process fans
    my $fan_data = $fans->{'Response'}->{'fan'} // $fans->{'brocade-fru'}->{'fan'} // [];
    $fan_data = [$fan_data] if (ref($fan_data) ne 'ARRAY');
    
    foreach my $fan (@{$fan_data}) {
        next if (!defined($fan->{'unit-number'}));
        
        my $fan_name = 'fan_' . $fan->{'unit-number'};
        if (defined($fan->{'slot-number'})) {
            $fan_name = 'slot' . $fan->{'slot-number'} . '_' . $fan_name;
        }
        
        my $status = $fan->{'operational-state'} // 'unknown';
        
        $self->{chassis}->{$first_chassis}->{fans}->{$fan_name} = {
            display => $fan_name,
            status => lc($status),
            speed => $fan->{'speed'} // $fan->{'airflow-direction'}
        };
    }

    # Process power supplies
    my $psu_data = $psus->{'Response'}->{'power-supply'} // $psus->{'brocade-fru'}->{'power-supply'} // [];
    $psu_data = [$psu_data] if (ref($psu_data) ne 'ARRAY');
    
    foreach my $psu (@{$psu_data}) {
        next if (!defined($psu->{'unit-number'}));
        
        my $psu_name = 'psu_' . $psu->{'unit-number'};
        my $status = $psu->{'operational-state'} // 'unknown';
        
        $self->{chassis}->{$first_chassis}->{psus}->{$psu_name} = {
            display => $psu_name,
            status => lc($status)
        };
    }

    # Process blades
    my $blade_data = $blades->{'Response'}->{'blade'} // $blades->{'brocade-fru'}->{'blade'} // [];
    $blade_data = [$blade_data] if (ref($blade_data) ne 'ARRAY');
    
    foreach my $blade (@{$blade_data}) {
        next if (!defined($blade->{'slot-number'}));
        
        my $blade_id = $blade->{'slot-number'};
        
        if (defined($self->{option_results}->{filter_blade_id}) && $self->{option_results}->{filter_blade_id} ne '' &&
            $blade_id !~ /$self->{option_results}->{filter_blade_id}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_blade_id}) && $self->{option_results}->{exclude_blade_id} ne '' &&
            $blade_id =~ /$self->{option_results}->{exclude_blade_id}/) {
            next;
        }
        
        my $blade_name = 'blade_slot' . $blade_id;
        my $status = $blade->{'blade-state'} // $blade->{'power-state'} // 'unknown';
        my $blade_type = $blade->{'blade-type'} // $blade->{'blade-id'} // '';
        my $firmware = $blade->{'firmware-version'} // $blade->{'primary-firmware-version'} // '';
        my $power = $blade->{'power-consumption'} // $blade->{'power-usage'} // undef;
        
        $self->{chassis}->{$first_chassis}->{blades}->{$blade_name} = {
            display => $blade_name,
            status => lc($status),
            blade_type => $blade_type,
            firmware => $firmware,
            power_consumption => $power
        };
    }

    # Process sensors
    my $sensor_data = $sensors->{'Response'}->{'sensor'} // $sensors->{'brocade-fru'}->{'sensor'} // [];
    $sensor_data = [$sensor_data] if (ref($sensor_data) ne 'ARRAY');
    
    foreach my $sensor (@{$sensor_data}) {
        next if (!defined($sensor->{'id'}));
        
        my $sensor_name = 'sensor_' . $sensor->{'id'};
        if (defined($sensor->{'slot-number'})) {
            $sensor_name = 'slot' . $sensor->{'slot-number'} . '_' . $sensor_name;
        }
        
        my $status = $sensor->{'state'} // 'unknown';
        my $temp = $sensor->{'temperature'} // $sensor->{'value'};
        
        $self->{chassis}->{$first_chassis}->{sensors}->{$sensor_name} = {
            display => $sensor_name,
            status => lc($status),
            temperature => $temp
        };
    }
}

1;

__END__

=head1 MODE

Check hardware components (fans, power supplies, blades, sensors).

=over 8

=item B<--filter-blade-id>

Filter blades by slot number (can be a regexp).

=item B<--exclude-blade-id>

Exclude blades by slot number (can be a regexp).

=item B<--unknown-fan-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{display}

=item B<--warning-fan-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{display}

=item B<--critical-fan-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /ok/i').
You can use the following variables: %{status}, %{display}

=item B<--unknown-psu-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{display}

=item B<--warning-psu-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{display}

=item B<--critical-psu-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /ok/i').
You can use the following variables: %{status}, %{display}

=item B<--unknown-blade-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{blade_type}, %{firmware}, %{display}

=item B<--warning-blade-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{blade_type}, %{firmware}, %{display}

=item B<--critical-blade-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /enabled|on/i').
You can use the following variables: %{status}, %{blade_type}, %{firmware}, %{display}

=item B<--unknown-sensor-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{display}

=item B<--warning-sensor-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{display}

=item B<--critical-sensor-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /ok/i').
You can use the following variables: %{status}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'fan-speed', 'sensor-temperature', 'blade-power'.

=back

=cut
