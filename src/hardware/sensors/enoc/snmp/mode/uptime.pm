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

package hardware::sensors::enoc::snmp::mode::uptime;

use base qw(snmp_standard::mode::uptime);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    return $self;
}

1;

__END__

=head1 MODE

Controleer de uptime van het ENOC EPB toestel.

=over 8

=item B<--warning-uptime>

Warning drempel.

=item B<--critical-uptime>

Critical drempel.

=item B<--add-sysdesc>

Toon de systeem beschrijving (sysDescr).

=item B<--check-overload>

De uptime teller heeft een limiet van 4294967296 en kan overlopen.
Met deze optie wordt de terugkerende teller beheerd. Er is echter een kleine kans dat een herstart gemist wordt.

=item B<--reboot-window>

Te gebruiken met de check-overload optie. Tijd in milliseconden (standaard: 5000).
Een lagere waarde verkleint de kans om een herstart te missen.

=item B<--unit>

Selecteer de tijdseenheid voor de performancedata en drempelwaarden.
Mogelijke waarden: 's' (seconden), 'm' (minuten), 'h' (uren), 'd' (dagen), 'w' (weken).
Standaard is seconden.

=back

=head1 AUTHOR

Centreon (http://www.centreon.com/)

=head1 LICENSE

Licensed under the Apache License, Version 2.0.
See http://www.apache.org/licenses/LICENSE-2.0

=cut
