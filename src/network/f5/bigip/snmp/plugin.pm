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

package network::f5::bigip::snmp::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_snmp);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{modes} = {
        # --- Existing modes ---
        'apm'                    => 'network::f5::bigip::snmp::mode::apm',
        'connections'            => 'network::f5::bigip::snmp::mode::connections',
        'failover'               => 'network::f5::bigip::snmp::mode::failover',
        'hardware'               => 'network::f5::bigip::snmp::mode::hardware',
        'list-nodes'             => 'network::f5::bigip::snmp::mode::listnodes',
        'list-pools'             => 'network::f5::bigip::snmp::mode::listpools',
        'list-trunks'            => 'network::f5::bigip::snmp::mode::listtrunks',
        'list-virtualservers'    => 'network::f5::bigip::snmp::mode::listvirtualservers',
        'node-status'            => 'network::f5::bigip::snmp::mode::nodestatus',
        'pool-status'            => 'network::f5::bigip::snmp::mode::poolstatus',
        'tmm-usage'              => 'network::f5::bigip::snmp::mode::tmmusage',
        'cpu-usage'              => 'network::f5::bigip::snmp::mode::cpuusage',
        'trunks'                 => 'network::f5::bigip::snmp::mode::trunks',
        'virtualserver-status'   => 'network::f5::bigip::snmp::mode::virtualserverstatus',
        'virtualserver-tree'     => 'network::f5::bigip::snmp::mode::virtualservertree',
        'certificates'           => 'network::f5::bigip::snmp::mode::certificates',
        # --- New: high priority ---
        'memory-usage'           => 'network::f5::bigip::snmp::mode::memoryusage',
        'config-sync'            => 'network::f5::bigip::snmp::mode::configsync',
        'gtm-wideip-status'      => 'network::f5::bigip::snmp::mode::gtmwideipstatus',
        'gtm-pool-status'        => 'network::f5::bigip::snmp::mode::gtmpoolstatus',
        'list-wideips'           => 'network::f5::bigip::snmp::mode::listwideips',
        'load-usage'             => 'network::f5::bigip::snmp::mode::loadusage',
        'pool-member-status'      => 'network::f5::bigip::snmp::mode::poolmemberusage',
        'swap-usage'             => 'network::f5::bigip::snmp::mode::swapusage',
        'uptime'                 => 'network::f5::bigip::snmp::mode::uptime',
        # --- New: medium priority ---
        'irule-statistics'       => 'network::f5::bigip::snmp::mode::irulestatistics',
        'snat-usage'             => 'network::f5::bigip::snmp::mode::snatusage',
        'ha-status'              => 'network::f5::bigip::snmp::mode::hastatus',
        'interfaces'             => 'snmp_standard::mode::interfaces',
        'list-interfaces'        => 'snmp_standard::mode::listinterfaces',
        'list-gtm-pools'         => 'network::f5::bigip::snmp::mode::listgtmpools',
        # --- New: lower priority ---
        'vlan-statistics'        => 'network::f5::bigip::snmp::mode::vlanstatistics',
        'http-profile-stats'     => 'network::f5::bigip::snmp::mode::httpprofilestats',
    };

    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check F5 BIG-IP devices in SNMP.

Supports LTM (Local Traffic Manager), GTM (Global Traffic Manager / BIG-IP DNS),
APM (Access Policy Manager), hardware health, and system resources.

For standard interface checks (traffic, errors, status), use the snmp_standard
interfaces mode: --plugin=snmp_standard --mode=interfaces

=cut
