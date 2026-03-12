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

package network::paloalto::snmp::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_snmp);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';
    $self->{modes} = {
        # --- Existing modes (with fixes applied) ---
        'cluster-status'         => 'network::paloalto::snmp::mode::clusterstatus',
        'cpu'                    => 'network::paloalto::snmp::mode::cpu',
        'gp-usage'               => 'network::paloalto::snmp::mode::gpusage',
        'hardware'               => 'snmp_standard::mode::hardwaredevice',
        'interfaces'             => 'snmp_standard::mode::interfaces',
        'list-interfaces'        => 'snmp_standard::mode::listinterfaces',
        'memory'                 => 'network::paloalto::snmp::mode::memory',
        'panorama'               => 'network::paloalto::snmp::mode::panorama',
        'sessions'               => 'network::paloalto::snmp::mode::sessions',
        'signatures'             => 'network::paloalto::snmp::mode::signatures',
        # --- New modes (PAN-COMMON-MIB) ---
        'cps'                    => 'network::paloalto::snmp::mode::cps',
        'device-logging'         => 'network::paloalto::snmp::mode::devicelogging',
        'dos-counters'           => 'network::paloalto::snmp::mode::doscounters',
        'drop-counters'          => 'network::paloalto::snmp::mode::dropcounters',
        'ha-cluster'             => 'network::paloalto::snmp::mode::hacluster',
        'interface-utilization'  => 'network::paloalto::snmp::mode::interfaceutilization',
        'pa-cluster'             => 'network::paloalto::snmp::mode::pacluster',
        'packet-broker'          => 'network::paloalto::snmp::mode::packetbroker',
        'pan-storage'            => 'network::paloalto::snmp::mode::panstorage',
        'system-info'            => 'network::paloalto::snmp::mode::systeminfo',
        'tcp-stats'              => 'network::paloalto::snmp::mode::tcpstats',
        'tunnel-stats'           => 'network::paloalto::snmp::mode::tunnelstats',
        'wildfire-monitor'       => 'network::paloalto::snmp::mode::wildfiremonitor',
        # --- New modes (PAN-ENTITY-EXT-MIB) ---
        'entity-power'           => 'network::paloalto::snmp::mode::entitypower',
        # --- New modes (PAN-LC-MIB) ---
        'log-collector'          => 'network::paloalto::snmp::mode::logcollector'
    };

    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check Palo Alto Networks equipment via SNMP.

Supported MIBs: PAN-COMMON-MIB, PAN-ENTITY-EXT-MIB, PAN-LC-MIB,
HOST-RESOURCES-MIB, IF-MIB.

=over 8

=item B<Existing modes>

cluster-status, cpu, gp-usage, hardware, interfaces, list-interfaces,
memory, panorama, sessions, signatures.

=item B<New modes (PAN-COMMON-MIB)>

cps, device-logging, dos-counters, drop-counters, ha-cluster,
interface-utilization, pa-cluster, packet-broker, pan-storage,
system-info, tcp-stats, tunnel-stats, wildfire-monitor.

=item B<New modes (PAN-ENTITY-EXT-MIB)>

entity-power.

=item B<New modes (PAN-LC-MIB)>

log-collector.

=back

=cut
