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

package network::f5::bigip::snmp::mode::irulestatistics;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_rule_output {
    my ($self, %options) = @_;

    return "iRule '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'rules', type => 1, cb_prefix_output => 'prefix_rule_output',
          message_multiple => 'All iRules are ok' }
    ];

    $self->{maps_counters}->{rules} = [
        { label => 'executions', nlabel => 'irule.executions.persecond', set => {
                key_values => [ { name => 'executions', diff => 1 }, { name => 'display' } ],
                output_template => 'executions: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'failures', nlabel => 'irule.failures.persecond', set => {
                key_values => [ { name => 'failures', diff => 1 }, { name => 'display' } ],
                output_template => 'failures: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'aborts', nlabel => 'irule.aborts.persecond', set => {
                key_values => [ { name => 'aborts', diff => 1 }, { name => 'display' } ],
                output_template => 'aborts: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'avg-cycles', nlabel => 'irule.cycles.average.count', set => {
                key_values => [ { name => 'avg_cycles' }, { name => 'display' } ],
                output_template => 'avg cycles: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'  => { name => 'filter_name' },
        'filter-event:s' => { name => 'filter_event' }
    });

    return $self;
}

# F5-BIGIP-LOCAL-MIB::ltmRuleEventStatTable
my $mapping = {
    ltmRuleEventStatTotExecutions => { oid => '.1.3.6.1.4.1.3375.2.2.8.6.2.1.4' },
    ltmRuleEventStatFailures      => { oid => '.1.3.6.1.4.1.3375.2.2.8.6.2.1.5' },
    ltmRuleEventStatAborts         => { oid => '.1.3.6.1.4.1.3375.2.2.8.6.2.1.6' },
    ltmRuleEventStatAvgCycles      => { oid => '.1.3.6.1.4.1.3375.2.2.8.6.2.1.7' },
};
my $oid_ltmRuleEventStatEntry = '.1.3.6.1.4.1.3375.2.2.8.6.2.1';

sub decode_string_index {
    my ($self, %options) = @_;

    my @indexes = split(/\./, $options{index});
    my $length = shift(@indexes);
    my $name = join('', map(chr($_), splice(@indexes, 0, $length)));
    my $remaining = join('.', @indexes);

    return ($name, $remaining);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_table(
        oid          => $oid_ltmRuleEventStatEntry,
        nothing_quit => 1
    );

    $self->{rules} = {};
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result})) {
        next if ($oid !~ /^$mapping->{ltmRuleEventStatTotExecutions}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping,
            results  => $snmp_result,
            instance => $instance
        );

        # Index: ruleName (length-prefixed) + eventType (length-prefixed) + priority (integer)
        my ($rule_name, $remaining) = $self->decode_string_index(index => $instance);
        my ($event_type, $remaining2) = $self->decode_string_index(index => $remaining);

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $rule_name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping iRule '" . $rule_name . "'.", debug => 1);
            next;
        }

        if (defined($self->{option_results}->{filter_event}) && $self->{option_results}->{filter_event} ne '' &&
            $event_type !~ /$self->{option_results}->{filter_event}/) {
            $self->{output}->output_add(long_msg => "skipping event '" . $event_type . "'.", debug => 1);
            next;
        }

        my $key = $rule_name . '_' . $event_type;

        # Aggregate if rule+event already seen (multiple priorities)
        if (defined($self->{rules}->{$key})) {
            $self->{rules}->{$key}->{executions} += $result->{ltmRuleEventStatTotExecutions};
            $self->{rules}->{$key}->{failures} += $result->{ltmRuleEventStatFailures};
            $self->{rules}->{$key}->{aborts} += $result->{ltmRuleEventStatAborts};
        } else {
            $self->{rules}->{$key} = {
                display    => $key,
                executions => $result->{ltmRuleEventStatTotExecutions},
                failures   => $result->{ltmRuleEventStatFailures},
                aborts     => $result->{ltmRuleEventStatAborts},
                avg_cycles => $result->{ltmRuleEventStatAvgCycles}
            };
        }
    }

    if (scalar(keys %{$self->{rules}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No iRule statistics found.');
        $self->{output}->option_exit();
    }

    $self->{cache_name} = 'f5_bigip_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_name}) ? md5_hex($self->{option_results}->{filter_name}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_event}) ? md5_hex($self->{option_results}->{filter_event}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check iRule execution statistics on F5 BIG-IP devices.

Monitors per-iRule and per-event execution rates, failures, aborts, and CPU cycles.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).

=item B<--filter-name>

Filter iRule name (can be a regexp).

=item B<--filter-event>

Filter event type (can be a regexp). Example: --filter-event='HTTP_REQUEST'

=item B<--warning-executions>

Warning threshold for executions per second.

=item B<--critical-executions>

Critical threshold for executions per second.

=item B<--warning-failures>

Warning threshold for failures per second.

=item B<--critical-failures>

Critical threshold for failures per second.

=item B<--warning-aborts>

Warning threshold for aborts per second.

=item B<--critical-aborts>

Critical threshold for aborts per second.

=item B<--warning-avg-cycles>

Warning threshold for average CPU cycles per execution.

=item B<--critical-avg-cycles>

Critical threshold for average CPU cycles per execution.

=back

=cut
