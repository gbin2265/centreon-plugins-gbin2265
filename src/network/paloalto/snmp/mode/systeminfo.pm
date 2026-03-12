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

package network::paloalto::snmp::mode::systeminfo;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'system', type => 0, skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{system} = [
        { label => 'status', threshold => 0, set => {
                key_values => [
                    { name => 'sw_version' }, { name => 'hw_version' },
                    { name => 'serial' }, { name => 'ha_mode' },
                    { name => 'chassis_type' }, { name => 'app_version' },
                    { name => 'av_version' }, { name => 'threat_version' },
                    { name => 'wildfire_version' }, { name => 'url_filtering_version' },
                    { name => 'gp_client_version' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; }
            }
        }
    ];
}

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "Software: %s, Hardware: %s, Serial: %s, Chassis: %s, HA Mode: %s, App-ID: %s, AV: %s, Threat: %s, Wildfire: %s, URL Filtering: %s, GP Client: %s",
        $self->{result_values}->{sw_version},
        $self->{result_values}->{hw_version},
        $self->{result_values}->{serial},
        $self->{result_values}->{chassis_type},
        $self->{result_values}->{ha_mode},
        $self->{result_values}->{app_version},
        $self->{result_values}->{av_version},
        $self->{result_values}->{threat_version},
        $self->{result_values}->{wildfire_version},
        $self->{result_values}->{url_filtering_version},
        $self->{result_values}->{gp_client_version}
    );
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
    });

    return $self;
}

my $mapping = {
    sw_version            => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.1' },  # panSysSwVersion
    hw_version            => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.2' },  # panSysHwVersion
    serial                => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.3' },  # panSysSerialNumber
    app_version           => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.7' },  # panSysAppVersion
    av_version            => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.8' },  # panSysAvVersion
    threat_version        => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.9' },  # panSysThreatVersion
    url_filtering_version => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.10' }, # panSysUrlFilteringVersion
    ha_mode               => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.13' }, # panSysHAMode
    gp_client_version     => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.15' }, # panSysGlobalProtectClientVersion
    wildfire_version      => { oid => '.1.3.6.1.4.1.25461.2.1.2.1.17' }, # panSysWildfireVersion
    chassis_type          => { oid => '.1.3.6.1.4.1.25461.2.1.2.2.1' }   # panChassisType
};

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [ map($_->{oid} . '.0', values(%$mapping)) ],
        nothing_quit => 1
    );
    $self->{system} = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');
}

1;

__END__

=head1 MODE

Display system information (software/hardware version, serial number, content versions).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).

=back

=cut
