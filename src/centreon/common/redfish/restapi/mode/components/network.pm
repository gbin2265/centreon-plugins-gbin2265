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

package centreon::common::redfish::restapi::mode::components::network;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking network interfaces');
    $self->{components}->{network} = { name => 'network', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'network'));

    my @interfaces = ();
    
    # Get Manager Ethernet Interfaces (iLO network)
    $self->get_managers() if (!defined($self->{managers}));
    foreach my $manager (@{$self->{managers}}) {
        my $eth_interfaces = $self->get_ethernet_interfaces(parent => $manager, type => 'manager');
        foreach my $eth (@$eth_interfaces) {
            $eth->{_parent_name} = 'Manager:' . $manager->{Id};
            $eth->{_parent_type} = 'manager';
            push @interfaces, $eth;
        }
    }
    
    # Get System Ethernet Interfaces (OS/Host network)
    $self->get_systems() if (!defined($self->{systems}));
    foreach my $system (@{$self->{systems}}) {
        my $eth_interfaces = $self->get_ethernet_interfaces(parent => $system, type => 'system');
        foreach my $eth (@$eth_interfaces) {
            $eth->{_parent_name} = 'System:' . $system->{Id};
            $eth->{_parent_type} = 'system';
            push @interfaces, $eth;
        }
    }
    
    foreach my $eth (@interfaces) {
        my $eth_id = defined($eth->{Id}) ? $eth->{Id} : 'unknown';
        my $eth_name = defined($eth->{Name}) ? $eth->{Name} : 'Interface' . $eth_id;
        my $parent_name = $eth->{_parent_name};
        
        my $state = defined($eth->{Status}->{State}) ? $eth->{Status}->{State} : 'n/a';
        my $health = defined($eth->{Status}->{Health}) ? $eth->{Status}->{Health} : 'n/a';
        my $link_status = defined($eth->{LinkStatus}) ? $eth->{LinkStatus} : 'n/a';
        my $speed_mbps = defined($eth->{SpeedMbps}) ? $eth->{SpeedMbps} : 0;
        my $full_duplex = defined($eth->{FullDuplex}) ? ($eth->{FullDuplex} ? 'Full' : 'Half') : 'n/a';
        my $mac = defined($eth->{MACAddress}) ? $eth->{MACAddress} : '';
        
        my $instance = $parent_name . '.' . $eth_id;
        next if ($self->check_filter(section => 'network', instance => $instance));
        $self->{components}->{network}->{total}++;
        
        $self->{output}->output_add(
            long_msg => sprintf(
                "network interface '%s/%s' status is '%s' [instance: %s, state: %s, link: %s, speed: %s Mbps, duplex: %s, mac: %s]",
                $parent_name, $eth_name, $health, $instance, $state, $link_status, $speed_mbps, $full_duplex, $mac
            )
        );
        
        my $exit = $self->get_severity(label => 'state', section => 'network.state', value => $state);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Network interface '%s/%s' state is '%s'", $parent_name, $eth_name, $state)
            );
        }
        
        $exit = $self->get_severity(label => 'status', section => 'network.status', value => $health);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Network interface '%s/%s' status is '%s'", $parent_name, $eth_name, $health)
            );
        }
        
        # Check link status
        if ($link_status ne 'n/a' && $link_status ne 'LinkUp') {
            $self->{output}->output_add(
                severity => 'WARNING',
                short_msg => sprintf("Network interface '%s/%s' link is '%s'", $parent_name, $eth_name, $link_status)
            );
        }
        
        # Speed perfdata
        if ($speed_mbps > 0) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.network.speed.mbps',
                unit => 'Mbps',
                instances => $eth_name,
                value => $speed_mbps,
                min => 0
            );
        }
        
        # Link status as perfdata (1=up, 0=down)
        my $link_value = ($link_status eq 'LinkUp') ? 1 : 0;
        $self->{output}->perfdata_add(
            nlabel => 'hardware.network.link.status',
            instances => $eth_name,
            value => $link_value,
            min => 0,
            max => 1
        );
    }
}


1;

__END__

=head1 DESCRIPTION

Check ethernet interface status, link state and speed.
Monitors EthernetInterfaces from the Systems resource for link status,
speed, duplex mode and MAC address.

=head2 Redfish Endpoint

/redfish/v1/Systems/{SystemId}/EthernetInterfaces/{EthId}

=head2 Perfdata

hardware.network.speed.mbps : Interface speed in Mbps
hardware.network.link.status : Link status (1=LinkUp, 0=other)

=cut
