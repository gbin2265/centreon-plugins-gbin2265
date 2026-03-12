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

package network::paloalto::restapi::mode::ipsec;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    my $msg = sprintf(
        'state: %s [monitor status: %s][ike phase1 state: %s]',
        $self->{result_values}->{state},
        $self->{result_values}->{monitor_status},
        $self->{result_values}->{ike_phase1_state}
    );

    if (defined($self->{result_values}->{show_extra}) && $self->{result_values}->{show_extra}) {
        $msg .= sprintf(
            '[peer: %s][local: %s][if: %s]',
            $self->{result_values}->{peer_address},
            $self->{result_values}->{local_ip},
            $self->{result_values}->{tunnel_if}
        );
    }

    return $msg;
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Total ';
}

sub tunnel_long_output {
    my ($self, %options) = @_;

    my $iv = $options{instance_value};
    my $msg = "checking ipsec tunnel '" . $iv->{display} . "'\n";
    $msg .= "        * peer address: " . $iv->{peer_address} . ", local ip: " . $iv->{local_ip} . ", tunnel interface: " . $iv->{tunnel_if} . "\n";
    $msg .= "        * ike: version " . $iv->{ike_version} . ", role " . $iv->{ike_role} . ", algorithm " . $iv->{ike_algorithm} . "\n";
    $msg .= "        * ike: established " . $iv->{ike_established} . ", expiration " . $iv->{ike_expiration} . "\n";
    $msg .= "        * ipsec: algorithm " . $iv->{ipsec_algorithm} . ", spi-in " . $iv->{spi_in} . ", spi-out " . $iv->{spi_out} . ", lifetime " . $iv->{ipsec_lifetime};
    return $msg;
}

