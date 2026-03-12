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

package network::paloalto::snmp::mode::packetbroker;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_chain_output {
    my ($self, %options) = @_;
    return "Chain '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'chain', type => 1, cb_prefix_output => 'prefix_chain_output',
          message_multiple => 'All packet broker chains are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{chain} = [
        { label => 'avg-latency', nlabel => 'packetbroker.chain.latency.average.milliseconds', set => {
                key_values => [ { name => 'avg_latency' }, { name => 'display' } ],
                output_template => 'avg latency: %s ms',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'ms', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'session-count', nlabel => 'packetbroker.chain.sessions.count', set => {
                key_values => [ { name => 'session_count' }, { name => 'display' } ],
                output_template => 'sessions: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
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
        'filter-chain-name:s' => { name => 'filter_chain_name' }
    });

    return $self;
}

# panPacketBroker = .1.3.6.1.4.1.25461.2.1.2.8
my $mapping = {
    display       => { oid => '.1.3.6.1.4.1.25461.2.1.2.8.1.1.2' }, # chainName
    avg_latency   => { oid => '.1.3.6.1.4.1.25461.2.1.2.8.1.1.3' }, # avgLatency
    session_count => { oid => '.1.3.6.1.4.1.25461.2.1.2.8.1.1.4' }  # sessionCount
};

sub manage_selection {
    my ($self, %options) = @_;

    my $oid_table = '.1.3.6.1.4.1.25461.2.1.2.8.1';
    my $snmp_result = $options{snmp}->get_table(oid => $oid_table, nothing_quit => 1);

    $self->{chain} = {};
    foreach my $oid (keys %$snmp_result) {
        next if ($oid !~ /^$mapping->{display}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => $instance);

        if (defined($self->{option_results}->{filter_chain_name}) && $self->{option_results}->{filter_chain_name} ne '' &&
            $result->{display} !~ /$self->{option_results}->{filter_chain_name}/) {
            $self->{output}->output_add(long_msg => "skipping chain '" . $result->{display} . "'.", debug => 1);
            next;
        }

        $self->{chain}->{$result->{display}} = $result;
    }

    if (scalar(keys %{$self->{chain}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No packet broker chains found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check SSL decryption packet broker chain statistics (panPacketBroker).
Monitors average latency and session count per broker chain.

=over 8

=item B<--filter-chain-name>

Filter chains by name (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'avg-latency' (ms), 'session-count'.

=back

=cut
