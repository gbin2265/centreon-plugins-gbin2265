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

package network::paloalto::snmp::mode::tcpstats;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_output {
    my ($self, %options) = @_;
    return 'TCP counters ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_output', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'tcp-deny', nlabel => 'tcp.deny.count', set => {
                key_values => [ { name => 'tcp_deny', diff => 1 } ],
                output_template => 'deny: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'tcp-drop-out-of-window', nlabel => 'tcp.drop.out.of.window.count', set => {
                key_values => [ { name => 'tcp_drop_oow', diff => 1 } ],
                output_template => 'out of window drops: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'tcp-drop-packet', nlabel => 'tcp.drop.packet.count', set => {
                key_values => [ { name => 'tcp_drop_pkt', diff => 1 } ],
                output_template => 'packet drops: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'flow-action-close', nlabel => 'tcp.flow.action.close.count', set => {
                key_values => [ { name => 'flow_close', diff => 1 } ],
                output_template => 'flow close: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'flow-action-reset', nlabel => 'tcp.flow.action.reset.count', set => {
                key_values => [ { name => 'flow_reset', diff => 1 } ],
                output_template => 'flow reset: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'tcp-non-syn', nlabel => 'tcp.non.syn.count', set => {
                key_values => [ { name => 'tcp_non_syn', diff => 1 } ],
                output_template => 'non-SYN: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'tcp-exceed-seg-limit', nlabel => 'tcp.exceed.segment.limit.count', set => {
                key_values => [ { name => 'tcp_exceed_seg', diff => 1 } ],
                output_template => 'exceed segment limit: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'tcp-alloc-wqe-failed', nlabel => 'tcp.alloc.wqe.failed.count', set => {
                key_values => [ { name => 'tcp_alloc_wqe', diff => 1 } ],
                output_template => 'WQE alloc failed: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1, statefile => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {});
    return $self;
}

# panGlobalCountersTCPState = .1.3.6.1.4.1.25461.2.1.2.1.19.11
my $mapping = {
    tcp_alloc_wqe  => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.11.1' }, # panTcpAllocWqeFailed
    tcp_deny       => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.11.2' }, # panTcpDeny
    tcp_drop_oow   => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.11.3' }, # panTcpDropOutOfWnd
    tcp_drop_pkt   => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.11.4' }, # panTcpDropPacket
    flow_close     => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.11.5' }, # panFlowActionClose
    flow_reset     => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.11.6' }, # panFlowActionReset
    tcp_non_syn    => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.11.7' }, # panFlowTcpNonSyn
    tcp_exceed_seg => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.11.8' }  # panTcpExceedSegLimit
};

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [ map($_->{oid} . '.0', values(%$mapping)) ],
        nothing_quit => 1
    );
    $self->{global} = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');

    $self->{cache_name} = 'paloalto_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check TCP state counters (delta values).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'tcp-deny', 'tcp-drop-out-of-window', 'tcp-drop-packet', 'flow-action-close',
'flow-action-reset', 'tcp-non-syn', 'tcp-exceed-seg-limit', 'tcp-alloc-wqe-failed'.

=back

=cut