sub prefix_tunnel_output {
    my ($self, %options) = @_;

    return "Tunnel ipsec '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        {
            name => 'tunnels', type => 3, cb_prefix_output => 'prefix_tunnel_output',
            cb_long_output => 'tunnel_long_output', indent_long_output => '    ',
            message_multiple => 'All ipsec tunnels are ok',
            group => [
                { name => 'status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'traffic', type => 0, skipped_code => { -10 => 1 } },
                { name => 'errors', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'ipsec-total', nlabel => 'tunnels.ipsec.total.count', set => {
                key_values => [ { name => 'total_ipsec' } ],
                output_template => 'ipsec tunnels: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'ipsec-error', nlabel => 'tunnels.ipsec.error.count', set => {
                key_values => [ { name => 'total_error' } ],
                output_template => 'error: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{status} = [
        { label => 'status', type => 2, critical_default => '%{ike_phase1_state} eq "down" or %{state} ne "active"', set => {
                key_values => [
                    { name => 'state' }, { name => 'ike_phase1_state' },
                    { name => 'monitor_status' }, { name => 'display' },
                    { name => 'peer_address' }, { name => 'local_ip' },
                    { name => 'tunnel_if' }, { name => 'show_extra' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{traffic} = [
        { label => 'tunnel-encap-packets', nlabel => 'tunnel.vpn.encap.packets.count', set => {
                key_values => [ { name => 'encap', diff => 1 }, { name => 'display' } ],
                output_template => 'encap packets: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'tunnel-decap-packets', nlabel => 'tunnel.vpn.decap.packets.count', set => {
                key_values => [ { name => 'decap', diff => 1 }, { name => 'display' } ],
                output_template => 'decap packets: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'tunnel-encap-bytes', nlabel => 'tunnel.vpn.encap.bytes', set => {
                key_values => [ { name => 'encap_bytes', diff => 1 }, { name => 'display' } ],
                output_template => 'encap bytes: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'tunnel-decap-bytes', nlabel => 'tunnel.vpn.decap.bytes', set => {
                key_values => [ { name => 'decap_bytes', diff => 1 }, { name => 'display' } ],
                output_template => 'decap bytes: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];

    $self->{maps_counters}->{errors} = [
        { label => 'tunnel-auth-errors', nlabel => 'tunnel.vpn.auth.errors.count', set => {
                key_values => [ { name => 'auth_errors', diff => 1 }, { name => 'display' } ],
                output_template => 'authentication errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'tunnel-decrypt-errors', nlabel => 'tunnel.vpn.decrypt.errors.count', set => {
                key_values => [ { name => 'decrypt_errors', diff => 1 }, { name => 'display' } ],
                output_template => 'decryption errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'tunnel-replay-errors', nlabel => 'tunnel.vpn.replay.errors.count', set => {
                key_values => [ { name => 'replay_errors', diff => 1 }, { name => 'display' } ],
                output_template => 'replay errors: %s',
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
        'filter-name:s' => { name => 'filter_name' }
    });

    return $self;
}

sub is_exact_filter {
    my ($self, %options) = @_;

    my $filter = $options{filter};
    return 0 if (!defined($filter) || $filter eq '');

    return 0 if ($filter =~ /(?<!\\)[.+*?{}()\[\]|\\]/ && $filter !~ /^\^[A-Za-z0-9_\-]+\$$/);

    if ($filter =~ /^\^([A-Za-z0-9_\-]+)\$$/) {
        return $1;
    }

    if ($filter =~ /^[A-Za-z0-9_\-]+$/) {
        return $filter;
    }

    return 0;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $filter = $self->{option_results}->{filter_name};
    my $exact_name = $self->is_exact_filter(filter => $filter);

    # Step 1: Get IKE SA (phase 1) - builds the tunnel list
    my $ike_cmd = $exact_name
        ? '<show><vpn><ike-sa><gateway>' . $exact_name . '</gateway></ike-sa></vpn></show>'
        : '<show><vpn><ike-sa></ike-sa></vpn></show>';

    my $ike_result = $options{custom}->request_api(
        cmd => $ike_cmd,
        ForceArray => ['entry']
    );

    $self->{global} = { total_ipsec => 0, total_error => 0 };
    $self->{tunnels} = {};

    if (defined($ike_result->{entry})) {
        foreach my $entry (@{$ike_result->{entry}}) {
            if (!$exact_name && defined($filter) && $filter ne '' &&
                $entry->{name} !~ /$filter/) {
                $self->{output}->output_add(long_msg => "skipping '" . $entry->{name} . "': no matching filter.", debug => 1);
                next;
            }

            my $tunnel_name = $entry->{name};
            $self->{tunnels}->{$tunnel_name} = {
                # Verbose header info (used by tunnel_long_output)
                display         => $tunnel_name,
                peer_address    => defined($entry->{peerip}) ? $entry->{peerip} : '-',
                local_ip        => '-',
                tunnel_if       => '-',
                ike_version     => defined($entry->{v}) ? $entry->{v} : '-',
                ike_role        => defined($entry->{role}) ? $entry->{role} : '-',
                ike_algorithm   => defined($entry->{algorithm}) ? $entry->{algorithm} : '-',
                ike_established => defined($entry->{established}) ? $entry->{established} : '-',
                ike_expiration  => defined($entry->{expiration}) ? $entry->{expiration} : '-',
                ipsec_algorithm => '-',
                spi_in          => '-',
                spi_out         => '-',
                ipsec_lifetime  => '-',

                # Sub-groups for type 3 counters
                status => {
                    display => $tunnel_name,
                    ike_phase1_state => (defined($entry->{created}) && $entry->{created} ne '') ? 'up' : 'down',
                    monitor_status => 'unknown',
                    state => 'unknown',
                    peer_address => defined($entry->{peerip}) ? $entry->{peerip} : '-',
                    local_ip => '-',
                    tunnel_if => '-',
                    show_extra => $exact_name ? 1 : 0
                },
                traffic => {
                    display => $tunnel_name,
                    encap => 0, decap => 0,
                    encap_bytes => 0, decap_bytes => 0
                },
                errors => {
                    display => $tunnel_name,
                    auth_errors => 0,
                    decrypt_errors => 0,
                    replay_errors => 0
                },

                # Internal fields for gwid/tid mapping
                _gwid => $entry->{gwid}
            };

            $self->{global}->{total_ipsec}++;
        }
    }

    return if ($self->{global}->{total_ipsec} == 0);

    # Step 2: Get IPSec SA (phase 2) - maps gwid to tid + verbose info
    my $ipsec_cmd = $exact_name
        ? '<show><vpn><ipsec-sa><tunnel>' . $exact_name . '</tunnel></ipsec-sa></vpn></show>'
        : '<show><vpn><ipsec-sa></ipsec-sa></vpn></show>';

    my $ipsec_result = $options{custom}->request_api(
        cmd => $ipsec_cmd,
        ForceArray => ['entry']
    );
    if (defined($ipsec_result->{entries}->{entry})) {
        foreach my $entry (@{$ipsec_result->{entries}->{entry}}) {
            foreach my $tunnel_name (keys %{$self->{tunnels}}) {
                next if ($self->{tunnels}->{$tunnel_name}->{_gwid} ne $entry->{gwid});
                $self->{tunnels}->{$tunnel_name}->{_tid} = $entry->{tid};
                # Verbose IPSec SA details
                $self->{tunnels}->{$tunnel_name}->{spi_in} =
                    defined($entry->{'spi-in'}) ? $entry->{'spi-in'} :
                    defined($entry->{spiin}) ? $entry->{spiin} : '-';
                $self->{tunnels}->{$tunnel_name}->{spi_out} =
                    defined($entry->{'spi-out'}) ? $entry->{'spi-out'} :
                    defined($entry->{spiout}) ? $entry->{spiout} : '-';
                $self->{tunnels}->{$tunnel_name}->{ipsec_algorithm} =
                    defined($entry->{algorithm}) ? $entry->{algorithm} : '-';
                $self->{tunnels}->{$tunnel_name}->{ipsec_lifetime} =
                    defined($entry->{life}) ? $entry->{life} :
                    defined($entry->{'life-remain'}) ? $entry->{'life-remain'} : '-';
            }
        }
    }

    # Step 3: Get VPN flow - state, monitor, counters, errors, verbose
    my $flow_cmd = $exact_name
        ? '<show><vpn><flow><name>' . $exact_name . '</name></flow></vpn></show>'
        : '<show><vpn><flow></flow></vpn></show>';

    my $flow_result = $options{custom}->request_api(
        cmd => $flow_cmd,
        ForceArray => ['entry']
    );
    if (defined($flow_result->{IPSec}->{entry})) {
        foreach my $tunnel_name (keys %{$self->{tunnels}}) {
            next if (!defined($self->{tunnels}->{$tunnel_name}->{_tid}));
            foreach my $entry (@{$flow_result->{IPSec}->{entry}}) {
                next if ($self->{tunnels}->{$tunnel_name}->{_tid} ne $entry->{id});

                # Status
                $self->{tunnels}->{$tunnel_name}->{status}->{state} = $entry->{state};
                $self->{tunnels}->{$tunnel_name}->{status}->{monitor_status} = $entry->{mon};
                $self->{tunnels}->{$tunnel_name}->{status}->{tunnel_if} =
                    defined($entry->{'tunnel-i/f'}) ? $entry->{'tunnel-i/f'} :
                    defined($entry->{tunnelif}) ? $entry->{tunnelif} : '-';
                $self->{tunnels}->{$tunnel_name}->{status}->{local_ip} =
                    defined($entry->{'local-ip'}) ? $entry->{'local-ip'} :
                    defined($entry->{localip}) ? $entry->{localip} : '-';

                # Traffic counters
                $self->{tunnels}->{$tunnel_name}->{traffic}->{encap} =
                    defined($entry->{encap}) ? $entry->{encap} : 0;
                $self->{tunnels}->{$tunnel_name}->{traffic}->{decap} =
                    defined($entry->{decap}) ? $entry->{decap} : 0;
                $self->{tunnels}->{$tunnel_name}->{traffic}->{encap_bytes} =
                    defined($entry->{enBytes}) ? $entry->{enBytes} :
                    defined($entry->{'encap-bytes'}) ? $entry->{'encap-bytes'} : 0;
                $self->{tunnels}->{$tunnel_name}->{traffic}->{decap_bytes} =
                    defined($entry->{deBytes}) ? $entry->{deBytes} :
                    defined($entry->{'decap-bytes'}) ? $entry->{'decap-bytes'} : 0;

                # Error counters
                $self->{tunnels}->{$tunnel_name}->{errors}->{auth_errors} =
                    defined($entry->{'auth-errors'}) ? $entry->{'auth-errors'} :
                    defined($entry->{authErrors}) ? $entry->{authErrors} : 0;
                $self->{tunnels}->{$tunnel_name}->{errors}->{decrypt_errors} =
                    defined($entry->{'decryption-errors'}) ? $entry->{'decryption-errors'} :
                    defined($entry->{decryptErrors}) ? $entry->{decryptErrors} : 0;
                $self->{tunnels}->{$tunnel_name}->{errors}->{replay_errors} =
                    defined($entry->{'replay-packets'}) ? $entry->{'replay-packets'} :
                    defined($entry->{replayPackets}) ? $entry->{replayPackets} : 0;

                # Verbose flow details
                $self->{tunnels}->{$tunnel_name}->{tunnel_if} =
                    defined($entry->{'tunnel-i/f'}) ? $entry->{'tunnel-i/f'} :
                    defined($entry->{tunnelif}) ? $entry->{tunnelif} : '-';
                $self->{tunnels}->{$tunnel_name}->{local_ip} =
                    defined($entry->{'local-ip'}) ? $entry->{'local-ip'} :
                    defined($entry->{localip}) ? $entry->{localip} : '-';
            }
        }
    }

    # Count tunnels in error (ike down or state not active)
    foreach my $tunnel_name (keys %{$self->{tunnels}}) {
        my $st = $self->{tunnels}->{$tunnel_name}->{status};
        if ($st->{ike_phase1_state} eq 'down' || $st->{state} ne 'active') {
            $self->{global}->{total_error}++;
        }
    }

    $self->{cache_name} = 'paloalto_' . $self->{mode} . '_' . $options{custom}->get_hostname() . '_' . $options{custom}->get_port() . '_' .
        md5_hex(
            (defined($self->{option_results}->{filter_name}) ? $self->{option_results}->{filter_name} : '') . '_' .
            (defined($self->{option_results}->{filter_counters}) ? $self->{option_results}->{filter_counters} : '')
        );
}

1;

__END__

=head1 MODE

Check IPSec tunnels.

=over 8

=item B<--filter-name>

Filter tunnels by name (can be a regexp).
If the filter is an exact name (no regex characters), targeted API calls
are used for better performance.

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{ike_phase1_state}, %{state}, %{monitor_status}, %{display}, %{peer_address}, %{local_ip}, %{tunnel_if}.

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{ike_phase1_state}, %{state}, %{monitor_status}, %{display}, %{peer_address}, %{local_ip}, %{tunnel_if}.

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{ike_phase1_state} eq "down" or %{state} ne "active"').
You can use the following variables: %{ike_phase1_state}, %{state}, %{monitor_status}, %{display}, %{peer_address}, %{local_ip}, %{tunnel_if}.

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'ipsec-total', 'ipsec-error', 'tunnel-encap-packets', 'tunnel-decap-packets',
'tunnel-encap-bytes', 'tunnel-decap-bytes',
'tunnel-auth-errors', 'tunnel-decrypt-errors', 'tunnel-replay-errors'.

=back

=cut
