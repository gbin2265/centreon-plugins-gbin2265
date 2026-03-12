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

package network::brocade::restapi::mode::ntp;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_global_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "active server: %s, sync status: %s",
        $self->{result_values}->{active_server},
        $self->{result_values}->{sync_status}
    );
}

sub custom_server_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "reachable: %s, stratum: %s",
        $self->{result_values}->{reachable},
        $self->{result_values}->{stratum}
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'NTP: ';
}

sub prefix_server_output {
    my ($self, %options) = @_;

    return "Server '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'servers', type => 1, cb_prefix_output => 'prefix_server_output', message_multiple => 'All NTP servers are ok' }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'sync-status',
            type => 2,
            warning_default => '%{sync_status} !~ /synchronized/i',
            set => {
                key_values => [
                    { name => 'active_server' }, { name => 'sync_status' }
                ],
                closure_custom_output => $self->can('custom_global_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'servers-total', nlabel => 'ntp.servers.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'configured servers: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'servers-reachable', nlabel => 'ntp.servers.reachable.count', set => {
                key_values => [ { name => 'reachable' } ],
                output_template => 'reachable: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'servers-unreachable', nlabel => 'ntp.servers.unreachable.count', set => {
                key_values => [ { name => 'unreachable' } ],
                output_template => 'unreachable: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{servers} = [
        {
            label => 'server-status',
            type => 2,
            critical_default => '%{reachable} ne "yes"',
            set => {
                key_values => [
                    { name => 'reachable' }, { name => 'stratum' },
                    { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_server_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'server-offset', nlabel => 'server.offset.milliseconds', set => {
                key_values => [ { name => 'offset' }, { name => 'display' } ],
                output_template => 'offset: %.3f ms',
                perfdatas => [
                    { template => '%.3f', unit => 'ms', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'server-delay', nlabel => 'server.delay.milliseconds', set => {
                key_values => [ { name => 'delay' }, { name => 'display' } ],
                output_template => 'delay: %.3f ms',
                perfdatas => [
                    { template => '%.3f', unit => 'ms', min => 0, label_extra_instance => 1 }
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
        'filter-server:s'  => { name => 'filter_server' },
        'exclude-server:s' => { name => 'exclude_server' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $clock_data = $options{custom}->get_clock_server();
    my $ntp_data = $options{custom}->get_ntp_clock_server();

    $self->{global} = { 
        active_server => 'none', 
        sync_status => 'unknown',
        total => 0, 
        reachable => 0, 
        unreachable => 0 
    };
    $self->{servers} = {};

    # Parse clock server info
    my $clock = $clock_data->{'Response'}->{'clock-server'} // 
                $clock_data->{'brocade-time'}->{'clock-server'} // {};
    $clock = $clock->[0] if (ref($clock) eq 'ARRAY');

    $self->{global}->{active_server} = $clock->{'active-server'} // 'none';
    
    # Determine sync status based on active server
    if ($self->{global}->{active_server} ne 'none' && $self->{global}->{active_server} ne '') {
        $self->{global}->{sync_status} = 'synchronized';
    } else {
        $self->{global}->{sync_status} = 'not synchronized';
    }

    # Parse NTP server list
    my $ntp_list = $ntp_data->{'Response'}->{'ntp-clock-server'} // 
                   $ntp_data->{'brocade-time'}->{'ntp-clock-server'} // [];
    $ntp_list = [$ntp_list] if (ref($ntp_list) ne 'ARRAY');

    # Also check legacy format
    if (scalar(@{$ntp_list}) == 0) {
        my $server_addr = $clock->{'ntp-server-address'};
        if (defined($server_addr)) {
            $server_addr = [$server_addr] if (ref($server_addr) ne 'ARRAY');
            foreach my $addr (@{$server_addr}) {
                next if (!defined($addr) || $addr eq '');
                push @{$ntp_list}, { 'server-address' => $addr };
            }
        }
    }

    foreach my $server (@{$ntp_list}) {
        my $server_addr = $server->{'server-address'} // $server->{'server'} // next;
        next if ($server_addr eq '' || $server_addr eq '0.0.0.0');

        # Apply filters
        if (defined($self->{option_results}->{filter_server}) && $self->{option_results}->{filter_server} ne '' &&
            $server_addr !~ /$self->{option_results}->{filter_server}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_server}) && $self->{option_results}->{exclude_server} ne '' &&
            $server_addr =~ /$self->{option_results}->{exclude_server}/) {
            next;
        }

        $self->{global}->{total}++;

        my $reachable = $server->{'reachable'} // $server->{'server-reachable'};
        my $is_active = ($server_addr eq $self->{global}->{active_server});
        
        # If no reachable field, assume reachable if it's the active server
        if (!defined($reachable)) {
            $reachable = $is_active ? 1 : 0;
        }
        $reachable = $reachable ? 'yes' : 'no';

        if ($reachable eq 'yes') {
            $self->{global}->{reachable}++;
        } else {
            $self->{global}->{unreachable}++;
        }

        my $stratum = $server->{'stratum'} // 'unknown';
        my $offset = $server->{'offset'} // 0;
        my $delay = $server->{'delay'} // $server->{'round-trip-delay'} // 0;

        $self->{servers}->{$server_addr} = {
            display => $server_addr,
            reachable => $reachable,
            stratum => $stratum,
            offset => $offset,
            delay => $delay
        };
    }
}

1;

__END__

=head1 MODE

Check NTP server configuration and synchronization status.

=over 8

=item B<--filter-server>

Filter NTP servers by address (can be a regexp).

=item B<--exclude-server>

Exclude NTP servers by address (can be a regexp).

=item B<--unknown-sync-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{active_server}, %{sync_status}

=item B<--warning-sync-status>

Define the conditions to match for the status to be WARNING (default: '%{sync_status} !~ /synchronized/i').
You can use the following variables: %{active_server}, %{sync_status}

=item B<--critical-sync-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{active_server}, %{sync_status}

=item B<--unknown-server-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{reachable}, %{stratum}, %{display}

=item B<--warning-server-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{reachable}, %{stratum}, %{display}

=item B<--critical-server-status>

Define the conditions to match for the status to be CRITICAL (default: '%{reachable} ne "yes"').
You can use the following variables: %{reachable}, %{stratum}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'servers-total', 'servers-reachable', 'servers-unreachable',
'server-offset', 'server-delay'.

=back

=cut
