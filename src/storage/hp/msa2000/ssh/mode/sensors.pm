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

package storage::hp::msa2000::ssh::mode::sensors;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'status: %s [value: %s %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{value},
        $self->{result_values}->{unit}
    );
}

sub prefix_sensor_output {
    my ($self, %options) = @_;

    return "Sensor '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'temperature', type => 1, cb_prefix_output => 'prefix_sensor_output', message_multiple => 'All temperature sensors are ok' },
        { name => 'voltage', type => 1, cb_prefix_output => 'prefix_sensor_output', message_multiple => 'All voltage sensors are ok' },
        { name => 'current', type => 1, cb_prefix_output => 'prefix_sensor_output', message_multiple => 'All current sensors are ok' },
    ];

    $self->{maps_counters}->{temperature} = [
        {
            label => 'sensor-temperature-status',
            type => 2,
            unknown_default => '%{status} =~ /unknown/i',
            warning_default => '%{status} =~ /warning|non-critical/i',
            critical_default => '%{status} =~ /critical|not installed|unavailable/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'display' }, { name => 'value' }, { name => 'unit' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'temperature', nlabel => 'sensor.temperature.celsius', set => {
                key_values => [ { name => 'value' }, { name => 'display' } ],
                output_template => 'temperature: %s C',
                perfdatas => [
                    { template => '%s', unit => 'C', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];

    $self->{maps_counters}->{voltage} = [
        {
            label => 'sensor-voltage-status',
            type => 2,
            unknown_default => '%{status} =~ /unknown/i',
            warning_default => '%{status} =~ /warning|non-critical/i',
            critical_default => '%{status} =~ /critical|not installed|unavailable/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'display' }, { name => 'value' }, { name => 'unit' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'voltage', nlabel => 'sensor.voltage.volt', set => {
                key_values => [ { name => 'value' }, { name => 'display' } ],
                output_template => 'voltage: %s V',
                perfdatas => [
                    { template => '%s', unit => 'V', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];

    $self->{maps_counters}->{current} = [
        {
            label => 'sensor-current-status',
            type => 2,
            unknown_default => '%{status} =~ /unknown/i',
            warning_default => '%{status} =~ /warning|non-critical/i',
            critical_default => '%{status} =~ /critical|not installed|unavailable/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'display' }, { name => 'value' }, { name => 'unit' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'current', nlabel => 'sensor.current.ampere', set => {
                key_values => [ { name => 'value' }, { name => 'display' } ],
                output_template => 'current: %s A',
                perfdatas => [
                    { template => '%s', unit => 'A', label_extra_instance => 1, instance_use => 'display' }
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
        'filter-sensor-name:s'  => { name => 'filter_sensor_name' },
        'filter-sensor-type:s'  => { name => 'filter_sensor_type' },
        'exclude-sensor-name:s' => { name => 'exclude_sensor_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($result) = $options{custom}->get_infos(
        cmd => 'show sensor-status',
        base_type => 'sensors',
        properties_name => '^(?:durable-id|sensor-name|sensor-type|value|status|container|unit)$'
    );

    $self->{temperature} = {};
    $self->{voltage} = {};
    $self->{current} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $sensor (@items) {
        my $name = defined($sensor->{'sensor-name'}) ? $sensor->{'sensor-name'} :
                   (defined($sensor->{'durable-id'}) ? $sensor->{'durable-id'} : 'unknown');

        my $type = defined($sensor->{'sensor-type'}) ? lc($sensor->{'sensor-type'}) : 'unknown';

        if (defined($self->{option_results}->{filter_sensor_name}) && $self->{option_results}->{filter_sensor_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_sensor_name}/) {
            $self->{output}->output_add(long_msg => "skipping sensor '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_sensor_name}) && $self->{option_results}->{exclude_sensor_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_sensor_name}/) {
            $self->{output}->output_add(long_msg => "skipping sensor '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        if (defined($self->{option_results}->{filter_sensor_type}) && $self->{option_results}->{filter_sensor_type} ne '' &&
            $type !~ /$self->{option_results}->{filter_sensor_type}/) {
            $self->{output}->output_add(long_msg => "skipping sensor '" . $name . "' (type: $type): no matching type filter.", debug => 1);
            next;
        }

        my $status = defined($sensor->{'status'}) ? lc($sensor->{'status'}) : 'unknown';
        my $value = defined($sensor->{'value'}) ? $sensor->{'value'} : '';
        my $unit = '';

        # Parse value: may contain unit like "35 C" or "12.1 V" or just "35"
        if ($value =~ /^([\d.]+)\s*(.*)$/) {
            $value = $1;
            $unit = $2 if ($2 ne '');
        }

        # Determine unit from sensor-type if not in value
        if ($unit eq '') {
            $unit = 'C' if ($type =~ /temp/i);
            $unit = 'V' if ($type =~ /volt/i);
            $unit = 'A' if ($type =~ /curr/i);
        }

        my $sensor_data = {
            display => $name,
            status => $status,
            value => $value,
            unit => $unit,
        };

        if ($type =~ /temp/i || $unit eq 'C') {
            $self->{temperature}->{$name} = $sensor_data;
        } elsif ($type =~ /volt/i || $unit eq 'V') {
            $self->{voltage}->{$name} = $sensor_data;
        } elsif ($type =~ /curr/i || $unit eq 'A') {
            $self->{current}->{$name} = $sensor_data;
        } else {
            # Default to temperature for unrecognized types
            $self->{temperature}->{$name} = $sensor_data;
        }
    }

    if (scalar(keys %{$self->{temperature}}) <= 0 && scalar(keys %{$self->{voltage}}) <= 0 && scalar(keys %{$self->{current}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No sensor found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check sensor status (temperature, voltage, and current).

=over 8

=item B<--filter-sensor-name>

Filter sensors by name (can be a regexp).

=item B<--exclude-sensor-name>

Exclude sensors by name (can be a regexp).

=item B<--filter-sensor-type>

Filter sensors by type (can be a regexp). Example: --filter-sensor-type='temperature'

=item B<--unknown-sensor-temperature-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{status} =~ /unknown/i').
You can use the following variables: %{status}, %{display}, %{value}, %{unit}

=item B<--warning-sensor-temperature-status>

Define the conditions to match for the status to be WARNING (default: '%{status} =~ /warning|non-critical/i').
You can use the following variables: %{status}, %{display}, %{value}, %{unit}

=item B<--critical-sensor-temperature-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} =~ /critical|not installed|unavailable/i').
You can use the following variables: %{status}, %{display}, %{value}, %{unit}

=item B<--unknown-sensor-voltage-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{status} =~ /unknown/i').
You can use the following variables: %{status}, %{display}, %{value}, %{unit}

=item B<--warning-sensor-voltage-status>

Define the conditions to match for the status to be WARNING (default: '%{status} =~ /warning|non-critical/i').
You can use the following variables: %{status}, %{display}, %{value}, %{unit}

=item B<--critical-sensor-voltage-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} =~ /critical|not installed|unavailable/i').
You can use the following variables: %{status}, %{display}, %{value}, %{unit}

=item B<--unknown-sensor-current-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{status} =~ /unknown/i').
You can use the following variables: %{status}, %{display}, %{value}, %{unit}

=item B<--warning-sensor-current-status>

Define the conditions to match for the status to be WARNING (default: '%{status} =~ /warning|non-critical/i').
You can use the following variables: %{status}, %{display}, %{value}, %{unit}

=item B<--critical-sensor-current-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} =~ /critical|not installed|unavailable/i').
You can use the following variables: %{status}, %{display}, %{value}, %{unit}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'temperature' (C), 'voltage' (V), 'current' (A).

=back

=cut
