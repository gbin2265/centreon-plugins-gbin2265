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

package storage::scality::ring::plugin;
use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{modes} = {
        'cluster-status'    => 'storage::scality::ring::mode::clusterstatus',
        'ring-status'       => 'storage::scality::ring::mode::ringstatus',
        'ring-health'       => 'storage::scality::ring::mode::ringhealth',
        'node-status'       => 'storage::scality::ring::mode::nodestatus',
        'server-status'     => 'storage::scality::ring::mode::serverstatus',
        'storage-usage'     => 'storage::scality::ring::mode::storageusage',
        'connector-status'  => 'storage::scality::ring::mode::connectorstatus',
        'drive-status'      => 'storage::scality::ring::mode::drivestatus',
        'task-status'       => 'storage::scality::ring::mode::taskstatus',
    };

    $self->{custom_modes}->{api} = 'storage::scality::ring::custom::api';
    return $self;
}
1;

__END__

=head1 PLUGIN DESCRIPTION

Check Scality RING object storage using the Supervisor REST API (SupAPI).

Supports both Keycloak OAuth2 authentication (new installations) and
Basic authentication (older installations).

=cut
