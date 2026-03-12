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

package network::brocade::restapi::mode::nameserver;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_device_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "port-id: %s, type: %s, symbolic-name: %s",
        $self->{result_values}->{port_id},
        $self->{result_values}->{device_type},
        $self->{result_values}->{symbolic_name}
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Name Server: ';
}

sub prefix_device_output {
    my ($self, %options) = @_;

    return "Device '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'devices', type => 1, cb_prefix_output => 'prefix_device_output', message_multiple => 'All name server entries are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'devices-total', nlabel => 'nameserver.devices.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total devices: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'devices-initiators', nlabel => 'nameserver.devices.initiators.count', set => {
                key_values => [ { name => 'initiators' } ],
                output_template => 'initiators: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'devices-targets', nlabel => 'nameserver.devices.targets.count', set => {
                key_values => [ { name => 'targets' } ],
                output_template => 'targets: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{devices} = [
        {
            label => 'device-status',
            type => 2,
            set => {
                key_values => [
                    { name => 'port_id' }, { name => 'device_type' },
                    { name => 'symbolic_name' }, { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_device_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-port-wwn:s'       => { name => 'filter_port_wwn' },
        'filter-node-wwn:s'       => { name => 'filter_node_wwn' },
        'filter-symbolic-name:s'  => { name => 'filter_symbolic_name' },
        'filter-device-type:s'    => { name => 'filter_device_type' },
        'exclude-port-wwn:s'      => { name => 'exclude_port_wwn' },
        'exclude-node-wwn:s'      => { name => 'exclude_node_wwn' },
        'exclude-symbolic-name:s' => { name => 'exclude_symbolic_name' },
        'exclude-device-type:s'   => { name => 'exclude_device_type' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $ns_data = $options{custom}->get_name_server();

    $self->{global} = { total => 0, initiators => 0, targets => 0 };
    $self->{devices} = {};

    my $ns_list = $ns_data->{'Response'}->{'fibrechannel-name-server'} // 
                  $ns_data->{'brocade-name-server'}->{'fibrechannel-name-server'} // [];
    $ns_list = [$ns_list] if (ref($ns_list) ne 'ARRAY');

    foreach my $entry (@{$ns_list}) {
        my $port_wwn = $entry->{'port-name'} // $entry->{'port-wwn'} // next;
        my $node_wwn = $entry->{'node-name'} // $entry->{'node-wwn'} // '';
        my $port_id = $entry->{'port-id'} // '';
        my $symbolic_name = $entry->{'port-symbolic-name'} // $entry->{'node-symbolic-name'} // '';
        
        # Determine device type from FC4 features
        my $device_type = 'unknown';
        my $fc4_features = $entry->{'fc4-features'} // '';
        my $fc4_type = $entry->{'fc4-type'} // '';
        
        if ($fc4_features =~ /initiator/i || $fc4_type =~ /FCP-Initiator/i) {
            $device_type = 'initiator';
        } elsif ($fc4_features =~ /target/i || $fc4_type =~ /FCP-Target/i) {
            $device_type = 'target';
        } elsif ($fc4_features =~ /nvme/i) {
            $device_type = 'nvme';
        }

        # Apply filters
        if (defined($self->{option_results}->{filter_port_wwn}) && $self->{option_results}->{filter_port_wwn} ne '' &&
            $port_wwn !~ /$self->{option_results}->{filter_port_wwn}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_node_wwn}) && $self->{option_results}->{filter_node_wwn} ne '' &&
            $node_wwn !~ /$self->{option_results}->{filter_node_wwn}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_symbolic_name}) && $self->{option_results}->{filter_symbolic_name} ne '' &&
            $symbolic_name !~ /$self->{option_results}->{filter_symbolic_name}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_device_type}) && $self->{option_results}->{filter_device_type} ne '' &&
            $device_type !~ /$self->{option_results}->{filter_device_type}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_port_wwn}) && $self->{option_results}->{exclude_port_wwn} ne '' &&
            $port_wwn =~ /$self->{option_results}->{exclude_port_wwn}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_node_wwn}) && $self->{option_results}->{exclude_node_wwn} ne '' &&
            $node_wwn =~ /$self->{option_results}->{exclude_node_wwn}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_symbolic_name}) && $self->{option_results}->{exclude_symbolic_name} ne '' &&
            $symbolic_name =~ /$self->{option_results}->{exclude_symbolic_name}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_device_type}) && $self->{option_results}->{exclude_device_type} ne '' &&
            $device_type =~ /$self->{option_results}->{exclude_device_type}/) {
            next;
        }

        $self->{global}->{total}++;
        $self->{global}->{initiators}++ if ($device_type eq 'initiator');
        $self->{global}->{targets}++ if ($device_type eq 'target');

        $self->{devices}->{$port_wwn} = {
            display => $port_wwn,
            port_id => $port_id,
            node_wwn => $node_wwn,
            device_type => $device_type,
            symbolic_name => $symbolic_name
        };
    }
}

1;

__END__

=head1 MODE

Check name server entries (devices registered in the fabric).

=over 8

=item B<--filter-port-wwn>

Filter devices by port WWN (can be a regexp).

=item B<--filter-node-wwn>

Filter devices by node WWN (can be a regexp).

=item B<--filter-symbolic-name>

Filter devices by symbolic name (can be a regexp).

=item B<--filter-device-type>

Filter devices by type: 'initiator', 'target', 'nvme' (can be a regexp).

=item B<--exclude-port-wwn>

Exclude devices by port WWN (can be a regexp).

=item B<--exclude-node-wwn>

Exclude devices by node WWN (can be a regexp).

=item B<--exclude-symbolic-name>

Exclude devices by symbolic name (can be a regexp).

=item B<--exclude-device-type>

Exclude devices by type (can be a regexp).

=item B<--unknown-device-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{port_id}, %{device_type}, %{symbolic_name}, %{display}

=item B<--warning-device-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{port_id}, %{device_type}, %{symbolic_name}, %{display}

=item B<--critical-device-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{port_id}, %{device_type}, %{symbolic_name}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'devices-total', 'devices-initiators', 'devices-targets'.

=back

=cut
