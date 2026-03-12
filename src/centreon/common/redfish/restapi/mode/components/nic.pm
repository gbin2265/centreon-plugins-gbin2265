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

package centreon::common::redfish::restapi::mode::components::nic;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking network adapters');
    $self->{components}->{nic} = { name => 'nic', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'nic'));

    # Get network adapters
    $self->get_network_adapters() if (!defined($self->{network_adapters}));
    return if (!defined($self->{network_adapters}) || scalar(@{$self->{network_adapters}}) == 0);

    foreach my $adapter (@{$self->{network_adapters}}) {
        my $adapter_id = defined($adapter->{Id}) ? $adapter->{Id} : 'unknown';
        my $adapter_name = defined($adapter->{Name}) ? $adapter->{Name} : 'NIC' . $adapter_id;
        my $manufacturer = defined($adapter->{Manufacturer}) ? $adapter->{Manufacturer} : '';
        
        my $state = defined($adapter->{Status}->{State}) ? $adapter->{Status}->{State} : 'n/a';
        my $health = defined($adapter->{Status}->{Health}) ? $adapter->{Status}->{Health} : 'n/a';
        
        my $instance = $adapter_id;
        next if ($self->check_filter(section => 'nic', instance => $instance));
        $self->{components}->{nic}->{total}++;
        
        # Count ports
        my $ports_total = 0;
        my $ports_up = 0;
        my @ports = ();
        
        if (defined($adapter->{PhysicalPorts}) && ref($adapter->{PhysicalPorts}) eq 'ARRAY') {
            @ports = @{$adapter->{PhysicalPorts}};
            $ports_total = scalar(@ports);
            foreach my $port (@ports) {
                if (defined($port->{LinkStatus}) && $port->{LinkStatus} eq 'LinkUp') {
                    $ports_up++;
                }
            }
        }
        
        $self->{output}->output_add(
            long_msg => sprintf(
                "network adapter '%s' status is '%s' [instance: %s, state: %s, ports: %s up / %s total]",
                $adapter_name, $health, $instance, $state, $ports_up, $ports_total
            )
        );
        
        my $exit = $self->get_severity(label => 'state', section => 'nic.state', value => $state);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Network adapter '%s' state is '%s'", $adapter_name, $state)
            );
        }
        
        $exit = $self->get_severity(label => 'status', section => 'nic.status', value => $health);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Network adapter '%s' status is '%s'", $adapter_name, $health)
            );
        }
        
        # Ports up/total perfdata
        if ($ports_total > 0) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nic.ports.up.count',
                instances => $adapter_name,
                value => $ports_up,
                min => 0,
                max => $ports_total
            );
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nic.ports.total.count',
                instances => $adapter_name,
                value => $ports_total,
                min => 0
            );
        }
        
        # Per-port details
        my $port_num = 0;
        foreach my $port (@ports) {
            $port_num++;
            my $port_name = defined($port->{Name}) ? $port->{Name} : 'Port' . $port_num;
            my $port_instance = $adapter_id . '.' . $port_num;
            
            my $link_status = defined($port->{LinkStatus}) ? $port->{LinkStatus} : 'n/a';
            my $speed_mbps = defined($port->{SpeedMbps}) ? $port->{SpeedMbps} : 0;
            my $full_duplex = defined($port->{FullDuplex}) ? ($port->{FullDuplex} ? 'Full' : 'Half') : 'n/a';
            my $mac = '';
            
            # Get MAC address
            if (defined($port->{MacAddress})) {
                $mac = $port->{MacAddress};
            } elsif (defined($port->{AssociatedNetworkAddresses}) && ref($port->{AssociatedNetworkAddresses}) eq 'ARRAY') {
                $mac = $port->{AssociatedNetworkAddresses}->[0] || '';
            }
            
            $self->{output}->output_add(
                long_msg => sprintf(
                    "  port '%s' link is '%s' [speed: %s Mbps, duplex: %s, mac: %s]",
                    $port_name, $link_status, $speed_mbps, $full_duplex, $mac
                )
            );
            
            # Port speed perfdata (only if port is up and has speed)
            if ($speed_mbps > 0) {
                $self->{output}->perfdata_add(
                    nlabel => 'hardware.nic.port.speed.mbps',
                    unit => 'Mbps',
                    instances => [$adapter_name, $port_name],
                    value => $speed_mbps,
                    min => 0
                );
            }
            
            # Port link status as perfdata (1=up, 0=down)
            my $link_value = ($link_status eq 'LinkUp') ? 1 : 0;
            $self->{output}->perfdata_add(
                nlabel => 'hardware.nic.port.link.status',
                instances => [$adapter_name, $port_name],
                value => $link_value,
                min => 0,
                max => 1
            );
        }
        
        # Check for NetworkPorts (Redfish standard)
        if (defined($adapter->{_network_ports}) && ref($adapter->{_network_ports}) eq 'ARRAY') {
            foreach my $port (@{$adapter->{_network_ports}}) {
                my $port_id = defined($port->{Id}) ? $port->{Id} : 'unknown';
                my $port_name = defined($port->{Name}) ? $port->{Name} : 'Port' . $port_id;
                
                my $link_status = defined($port->{LinkStatus}) ? $port->{LinkStatus} : 'n/a';
                my $speed_mbps = defined($port->{CurrentLinkSpeedMbps}) ? $port->{CurrentLinkSpeedMbps} : 0;
                
                $self->{output}->output_add(
                    long_msg => sprintf(
                        "  network port '%s' link is '%s' [speed: %s Mbps]",
                        $port_name, $link_status, $speed_mbps
                    )
                );
                
                if ($speed_mbps > 0) {
                    $self->{output}->perfdata_add(
                        nlabel => 'hardware.nic.port.speed.mbps',
                        unit => 'Mbps',
                        instances => [$adapter_name, $port_name],
                        value => $speed_mbps,
                        min => 0
                    );
                }
            }
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check network adapter status, health and port information.
Monitors NetworkAdapters and their NetworkPorts/NetworkDeviceFunctions
for adapter state, port link status and speed.

=head2 Redfish Endpoint

/redfish/v1/Chassis/{ChassisId}/NetworkAdapters/{AdapterId}

=head2 Perfdata

hardware.nic.port.speed.mbps : Port speed in Mbps
hardware.nic.port.link.status : Port link status (1=LinkUp, 0=other)
hardware.nic.ports.total.count : Total ports per adapter
hardware.nic.ports.up.count : Ports with LinkUp status per adapter

=cut
