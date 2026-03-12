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

package hardware::sensors::enoc::snmp::mode::power;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my $mapping_power = {
    deviceName  => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.3'  },
    voltageIn   => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.12' },
    currentIn   => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.13' },
    energyIn    => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.14' },
    voltageOut1 => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.15' },
    currentOut1 => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.16' },
    energyOut1  => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.17' },
    voltageOut2 => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.18' },
    currentOut2 => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.19' },
    energyOut2  => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.20' },
    voltageOut3 => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.21' },
    currentOut3 => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.22' },
    energyOut3  => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.23' },
};

# Helper: bouw een closure_custom_perfdata met punt-separator in de label
sub _perfdata_closure {
    my ($field, $label, $fmt, $unit) = @_;
    return sub {
        my ($self, %options) = @_;
        return if (!defined($self->{result_values}->{$field}));
        $self->{output}->perfdata_add(
            label    => do { (my $d = $self->{result_values}->{display}) =~ s/ /_/g; $label . '.' . lc($d) },
            unit     => $unit,
            value    => sprintf($fmt, $self->{result_values}->{$field}),
            warning  => $self->{perfdata}->get_perfdata_for_output(label => 'warning-'  . $field),
            critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $field),
        );
    };
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        {
            name => 'devices', type => 1,
            cb_prefix_output => 'prefix_device_output',
            message_multiple => 'All power measurements are OK',
            skipped_code => { -10 => 1 }
        }
    ];

    $self->{maps_counters}->{devices} = [
        { label => 'voltage-in',  nlabel => 'power.voltage.input.volt', set => {
            key_values => [ { name => 'voltage_in'  }, { name => 'display' } ],
            output_template => 'input voltage: %.1fV', output_use => 'voltage_in',
            closure_custom_perfdata => _perfdata_closure('voltage_in',  'voltage.in.0',   '%.1f', 'V'),
        }},
        { label => 'current-in',  nlabel => 'power.current.input.ampere', set => {
            key_values => [ { name => 'current_in'  }, { name => 'display' } ],
            output_template => 'input current: %.2fA', output_use => 'current_in',
            closure_custom_perfdata => _perfdata_closure('current_in',  'current.in.0',   '%.2f', 'A'),
        }},
        { label => 'energy-in',   nlabel => 'power.energy.input.watthour', set => {
            key_values => [ { name => 'energy_in'   }, { name => 'display' } ],
            output_template => 'input energy: %.1fWh', output_use => 'energy_in',
            closure_custom_perfdata => _perfdata_closure('energy_in',   'energy.in.0',    '%.1f', 'Wh'),
        }},
        { label => 'voltage-out1', nlabel => 'power.voltage.output1.volt', set => {
            key_values => [ { name => 'voltage_out1' }, { name => 'display' } ],
            output_template => 'output1 voltage: %.1fV', output_use => 'voltage_out1',
            closure_custom_perfdata => _perfdata_closure('voltage_out1', 'voltage.out.1', '%.1f', 'V'),
        }},
        { label => 'current-out1', nlabel => 'power.current.output1.ampere', set => {
            key_values => [ { name => 'current_out1' }, { name => 'display' } ],
            output_template => 'output1 current: %.2fA', output_use => 'current_out1',
            closure_custom_perfdata => _perfdata_closure('current_out1', 'current.out.1', '%.2f', 'A'),
        }},
        { label => 'energy-out1',  nlabel => 'power.energy.output1.watthour', set => {
            key_values => [ { name => 'energy_out1'  }, { name => 'display' } ],
            output_template => 'output1 energy: %.1fWh', output_use => 'energy_out1',
            closure_custom_perfdata => _perfdata_closure('energy_out1',  'energy.out.1',  '%.1f', 'Wh'),
        }},
        { label => 'voltage-out2', nlabel => 'power.voltage.output2.volt', set => {
            key_values => [ { name => 'voltage_out2' }, { name => 'display' } ],
            output_template => 'output2 voltage: %.1fV', output_use => 'voltage_out2',
            closure_custom_perfdata => _perfdata_closure('voltage_out2', 'voltage.out.2', '%.1f', 'V'),
        }},
        { label => 'current-out2', nlabel => 'power.current.output2.ampere', set => {
            key_values => [ { name => 'current_out2' }, { name => 'display' } ],
            output_template => 'output2 current: %.2fA', output_use => 'current_out2',
            closure_custom_perfdata => _perfdata_closure('current_out2', 'current.out.2', '%.2f', 'A'),
        }},
        { label => 'energy-out2',  nlabel => 'power.energy.output2.watthour', set => {
            key_values => [ { name => 'energy_out2'  }, { name => 'display' } ],
            output_template => 'output2 energy: %.1fWh', output_use => 'energy_out2',
            closure_custom_perfdata => _perfdata_closure('energy_out2',  'energy.out.2',  '%.1f', 'Wh'),
        }},
        { label => 'voltage-out3', nlabel => 'power.voltage.output3.volt', set => {
            key_values => [ { name => 'voltage_out3' }, { name => 'display' } ],
            output_template => 'output3 voltage: %.1fV', output_use => 'voltage_out3',
            closure_custom_perfdata => _perfdata_closure('voltage_out3', 'voltage.out.3', '%.1f', 'V'),
        }},
        { label => 'current-out3', nlabel => 'power.current.output3.ampere', set => {
            key_values => [ { name => 'current_out3' }, { name => 'display' } ],
            output_template => 'output3 current: %.2fA', output_use => 'current_out3',
            closure_custom_perfdata => _perfdata_closure('current_out3', 'current.out.3', '%.2f', 'A'),
        }},
        { label => 'energy-out3',  nlabel => 'power.energy.output3.watthour', set => {
            key_values => [ { name => 'energy_out3'  }, { name => 'display' } ],
            output_template => 'output3 energy: %.1fWh', output_use => 'energy_out3',
            closure_custom_perfdata => _perfdata_closure('energy_out3',  'energy.out.3',  '%.1f', 'Wh'),
        }},
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        'filter-device:s'  => { name => 'filter_device'  },
        'exclude-device:s' => { name => 'exclude_device' },
        'filter-metric:s'  => { name => 'filter_metric'  },
        'exclude-metric:s' => { name => 'exclude_metric' },
        'filter-phase:s'   => { name => 'filter_phase'   },
        'exclude-phase:s'  => { name => 'exclude_phase'  },
    });
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
}

