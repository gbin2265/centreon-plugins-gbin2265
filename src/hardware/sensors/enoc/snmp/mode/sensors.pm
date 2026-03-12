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

package hardware::sensors::enoc::snmp::mode::sensors;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

# OID mapping voor ENOC EPB (enterprise 30966)
# .30966.2.2.1.1.3.X  = device naam
# .30966.2.2.1.1.4.X  = temperatuur sensor 1 (C)
# .30966.2.2.1.1.5.X  = vochtigheid sensor 1 (%)
# .30966.2.2.1.1.6.X  = temperatuur sensor 2 (C)
# .30966.2.2.1.1.7.X  = vochtigheid sensor 2 (%)
# Drempelwaarden (.30966.2.3.1.1):
# .3.X  = temp warn laag   .4.X  = temp warn hoog
# .5.X  = temp crit laag   .6.X  = temp crit hoog
# .7.X  = hum warn laag    .8.X  = hum warn hoog
# .9.X  = hum crit laag    .10.X = hum crit hoog

my $mapping_sensors = {
    deviceName => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.3'  },
    temp1      => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.4'  },
    hum1       => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.5'  },
    temp2      => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.6'  },
    hum2       => { oid => '.1.3.6.1.4.1.30966.2.2.1.1.7'  },
};

my $mapping_thresholds = {
    tempWarnLow  => { oid => '.1.3.6.1.4.1.30966.2.3.1.1.3'  },
    tempWarnHigh => { oid => '.1.3.6.1.4.1.30966.2.3.1.1.4'  },
    tempCritLow  => { oid => '.1.3.6.1.4.1.30966.2.3.1.1.5'  },
    tempCritHigh => { oid => '.1.3.6.1.4.1.30966.2.3.1.1.6'  },
    humWarnLow   => { oid => '.1.3.6.1.4.1.30966.2.3.1.1.7'  },
    humWarnHigh  => { oid => '.1.3.6.1.4.1.30966.2.3.1.1.8'  },
    humCritLow   => { oid => '.1.3.6.1.4.1.30966.2.3.1.1.9'  },
    humCritHigh  => { oid => '.1.3.6.1.4.1.30966.2.3.1.1.10' },
};

# Helper: bouw perfdata closure - zelfde patroon als power.pm

sub _perfdata_closure {
    my ($field, $label, $fmt, $unit, $warn_label, $crit_label, $min, $max) = @_;
    return sub {
        my ($self, %options) = @_;
        return if (!defined($self->{result_values}->{$field}));
        (my $d = $self->{result_values}->{display}) =~ s/ /_/g;
        $self->{output}->perfdata_add(
            label    => $label . '.' . lc($d),
            unit     => $unit,
            value    => sprintf($fmt, $self->{result_values}->{$field}),
            warning  => $self->{perfdata}->get_perfdata_for_output(label => $warn_label),
            critical => $self->{perfdata}->get_perfdata_for_output(label => $crit_label),
            (defined($min) ? (min => $min) : ()),
            (defined($max) ? (max => $max) : ()),
        );
    };
}

# Threshold closures - device-eigen drempelwaarden

sub _threshold_closure_temp {
    my ($field) = @_;
    return sub {
        my ($self, %options) = @_;
        my $value     = $self->{result_values}->{$field};
        my $warn_low  = $self->{result_values}->{temp_warn_low};
        my $warn_high = $self->{result_values}->{temp_warn_high};
        my $crit_low  = $self->{result_values}->{temp_crit_low};
        my $crit_high = $self->{result_values}->{temp_crit_high};
        return 'ok' unless defined($value);
        if (defined($crit_high) && $value >= $crit_high) { return 'critical'; }
        if (defined($crit_low)  && $value <= $crit_low)  { return 'critical'; }
        if (defined($warn_high) && $value >= $warn_high)  { return 'warning';  }
        if (defined($warn_low)  && $value <= $warn_low)   { return 'warning';  }
        return 'ok';
    };
}

