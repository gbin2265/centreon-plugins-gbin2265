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

package hardware::server::dell::idrac::restapi::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{modes} = {
        'eventlog'      => 'hardware::server::dell::idrac::restapi::mode::eventlog',
        'firmware'      => 'hardware::server::dell::idrac::restapi::mode::firmware',
        'hardware'      => 'hardware::server::dell::idrac::restapi::mode::hardware',
        'interfaces'    => 'hardware::server::dell::idrac::restapi::mode::interfaces',
        'license'       => 'hardware::server::dell::idrac::restapi::mode::license',
        'manager'       => 'hardware::server::dell::idrac::restapi::mode::manager',
        'power'         => 'hardware::server::dell::idrac::restapi::mode::power',
        'system'        => 'hardware::server::dell::idrac::restapi::mode::system',
        'usage'         => 'hardware::server::dell::idrac::restapi::mode::usage'
    };

    $self->{custom_modes}->{api} = 'hardware::server::dell::idrac::restapi::custom::api';

    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check Dell iDRAC hardware and system status through the Redfish REST API.

The 'hardware' mode checks physical components: battery, drive, fan, memory,
processor, psu, sc (storage controllers), temperature, voltage, volume.
Use --component to select specific components.

Standalone modes: eventlog, firmware, interfaces, license, manager, power, system, usage.

=cut
