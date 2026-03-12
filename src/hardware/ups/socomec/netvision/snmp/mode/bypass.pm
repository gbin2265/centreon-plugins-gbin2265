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

package hardware::ups::socomec::netvision::snmp::mode::bypass;

use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;

sub prefix_bline_output {
    my ($self, %options) = @_;
    return "Bypass line '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'bline',  type => 1, cb_prefix_output => 'prefix_bline_output',
          message_multiple => 'All bypass lines are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'frequence', nlabel => 'lines.bypass.frequence.hertz', set => {
                key_values      => [ { name => 'frequency', no_value => 0 } ],
                output_template => 'frequence: %.2f Hz',
                perfdatas       => [ { template => '%.2f', unit => 'Hz' } ]
            }
        }
    ];

    $self->{maps_counters}->{bline} = [
        { label => 'voltage', nlabel => 'line.bypass.voltage.volt', set => {
                key_values      => [ { name => 'voltage', no_value => 0 } ],
                output_template => 'voltage: %.2f V',
                perfdatas       => [ { template => '%.2f', unit => 'V', label_extra_instance => 1 } ]
            }
        },
        { label => 'current', nlabel => 'line.bypass.current.ampere', display_ok => 0, set => {
                key_values      => [ { name => 'current', no_value => 0 } ],
                output_template => 'current: %.2f A',
                perfdatas       => [ { template => '%.2f', min => 0, unit => 'A', label_extra_instance => 1 } ]
            }
        },
        { label => 'power', nlabel => 'line.bypass.power.watt', display_ok => 0, set => {
                key_values      => [ { name => 'power', no_value => 0 } ],
                output_template => 'power: %.2f W',
                perfdatas       => [ { template => '%.2f', min => 0, unit => 'W', label_extra_instance => 1 } ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        # Include filter: only process lines matching this regex (on line number)
        'filter-line:s'   => { name => 'filter_line'   },
        # Exclude filter: skip lines matching this regex
        'exclude-line:s'  => { name => 'exclude_line'  },
    });
    return $self;
}

my $mapping = {
    netvision5 => {
        voltage => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.5.3.1.2' },
        current => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.5.3.1.3' },
        power   => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.5.3.1.4' }
    },
    netvision6 => {
        voltage => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.5.3.1.2' },
        current => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.5.3.1.3' },
        power   => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.5.3.1.4' }
    }
};
# BUG FIX: NV5 .5.1=frequency, .5.2=numLines (was swapped before)
my $mapping_freq = {
    netvision5 => { frequency => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.5.1' } },
    netvision6 => { frequency => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.5.1' } }
};
my $tables = {
    netvision5 => { upsBypass => '.1.3.6.1.4.1.4555.1.1.1.1.5', upsBypassEntry => '.1.3.6.1.4.1.4555.1.1.1.1.5.3.1' },
    netvision6 => { upsBypass => '.1.3.6.1.4.1.4555.1.1.7.1.5', upsBypassEntry => '.1.3.6.1.4.1.4555.1.1.7.1.5.3.1' }
};

sub manage_selection {
    my ($self, %options) = @_;

    my $label = 'netvision6';
    my $snmp_result = $options{snmp}->get_table(
        oid   => $tables->{$label}->{upsBypass},
        start => $mapping_freq->{$label}->{frequency}->{oid},
        end   => $mapping->{$label}->{power}->{oid}
    );
    if (scalar(keys %$snmp_result) <= 0) {
        $label = 'netvision5';
        $snmp_result = $options{snmp}->get_table(
            oid          => $tables->{$label}->{upsBypass},
            start        => $mapping_freq->{$label}->{frequency}->{oid},
            end          => $mapping->{$label}->{power}->{oid},
            nothing_quit => 1
        );
    }

    my $filter_line  = $self->{option_results}->{filter_line}  // '';
    my $exclude_line = $self->{option_results}->{exclude_line} // '';

    $self->{bline} = {};
    foreach my $oid (keys %$snmp_result) {
        next if ($oid !~ /^$tables->{$label}->{upsBypassEntry}\.\d+\.(.*)$/);
        my $instance = $1;
        next if (defined($self->{bline}->{$instance}));

        # ---- include filter ----
        if ($filter_line ne '' && $instance !~ /$filter_line/) {
            $self->{output}->output_add(long_msg => "skipping bypass line '$instance': no matching filter", debug => 1);
            next;
        }
        # ---- exclude filter ----
        if ($exclude_line ne '' && $instance =~ /$exclude_line/) {
            $self->{output}->output_add(long_msg => "skipping bypass line '$instance': excluded", debug => 1);
            next;
        }

        my $result = $options{snmp}->map_instance(mapping => $mapping->{$label}, results => $snmp_result, instance => $instance);
        foreach ('current', 'voltage') {
            $result->{$_} = 0 if (defined($result->{$_}) && (
                $result->{$_} eq '' || $result->{$_} == -1 || $result->{$_} == 65535 || $result->{$_} == 655350));
            $result->{$_} *= 0.1;
        }
        $result->{power} = (defined($result->{power}) && $result->{power} != -1 && $result->{power} != 65535) ? $result->{power} : 0;
        $self->{bline}->{$instance} = { display => $instance, %$result };
    }

    if (scalar(keys %{$self->{bline}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No bypass lines found (bypass may not be active, or all filtered out).");
        $self->{output}->option_exit();
    }

    my $freq_result = $options{snmp}->map_instance(mapping => $mapping_freq->{$label}, results => $snmp_result, instance => 0);
    my $raw_freq    = $freq_result->{frequency};
    if (defined($raw_freq) && $raw_freq != -1 && $raw_freq != 65535 && $raw_freq > 0) {
        $self->{global}->{frequency} = ($label eq 'netvision5' && $raw_freq <= 100) ? $raw_freq : $raw_freq * 0.1;
    } else {
        $self->{global}->{frequency} = 0;
    }
}

1;

__END__

=head1 MODE

Check bypass lines metrics (frequence, voltage, current, power).
Supports Net Vision 5, 6 and 7.

=over 8

=item B<--filter-line>

Only check bypass lines whose line number matches this regex.
Example: --filter-line=^[12]$ (only lines 1 and 2)

=item B<--exclude-line>

Skip bypass lines whose line number matches this regex.
Example: --exclude-line=3

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'frequence' (Hz), 'voltage' (V), 'current' (A), 'power' (W).

=back

=cut
