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

package storage::hp::msa2000::ssh::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{modes} = {
        'controllers'       => 'storage::hp::msa2000::ssh::mode::controllers',
        'disk-groups'       => 'storage::hp::msa2000::ssh::mode::diskgroups',
        'disks'             => 'storage::hp::msa2000::ssh::mode::disks',
        'enclosures'        => 'storage::hp::msa2000::ssh::mode::enclosures',
        'fans'              => 'storage::hp::msa2000::ssh::mode::fans',
        'ntp-status'        => 'storage::hp::msa2000::ssh::mode::ntpstatus',
        'pools'             => 'storage::hp::msa2000::ssh::mode::pools',
        'ports'             => 'storage::hp::msa2000::ssh::mode::ports',
        'psu'               => 'storage::hp::msa2000::ssh::mode::powersupplies',
        'redundancy'        => 'storage::hp::msa2000::ssh::mode::redundancy',
        'sensors'           => 'storage::hp::msa2000::ssh::mode::sensors',
        'shutdown-status'   => 'storage::hp::msa2000::ssh::mode::shutdownstatus',
        'system'            => 'storage::hp::msa2000::ssh::mode::system',
        'uptime'            => 'storage::hp::msa2000::ssh::mode::uptime',
        'versions'          => 'storage::hp::msa2000::ssh::mode::versions',
        'volumes'           => 'storage::hp::msa2000::ssh::mode::volumes',
    };

    $self->{custom_modes}->{ssh} = 'storage::hp::msa2000::ssh::custom::custom';
    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check HPE MSA 2060 storage array via SSH.
The MSA 2060 CLI returns XML output which is parsed by this plugin.

=cut
