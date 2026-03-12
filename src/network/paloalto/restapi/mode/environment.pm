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

package network::paloalto::restapi::mode::environment;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_psu_status_output {
    my ($self, %options) = @_;

    return sprintf('alarm: %s', $self->{result_values}->{alarm});
}

sub custom_fan_status_output {
    my ($self, %options) = @_;

    return sprintf('alarm: %s [%s RPM]', $self->{result_values}->{alarm}, $self->{result_values}->{rpm});
}

sub prefix_temperature_output {
    my ($self, %options) = @_;

    return "Temperature sensor '" . $options{instance_value}->{display} . "' ";
}

sub prefix_fan_output {
    my ($self, %options) = @_;

    return "Fan '" . $options{instance_value}->{display} . "' ";
}

sub prefix_psu_output {
    my ($self, %options) = @_;

    return "Power supply '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'temperatures', type => 1, cb_prefix_output => 'prefix_temperature_output', message_multiple => 'All temperatures are ok' },
        { name => 'fans', type => 1, cb_prefix_output => 'prefix_fan_output', message_multiple => 'All fans are ok' },
        { name => 'psus', type => 1, cb_prefix_output => 'prefix_psu_output', message_multiple => 'All power supplies are ok' }
    ];

    $self->{maps_counters}->{temperatures} = [
        { label => 'temperature', nlabel => 'hardware.temperature.celsius', set => {
                key_values => [ { name => 'temperature' }, { name => 'display' }, { name => 'min' }, { name => 'max' } ],
                output_template => '%s C',
                perfdatas => [
                    { template => '%s', unit => 'C', label_extra_instance => 1, instance_use => 'display',
                      min => 'min', max => 'max' }
                ]
            }
        },
        { label => 'temperature-alarm', type => 2, critical_default => '%{alarm} ne "false" and %{alarm} ne "False"', set => {
                key_values => [ { name => 'alarm' }, { name => 'display' } ],
                output_template => 'alarm: %s',
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{fans} = [
        { label => 'fan-speed', nlabel => 'hardware.fan.speed.rpm', set => {
                key_values => [ { name => 'rpm' }, { name => 'display' } ],
                output_template => '%s RPM',
                perfdatas => [
                    { template => '%s', unit => 'rpm', label_extra_instance => 1, instance_use => 'display', min => 0 }
                ]
            }
        },
        { label => 'fan-alarm', type => 2, critical_default => '%{alarm} ne "false" and %{alarm} ne "False"', set => {
                key_values => [ { name => 'alarm' }, { name => 'rpm' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_fan_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{psus} = [
        { label => 'psu-alarm', type => 2, critical_default => '%{alarm} ne "false" and %{alarm} ne "False"', set => {
                key_values => [ { name => 'alarm' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_psu_status_output'),
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
        'filter-sensor:s' => { name => 'filter_sensor' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(
        cmd => '<show><system><environmentals></environmentals></system></show>',
        ForceArray => ['entry']
    );

    $self->{temperatures} = {};
    $self->{fans} = {};
    $self->{psus} = {};

    # Temperature sensors - stored under 'thermal' key with slot sub-keys
    if (defined($result->{thermal})) {
        foreach my $slot (values %{$result->{thermal}}) {
            next if (ref($slot) ne 'HASH' || !defined($slot->{entry}));
            foreach my $entry (@{$slot->{entry}}) {
                my $desc = defined($entry->{description}) ? $entry->{description} : 'unknown';
                next if (defined($self->{option_results}->{filter_sensor}) && $self->{option_results}->{filter_sensor} ne '' &&
                    $desc !~ /$self->{option_results}->{filter_sensor}/);

                $self->{temperatures}->{$desc} = {
                    display     => $desc,
                    temperature => defined($entry->{DegreesC}) ? $entry->{DegreesC} : 0,
                    alarm       => defined($entry->{alarm}) ? $entry->{alarm} : 'unknown',
                    min         => defined($entry->{min}) ? $entry->{min} : undef,
                    max         => defined($entry->{max}) ? $entry->{max} : undef
                };
            }
        }
    }

    # Fan sensors
    if (defined($result->{fan})) {
        foreach my $slot (values %{$result->{fan}}) {
            next if (ref($slot) ne 'HASH' || !defined($slot->{entry}));
            foreach my $entry (@{$slot->{entry}}) {
                my $desc = defined($entry->{description}) ? $entry->{description} : 'unknown';
                next if (defined($self->{option_results}->{filter_sensor}) && $self->{option_results}->{filter_sensor} ne '' &&
                    $desc !~ /$self->{option_results}->{filter_sensor}/);

                $self->{fans}->{$desc} = {
                    display => $desc,
                    rpm     => defined($entry->{RPMs}) ? $entry->{RPMs} : 0,
                    alarm   => defined($entry->{alarm}) ? $entry->{alarm} : 'unknown'
                };
            }
        }
    }

    # Power supply
    if (defined($result->{'power-supply'})) {
        foreach my $slot (values %{$result->{'power-supply'}}) {
            next if (ref($slot) ne 'HASH' || !defined($slot->{entry}));
            foreach my $entry (@{$slot->{entry}}) {
                my $desc = defined($entry->{description}) ? $entry->{description} : 'unknown';
                next if (defined($self->{option_results}->{filter_sensor}) && $self->{option_results}->{filter_sensor} ne '' &&
                    $desc !~ /$self->{option_results}->{filter_sensor}/);

                $self->{psus}->{$desc} = {
                    display => $desc,
                    alarm   => defined($entry->{alarm}) ? $entry->{alarm} : 'unknown'
                };
            }
        }
    }
}

1;

__END__

=head1 MODE

Check hardware environment (temperature, fans, power supplies).

=over 8

=item B<--filter-sensor>

Filter sensor by description (can be a regexp).

=item B<--warning-temperature>

Warning threshold for temperature in Celsius.

=item B<--critical-temperature>

Critical threshold for temperature in Celsius.

=item B<--warning-fan-speed>

Warning threshold for fan speed in RPM.

=item B<--critical-fan-speed>

Critical threshold for fan speed in RPM.

=item B<--unknown-temperature-alarm>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{alarm}, %{display}.

=item B<--warning-temperature-alarm>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{alarm}, %{display}.

=item B<--critical-temperature-alarm>

Define the conditions to match for the status to be CRITICAL (default: '%{alarm} ne "false" and %{alarm} ne "False"').
You can use the following variables: %{alarm}, %{display}.

=item B<--unknown-fan-alarm>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{alarm}, %{rpm}, %{display}.

=item B<--warning-fan-alarm>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{alarm}, %{rpm}, %{display}.

=item B<--critical-fan-alarm>

Define the conditions to match for the status to be CRITICAL (default: '%{alarm} ne "false" and %{alarm} ne "False"').
You can use the following variables: %{alarm}, %{rpm}, %{display}.

=item B<--unknown-psu-alarm>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{alarm}, %{display}.

=item B<--warning-psu-alarm>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{alarm}, %{display}.

=item B<--critical-psu-alarm>

Define the conditions to match for the status to be CRITICAL (default: '%{alarm} ne "false" and %{alarm} ne "False"').
You can use the following variables: %{alarm}, %{display}.

=back

=cut
