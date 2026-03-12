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

package storage::hp::msa2000::ssh::mode::powersupplies;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf('status: %s [location: %s]', $self->{result_values}->{health}, $self->{result_values}->{location});
}

sub prefix_psu_output {
    my ($self, %options) = @_;

    return "Power supply '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'psu', type => 1, cb_prefix_output => 'prefix_psu_output', message_multiple => 'All power supplies are ok' }
    ];

    $self->{maps_counters}->{psu} = [
        {
            label => 'status',
            type => 2,
            unknown_default => '%{health} =~ /unknown/i',
            warning_default => '',
            critical_default => '%{health} =~ /degraded|fault|failed|off|error/i',
            set => {
                key_values => [ { name => 'health' }, { name => 'display' }, { name => 'location' }, { name => 'reason' }, { name => 'recommendation' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'psu-temperature', nlabel => 'psu.temperature.celsius', display_ok => 0, set => {
                key_values => [ { name => 'temperature' }, { name => 'display' } ],
                output_template => 'temperature: %.1f C',
                perfdatas => [
                    { template => '%.1f', unit => 'C', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'psu-voltage', nlabel => 'psu.voltage.volt', display_ok => 0, set => {
                key_values => [ { name => 'voltage' }, { name => 'display' } ],
                output_template => 'voltage: %.2f V',
                perfdatas => [
                    { template => '%.2f', unit => 'V', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'psu-current', nlabel => 'psu.current.ampere', display_ok => 0, set => {
                key_values => [ { name => 'current' }, { name => 'display' } ],
                output_template => 'current: %.2f A',
                perfdatas => [
                    { template => '%.2f', unit => 'A', label_extra_instance => 1, instance_use => 'display' }
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
        'filter-psu-name:s' => { name => 'filter_psu_name' },
        'exclude-psu-name:s' => { name => 'exclude_psu_name' }
    });

    return $self;
}

my $map_health = {
    0 => 'ok', 1 => 'degraded',
    2 => 'fault', 3 => 'unknown',
    4 => 'not available',
};

sub manage_selection {
    my ($self, %options) = @_;

    my ($result) = $options{custom}->get_infos(
        cmd => 'show power-supplies',
        base_type => 'power-supplies',
        properties_name => '^(?:durable-id|dom-id|name|location|serial-number|model|vendor|status|status-numeric|health|health-numeric|health-reason|health-recommendation|dc12v|dc5v|dc33v|dc12i|dc5i|dctemp|position|revision)$'
    );

    $self->{psu} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $psu (@items) {
        my $name = defined($psu->{'durable-id'}) ? $psu->{'durable-id'} :
                   (defined($psu->{'name'}) ? $psu->{'name'} :
                   (defined($psu->{'location'}) ? $psu->{'location'} : 'unknown'));

        if (defined($self->{option_results}->{filter_psu_name}) && $self->{option_results}->{filter_psu_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_psu_name}/) {
            $self->{output}->output_add(long_msg => "skipping power supply '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_psu_name}) && $self->{option_results}->{exclude_psu_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_psu_name}/) {
            $self->{output}->output_add(long_msg => "skipping power supply '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $health = defined($psu->{'health-numeric'}) ?
            ($map_health->{ $psu->{'health-numeric'} } // 'unknown') :
            (defined($psu->{'health'}) ? lc($psu->{'health'}) :
            (defined($psu->{'status'}) ? lc($psu->{'status'}) : 'unknown'));

        $self->{psu}->{$name} = {
            display => $name,
            health => $health,
            location => defined($psu->{'location'}) ? $psu->{'location'} : '-',
            reason => defined($psu->{'health-reason'}) ? $psu->{'health-reason'} : '',
            recommendation => defined($psu->{'health-recommendation'}) ? $psu->{'health-recommendation'} : '',
            dom_id => defined($psu->{'dom-id'}) ? $psu->{'dom-id'} : undef,
            temperature => undef,
            voltage => undef,
            current => undef,
        };
    }

    # Fetch sensor-status to get PSU temperature, voltage, current
    my ($sensor_result) = $options{custom}->get_infos(
        cmd => 'show sensor-status',
        base_type => 'sensors',
        properties_name => '^(?:durable-id|sensor-name|sensor-type|value|status|container)$',
        no_quit => 1
    );

    if (defined($sensor_result)) {
        my @sensor_items = ref($sensor_result) eq 'ARRAY' ? @$sensor_result : values %$sensor_result;

        # Build per-PSU sensor averages
        my %psu_sensors; # { psu_dom_id => { temp => [], volt => [], curr => [] } }

        foreach my $sensor (@sensor_items) {
            my $did = defined($sensor->{'durable-id'}) ? $sensor->{'durable-id'} : '';
            # Match sensor_temp_psu_X.N.M, sensor_volt_psu_X.N.M, sensor_curr_psu_X.N.M
            # N = PSU dom-id
            next unless ($did =~ /^sensor_(temp|volt|curr)_psu_\d+\.(\d+)\.\d+$/);
            my $type = $1;
            my $psu_num = $2;

            my $value = defined($sensor->{'value'}) ? $sensor->{'value'} : next;
            $value =~ s/[^\d.-]//g;
            next if ($value eq '');

            $psu_sensors{$psu_num} //= { temp => [], volt => [], curr => [] };
            push @{$psu_sensors{$psu_num}->{$type}}, $value;
        }

        # Assign averaged sensor values to matching PSUs
        foreach my $psu_name (keys %{$self->{psu}}) {
            my $dom_id = $self->{psu}->{$psu_name}->{dom_id};
            next if (!defined($dom_id) || !defined($psu_sensors{$dom_id}));

            my $s = $psu_sensors{$dom_id};
            if (scalar(@{$s->{temp}}) > 0) {
                my $sum = 0; $sum += $_ for @{$s->{temp}};
                $self->{psu}->{$psu_name}->{temperature} = $sum / scalar(@{$s->{temp}});
            }
            if (scalar(@{$s->{volt}}) > 0) {
                my $sum = 0; $sum += $_ for @{$s->{volt}};
                $self->{psu}->{$psu_name}->{voltage} = $sum / scalar(@{$s->{volt}});
            }
            if (scalar(@{$s->{curr}}) > 0) {
                my $sum = 0; $sum += $_ for @{$s->{curr}};
                $self->{psu}->{$psu_name}->{current} = $sum / scalar(@{$s->{curr}});
            }
        }
    }

    if (scalar(keys %{$self->{psu}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No power supply found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check power supplies health, temperature, voltage and current.

Uses 'show power-supplies' for health/status and 'show sensor-status' for PSU sensor readings.

=over 8

=item B<--filter-psu-name>

Filter power supplies by name (can be a regexp).

=item B<--exclude-psu-name>

Exclude power supplies by name (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{health} =~ /unknown/i').
You can use the following variables: %{health}, %{display}, %{location}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{health} =~ /degraded/i').
You can use the following variables: %{health}, %{display}, %{location}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{health} =~ /fault|failed|off|error/i').
You can use the following variables: %{health}, %{display}, %{location}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'psu-temperature' (C), 'psu-voltage' (V), 'psu-current' (A).

=back

=cut