sub prefix_device_output {
    my ($self, %options) = @_;
    return "Device '" . $options{instance_value}->{display} . "' ";
}

sub _val {
    my ($snmp_result, $oid, $instance) = @_;
    my $v = $snmp_result->{$oid}->{ $oid . '.' . $instance };
    return (defined($v) && $v ne '--') ? $v + 0 : undef;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_multiple_table(
        oids => [ map { { oid => $_->{oid} } } values %$mapping_power ],
        nothing_quit => 1
    );

    $self->{devices} = {};

    foreach my $oid (keys %{$snmp_result->{ $mapping_power->{deviceName}->{oid} }}) {
        next if ($oid !~ /^$mapping_power->{deviceName}->{oid}\.(.+)$/);
        my $instance    = $1;
        my $device_name = $snmp_result->{ $mapping_power->{deviceName}->{oid} }->{$oid};

        if (defined($self->{option_results}->{filter_device}) &&
            $self->{option_results}->{filter_device} ne '' &&
            $device_name !~ /$self->{option_results}->{filter_device}/) {
            $self->{output}->output_add(long_msg => "skipping device '$device_name' (filter-device)", debug => 1);
            next;
        }

        if (defined($self->{option_results}->{exclude_device}) &&
            $self->{option_results}->{exclude_device} ne '' &&
            $device_name =~ /$self->{option_results}->{exclude_device}/) {
            $self->{output}->output_add(long_msg => "skipping device '$device_name' (exclude-device)", debug => 1);
            next;
        }

        # Helper: check of een metric/fase toegelaten is
        my $allow = sub {
            my ($metric, $phase) = @_;
            if (defined($self->{option_results}->{filter_metric}) && $self->{option_results}->{filter_metric} ne '') {
                return 0 if ($metric !~ /$self->{option_results}->{filter_metric}/);
            }
            if (defined($self->{option_results}->{exclude_metric}) && $self->{option_results}->{exclude_metric} ne '') {
                return 0 if ($metric =~ /$self->{option_results}->{exclude_metric}/);
            }
            if (defined($self->{option_results}->{filter_phase}) && $self->{option_results}->{filter_phase} ne '') {
                return 0 if ($phase !~ /$self->{option_results}->{filter_phase}/);
            }
            if (defined($self->{option_results}->{exclude_phase}) && $self->{option_results}->{exclude_phase} ne '') {
                return 0 if ($phase =~ /$self->{option_results}->{exclude_phase}/);
            }
            return 1;
        };

        $self->{devices}->{$instance} = {
            display      => $device_name,
            voltage_in   => $allow->('voltage', 'in')    ? _val($snmp_result, $mapping_power->{voltageIn}->{oid},   $instance) : undef,
            current_in   => $allow->('current', 'in')    ? _val($snmp_result, $mapping_power->{currentIn}->{oid},   $instance) : undef,
            energy_in    => $allow->('energy',  'in')    ? _val($snmp_result, $mapping_power->{energyIn}->{oid},    $instance) : undef,
            voltage_out1 => $allow->('voltage', 'out.1') ? _val($snmp_result, $mapping_power->{voltageOut1}->{oid}, $instance) : undef,
            current_out1 => $allow->('current', 'out.1') ? _val($snmp_result, $mapping_power->{currentOut1}->{oid}, $instance) : undef,
            energy_out1  => $allow->('energy',  'out.1') ? _val($snmp_result, $mapping_power->{energyOut1}->{oid},  $instance) : undef,
            voltage_out2 => $allow->('voltage', 'out.2') ? _val($snmp_result, $mapping_power->{voltageOut2}->{oid}, $instance) : undef,
            current_out2 => $allow->('current', 'out.2') ? _val($snmp_result, $mapping_power->{currentOut2}->{oid}, $instance) : undef,
            energy_out2  => $allow->('energy',  'out.2') ? _val($snmp_result, $mapping_power->{energyOut2}->{oid},  $instance) : undef,
            voltage_out3 => $allow->('voltage', 'out.3') ? _val($snmp_result, $mapping_power->{voltageOut3}->{oid}, $instance) : undef,
            current_out3 => $allow->('current', 'out.3') ? _val($snmp_result, $mapping_power->{currentOut3}->{oid}, $instance) : undef,
            energy_out3  => $allow->('energy',  'out.3') ? _val($snmp_result, $mapping_power->{energyOut3}->{oid},  $instance) : undef,
        };
    }

    if (scalar(keys %{$self->{devices}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No ENOC devices found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check ENOC EPB power measurements (voltage, current, energy).

=over 8

=item B<--filter-device>

Toon enkel devices waarvan de naam matcht (regex). Voorbeeld: --filter-device="Slave A7"

=item B<--exclude-device>

Sla devices over waarvan de naam matcht (regex). Voorbeeld: --exclude-device="Master"

=item B<--filter-metric>

Toon enkel een bepaald type meting (regex: voltage, current, energy).
Voorbeeld: --filter-metric="voltage"

=item B<--exclude-metric>

Sluit een bepaald type meting uit (regex: voltage, current, energy).
Voorbeeld: --exclude-metric="energy"

=item B<--filter-phase>

Toon enkel een bepaalde fase (regex: in, out.1, out.2, out.3).
Voorbeeld: --filter-phase="out"  of  --filter-phase="out\.1"

=item B<--exclude-phase>

Sluit een bepaalde fase uit (regex: in, out.1, out.2, out.3).
Voorbeeld: --exclude-phase="out\.3"

=item B<--warning-voltage-in> B<--critical-voltage-in>

Drempelwaarden voor ingangs spanning (V).

=item B<--warning-current-in> B<--critical-current-in>

Drempelwaarden voor ingangs stroom (A).

=item B<--warning-energy-in> B<--critical-energy-in>

Drempelwaarden voor ingangs energie (Wh).

=head1 AUTHOR

Centreon (http://www.centreon.com/)

=head1 LICENSE

Licensed under the Apache License, Version 2.0.
See http://www.apache.org/licenses/LICENSE-2.0

=cut
