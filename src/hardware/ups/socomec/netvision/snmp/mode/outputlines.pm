#
# Copyright 2026 Centreon (http://www.centreon.com/)
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

package hardware::ups::socomec::netvision::snmp::mode::outputlines;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("Output source status is '%s'", $self->{result_values}->{status});
}

sub prefix_oline_output {
    my ($self, %options) = @_;
    return "Output line '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'oline',  type => 1, cb_prefix_output => 'prefix_oline_output',
          message_multiple => 'All output lines are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'source-status',
            type  => 2,
            unknown_default => '%{status} =~ /unknown/i',
            set => {
                key_values => [ { name => 'status' } ],
                closure_custom_output   => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'frequence', nlabel => 'lines.output.frequence.hertz', display_ok => 0, set => {
                key_values => [ { name => 'frequency', no_value => 0 } ],
                output_template => 'frequence: %.2f Hz',
                perfdatas => [ { template => '%.2f', unit => 'Hz' } ]
            }
        },
        # NV7 totals
        { label => 'total-active-power', nlabel => 'lines.output.total.active.power.watt', display_ok => 0, set => {
                key_values => [ { name => 'total_active_power', no_value => 0 } ],
                output_template => 'total active power: %s W',
                perfdatas => [ { template => '%s', min => 0, unit => 'W' } ]
            }
        },
        { label => 'total-apparent-power', nlabel => 'lines.output.total.apparent.power.voltampere', display_ok => 0, set => {
                key_values => [ { name => 'total_apparent_power', no_value => 0 } ],
                output_template => 'total apparent power: %s VA',
                perfdatas => [ { template => '%s', min => 0, unit => 'VA' } ]
            }
        },
        { label => 'total-load', nlabel => 'lines.output.total.load.percentage', display_ok => 0, set => {
                key_values => [ { name => 'total_load', no_value => 0 } ],
                output_template => 'total load: %s %%',
                perfdatas => [ { template => '%s', min => 0, max => 100, unit => '%' } ]
            }
        }
    ];

    $self->{maps_counters}->{oline} = [
        { label => 'load', nlabel => 'line.output.load.percentage', set => {
                key_values => [ { name => 'percent_load' } ],
                output_template => 'load: %.2f %%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'current', nlabel => 'line.output.current.ampere', set => {
                key_values => [ { name => 'current' } ],
                output_template => 'current: %.2f A',
                perfdatas => [
                    { template => '%.2f', min => 0, unit => 'A', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'voltage', nlabel => 'line.output.voltage.volt', set => {
                key_values => [ { name => 'voltage' } ],
                output_template => 'voltage: %.2f V',
                perfdatas => [
                    { template => '%.2f', unit => 'V', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'power', nlabel => 'line.output.power.watt', display_ok => 0, set => {
                key_values => [ { name => 'power' } ],
                output_template => 'power: %.2f W',
                perfdatas => [
                    { template => '%.2f', min => 0, unit => 'W', label_extra_instance => 1 }
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
        'ignore-zero-counters' => { name => 'ignore_zero_counters' },
        'filter-line:s'  => { name => 'filter_line'  },
        'exclude-line:s' => { name => 'exclude_line' },
    });
    return $self;
}

my $map_status = {
    1 => 'unknown', 2 => 'onMaintenBypass', 3 => 'onInverter',
    4 => 'normalMode', 5 => 'ecoMode', 6 => 'onBypass',
    7 => 'standby', 8 => 'upsOff'
};

my $mapping = {
    netvision5 => {
        voltage      => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.4.4.1.2' }, # upsOutputVoltage (V)
        current      => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.4.4.1.3' }, # upsOutputCurrent (dA)
        percent_load => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.4.4.1.4' }, # upsOutputPercentLoad
        power        => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.4.4.1.5' }  # upsOutputPower (W)
    },
    netvision6 => {
        voltage      => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.4.4.1.2' }, # upsOutputVoltage (V)
        current      => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.4.4.1.3' }, # upsOutputCurrent (dA)
        percent_load => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.4.4.1.4' }, # upsOutputPercentLoad
        power        => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.4.4.1.5' }  # upsOutputPower (W)
    }
};
my $mapping2 = {
    netvision5 => {
        status    => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.4.1', map => $map_status }, # upsOutputSource
        frequency => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.4.2' }                      # upsOutputFrequency (dHz)
    },
    netvision6 => {
        status    => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.4.1', map => $map_status }, # upsOutputSource
        frequency => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.4.2' }                      # upsOutputFrequency (dHz)
    }
};
# NV7-only totals (scalars outside the per-phase table)
my $mapping_totals_nv7 = {
    total_apparent_power => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.4.5' }, # upsOutputTotalApparentPower (VA)
    total_active_power   => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.4.6' }, # upsOutputTotalActivePower   (W)
    total_load           => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.4.7' }  # upsOutputTotalPercentLoad   (%)
};
my $tables = {
    netvision5 => {
        upsOutput      => '.1.3.6.1.4.1.4555.1.1.1.1.4',
        upsOutputEntry => '.1.3.6.1.4.1.4555.1.1.1.1.4.4.1'
    },
    netvision6 => {
        upsOutput      => '.1.3.6.1.4.1.4555.1.1.7.1.4',
        upsOutputEntry => '.1.3.6.1.4.1.4555.1.1.7.1.4.4.1'
    }
};

sub manage_selection {
    my ($self, %options) = @_;

    my $label = 'netvision6';
    my $snmp_result = $options{snmp}->get_table(
        oid => $tables->{$label}->{upsOutput},
        end => $mapping->{$label}->{power}->{oid}
    );
    if (scalar(keys %$snmp_result) <= 0) {
        $label = 'netvision5';
        $snmp_result = $options{snmp}->get_table(
            oid          => $tables->{$label}->{upsOutput},
            end          => $mapping->{$label}->{power}->{oid},
            nothing_quit => 1
        );
    }

    my $filter_line  = $self->{option_results}->{filter_line}  // '';
    my $exclude_line = $self->{option_results}->{exclude_line} // '';

    $self->{oline} = {};
    foreach my $oid (keys %$snmp_result) {
        next if ($oid !~ /^$tables->{$label}->{upsOutputEntry}\.\d+\.(.*)$/);
        my $instance = $1;
        next if (defined($self->{oline}->{$instance}));

        if ($filter_line ne '' && $instance !~ /$filter_line/) {
            $self->{output}->output_add(long_msg => "skipping output line '$instance': no matching filter", debug => 1);
            next;
        }
        if ($exclude_line ne '' && $instance =~ /$exclude_line/) {
            $self->{output}->output_add(long_msg => "skipping output line '$instance': excluded", debug => 1);
            next;
        }

        my $result = $options{snmp}->map_instance(mapping => $mapping->{$label}, results => $snmp_result, instance => $instance);
        foreach (keys %$result) {
            delete $result->{$_} if (
                (defined($self->{option_results}->{ignore_zero_counters}) && $result->{$_} == 0) ||
                ($result->{$_} == -1 || $result->{$_} == 65535)
            );
        }
        $result->{current} *= 0.1 if (defined($result->{current}));
        $result->{voltage} *= 0.1 if (defined($result->{voltage}));
        if (scalar(keys %$result) > 0) {
            $self->{oline}->{$instance} = { display => $instance, %$result };
        }
    }

    $self->{global} = $options{snmp}->map_instance(mapping => $mapping2->{$label}, results => $snmp_result, instance => 0);
    if (defined($self->{global}->{frequency}) && $self->{global}->{frequency} != -1 && $self->{global}->{frequency} != 65535) {
        $self->{global}->{frequency} *= 0.1;
    } else {
        $self->{global}->{frequency} = 0;
    }

    # NV7 totals — fetch separately if available
    if ($label eq 'netvision6') {
        my $totals = $options{snmp}->get_leef(
            oids => [ map($_->{oid} . '.0', values(%{$mapping_totals_nv7})) ]
        );
        my $t = $options{snmp}->map_instance(mapping => $mapping_totals_nv7, results => $totals, instance => 0);
        $self->{global}->{total_apparent_power} = (defined($t->{total_apparent_power}) && $t->{total_apparent_power} != 65535) ? $t->{total_apparent_power} : 0;
        $self->{global}->{total_active_power}   = (defined($t->{total_active_power})   && $t->{total_active_power}   != 65535) ? $t->{total_active_power}   : 0;
        $self->{global}->{total_load}           = (defined($t->{total_load})           && $t->{total_load}           != 65535) ? $t->{total_load}           : 0;
    }
}

1;

__END__

=head1 MODE

Check output lines. Supports Net Vision 5, 6 and 7.
Net Vision 7 additionally exposes total apparent power (VA),
total active power (W) and total load (%).

=over 8

=item B<--filter-line>

Only check output lines whose line number matches this regex.
Example: --filter-line=^[12]$

=item B<--exclude-line>

Skip output lines whose line number matches this regex.
Example: --exclude-line=3

=item B<--ignore-zero-counters>

Ignore counters equals to 0.

=item B<--unknown-source-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{status} =~ /unknown/i').
You can use the following variables: %{status}

=item B<--warning-source-status>

Define the conditions to match for the status to be WARNING.

=item B<--critical-source-status>

Define the conditions to match for the status to be CRITICAL.

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'frequence' (Hz), 'load' (%), 'voltage' (V), 'current' (A), 'power' (W),
'total-active-power' (W), 'total-apparent-power' (VA), 'total-load' (%).

=back

=cut
