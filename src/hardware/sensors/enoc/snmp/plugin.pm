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

package hardware::sensors::enoc::snmp::plugin;

use strict;
use warnings;
use base qw(centreon::plugins::script_snmp);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $self->{version} = '1.0';
    %{$self->{modes}} = (
        'sensors' => 'hardware::sensors::enoc::snmp::mode::sensors',
        'power'   => 'hardware::sensors::enoc::snmp::mode::power',
        'uptime'  => 'hardware::sensors::enoc::snmp::mode::uptime',
        'system'  => 'hardware::sensors::enoc::snmp::mode::system',
    );

    return $self;
}

1;

__END__

=head1 PLUGIN DESCRIPTION

Check ENOC EPB environmental monitoring devices via SNMP (enterprise OID 1.3.6.1.4.1.30966).

=head1 SYNOPSIS

    perl centreon_plugins.pl --plugin=hardware::sensors::enoc::snmp::plugin
        --mode=<mode> --hostname=<hostname> --snmp-community=<community>

=head1 MODES

=over 8

=item B<sensors>

Check temperature and humidity sensors (F<hardware::sensors::enoc::snmp::mode::sensors>).

=item B<power>

Check voltage, current and energy measurements (F<hardware::sensors::enoc::snmp::mode::power>).

=item B<uptime>

Check system uptime (F<hardware::sensors::enoc::snmp::mode::uptime>).

=item B<system>

Show system information: sysDescr, sysName, sysLocation, sysContact (F<hardware::sensors::enoc::snmp::mode::system>).

=back

=head1 AUTHOR

Centreon (http://www.centreon.com/)

=head1 LICENSE

Licensed under the Apache License, Version 2.0.
See http://www.apache.org/licenses/LICENSE-2.0

=cut
