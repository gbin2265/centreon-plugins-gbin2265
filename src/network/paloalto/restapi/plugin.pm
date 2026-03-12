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

package network::paloalto::restapi::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{modes} = {
        'certificates'    => 'network::paloalto::restapi::mode::certificates',
        'environment'     => 'network::paloalto::restapi::mode::environment',
        'globalprotect'   => 'network::paloalto::restapi::mode::globalprotect',
        'ha'              => 'network::paloalto::restapi::mode::ha',
        'interfaces'      => 'network::paloalto::restapi::mode::interfaces',
        'ipsec'           => 'network::paloalto::restapi::mode::ipsec',
        'licenses'        => 'network::paloalto::restapi::mode::licenses',
        'list-interfaces' => 'network::paloalto::restapi::mode::listinterfaces',
        'list-ipsec'      => 'network::paloalto::restapi::mode::listipsec',
        'panorama'        => 'network::paloalto::restapi::mode::panorama',
        'sessions'        => 'network::paloalto::restapi::mode::sessions',
        'system'          => 'network::paloalto::restapi::mode::system',
        'threats'         => 'network::paloalto::restapi::mode::threats'
    };

    $self->{custom_modes}->{api} = 'network::paloalto::restapi::custom::api';
    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check Palo Alto firewall using PAN-OS XML API.

=cut