sub _threshold_closure_hum {
    my ($field) = @_;
    return sub {
        my ($self, %options) = @_;
        my $value     = $self->{result_values}->{$field};
        my $warn_low  = $self->{result_values}->{hum_warn_low};
        my $warn_high = $self->{result_values}->{hum_warn_high};
        my $crit_low  = $self->{result_values}->{hum_crit_low};
        my $crit_high = $self->{result_values}->{hum_crit_high};
        return 'ok' unless defined($value);
        if (defined($crit_high) && $value >= $crit_high) { return 'critical'; }
        if (defined($crit_low)  && $value <= $crit_low)  { return 'critical'; }
        if (defined($warn_high) && $value >= $warn_high)  { return 'warning';  }
        if (defined($warn_low)  && $value <= $warn_low)   { return 'warning';  }
        return 'ok';
    };
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        {
            name             => 'devices',
            type             => 1,
            cb_prefix_output => 'prefix_device_output',
            message_multiple => 'All sensors are OK',
            skipped_code     => { -10 => 1 },
        }
    ];

    $self->{maps_counters}->{devices} = [
        { label => 'temperature1', nlabel => 'sensor.temperature1.celsius', set => {
            key_values => [
                { name => 'temp1' }, { name => 'display' },
                { name => 'temp_warn_low',  no_value => '' },
                { name => 'temp_warn_high', no_value => '' },
                { name => 'temp_crit_low',  no_value => '' },
                { name => 'temp_crit_high', no_value => '' },
            ],
            output_template => 'temperature sensor 1: %.1f C',
            output_use      => 'temp1',
            closure_custom_perfdata        => _perfdata_closure('temp1', 'temp.1', '%.1f', 'C', 'warning-temperature1', 'critical-temperature1', undef, undef),
            closure_custom_threshold_check => _threshold_closure_temp('temp1'),
        }},
        { label => 'humidity1', nlabel => 'sensor.humidity1.percentage', set => {
            key_values => [
                { name => 'hum1' }, { name => 'display' },
                { name => 'hum_warn_low',  no_value => '' },
                { name => 'hum_warn_high', no_value => '' },
                { name => 'hum_crit_low',  no_value => '' },
                { name => 'hum_crit_high', no_value => '' },
            ],
            output_template => 'humidity sensor 1: %.1f %%',
            output_use      => 'hum1',
            closure_custom_perfdata        => _perfdata_closure('hum1', 'hum.1', '%.1f', '%', 'warning-humidity1', 'critical-humidity1', 0, 100),
            closure_custom_threshold_check => _threshold_closure_hum('hum1'),
        }},
        { label => 'temperature2', nlabel => 'sensor.temperature2.celsius', set => {
            key_values => [
                { name => 'temp2' }, { name => 'display' },
                { name => 'temp_warn_low',  no_value => '' },
                { name => 'temp_warn_high', no_value => '' },
                { name => 'temp_crit_low',  no_value => '' },
                { name => 'temp_crit_high', no_value => '' },
            ],
            output_template => 'temperature sensor 2: %.1f C',
            output_use      => 'temp2',
            closure_custom_perfdata        => _perfdata_closure('temp2', 'temp.2', '%.1f', 'C', 'warning-temperature2', 'critical-temperature2', undef, undef),
            closure_custom_threshold_check => _threshold_closure_temp('temp2'),
        }},
        { label => 'humidity2', nlabel => 'sensor.humidity2.percentage', set => {
            key_values => [
                { name => 'hum2' }, { name => 'display' },
                { name => 'hum_warn_low',  no_value => '' },
                { name => 'hum_warn_high', no_value => '' },
                { name => 'hum_crit_low',  no_value => '' },
                { name => 'hum_crit_high', no_value => '' },
            ],
            output_template => 'humidity sensor 2: %.1f %%',
            output_use      => 'hum2',
            closure_custom_perfdata        => _perfdata_closure('hum2', 'hum.2', '%.1f', '%', 'warning-humidity2', 'critical-humidity2', 0, 100),
            closure_custom_threshold_check => _threshold_closure_hum('hum2'),
        }},
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-device:s'  => { name => 'filter_device'  },
        'exclude-device:s' => { name => 'exclude_device' },
        'filter-sensor:s'  => { name => 'filter_sensor'  },
        'exclude-sensor:s' => { name => 'exclude_sensor' },
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

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_multiple_table(
        oids => [
            { oid => $mapping_sensors->{deviceName}->{oid} },
            { oid => $mapping_sensors->{temp1}->{oid} },
            { oid => $mapping_sensors->{hum1}->{oid} },
            { oid => $mapping_sensors->{temp2}->{oid} },
            { oid => $mapping_sensors->{hum2}->{oid} },
            { oid => $mapping_thresholds->{tempWarnLow}->{oid} },
            { oid => $mapping_thresholds->{tempWarnHigh}->{oid} },
            { oid => $mapping_thresholds->{tempCritLow}->{oid} },
            { oid => $mapping_thresholds->{tempCritHigh}->{oid} },
            { oid => $mapping_thresholds->{humWarnLow}->{oid} },
            { oid => $mapping_thresholds->{humWarnHigh}->{oid} },
            { oid => $mapping_thresholds->{humCritLow}->{oid} },
            { oid => $mapping_thresholds->{humCritHigh}->{oid} },
        ],
        nothing_quit => 1
    );

    $self->{devices} = {};

    foreach my $oid (keys %{$snmp_result->{ $mapping_sensors->{deviceName}->{oid} }}) {
        next if ($oid !~ /^$mapping_sensors->{deviceName}->{oid}\.(.+)$/);
        my $instance    = $1;
        my $device_name = $snmp_result->{ $mapping_sensors->{deviceName}->{oid} }->{$oid};

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

        my $temp1 = $snmp_result->{ $mapping_sensors->{temp1}->{oid} }->{ $mapping_sensors->{temp1}->{oid} . '.' . $instance };
        my $hum1  = $snmp_result->{ $mapping_sensors->{hum1}->{oid}  }->{ $mapping_sensors->{hum1}->{oid}  . '.' . $instance };
        my $temp2 = $snmp_result->{ $mapping_sensors->{temp2}->{oid} }->{ $mapping_sensors->{temp2}->{oid} . '.' . $instance };
        my $hum2  = $snmp_result->{ $mapping_sensors->{hum2}->{oid}  }->{ $mapping_sensors->{hum2}->{oid}  . '.' . $instance };

        my ($use_s1, $use_s2) = (1, 1);
        if (defined($self->{option_results}->{filter_sensor}) && $self->{option_results}->{filter_sensor} ne '') {
            $use_s1 = ('1' =~ /$self->{option_results}->{filter_sensor}/) ? 1 : 0;
            $use_s2 = ('2' =~ /$self->{option_results}->{filter_sensor}/) ? 1 : 0;
        }
        if (defined($self->{option_results}->{exclude_sensor}) && $self->{option_results}->{exclude_sensor} ne '') {
            $use_s1 = 0 if ('1' =~ /$self->{option_results}->{exclude_sensor}/);
            $use_s2 = 0 if ('2' =~ /$self->{option_results}->{exclude_sensor}/);
        }
        $temp1 = undef unless $use_s1;
        $hum1  = undef unless $use_s1;
        $temp2 = undef unless $use_s2;
        $hum2  = undef unless $use_s2;

        my $twl = $snmp_result->{ $mapping_thresholds->{tempWarnLow}->{oid}  }->{ $mapping_thresholds->{tempWarnLow}->{oid}  . '.' . $instance };
        my $twh = $snmp_result->{ $mapping_thresholds->{tempWarnHigh}->{oid} }->{ $mapping_thresholds->{tempWarnHigh}->{oid} . '.' . $instance };
        my $tcl = $snmp_result->{ $mapping_thresholds->{tempCritLow}->{oid}  }->{ $mapping_thresholds->{tempCritLow}->{oid}  . '.' . $instance };
        my $tch = $snmp_result->{ $mapping_thresholds->{tempCritHigh}->{oid} }->{ $mapping_thresholds->{tempCritHigh}->{oid} . '.' . $instance };
        my $hwl = $snmp_result->{ $mapping_thresholds->{humWarnLow}->{oid}   }->{ $mapping_thresholds->{humWarnLow}->{oid}   . '.' . $instance };
        my $hwh = $snmp_result->{ $mapping_thresholds->{humWarnHigh}->{oid}  }->{ $mapping_thresholds->{humWarnHigh}->{oid}  . '.' . $instance };
        my $hcl = $snmp_result->{ $mapping_thresholds->{humCritLow}->{oid}   }->{ $mapping_thresholds->{humCritLow}->{oid}   . '.' . $instance };
        my $hch = $snmp_result->{ $mapping_thresholds->{humCritHigh}->{oid}  }->{ $mapping_thresholds->{humCritHigh}->{oid}  . '.' . $instance };

        $self->{devices}->{$instance} = {
            display        => $device_name,
            temp1          => (defined($temp1) && $temp1 ne '--') ? $temp1 + 0 : undef,
            hum1           => (defined($hum1)  && $hum1  ne '--') ? $hum1  + 0 : undef,
            temp2          => (defined($temp2) && $temp2 ne '--') ? $temp2 + 0 : undef,
            hum2           => (defined($hum2)  && $hum2  ne '--') ? $hum2  + 0 : undef,
            temp_warn_low  => (defined($twl) && $twl ne '--') ? $twl + 0 : undef,
            temp_warn_high => (defined($twh) && $twh ne '--') ? $twh + 0 : undef,
            temp_crit_low  => (defined($tcl) && $tcl ne '--') ? $tcl + 0 : undef,
            temp_crit_high => (defined($tch) && $tch ne '--') ? $tch + 0 : undef,
            hum_warn_low   => (defined($hwl) && $hwl ne '--') ? $hwl + 0 : undef,
            hum_warn_high  => (defined($hwh) && $hwh ne '--') ? $hwh + 0 : undef,
            hum_crit_low   => (defined($hcl) && $hcl ne '--') ? $hcl + 0 : undef,
            hum_crit_high  => (defined($hch) && $hch ne '--') ? $hch + 0 : undef,
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

Check ENOC EPB temperature and humidity sensors.

=over 8

=item B<--filter-device>

Toon enkel devices waarvan de naam matcht (regex). Voorbeeld: --filter-device="Master"

=item B<--exclude-device>

Sla devices over waarvan de naam matcht (regex). Voorbeeld: --exclude-device="Slave A3"

=item B<--filter-sensor>

Toon enkel sensor nummer 1 of 2. Voorbeeld: --filter-sensor="1"

=item B<--exclude-sensor>

Sluit sensor nummer 1 of 2 uit. Voorbeeld: --exclude-sensor="2"

=item B<--warning-temperature1>

Warning drempel temperatuur sensor 1 (overschrijft device drempel).

=item B<--critical-temperature1>

Critical drempel temperatuur sensor 1 (overschrijft device drempel).

=item B<--warning-humidity1>

Warning drempel vochtigheid sensor 1 (overschrijft device drempel).

=item B<--critical-humidity1>

Critical drempel vochtigheid sensor 1 (overschrijft device drempel).

=item B<--warning-temperature2>

Warning drempel temperatuur sensor 2 (overschrijft device drempel).

=item B<--critical-temperature2>

Critical drempel temperatuur sensor 2 (overschrijft device drempel).

=item B<--warning-humidity2>

Warning drempel vochtigheid sensor 2 (overschrijft device drempel).

=item B<--critical-humidity2>

Critical drempel vochtigheid sensor 2 (overschrijft device drempel).

=back

=head1 AUTHOR

Centreon (http://www.centreon.com/)

=head1 LICENSE

Licensed under the Apache License, Version 2.0.
See http://www.apache.org/licenses/LICENSE-2.0

=cut
