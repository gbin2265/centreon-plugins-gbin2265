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

package storage::hp::msa2000::restapi::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{modes} = {
        'controller'    => 'storage::hp::msa2000::restapi::mode::controller',
        'disk-group'    => 'storage::hp::msa2000::restapi::mode::diskgroup',
        'drive'         => 'storage::hp::msa2000::restapi::mode::drive',
        'drive-spare'   => 'storage::hp::msa2000::restapi::mode::drivespare',
        'enclosure'     => 'storage::hp::msa2000::restapi::mode::enclosure',
        'fan'           => 'storage::hp::msa2000::restapi::mode::fan',
        'fc-initiator'  => 'storage::hp::msa2000::restapi::mode::fcinitiator',
        'firmware'      => 'storage::hp::msa2000::restapi::mode::firmware',
        'interface'     => 'storage::hp::msa2000::restapi::mode::interface',
        'pool'          => 'storage::hp::msa2000::restapi::mode::pool',
        'port'          => 'storage::hp::msa2000::restapi::mode::port',
        'psu'           => 'storage::hp::msa2000::restapi::mode::psu',
        'storage-group' => 'storage::hp::msa2000::restapi::mode::storagegroup',
        'system-health' => 'storage::hp::msa2000::restapi::mode::systemhealth',
        'task'          => 'storage::hp::msa2000::restapi::mode::task',
        'temperature'   => 'storage::hp::msa2000::restapi::mode::temperature',
        'voltage'       => 'storage::hp::msa2000::restapi::mode::voltage',
        'volume'        => 'storage::hp::msa2000::restapi::mode::volume'
    };

    $self->{custom_modes}->{api} = 'storage::hp::msa2000::restapi::custom::api';
    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check HPE MSA 2000/2060/2062 storage systems using the Redfish REST API.

=cut
