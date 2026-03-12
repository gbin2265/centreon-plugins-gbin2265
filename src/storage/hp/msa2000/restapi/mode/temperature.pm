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

package storage::hp::msa2000::restapi::mode::temperature;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state}
    );
}

sub prefix_sensor_output {
    my ($self, %options) = @_;

    return sprintf(
        "Temperature '%s' [Enclosure: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{enclosure}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'sensors', type => 1, cb_prefix_output => 'prefix_sensor_output', message_multiple => 'All temperature sensors are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'sensors-total', nlabel => 'temperature_sensors.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total sensors: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{sensors} = [
        {
            label => 'sensor-status',
            type => 2,
            warning_default => '%{health} =~ /degraded/i',
            critical_default => '%{health} =~ /fault|failed/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'enclosure' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'temperature-reading', nlabel => 'sensor.temperature.celsius', set => {
                key_values => [ { name => 'reading' }, { name => 'name' } ],
                output_template => 'temperature: %s C',
                perfdatas => [
                    { template => '%s', unit => 'C', label_extra_instance => 1, instance_use => 'name' }
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
        'filter-sensor-id:s' => { name => 'filter_sensor_id' },
        'filter-enclosure:s' => { name => 'filter_enclosure' },
        'filter-sensor-name:s' => { name => 'filter_sensor_name' },
        'exclude-enclosure:s' => { name => 'exclude_enclosure' },
        'exclude-sensor-id:s' => { name => 'exclude_sensor_id' },
        'exclude-sensor-name:s' => { name => 'exclude_sensor_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0 };
    $self->{sensors} = {};

    my $chassis_result = $options{custom}->request_api(url_path => '/redfish/v1/Chassis');
    return if (!defined($chassis_result) || !defined($chassis_result->{Members}));

    foreach my $chassis (@{$chassis_result->{Members}}) {
        next if (!defined($chassis->{'@odata.id'}));
        
        my $chassis_data = $options{custom}->request_api(
            url_path => $chassis->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($chassis_data));

        my $enclosure_id = defined($chassis_data->{Id}) ? $chassis_data->{Id} : 'unknown';
        
        if (defined($self->{option_results}->{filter_enclosure}) && $self->{option_results}->{filter_enclosure} ne '' &&
            $enclosure_id !~ /$self->{option_results}->{filter_enclosure}/) {
            next;
        }

        
        if (defined($self->{option_results}->{exclude_enclosure}) && $self->{option_results}->{exclude_enclosure} ne '' &&
            $enclosure_id =~ /$self->{option_results}->{exclude_enclosure}/) {
            next;
        }

        next if (!defined($chassis_data->{ThermalSubsystem}) && !defined($chassis_data->{Thermal}));

        my $thermal_url = defined($chassis_data->{ThermalSubsystem}) 
            ? $chassis_data->{ThermalSubsystem}->{'@odata.id'} 
            : $chassis_data->{Thermal}->{'@odata.id'};
        next if (!defined($thermal_url));

        # MSA may return invalid URLs like "UNKNOWN/enclosure_1/Thermal"
        # Build correct path from chassis ID if URL doesn't start with /redfish
        if ($thermal_url !~ /^\/redfish/) {
            my $chassis_id = defined($chassis_data->{Id}) ? $chassis_data->{Id} : '';
            if ($chassis_id ne '') {
                $thermal_url = '/redfish/v1/Chassis/' . $chassis_id . '/Thermal';
            } else {
                next;
            }
        }

        my $thermal_data = $options{custom}->request_api(
            url_path => $thermal_url,
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($thermal_data));

        my @temperatures;
        if (defined($thermal_data->{Temperatures}) && ref($thermal_data->{Temperatures}) eq 'ARRAY') {
            @temperatures = @{$thermal_data->{Temperatures}};
        } elsif (defined($thermal_data->{Temperatures}) && defined($thermal_data->{Temperatures}->{'@odata.id'})) {
            my $temps_collection = $options{custom}->request_api(
                url_path => $thermal_data->{Temperatures}->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            if (defined($temps_collection) && defined($temps_collection->{Members})) {
                foreach my $temp_ref (@{$temps_collection->{Members}}) {
                    next if (!defined($temp_ref->{'@odata.id'}));
                    my $temp_data = $options{custom}->request_api(
                        url_path => $temp_ref->{'@odata.id'},
                        ignore_codes => { 404 => 1 }
                    );
                    push @temperatures, $temp_data if (defined($temp_data));
                }
            }
        }

        foreach my $sensor (@temperatures) {
            my $sensor_id = defined($sensor->{MemberId}) ? $sensor->{MemberId} : 
                (defined($sensor->{Id}) ? $sensor->{Id} : 'unknown');

            if (defined($self->{option_results}->{filter_sensor_id}) && $self->{option_results}->{filter_sensor_id} ne '' &&
                $sensor_id !~ /$self->{option_results}->{filter_sensor_id}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_sensor_id}) && $self->{option_results}->{exclude_sensor_id} ne '' &&
                $sensor_id =~ /$self->{option_results}->{exclude_sensor_id}/) {
                next;
            }

            my $sensor_name = defined($sensor->{Name}) ? $sensor->{Name} : $sensor_id;

            if (defined($self->{option_results}->{filter_sensor_name}) && $self->{option_results}->{filter_sensor_name} ne '' &&
                $sensor_name !~ /$self->{option_results}->{filter_sensor_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_sensor_name}) && $self->{option_results}->{exclude_sensor_name} ne '' &&
                $sensor_name =~ /$self->{option_results}->{exclude_sensor_name}/) {
                next;
            }

            my $health = defined($sensor->{Status}) && defined($sensor->{Status}->{Health})
                ? $sensor->{Status}->{Health} : 'n/a';
            my $state = defined($sensor->{Status}) && defined($sensor->{Status}->{State})
                ? $sensor->{Status}->{State} : 'n/a';
            next if ($state =~ /^Absent$/i);


            my $reading = defined($sensor->{ReadingCelsius}) ? $sensor->{ReadingCelsius} : 
                (defined($sensor->{Reading}) ? $sensor->{Reading} : undef);

            my $sensor_full_id = $enclosure_id . '_' . $sensor_id;

            $self->{sensors}->{$sensor_full_id} = {
                name      => $sensor_name,
                enclosure => $enclosure_id,
                health    => $health,
                state     => $state,
                reading   => $reading,
            };
            
            $self->{global}->{total}++;
        }
    }

    if (scalar(keys %{$self->{sensors}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No temperature sensors found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA temperature sensors via Redfish API.

=over 8

=item B<--filter-enclosure>

Filter by enclosure (can be a regexp).

=item B<--filter-sensor-id>

Filter by sensor id (can be a regexp).

=item B<--filter-sensor-name>

Filter by sensor name (can be a regexp).

=item B<--exclude-enclosure>

Exclude by enclosure (can be a regexp).

=item B<--exclude-sensor-id>

Exclude by sensor id (can be a regexp).

=item B<--exclude-sensor-name>

Exclude by sensor name (can be a regexp).

=item B<--warning-sensor-status> B<--critical-sensor-status>

Set warning/critical threshold for sensor status.
Default warning: '%{health} =~ /degraded/i'
Default critical: '%{health} =~ /fault|failed/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'sensors-total', 'temperature-reading'.

=back

=cut
