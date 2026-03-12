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

package hardware::ups::powerware::snmp::mode::upsinfo;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "manufacturer: '%s', model: '%s', firmware: '%s', agent: '%s', serial: '%s'",
        $self->{result_values}->{manufacturer},
        $self->{result_values}->{model},
        $self->{result_values}->{firmware},
        $self->{result_values}->{agent_version},
        $self->{result_values}->{serial}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
    ];

    $self->{maps_counters}->{global} = [
        { label => 'status', threshold => 0, set => {
                key_values => [
                    { name => 'manufacturer' },
                    { name => 'model' },
                    { name => 'firmware' },
                    { name => 'agent_version' },
                    { name => 'serial' },
                ],
                closure_custom_calc => \&catalog_status_calc,
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => sub { return 'OK'; }
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

my $mapping = {
    xupsMfgName              => { oid => '.1.3.6.1.4.1.534.1.1.1' },
    xupsMfgModel             => { oid => '.1.3.6.1.4.1.534.1.1.2' },
    xupsMfgFirmwareVersion   => { oid => '.1.3.6.1.4.1.534.1.1.3' },
    xupsAgentSoftwareVersion => { oid => '.1.3.6.1.4.1.534.1.1.4' },
    xupsDescription          => { oid => '.1.3.6.1.4.1.534.1.1.5' },
};

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [ map { $_->{oid} . '.0' } values(%$mapping) ],
        nothing_quit => 1
    );

    my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');

    $self->{global} = {
        manufacturer  => defined($result->{xupsMfgName})              && $result->{xupsMfgName}              ne '' ? $result->{xupsMfgName}              : 'N/A',
        model         => defined($result->{xupsMfgModel})             && $result->{xupsMfgModel}             ne '' ? $result->{xupsMfgModel}             : 'N/A',
        firmware      => defined($result->{xupsMfgFirmwareVersion})   && $result->{xupsMfgFirmwareVersion}   ne '' ? $result->{xupsMfgFirmwareVersion}   : 'N/A',
        agent_version => defined($result->{xupsAgentSoftwareVersion}) && $result->{xupsAgentSoftwareVersion} ne '' ? $result->{xupsAgentSoftwareVersion} : 'N/A',
        serial        => defined($result->{xupsDescription})          && $result->{xupsDescription}          ne '' ? $result->{xupsDescription}          : 'N/A',
    };
}

1;

__END__

=head1 MODE

Check UPS identity information: manufacturer, model, firmware version,
agent software version and serial/description (XUPS-MIB).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='status'

=back

=cut
