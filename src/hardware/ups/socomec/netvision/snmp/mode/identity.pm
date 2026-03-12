#
# Copyright 2026 Centreon (http://www.centreon.com/)
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

package hardware::ups::socomec::netvision::snmp::mode::identity;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_identity_output {
    my ($self, %options) = @_;

    my $out = sprintf(
        "manufacturer: '%s', model: '%s', firmware: '%s', agent firmware: '%s', name: '%s', attached devices: '%s'",
        $self->{result_values}->{manufacturer},
        $self->{result_values}->{model},
        $self->{result_values}->{firmware},
        $self->{result_values}->{agent_firmware},
        $self->{result_values}->{name},
        $self->{result_values}->{attached_devices}
    );
    # NV7 extra fields
    $out .= sprintf(", contact: '%s'", $self->{result_values}->{contact})
        if (defined($self->{result_values}->{contact}) && $self->{result_values}->{contact} ne 'n/a');
    $out .= sprintf(", location: '%s'", $self->{result_values}->{location})
        if (defined($self->{result_values}->{location}) && $self->{result_values}->{location} ne 'n/a');
    return $out;
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'identity',
            type  => 2,
            set   => {
                key_values => [
                    { name => 'manufacturer'     },
                    { name => 'model'            },
                    { name => 'firmware'         },
                    { name => 'agent_firmware'   },
                    { name => 'name'             },
                    { name => 'attached_devices' },
                    { name => 'contact'          },
                    { name => 'location'         }
                ],
                closure_custom_output   => $self->can('custom_identity_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => sub {
                    my ($self, %options) = @_;
                    return $self->{perfdata}->threshold_check(
                        value     => 0,
                        threshold => [
                            { label => 'critical-identity', exit_litteral => 'critical' },
                            { label => 'warning-identity',  exit_litteral => 'warning'  },
                        ]
                    );
                }
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {});
    return $self;
}

# NV5 mapping: fields 1-6 (classic layout)
my $mapping_nv5 = {
    manufacturer     => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.1.1' }, # upsIdentManufacturer
    model            => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.1.2' }, # upsIdentModel
    firmware         => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.1.3' }, # upsIdentUPSSoftwareVersion
    agent_firmware   => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.1.4' }, # upsIdentAgentSoftwareVersion
    name             => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.1.5' }, # upsIdentName
    attached_devices => { oid => '.1.3.6.1.4.1.4555.1.1.1.1.1.6' }, # upsIdentAttachedDevices
};

# NV6 mapping: same structure as NV5
my $mapping_nv6 = {
    manufacturer     => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.1.1' },
    model            => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.1.2' },
    firmware         => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.1.3' },
    agent_firmware   => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.1.4' },
    name             => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.1.5' },
    attached_devices => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.1.6' },
    contact          => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.1.7' }, # NV7: contact person
    location         => { oid => '.1.3.6.1.4.1.4555.1.1.7.1.1.8' }, # NV7: location
};

sub _val {
    my ($r, $k) = @_;
    return (defined($r->{$k}) && $r->{$k} ne '') ? $r->{$k} : 'n/a';
}

sub manage_selection {
    my ($self, %options) = @_;

    # Try NV6/NV7 first (richer mapping)
    my $snmp_result = $options{snmp}->get_leef(
        oids => [ map($_->{oid} . '.0', values(%{$mapping_nv6})) ]
    );

    my ($label, $mapping);
    if (defined($snmp_result->{ $mapping_nv6->{manufacturer}->{oid} . '.0' }) &&
        $snmp_result->{ $mapping_nv6->{manufacturer}->{oid} . '.0' } ne '') {
        $label   = 'netvision6/7';
        $mapping = $mapping_nv6;
    } else {
        $label   = 'netvision5';
        $mapping = $mapping_nv5;
        $snmp_result = $options{snmp}->get_leef(
            oids         => [ map($_->{oid} . '.0', values(%{$mapping})) ],
            nothing_quit => 1
        );
    }

    my $r = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => 0);

    # NV7 quirk: fields are shifted vs NV6
    # .1=manufacturer .2=serial .3=empty .4=empty .5=firmware .6=name .7=contact .8=location
    # Detect by checking if .3 (firmware) is empty and .5 has content
    my $is_nv7 = ($label eq 'netvision6/7' &&
                  (!defined($r->{firmware}) || $r->{firmware} eq '') &&
                  defined($r->{name}) && $r->{name} ne '');

    if ($is_nv7) {
        # Remap: serial is in .2, firmware is in .5 (name slot), name is in .6 (attached_devices slot)
        $r->{serial}          = _val($r, 'model');        # .2 = serial number
        $r->{firmware}        = _val($r, 'name');         # .5 = firmware
        $r->{name}            = _val($r, 'attached_devices'); # .6 = UPS name
        $r->{attached_devices} = 'n/a';
        $r->{model}           = 'n/a';
        $r->{agent_firmware}  = 'n/a';
    }

    $self->{global} = {
        manufacturer     => _val($r, 'manufacturer'),
        model            => _val($r, 'model'),
        firmware         => _val($r, 'firmware'),
        agent_firmware   => _val($r, 'agent_firmware'),
        name             => _val($r, 'name'),
        attached_devices => _val($r, 'attached_devices'),
        contact          => _val($r, 'contact'),
        location         => _val($r, 'location'),
    };
}

1;

__END__

=head1 MODE

Check UPS identity information.

Works with Net Vision 5, 6 and 7.
Net Vision 7 exposes additional fields: contact person and location.

=over 8

=item B<--warning-identity> B<--critical-identity>

Define the conditions to match for the status to be WARNING or CRITICAL.
You can use the following variables: %{manufacturer}, %{model},
%{firmware}, %{agent_firmware}, %{name}, %{attached_devices},
%{contact} (NV7 only), %{location} (NV7 only).

=back

=cut
