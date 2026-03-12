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

package network::paloalto::snmp::mode::dropcounters;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_output {
    my ($self, %options) = @_;
    return 'Drop counters ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_output', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'pkt-alloc-failure', nlabel => 'drop.packet.allocation.failure.count', set => {
                key_values => [ { name => 'pkt_alloc_failure', diff => 1 } ],
                output_template => 'packet allocation failures: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'pkt-alloc-failure-cos', nlabel => 'drop.packet.allocation.failure.cos.count', set => {
                key_values => [ { name => 'pkt_alloc_failure_cos', diff => 1 } ],
                output_template => 'packet allocation failures (CoS): %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'session-discard', nlabel => 'drop.session.discard.count', set => {
                key_values => [ { name => 'session_discard', diff => 1 } ],
                output_template => 'session discards: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'ttl-zero', nlabel => 'drop.forwarding.l3.ttl.zero.count', set => {
                key_values => [ { name => 'ttl_zero', diff => 1 } ],
                output_template => 'TTL zero drops: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'host-throttle', nlabel => 'drop.meter.host.throttle.count', set => {
                key_values => [ { name => 'host_throttle', diff => 1 } ],
                output_template => 'host throttle drops: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'host-service-deny', nlabel => 'drop.host.service.deny.count', set => {
                key_values => [ { name => 'host_service_deny', diff => 1 } ],
                output_template => 'host service denies: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'host-service-unknown', nlabel => 'drop.host.service.unknown.count', set => {
                key_values => [ { name => 'host_service_unknown', diff => 1 } ],
                output_template => 'host service unknown: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
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

my $mapping = {
    ttl_zero              => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.9.1' }, # panFlowFwdL3TtlZero
    host_throttle         => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.9.2' }, # panFlowMeterHostThrottle
    host_service_deny     => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.9.3' }, # panFlowHostServiceDeny
    host_service_unknown  => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.9.4' }, # panFlowHostServiceUnknown
    pkt_alloc_failure     => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.9.5' }, # panPktAllocFailure
    pkt_alloc_failure_cos => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.9.6' }, # panPktAllocFailureCos
    session_discard       => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.19.9.7' }  # panSessionDiscard
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

Check global drop counters (delta values).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='pkt-alloc'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'pkt-alloc-failure', 'pkt-alloc-failure-cos', 'session-discard',
'ttl-zero', 'host-throttle', 'host-service-deny', 'host-service-unknown'.

=back

=cut
