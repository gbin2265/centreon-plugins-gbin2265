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

package hardware::ups::powerware::snmp::mode::bypasslines;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_bline_output {
    my ($self, %options) = @_;

    return "Bypass Line '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'bline', type => 1, cb_prefix_output => 'prefix_bline_output', message_multiple => 'All bypass lines are ok', skipped_code => { -10 => 1 } },
    ];

    $self->{maps_counters}->{global} = [
        { label => 'frequence', nlabel => 'lines.bypass.frequence.hertz', set => {
                key_values => [ { name => 'xupsBypassFrequency', no_value => 0 } ],
                output_template => 'frequency: %.2f Hz',
                perfdatas => [
                    { template => '%.2f', unit => 'Hz' }
                ]
            }
        },
    ];

    $self->{maps_counters}->{bline} = [
        { label => 'voltage', nlabel => 'line.bypass.voltage.volt', set => {
                key_values => [ { name => 'xupsBypassVoltage', no_value => 0 } ],
                output_template => 'voltage: %.2f V',
                perfdatas => [
                    { template => '%.2f', unit => 'V', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'current', nlabel => 'line.bypass.current.ampere', set => {
                key_values => [ { name => 'xupsBypassCurrent', no_value => 0 } ],
                output_template => 'current: %.2f A',
                perfdatas => [
                    { template => '%.2f', min => 0, unit => 'A', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'power', nlabel => 'line.bypass.power.watt', set => {
                key_values => [ { name => 'xupsBypassWatts', no_value => 0 } ],
                output_template => 'power: %.2f W',
                perfdatas => [
                    { template => '%.2f', unit => 'W', label_extra_instance => 1 }
                ]
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-bline:s'  => { name => 'filter_bline' },
        'exclude-bline:s' => { name => 'exclude_bline' },
    });

    return $self;
}

my $mapping = {
    xupsBypassVoltage  => { oid => '.1.3.6.1.4.1.534.1.5.3.1.2' }, # in V  - all firmware
    xupsBypassCurrent  => { oid => '.1.3.6.1.4.1.534.1.5.3.1.3' }, # in A  - newer firmware only
    xupsBypassWatts    => { oid => '.1.3.6.1.4.1.534.1.5.3.1.4' }, # in W  - newer firmware only
};
my $mapping2 = {
    xupsBypassFrequency => { oid => '.1.3.6.1.4.1.534.1.5.1' }, # in dHz
};

my $oid_xupsBypassEntry = '.1.3.6.1.4.1.534.1.5.3.1';
my $oid_xupsBypass      = '.1.3.6.1.4.1.534.1.5';

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_multiple_table(
        oids => [
            { oid => $mapping2->{xupsBypassFrequency}->{oid} },
            { oid => $oid_xupsBypassEntry },
        ],
        return_type => 1,
        nothing_quit => 1
    );

    $self->{bline} = {};
    foreach my $oid (keys %{$snmp_result}) {
        next if ($oid !~ /^$oid_xupsBypassEntry\.\d+\.(.*)$/);
        my $instance = $1;

        if (defined($self->{option_results}->{filter_bline}) && $self->{option_results}->{filter_bline} ne '' &&
            $instance !~ /$self->{option_results}->{filter_bline}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $instance . "': no matching 'bline' filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_bline}) && $self->{option_results}->{exclude_bline} ne '' &&
            $instance =~ /$self->{option_results}->{exclude_bline}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $instance . "': excluded by 'exclude-bline'.", debug => 1);
            next;
        }

        next if (defined($self->{bline}->{$instance}));

        my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => $instance);
        $self->{bline}->{$instance} = { display => $instance, %$result };
    }

    if (scalar(keys %{$self->{bline}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No bypass lines found.");
        $self->{output}->option_exit();
    }

    my $result = $options{snmp}->map_instance(mapping => $mapping2, results => $snmp_result, instance => '0');
    $result->{xupsBypassFrequency} = defined($result->{xupsBypassFrequency}) ? ($result->{xupsBypassFrequency} * 0.1) : 0;
    $self->{global} = $result;
}

1;

__END__

=head1 MODE

Check bypass line metrics (frequency, voltage, current, power) (XUPS-MIB).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='voltage|frequence'

=item B<--filter-bline>

Only check bypass lines matching this regexp (e.g. --filter-bline='^[12]$' for phases 1 and 2 only).

=item B<--exclude-bline>

Exclude bypass lines matching this regexp (e.g. --exclude-bline='^3$' to skip phase 3).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'frequence' (Hz), 'voltage' (V), 'current' (A), 'power' (W).

=back

=cut
