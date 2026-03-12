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

package hardware::sensors::enoc::snmp::mode::system;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

my $mapping = {
    sysDescr    => { oid => '.1.3.6.1.2.1.1.1' },
    sysName     => { oid => '.1.3.6.1.2.1.1.5' },
    sysLocation => { oid => '.1.3.6.1.2.1.1.6' },
    sysContact  => { oid => '.1.3.6.1.2.1.1.4' },
};

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'system', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{system} = [
        { label => 'sysdesc', display_ok => 1, set => {
                key_values      => [ { name => 'sysDescr' } ],
                output_template => 'Description: %s',
                perfdatas       => [],
            }
        },
        { label => 'sysname', display_ok => 1, set => {
                key_values      => [ { name => 'sysName' } ],
                output_template => 'Name: %s',
                perfdatas       => [],
            }
        },
        { label => 'syslocation', display_ok => 1, set => {
                key_values      => [ { name => 'sysLocation' } ],
                output_template => 'Location: %s',
                perfdatas       => [],
            }
        },
        { label => 'syscontact', display_ok => 1, set => {
                key_values      => [ { name => 'sysContact' } ],
                output_template => 'Contact: %s',
                perfdatas       => [],
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids         => [ map { $_->{oid} . '.0' } values(%$mapping) ],
        nothing_quit => 1
    );

    my $result = $options{snmp}->map_instance(
        mapping  => $mapping,
        results  => $snmp_result,
        instance => '0'
    );

    $self->{system} = {
        sysDescr    => $result->{sysDescr}    // '',
        sysName     => $result->{sysName}     // '',
        sysLocation => $result->{sysLocation} // '',
        sysContact  => $result->{sysContact}  // '',
    };
}

1;

__END__

=head1 MODE

Toon systeem informatie van het ENOC EPB toestel (sysDescr, sysName, sysLocation, sysContact).

=over 8

=item B<--warning-sysdesc>

Warning drempel voor de systeem beschrijving.

=item B<--critical-sysdesc>

Critical drempel voor de systeem beschrijving.

=back

=head1 AUTHOR

Centreon (http://www.centreon.com/)

=head1 LICENSE

Licensed under the Apache License, Version 2.0.
See http://www.apache.org/licenses/LICENSE-2.0

=cut
