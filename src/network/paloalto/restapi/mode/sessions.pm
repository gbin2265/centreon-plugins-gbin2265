#
# Copyright 2026-Present Centreon (http://www.centreon.com/)
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

package network::paloalto::restapi::mode::sessions;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use centreon::plugins::misc;

sub prefix_session_output {
    my ($self, %options) = @_;

    return 'Sessions ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'sessions', type => 0, cb_prefix_output => 'prefix_session_output', message_separator => ' - ', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{sessions} = [
        { label => 'active', nlabel => 'sessions.active.count', set => {
                key_values => [ { name => 'active' } ],
                output_template => 'active: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'max', nlabel => 'sessions.max.count', display_ok => 0, set => {
                key_values => [ { name => 'max' } ],
                output_template => 'max: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'utilization', nlabel => 'sessions.utilization.percentage', set => {
                key_values => [ { name => 'utilization' } ],
                output_template => 'utilization: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100 }
                ]
            }
        },
        { label => 'tcp', nlabel => 'sessions.tcp.active.count', display_ok => 0, set => {
                key_values => [ { name => 'tcp' } ],
                output_template => 'tcp: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'udp', nlabel => 'sessions.udp.active.count', display_ok => 0, set => {
                key_values => [ { name => 'udp' } ],
                output_template => 'udp: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'icmp', nlabel => 'sessions.icmp.active.count', display_ok => 0, set => {
                key_values => [ { name => 'icmp' } ],
                output_template => 'icmp: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'other', nlabel => 'sessions.other.active.count', display_ok => 0, set => {
                key_values => [ { name => 'other' } ],
                output_template => 'other: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'throughput', nlabel => 'sessions.throughput.bitspersecond', set => {
                key_values => [ { name => 'throughput' } ],
                output_template => 'throughput: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0 }
                ]
            }
        },
        { label => 'packet-rate', nlabel => 'sessions.packets.rate.persecond', display_ok => 0, set => {
                key_values => [ { name => 'pps' } ],
                output_template => 'packet rate: %s/s',
                perfdatas => [
                    { template => '%s', unit => '/s', min => 0 }
                ]
            }
        },
        { label => 'new-cps', nlabel => 'sessions.new.persecond', display_ok => 0, set => {
                key_values => [ { name => 'cps' } ],
                output_template => 'new connections: %s/s',
                perfdatas => [
                    { template => '%s', unit => '/s', min => 0 }
                ]
            }
        },
        { label => 'install-rate', nlabel => 'sessions.install.rate.persecond', display_ok => 0, set => {
                key_values => [ { name => 'install_rate' } ],
                output_template => 'install rate: %s/s',
                perfdatas => [
                    { template => '%s', unit => '/s', min => 0 }
                ]
            }
        },
        { label => 'discard-rate', nlabel => 'sessions.discard.rate.persecond', display_ok => 0, set => {
                key_values => [ { name => 'discard_rate' } ],
                output_template => 'discard rate: %s/s',
                perfdatas => [
                    { template => '%s', unit => '/s', min => 0 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # show session info returns structured XML
    my $info = $options{custom}->request_api(
        cmd => '<show><session><info></info></session></show>'
    );

    # show system statistics session returns text
    my $stats = $options{custom}->request_api(
        cmd => '<show><system><statistics><session></session></statistics></system></show>'
    );

    $self->{sessions} = {};

    # Parse structured info (num-max, num-active, etc.)
    if (defined($info) && ref($info) eq 'HASH') {
        $self->{sessions}->{max} = defined($info->{'num-max'}) ? $info->{'num-max'} : undef;
        $self->{sessions}->{active} = defined($info->{'num-active'}) ? $info->{'num-active'} : undef;
        $self->{sessions}->{tcp} = defined($info->{'num-tcp'}) ? $info->{'num-tcp'} : undef;
        $self->{sessions}->{udp} = defined($info->{'num-udp'}) ? $info->{'num-udp'} : undef;
        $self->{sessions}->{icmp} = defined($info->{'num-icmp'}) ? $info->{'num-icmp'} : undef;
        $self->{sessions}->{other} =
            (defined($info->{'num-active'}) ? $info->{'num-active'} : 0) -
            (defined($info->{'num-tcp'}) ? $info->{'num-tcp'} : 0) -
            (defined($info->{'num-udp'}) ? $info->{'num-udp'} : 0) -
            (defined($info->{'num-icmp'}) ? $info->{'num-icmp'} : 0);
        $self->{sessions}->{other} = 0 if ($self->{sessions}->{other} < 0);
        $self->{sessions}->{cps} = defined($info->{'cps'}) ? $info->{'cps'} : undef;

        # Calculate utilization
        if (defined($self->{sessions}->{active}) && defined($self->{sessions}->{max}) && $self->{sessions}->{max} > 0) {
            $self->{sessions}->{utilization} = ($self->{sessions}->{active} / $self->{sessions}->{max}) * 100;
        }
    }

    # Parse text stats output as fallback / additional data
    if (defined($stats) && !ref($stats)) {
        if (!defined($self->{sessions}->{active}) && $stats =~ /^Total\s+active\s+sessions\s*:\s*(\d+)/mi) {
            $self->{sessions}->{active} = $1;
        }
        if (!defined($self->{sessions}->{tcp}) && $stats =~ /^Active\s+TCP\s+sessions\s*:\s*(\d+)/mi) {
            $self->{sessions}->{tcp} = $1;
        }
        if (!defined($self->{sessions}->{udp}) && $stats =~ /^Active\s+UDP\s+sessions\s*:\s*(\d+)/mi) {
            $self->{sessions}->{udp} = $1;
        }
        if (!defined($self->{sessions}->{icmp}) && $stats =~ /^Active\s+ICMP\s+sessions\s*:\s*(\d+)/mi) {
            $self->{sessions}->{icmp} = $1;
        }
        if ($stats =~ /^Throughput\s*:\s*(\d+)\s+(..)/mi) {
            $self->{sessions}->{throughput} = centreon::plugins::misc::convert_bytes(value => $1, unit => $2);
        }
        if ($stats =~ /^Packet\s+rate\s*:\s*(\d+)/mi) {
            $self->{sessions}->{pps} = $1;
        }
        if ($stats =~ /^New\s+connection.*?:\s*(\d+)/mi) {
            $self->{sessions}->{cps} = $1 if (!defined($self->{sessions}->{cps}));
        }
        if ($stats =~ /^Session\s+install\s+rate\s*:\s*(\d+)/mi) {
            $self->{sessions}->{install_rate} = $1;
        }
        if ($stats =~ /^Session\s+discard\s+rate\s*:\s*(\d+)/mi) {
            $self->{sessions}->{discard_rate} = $1;
        }
    }
}

1;

__END__

=head1 MODE

Check session statistics (active sessions, utilization, throughput, connection rates).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^(active|utilization)'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'active', 'max', 'utilization' (%), 'tcp', 'udp', 'icmp', 'other',
'throughput' (b/s), 'packet-rate' (/s), 'new-cps' (/s),
'install-rate' (/s), 'discard-rate' (/s).

=back

=cut
