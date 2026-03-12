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

package network::brocade::restapi::mode::lldp;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_global_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "LLDP enabled: %s, system name: %s",
        $self->{result_values}->{lldp_enabled},
        $self->{result_values}->{system_name}
    );
}

sub custom_neighbor_output {
    my ($self, %options) = @_;

    return sprintf(
        "remote system: %s, remote port: %s",
        $self->{result_values}->{remote_system},
        $self->{result_values}->{remote_port}
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'LLDP: ';
}

sub prefix_neighbor_output {
    my ($self, %options) = @_;

    return "Port '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'neighbors', type => 1, cb_prefix_output => 'prefix_neighbor_output', message_multiple => 'All LLDP neighbors are ok' }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'lldp-status',
            type => 2,
            set => {
                key_values => [
                    { name => 'lldp_enabled' }, { name => 'system_name' }
                ],
                closure_custom_output => $self->can('custom_global_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'neighbors-total', nlabel => 'lldp.neighbors.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'neighbors: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{neighbors} = [
        {
            label => 'neighbor-info',
            type => 2,
            set => {
                key_values => [
                    { name => 'remote_system' }, { name => 'remote_port' },
                    { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_neighbor_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        },
        { label => 'neighbor-ttl', nlabel => 'neighbor.ttl.seconds', set => {
                key_values => [ { name => 'ttl' }, { name => 'display' } ],
                output_template => 'TTL: %s s',
                perfdatas => [
                    { template => '%s', unit => 's', min => 0, label_extra_instance => 1 }
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
        'filter-local-port:s'    => { name => 'filter_local_port' },
        'filter-remote-system:s' => { name => 'filter_remote_system' },
        'exclude-local-port:s'   => { name => 'exclude_local_port' },
        'exclude-remote-system:s' => { name => 'exclude_remote_system' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $global_data = $options{custom}->get_lldp_global();
    my $neighbor_data = $options{custom}->get_lldp_neighbor();

    # Check if LLDP is available on this switch
    if (!defined($global_data) && !defined($neighbor_data)) {
        $self->{output}->add_option_msg(short_msg => "LLDP is not enabled or not available on this switch.");
        $self->{output}->option_exit();
    }

    $self->{global} = { 
        lldp_enabled => 'no', 
        system_name => 'unknown',
        total => 0
    };
    $self->{neighbors} = {};

    # Parse LLDP global settings
    if (defined($global_data)) {
        my $lldp = $global_data->{'Response'}->{'lldp-global'} // 
                   $global_data->{'brocade-lldp'}->{'lldp-global'} // {};
        $lldp = $lldp->[0] if (ref($lldp) eq 'ARRAY');

        my $enabled = $lldp->{'enabled-state'} // $lldp->{'lldp-enabled'} // 0;
        $self->{global}->{lldp_enabled} = $enabled ? 'yes' : 'no';
        $self->{global}->{system_name} = $lldp->{'system-name'} // 'unknown';
    }

    # Parse neighbors
    if (defined($neighbor_data)) {
        my $neighbor_list = $neighbor_data->{'Response'}->{'lldp-neighbor-details'} // 
                            $neighbor_data->{'brocade-lldp'}->{'lldp-neighbor-details'} // [];
        $neighbor_list = [$neighbor_list] if (ref($neighbor_list) ne 'ARRAY');

        foreach my $neighbor (@{$neighbor_list}) {
            my $local_port = $neighbor->{'slot-port'} // $neighbor->{'local-port-id'} // next;
            my $remote_system = $neighbor->{'remote-system-name'} // $neighbor->{'chassis-id'} // 'unknown';
            my $remote_port = $neighbor->{'remote-port-id'} // $neighbor->{'port-id'} // 'unknown';
            my $ttl = $neighbor->{'remaining-life'} // $neighbor->{'ttl'} // 0;

            # Apply filters
            if (defined($self->{option_results}->{filter_local_port}) && $self->{option_results}->{filter_local_port} ne '' &&
                $local_port !~ /$self->{option_results}->{filter_local_port}/) {
                next;
            }
            if (defined($self->{option_results}->{filter_remote_system}) && $self->{option_results}->{filter_remote_system} ne '' &&
                $remote_system !~ /$self->{option_results}->{filter_remote_system}/) {
                next;
            }

            # Apply excludes
            if (defined($self->{option_results}->{exclude_local_port}) && $self->{option_results}->{exclude_local_port} ne '' &&
                $local_port =~ /$self->{option_results}->{exclude_local_port}/) {
                next;
            }
            if (defined($self->{option_results}->{exclude_remote_system}) && $self->{option_results}->{exclude_remote_system} ne '' &&
                $remote_system =~ /$self->{option_results}->{exclude_remote_system}/) {
                next;
            }

            $self->{global}->{total}++;

            $self->{neighbors}->{$local_port} = {
                display => $local_port,
                remote_system => $remote_system,
                remote_port => $remote_port,
                ttl => $ttl
            };
        }
    }
}

1;

__END__

=head1 MODE

Check LLDP status and discovered neighbors.

Note: This mode requires LLDP to be enabled on the switch. If LLDP is not
configured, the mode will exit with a message indicating LLDP is not available.

=over 8

=item B<--filter-local-port>

Filter neighbors by local port (can be a regexp).

=item B<--filter-remote-system>

Filter neighbors by remote system name (can be a regexp).

=item B<--exclude-local-port>

Exclude neighbors by local port (can be a regexp).

=item B<--exclude-remote-system>

Exclude neighbors by remote system name (can be a regexp).

=item B<--unknown-lldp-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{lldp_enabled}, %{system_name}

=item B<--warning-lldp-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{lldp_enabled}, %{system_name}

=item B<--critical-lldp-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{lldp_enabled}, %{system_name}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'neighbors-total', 'neighbor-ttl'.

=back

=cut
