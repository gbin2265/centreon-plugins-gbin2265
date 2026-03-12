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

package network::brocade::restapi::mode::fcrrouting;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_config_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "FCR enabled: %s, backbone FID: %s",
        $self->{result_values}->{fcr_enabled},
        $self->{result_values}->{backbone_fid}
    );
}

sub custom_edge_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "edge FID: %s, online: %s",
        $self->{result_values}->{edge_fid},
        $self->{result_values}->{online}
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'FC Routing: ';
}

sub prefix_edge_output {
    my ($self, %options) = @_;

    return "Edge fabric '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'edges', type => 1, cb_prefix_output => 'prefix_edge_output', message_multiple => 'All edge fabrics are ok' }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'fcr-status',
            type => 2,
            set => {
                key_values => [
                    { name => 'fcr_enabled' }, { name => 'backbone_fid' }
                ],
                closure_custom_output => $self->can('custom_config_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'edge-fabrics-total', nlabel => 'fcr.edge.fabrics.total.count', set => {
                key_values => [ { name => 'total_edges' } ],
                output_template => 'edge fabrics: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'edge-fabrics-online', nlabel => 'fcr.edge.fabrics.online.count', set => {
                key_values => [ { name => 'online_edges' } ],
                output_template => 'online: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'edge-fabrics-offline', nlabel => 'fcr.edge.fabrics.offline.count', set => {
                key_values => [ { name => 'offline_edges' } ],
                output_template => 'offline: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{edges} = [
        {
            label => 'edge-status',
            type => 2,
            critical_default => '%{online} ne "yes"',
            set => {
                key_values => [
                    { name => 'edge_fid' }, { name => 'online' },
                    { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_edge_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'edge-devices', nlabel => 'edge.fabric.devices.count', set => {
                key_values => [ { name => 'device_count' }, { name => 'display' } ],
                output_template => 'devices: %s',
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
        'filter-edge-fid:s'    => { name => 'filter_edge_fid' },
        'filter-edge-alias:s'  => { name => 'filter_edge_alias' },
        'exclude-edge-fid:s'   => { name => 'exclude_edge_fid' },
        'exclude-edge-alias:s' => { name => 'exclude_edge_alias' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $fcr_config = $options{custom}->get_fcr_configuration();
    my $edge_data = $options{custom}->get_fcr_edge_fabric();

    $self->{global} = { 
        fcr_enabled => 'no', 
        backbone_fid => 'n/a',
        total_edges => 0, 
        online_edges => 0, 
        offline_edges => 0 
    };
    $self->{edges} = {};

    # Parse FCR configuration
    my $config = $fcr_config->{'Response'}->{'routing-configuration'} // 
                 $fcr_config->{'brocade-fibrechannel-routing'}->{'routing-configuration'} // {};
    $config = $config->[0] if (ref($config) eq 'ARRAY');

    my $fcr_enabled = $config->{'fcr-enabled'} // $config->{'backbone-fabric-id'};
    $self->{global}->{fcr_enabled} = (defined($fcr_enabled) && $fcr_enabled) ? 'yes' : 'no';
    $self->{global}->{backbone_fid} = $config->{'backbone-fabric-id'} // 'n/a';

    # Parse edge fabrics
    my $edge_list = $edge_data->{'Response'}->{'edge-fabric-alias'} // 
                    $edge_data->{'brocade-fibrechannel-routing'}->{'edge-fabric-alias'} // [];
    $edge_list = [$edge_list] if (ref($edge_list) ne 'ARRAY');

    foreach my $edge (@{$edge_list}) {
        my $edge_fid = $edge->{'edge-fabric-id'} // next;
        my $alias = $edge->{'alias-name'} // "edge-$edge_fid";
        my $online = $edge->{'online'} // $edge->{'reachable'} // 0;
        $online = $online ? 'yes' : 'no';

        # Apply filters
        if (defined($self->{option_results}->{filter_edge_fid}) && $self->{option_results}->{filter_edge_fid} ne '' &&
            $edge_fid !~ /$self->{option_results}->{filter_edge_fid}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_edge_alias}) && $self->{option_results}->{filter_edge_alias} ne '' &&
            $alias !~ /$self->{option_results}->{filter_edge_alias}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_edge_fid}) && $self->{option_results}->{exclude_edge_fid} ne '' &&
            $edge_fid =~ /$self->{option_results}->{exclude_edge_fid}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_edge_alias}) && $self->{option_results}->{exclude_edge_alias} ne '' &&
            $alias =~ /$self->{option_results}->{exclude_edge_alias}/) {
            next;
        }

        $self->{global}->{total_edges}++;
        if ($online eq 'yes') {
            $self->{global}->{online_edges}++;
        } else {
            $self->{global}->{offline_edges}++;
        }

        my $device_count = $edge->{'device-count'} // $edge->{'number-of-devices'} // 0;

        $self->{edges}->{$alias} = {
            display => $alias,
            edge_fid => $edge_fid,
            online => $online,
            device_count => $device_count
        };
    }

    if ($self->{global}->{fcr_enabled} eq 'no' && scalar(keys %{$self->{edges}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "FC Routing not enabled or not configured.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check FC Routing (FCR) configuration and edge fabric status.

=over 8

=item B<--filter-edge-fid>

Filter edge fabrics by Fabric ID (can be a regexp).

=item B<--filter-edge-alias>

Filter edge fabrics by alias name (can be a regexp).

=item B<--exclude-edge-fid>

Exclude edge fabrics by Fabric ID (can be a regexp).

=item B<--exclude-edge-alias>

Exclude edge fabrics by alias name (can be a regexp).

=item B<--unknown-fcr-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{fcr_enabled}, %{backbone_fid}

=item B<--warning-fcr-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{fcr_enabled}, %{backbone_fid}

=item B<--critical-fcr-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{fcr_enabled}, %{backbone_fid}

=item B<--unknown-edge-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{edge_fid}, %{online}, %{display}

=item B<--warning-edge-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{edge_fid}, %{online}, %{display}

=item B<--critical-edge-status>

Define the conditions to match for the status to be CRITICAL (default: '%{online} ne "yes"').
You can use the following variables: %{edge_fid}, %{online}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'edge-fabrics-total', 'edge-fabrics-online', 'edge-fabrics-offline', 'edge-devices'.

=back

=cut
