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

package hardware::ups::socomec::netvision::snmp::mode::inputlines;

use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;

sub prefix_iline_output {
    my ($self, %options) = @_;
    return "Input line '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'iline',  type => 1, cb_prefix_output => 'prefix_iline_output',
          message_multiple => 'All input lines are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'frequence', nlabel => 'lines.input.frequence.hertz', set => {
                key_values      => [ { name => 'frequency', no_value => 0 } ],
                output_template => 'frequence: %.2f Hz',
                perfdatas       => [ { template => '%.2f', unit => 'Hz' } ]
            }
        }
    ];

    $self->{maps_counters}->{iline} = [
        { label => 'current', nlabel => 'line.input.current.ampere', set => {
                key_values      => [ { name => 'current', no_value => 0 } ],
                output_template => 'current: %.2f A',
                perfdatas       => [ { template => '%.2f', min => 0, unit => 'A', label_extra_instance => 1 } ]
            }
        },
        { label => 'voltage', nlabel => 'line.input.voltage.volt', set => {
                key_values      => [ { name => 'voltage', no_value => 0 } ],
                output_template => 'voltage: %.2f V',
                perfdatas       => [ { template => '%.2f', unit => 'V', label_extra_instance => 1 } ]
            }
        },
        { label => 'power', nlabel => 'line.input.power.watt', display_ok => 0, set => {
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
        'filter-line:s'  => { name => 'filter_line'  },
        'exclude-line:s' => { name => 'exclude_line' },
    });
    return $self;
}

my $mapping = {
    netvision5 => {
        voltage => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.3.3.1.2' },
        current => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.3.3.1.3' },
        power   => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.3.3.1.4' }
    },
    netvision6 => {
        voltage => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.3.3.1.2' },
        current => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.3.3.1.3' },
        power   => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.3.3.1.4' }
    }
};
my $mapping2 = {
    netvision5 => { frequency => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.3.2' } },
    netvision6 => { frequency => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.3.2' } }
};
my $tables = {
    netvision5 => { upsInput => '.1.3.6.1.4.1.4555.1.1.1.1.3', upsInputEntry => '.1.3.6.1.4.1.4555.1.1.1.1.3.3.1' },
    netvision6 => { upsInput => '.1.3.6.1.4.1.4555.1.1.7.1.3', upsInputEntry => '.1.3.6.1.4.1.4555.1.1.7.1.3.3.1' }
};

sub manage_selection {
    my ($self, %options) = @_;

    my $label = 'netvision6';
    my $snmp_result = $options{snmp}->get_table(
        oid   => $tables->{$label}->{upsInput},
        start => $mapping2->{$label}->{frequency}->{oid},
        end   => $mapping->{$label}->{power}->{oid}
    );
    if (scalar(keys %$snmp_result) <= 0) {
        $label = 'netvision5';
        $snmp_result = $options{snmp}->get_table(
            oid          => $tables->{$label}->{upsInput},
            start        => $mapping2->{$label}->{frequency}->{oid},
            end          => $mapping->{$label}->{power}->{oid},
            nothing_quit => 1
        );
    }

    my $filter_line  = $self->{option_results}->{filter_line}  // '';
    my $exclude_line = $self->{option_results}->{exclude_line} // '';

    $self->{iline} = {};
    foreach my $oid (keys %$snmp_result) {
        next if ($oid !~ /^$tables->{$label}->{upsInputEntry}\.\d+\.(.*)$/);
        my $instance = $1;
        next if (defined($self->{iline}->{$instance}));

        if ($filter_line ne '' && $instance !~ /$filter_line/) {
            $self->{output}->output_add(long_msg => "skipping input line '$instance': no matching filter", debug => 1);
            next;
        }
        if ($exclude_line ne '' && $instance =~ /$exclude_line/) {
            $self->{output}->output_add(long_msg => "skipping input line '$instance': excluded", debug => 1);
            next;
        }

        my $result = $options{snmp}->map_instance(mapping => $mapping->{$label}, results => $snmp_result, instance => $instance);
        foreach ('current', 'voltage') {
            $result->{$_} = 0 if (defined($result->{$_}) && (
                $result->{$_} eq '' || $result->{$_} == -1 || $result->{$_} == 65535 || $result->{$_} == 655350));
            $result->{$_} *= 0.1;
        }
        $result->{power} = (defined($result->{power}) && $result->{power} != -1 && $result->{power} != 65535) ? $result->{power} : 0;
        $self->{iline}->{$instance} = { display => $instance, %$result };
    }

    if (scalar(keys %{$self->{iline}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No input lines found.");
        $self->{output}->option_exit();
    }

    $self->{global} = $options{snmp}->map_instance(mapping => $mapping2->{$label}, results => $snmp_result, instance => 0);
    $self->{global}->{frequency} = defined($self->{global}->{frequency}) && $self->{global}->{frequency} != -1 && $self->{global}->{frequency} != 65535
        ? ($self->{global}->{frequency} * 0.1) : 0;
}

1;

__END__

=head1 MODE

Check input lines metrics (frequence, voltage, current, power).
Supports Net Vision 5, 6 and 7.

=over 8

=item B<--filter-line>

Only check input lines whose line number matches this regex.
Example: --filter-line=^[12]$

=item B<--exclude-line>

Skip input lines whose line number matches this regex.
Example: --exclude-line=3

=item B<--warning-*> B<--critical-*>

Thresholds: 'frequence' (Hz), 'voltage' (V), 'current' (A), 'power' (W).

=back

=cut
