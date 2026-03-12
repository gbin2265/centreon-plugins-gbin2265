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

package network::paloalto::snmp::mode::tunnelstats;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'gre', type => 0, cb_prefix_output => sub { return 'GRE tunnel '; }, skipped_code => { -10 => 1 } },
        { name => 'ipsec', type => 0, cb_prefix_output => sub { return 'IPSec tunnel '; }, skipped_code => { -10 => 1 } },
        { name => 'gtp', type => 0, cb_prefix_output => sub { return 'GTP tunnel '; }, skipped_code => { -10 => 1 } }
    ];

    foreach my $proto ('gre', 'ipsec', 'gtp') {
        $self->{maps_counters}->{$proto} = [
            { label => $proto . '-success', nlabel => 'tunnel.' . $proto . '.decap.success.count', set => {
                    key_values => [ { name => 'success', diff => 1 } ],
                    output_template => 'decap success: %s',
                    perfdatas => [ { template => '%s', min => 0 } ]
                }
            },
            { label => $proto . '-failed', nlabel => 'tunnel.' . $proto . '.decap.failed.count', set => {
                    key_values => [ { name => 'failed', diff => 1 } ],
                    output_template => 'decap failed: %s',
                    perfdatas => [ { template => '%s', min => 0 } ]
                }
            },
            { label => $proto . '-unknown', nlabel => 'tunnel.' . $proto . '.decap.unknown.count', set => {
                    key_values => [ { name => 'unknown', diff => 1 } ],
                    output_template => 'decap unknown: %s',
                    perfdatas => [ { template => '%s', min => 0 } ]
                }
            }
        ];
    }
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1, statefile => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {});
    return $self;
}

# panGlobalCountersTunnelInspect = .1.3.6.1.4.1.25461.2.1.2.1.19.12
sub manage_selection {
    my ($self, %options) = @_;

    my $base = '.1.3.6.1.4.1.25461.2.1.2.1.19.12';
    my $snmp_result = $options{snmp}->get_leef(
        oids => [
            "$base.1.0", "$base.2.0", "$base.3.0",  # GRE
            "$base.4.0", "$base.5.0", "$base.6.0",  # IPSec
            "$base.7.0", "$base.8.0", "$base.9.0"   # GTP
        ],
        nothing_quit => 1
    );

    $self->{gre}   = { success => $snmp_result->{"$base.1.0"}, failed => $snmp_result->{"$base.2.0"}, unknown => $snmp_result->{"$base.3.0"} };
    $self->{ipsec} = { success => $snmp_result->{"$base.4.0"}, failed => $snmp_result->{"$base.5.0"}, unknown => $snmp_result->{"$base.6.0"} };
    $self->{gtp}   = { success => $snmp_result->{"$base.7.0"}, failed => $snmp_result->{"$base.8.0"}, unknown => $snmp_result->{"$base.9.0"} };

    $self->{cache_name} = 'paloalto_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check tunnel inspection counters for GRE, IPSec and GTP (delta values).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='ipsec'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'gre-success', 'gre-failed', 'gre-unknown',
'ipsec-success', 'ipsec-failed', 'ipsec-unknown',
'gtp-success', 'gtp-failed', 'gtp-unknown'.

=back

=cut
