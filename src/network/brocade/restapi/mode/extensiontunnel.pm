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

package network::brocade::restapi::mode::extensiontunnel;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_tunnel_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "operational status: %s, HA status: %s",
        $self->{result_values}->{oper_status},
        $self->{result_values}->{ha_status}
    );
}

sub custom_circuit_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "admin status: %s, operational status: %s",
        $self->{result_values}->{admin_status},
        $self->{result_values}->{oper_status}
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Extension tunnels: ';
}

sub prefix_tunnel_output {
    my ($self, %options) = @_;

    return "Tunnel '" . $options{instance_value}->{display} . "' ";
}

sub prefix_circuit_output {
    my ($self, %options) = @_;

    return "Circuit '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'tunnels', type => 1, cb_prefix_output => 'prefix_tunnel_output', message_multiple => 'All tunnels are ok' },
        { name => 'circuits', type => 1, cb_prefix_output => 'prefix_circuit_output', message_multiple => 'All circuits are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'tunnels-total', nlabel => 'extension.tunnels.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'tunnels-up', nlabel => 'extension.tunnels.up.count', set => {
                key_values => [ { name => 'up' } ],
                output_template => 'up: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'tunnels-down', nlabel => 'extension.tunnels.down.count', set => {
                key_values => [ { name => 'down' } ],
                output_template => 'down: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{tunnels} = [
        {
            label => 'tunnel-status',
            type => 2,
            critical_default => '%{oper_status} !~ /online|up/i',
            set => {
                key_values => [
                    { name => 'oper_status' }, { name => 'ha_status' },
                    { name => 'remote_ip' }, { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_tunnel_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'tunnel-throughput-in', nlabel => 'tunnel.throughput.in.bitspersecond', set => {
                key_values => [ { name => 'throughput_in' }, { name => 'display' } ],
                output_template => 'throughput in: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'tunnel-throughput-out', nlabel => 'tunnel.throughput.out.bitspersecond', set => {
                key_values => [ { name => 'throughput_out' }, { name => 'display' } ],
                output_template => 'throughput out: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{circuits} = [
        {
            label => 'circuit-status',
            type => 2,
            critical_default => '%{admin_status} eq "enabled" and %{oper_status} !~ /online|up/i',
            set => {
                key_values => [
                    { name => 'admin_status' }, { name => 'oper_status' },
                    { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_circuit_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'circuit-latency', nlabel => 'circuit.latency.milliseconds', set => {
                key_values => [ { name => 'latency' }, { name => 'display' } ],
                output_template => 'latency: %.2f ms',
                perfdatas => [
                    { template => '%.2f', unit => 'ms', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'circuit-packet-loss', nlabel => 'circuit.packet.loss.percentage', set => {
                key_values => [ { name => 'packet_loss' }, { name => 'display' } ],
                output_template => 'packet loss: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'circuit-compression-ratio', nlabel => 'circuit.compression.ratio', set => {
                key_values => [ { name => 'compression_ratio' }, { name => 'display' } ],
                output_template => 'compression ratio: %.2f',
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1 }
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
        'filter-tunnel-name:s'  => { name => 'filter_tunnel_name' },
        'filter-circuit-name:s' => { name => 'filter_circuit_name' },
        'filter-remote-ip:s'    => { name => 'filter_remote_ip' },
        'exclude-tunnel-name:s'  => { name => 'exclude_tunnel_name' },
        'exclude-circuit-name:s' => { name => 'exclude_circuit_name' },
        'exclude-remote-ip:s'    => { name => 'exclude_remote_ip' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $tunnel_data = $options{custom}->get_extension_tunnel();
    my $circuit_data = $options{custom}->get_extension_circuit();

    $self->{global} = { total => 0, up => 0, down => 0 };
    $self->{tunnels} = {};
    $self->{circuits} = {};

    # Process tunnels
    my $tunnel_list = $tunnel_data->{'Response'}->{'extension-tunnel'} // 
                      $tunnel_data->{'brocade-extension-tunnel'}->{'extension-tunnel'} // [];
    $tunnel_list = [$tunnel_list] if (ref($tunnel_list) ne 'ARRAY');

    foreach my $tunnel (@{$tunnel_list}) {
        my $tunnel_name = $tunnel->{'name'} // next;
        my $remote_ip = $tunnel->{'remote-ip-address'} // $tunnel->{'ip-address'} // '';
        my $oper_status = $tunnel->{'operational-status'} // $tunnel->{'oper-status'} // 'unknown';
        my $ha_status = $tunnel->{'ha-operational-status'} // 'unknown';

        # Apply filters
        if (defined($self->{option_results}->{filter_tunnel_name}) && $self->{option_results}->{filter_tunnel_name} ne '' &&
            $tunnel_name !~ /$self->{option_results}->{filter_tunnel_name}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_remote_ip}) && $self->{option_results}->{filter_remote_ip} ne '' &&
            $remote_ip !~ /$self->{option_results}->{filter_remote_ip}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_tunnel_name}) && $self->{option_results}->{exclude_tunnel_name} ne '' &&
            $tunnel_name =~ /$self->{option_results}->{exclude_tunnel_name}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_remote_ip}) && $self->{option_results}->{exclude_remote_ip} ne '' &&
            $remote_ip =~ /$self->{option_results}->{exclude_remote_ip}/) {
            next;
        }

        $self->{global}->{total}++;
        if ($oper_status =~ /online|up/i) {
            $self->{global}->{up}++;
        } else {
            $self->{global}->{down}++;
        }

        # Get throughput (may be in different fields)
        my $throughput_in = $tunnel->{'throughput-read'} // $tunnel->{'rx-throughput'} // 0;
        my $throughput_out = $tunnel->{'throughput-write'} // $tunnel->{'tx-throughput'} // 0;

        $self->{tunnels}->{$tunnel_name} = {
            display => $tunnel_name,
            oper_status => lc($oper_status),
            ha_status => lc($ha_status),
            remote_ip => $remote_ip,
            throughput_in => $throughput_in,
            throughput_out => $throughput_out
        };
    }

    # Process circuits
    my $circuit_list = $circuit_data->{'Response'}->{'extension-circuit'} // 
                       $circuit_data->{'brocade-extension-tunnel'}->{'extension-circuit'} // [];
    $circuit_list = [$circuit_list] if (ref($circuit_list) ne 'ARRAY');

    foreach my $circuit (@{$circuit_list}) {
        my $circuit_name = $circuit->{'name'} // $circuit->{'circuit-id'} // next;
        my $admin_status = $circuit->{'admin-enabled'} // $circuit->{'admin-status'};
        $admin_status = (defined($admin_status) && $admin_status) ? 'enabled' : 'disabled';
        my $oper_status = $circuit->{'operational-status'} // $circuit->{'oper-status'} // 'unknown';

        # Apply filters
        if (defined($self->{option_results}->{filter_circuit_name}) && $self->{option_results}->{filter_circuit_name} ne '' &&
            $circuit_name !~ /$self->{option_results}->{filter_circuit_name}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_circuit_name}) && $self->{option_results}->{exclude_circuit_name} ne '' &&
            $circuit_name =~ /$self->{option_results}->{exclude_circuit_name}/) {
            next;
        }

        # Get circuit metrics
        my $latency = $circuit->{'round-trip-time'} // $circuit->{'latency'} // 0;
        my $packet_loss = $circuit->{'packet-loss'} // 0;
        my $compression = $circuit->{'compression-ratio'} // 0;

        $self->{circuits}->{$circuit_name} = {
            display => $circuit_name,
            admin_status => $admin_status,
            oper_status => lc($oper_status),
            latency => $latency,
            packet_loss => $packet_loss,
            compression_ratio => $compression
        };
    }

    if (scalar(keys %{$self->{tunnels}}) <= 0 && scalar(keys %{$self->{circuits}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No extension tunnels found (FCIP not configured or not supported).");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check FCIP extension tunnels and circuits status.

=over 8

=item B<--filter-tunnel-name>

Filter tunnels by name (can be a regexp).

=item B<--filter-circuit-name>

Filter circuits by name (can be a regexp).

=item B<--filter-remote-ip>

Filter tunnels by remote IP address (can be a regexp).

=item B<--exclude-tunnel-name>

Exclude tunnels by name (can be a regexp).

=item B<--exclude-circuit-name>

Exclude circuits by name (can be a regexp).

=item B<--exclude-remote-ip>

Exclude tunnels by remote IP address (can be a regexp).

=item B<--unknown-tunnel-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{oper_status}, %{ha_status}, %{remote_ip}, %{display}

=item B<--warning-tunnel-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{oper_status}, %{ha_status}, %{remote_ip}, %{display}

=item B<--critical-tunnel-status>

Define the conditions to match for the status to be CRITICAL (default: '%{oper_status} !~ /online|up/i').
You can use the following variables: %{oper_status}, %{ha_status}, %{remote_ip}, %{display}

=item B<--unknown-circuit-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{admin_status}, %{oper_status}, %{display}

=item B<--warning-circuit-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{admin_status}, %{oper_status}, %{display}

=item B<--critical-circuit-status>

Define the conditions to match for the status to be CRITICAL (default: '%{admin_status} eq "enabled" and %{oper_status} !~ /online|up/i').
You can use the following variables: %{admin_status}, %{oper_status}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'tunnels-total', 'tunnels-up', 'tunnels-down',
'tunnel-throughput-in', 'tunnel-throughput-out',
'circuit-latency', 'circuit-packet-loss', 'circuit-compression-ratio'.

=back

=cut
