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

package network::brocade::restapi::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';
    $self->{modes} = {
        'access-gateway'   => 'network::brocade::restapi::mode::accessgateway',
        'blade'            => 'network::brocade::restapi::mode::blade',
        'blade-statistics' => 'network::brocade::restapi::mode::bladestatistics',
        'cpu'              => 'network::brocade::restapi::mode::cpu',
        'credit-recovery'  => 'network::brocade::restapi::mode::creditrecovery',
        'diagnostics'      => 'network::brocade::restapi::mode::diagnostics',
        'extension-tunnel' => 'network::brocade::restapi::mode::extensiontunnel',
        'fabric'           => 'network::brocade::restapi::mode::fabric',
        'fcports'          => 'network::brocade::restapi::mode::fcports',
        'fcr-routing'      => 'network::brocade::restapi::mode::fcrrouting',
        'fdmi'             => 'network::brocade::restapi::mode::fdmi',
        'firmware'         => 'network::brocade::restapi::mode::firmware',
        'ha-status'        => 'network::brocade::restapi::mode::hastatus',
        'hardware'         => 'network::brocade::restapi::mode::hardware',
        'isl'              => 'network::brocade::restapi::mode::isl',
        'license'          => 'network::brocade::restapi::mode::license',
        'list-fcports'     => 'network::brocade::restapi::mode::listfcports',
        'lldp'             => 'network::brocade::restapi::mode::lldp',
        'logical-switch'   => 'network::brocade::restapi::mode::logicalswitch',
        'memory'           => 'network::brocade::restapi::mode::memory',
        'name-server'      => 'network::brocade::restapi::mode::nameserver',
        'ntp'              => 'network::brocade::restapi::mode::ntp',
        'security-certificates' => 'network::brocade::restapi::mode::securitycertificates',
        'sfp'              => 'network::brocade::restapi::mode::sfp',
        'switch-status'    => 'network::brocade::restapi::mode::switchstatus',
        'trunk'            => 'network::brocade::restapi::mode::trunk',
        'uptime'           => 'network::brocade::restapi::mode::uptime',
        'zone'             => 'network::brocade::restapi::mode::zone'
    };

    $self->{custom_modes}->{api} = 'network::brocade::restapi::custom::api';

    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check Brocade Fibre Channel switches (X7 Directors and Gen7/Gen6 switches) using REST API.
Requires Fabric OS 8.2.1 or later.

=cut
