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

package network::paloalto::snmp::mode::doscounters;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_output {
    my ($self, %options) = @_;
    return 'DoS counters ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_output', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'aggregate-max-session', nlabel => 'dos.aggregate.max.session.limit.count', set => {
                key_values => [ { name => 'ag_max_sess', diff => 1 } ],
                output_template => 'aggregate max session limit: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'classified-max-session', nlabel => 'dos.classified.max.session.limit.count', set => {
                key_values => [ { name => 'cl_max_sess', diff => 1 } ],
                output_template => 'classified max session limit: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'blocked-ip', nlabel => 'dos.drop.ip.blocked.count', set => {
                key_values => [ { name => 'drop_ip_blocked', diff => 1 } ],
                output_template => 'blocked IP drops: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'scan-drop', nlabel => 'dos.scan.drop.count', set => {
                key_values => [ { name => 'scan_drop', diff => 1 } ],
                output_template => 'scan drops: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'red-tcp', nlabel => 'dos.red.tcp.count', set => {
                key_values => [ { name => 'red_tcp', diff => 1 } ],
                output_template => 'RED TCP: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'red-udp', nlabel => 'dos.red.udp.count', set => {
                key_values => [ { name => 'red_udp', diff => 1 } ],
                output_template => 'RED UDP: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'red-icmp', nlabel => 'dos.red.icmp.count', set => {
                key_values => [ { name => 'red_icmp', diff => 1 } ],
                output_template => 'RED ICMP: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'red-ip', nlabel => 'dos.red.ip.count', set => {
                key_values => [ { name => 'red_ip', diff => 1 } ],
                output_template => 'RED IP: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'syncookie-sent', nlabel => 'dos.syncookie.sent.count', set => {
                key_values => [ { name => 'syncookie_sent', diff => 1 } ],
                output_template => 'SYN cookies sent: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'syncookie-ack-err', nlabel => 'dos.syncookie.ack.error.count', set => {
                key_values => [ { name => 'syncookie_ack_err', diff => 1 } ],
                output_template => 'SYN cookie ACK errors: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'policy-deny', nlabel => 'dos.policy.deny.count', set => {
                key_values => [ { name => 'policy_deny', diff => 1 } ],
                output_template => 'policy deny: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'policy-nat', nlabel => 'dos.policy.nat.count', set => {
                key_values => [ { name => 'policy_nat', diff => 1 } ],
                output_template => 'policy NAT: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'ip-spoof', nlabel => 'dos.protection.ip.spoof.count', set => {
                key_values => [ { name => 'pf_ipspoof', diff => 1 } ],
                output_template => 'IP spoof: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'ip-frag', nlabel => 'dos.protection.ip.fragment.count', set => {
                key_values => [ { name => 'pf_ipfrag', diff => 1 } ],
                output_template => 'IP fragment: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'vsys-throttle', nlabel => 'dos.vsys.throttle.count', set => {
                key_values => [ { name => 'vsys_throttle', diff => 1 } ],
                output_template => 'vsys throttle: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1, statefile => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
    });

    return $self;
}

# panGlobalCountersDOSCounters = .1.3.6.1.4.1.25461.2.1.2.1.19.8
my $mapping = {
    ag_max_sess       => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.1' },  # panFlowDosAgMaxSessLimit
    cl_max_sess       => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.3' },  # panFlowDosClMaxSessLimit
    syncookie_ack_err => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.4' },  # panFlowDosClSyncookieAckErr
    syncookie_sent    => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.8' },  # panFlowDosClSyncookieSent
    vsys_throttle     => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.9' },  # panFlowMeterVsysThrottle
    policy_deny       => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.10' }, # panFlowPolicyDeny
    policy_nat        => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.11' }, # panFlowPolicyNat
    scan_drop         => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.12' }, # panFlowScanDrop
    drop_ip_blocked   => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.13' }, # panFlowDosDropIpBlocked
    red_icmp          => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.14' }, # panFlowDosRedIcmp
    red_ip            => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.16' }, # panFlowDosRedIp
    red_tcp           => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.17' }, # panFlowDosRedTcp
    red_udp           => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.18' }, # panFlowDosRedUdp
    pf_ipspoof        => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.37' }, # panFlowDosPfIpspoof
    pf_ipfrag         => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.8.38' }  # panFlowDosPfIpfrag
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

Check DoS protection counters (delta values).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='red|syncookie'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'aggregate-max-session', 'classified-max-session', 'blocked-ip', 'scan-drop',
'red-tcp', 'red-udp', 'red-icmp', 'red-ip', 'syncookie-sent', 'syncookie-ack-err',
'policy-deny', 'policy-nat', 'ip-spoof', 'ip-frag', 'vsys-throttle'.

=back

=cut
