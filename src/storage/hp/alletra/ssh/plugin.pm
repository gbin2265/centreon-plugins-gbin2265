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

package storage::hp::alletra::ssh::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_custom);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{modes} = {
        'cage'        => 'storage::hp::alletra::ssh::mode::showcage',
        'checkhealth' => 'storage::hp::alletra::ssh::mode::checkhealth',
        'date'        => 'storage::hp::alletra::ssh::mode::showdate',
        'maint'       => 'storage::hp::alletra::ssh::mode::showmaint',
        'node'        => 'storage::hp::alletra::ssh::mode::shownode',
        'pd'          => 'storage::hp::alletra::ssh::mode::showpd',
        'port'        => 'storage::hp::alletra::ssh::mode::showport',
        'stat'        => 'storage::hp::alletra::ssh::mode::stat',
        'switch'      => 'storage::hp::alletra::ssh::mode::showswitch',
        'vv'          => 'storage::hp::alletra::ssh::mode::showvv'
    };

    $self->{custom_modes}->{ssh} = 'storage::hp::alletra::ssh::custom::custom';
    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check HPE Alletra MP / Alletra 9000 storage systems through SSH.

=cut
