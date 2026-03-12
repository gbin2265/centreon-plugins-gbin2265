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

package hardware::server::dell::idrac::restapi::mode::hardware;

use base qw(centreon::plugins::templates::hardware);

use strict;
use warnings;

sub set_system {
    my ($self, %options) = @_;

    $self->{regexp_threshold_numeric_check_section_option} = '^(?:fan|temperature|psu|voltage|drive)$';

    $self->{cb_hook2} = 'execute_custom';

    $self->{thresholds} = {
        status => [
            ['ok', 'OK'],
            ['warning', 'WARNING'],
            ['critical', 'CRITICAL'],
            ['n/a', 'OK']
        ],
        state => [
            # Redfish Resource.State enum:
            # absent, deferring, disabled, enabled,
            #    inTest, quiesced, standbyOffline, standbySpare,
            #    starting, unavailableOffline, updating
            ['updating', 'WARNING'],
            ['.*', 'OK']
        ]
    };

    $self->{components_exec_load} = 0;

    $self->{components_path} = 'hardware::server::dell::idrac::restapi::mode::components';
    $self->{components_module} = ['battery', 'drive', 'fan', 'memory', 'processor', 'psu', 'sc', 'system', 'temperature', 'voltage', 'volume'];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, no_absent => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub execute_custom {
    my ($self, %options) = @_;

    $self->{custom} = $options{custom};
}

sub get_thermal {
    my ($self, %options) = @_;

    if (!defined($self->{thermal})) {
        $self->{thermal} = $self->{custom}->request_api(
            endpoint => '/redfish/v1/Chassis/System.Embedded.1/Thermal',
            ignore_error => 1
        ) // {};
    }
    return $self->{thermal};
}

sub get_power {
    my ($self, %options) = @_;

    if (!defined($self->{power_data})) {
        $self->{power_data} = $self->{custom}->request_api(
            endpoint => '/redfish/v1/Chassis/System.Embedded.1/Power',
            ignore_error => 1
        ) // {};
    }
    return $self->{power_data};
}

sub get_storages {
    my ($self, %options) = @_;

    if (!defined($self->{storages})) {
        $self->{storages} = [];
        my $result = $self->{custom}->request_api(
            endpoint => '/redfish/v1/Systems/System.Embedded.1/Storage',
            ignore_error => 1
        );
        return $self->{storages} if (!defined($result) || !defined($result->{Members}));

        foreach my $member (@{$result->{Members}}) {
            next if (!defined($member->{'@odata.id'}));
            my $storage = $self->{custom}->request_api(
                endpoint => $member->{'@odata.id'},
                ignore_error => 1
            );
            push @{$self->{storages}}, $storage if defined($storage);
        }
    }
    return $self->{storages};
}

sub get_drive {
    my ($self, %options) = @_;

    return {} if (!defined($options{drive}->{'@odata.id'}));
    return $self->{custom}->request_api(
        endpoint => $options{drive}->{'@odata.id'},
        ignore_error => 1
    ) // {};
}

sub get_volumes {
    my ($self, %options) = @_;

    return [] if (!defined($options{storage}->{Volumes}) || !defined($options{storage}->{Volumes}->{'@odata.id'}));

    my $vol_list = $self->{custom}->request_api(
        endpoint => $options{storage}->{Volumes}->{'@odata.id'},
        ignore_error => 1
    );
    return [] if (!defined($vol_list) || !defined($vol_list->{Members}));

    my $result = [];
    foreach my $vol_member (@{$vol_list->{Members}}) {
        next if (!defined($vol_member->{'@odata.id'}));
        my $volume = $self->{custom}->request_api(
            endpoint => $vol_member->{'@odata.id'},
            ignore_error => 1
        );
        push @$result, $volume if defined($volume);
    }
    return $result;
}

sub get_sensors {
    my ($self, %options) = @_;

    if (!defined($self->{sensors_data})) {
        $self->{sensors_data} = [];
        my $result = $self->{custom}->request_api(
            endpoint => '/redfish/v1/Chassis/System.Embedded.1/Sensors',
            ignore_error => 1
        );
        return $self->{sensors_data} if (!defined($result) || !defined($result->{Members}));

        foreach my $member (@{$result->{Members}}) {
            next if (!defined($member->{'@odata.id'}));
            my $sensor = $self->{custom}->request_api(
                endpoint => $member->{'@odata.id'},
                ignore_error => 1
            );
            push @{$self->{sensors_data}}, $sensor if defined($sensor);
        }
    }
    return $self->{sensors_data};
}

sub get_memory {
    my ($self, %options) = @_;

    if (!defined($self->{memory_data})) {
        $self->{memory_data} = [];
        my $result = $self->{custom}->request_api(
            endpoint => '/redfish/v1/Systems/System.Embedded.1/Memory',
            ignore_error => 1
        );
        return $self->{memory_data} if (!defined($result) || !defined($result->{Members}));

        foreach my $member (@{$result->{Members}}) {
            next if (!defined($member->{'@odata.id'}));
            my $dimm = $self->{custom}->request_api(
                endpoint => $member->{'@odata.id'},
                ignore_error => 1
            );
            push @{$self->{memory_data}}, $dimm if defined($dimm);
        }
    }
    return $self->{memory_data};
}

sub get_processors {
    my ($self, %options) = @_;

    if (!defined($self->{processors_data})) {
        $self->{processors_data} = [];
        my $result = $self->{custom}->request_api(
            endpoint => '/redfish/v1/Systems/System.Embedded.1/Processors',
            ignore_error => 1
        );
        return $self->{processors_data} if (!defined($result) || !defined($result->{Members}));

        foreach my $member (@{$result->{Members}}) {
            next if (!defined($member->{'@odata.id'}));
            my $cpu = $self->{custom}->request_api(
                endpoint => $member->{'@odata.id'},
                ignore_error => 1
            );
            push @{$self->{processors_data}}, $cpu if defined($cpu);
        }
    }
    return $self->{processors_data};
}

sub get_system_info {
    my ($self, %options) = @_;

    if (!defined($self->{system_info})) {
        $self->{system_info} = $self->{custom}->request_api(
            endpoint => '/redfish/v1/Systems/System.Embedded.1',
            ignore_error => 1
        );
    }
    return $self->{system_info};
}

sub get_manager_info {
    my ($self, %options) = @_;

    if (!defined($self->{manager_info})) {
        $self->{manager_info} = $self->{custom}->request_api(
            endpoint => '/redfish/v1/Managers/iDRAC.Embedded.1',
            ignore_error => 1
        );
    }
    return $self->{manager_info};
}

1;

__END__

=head1 MODE

Check hardware components.

=over 8

=item B<--component>

Which component to check (default: '.*').
Can be: 'battery', 'drive', 'fan', 'memory', 'processor', 'psu', 'sc', 'system', 'temperature', 'voltage', 'volume'.

=item B<--filter>

Exclude some parts (comma separated list).
You can also exclude items from specific instances: --filter='fan,Fan.Embedded.1'

=item B<--absent-problem>

Return an error if a component is not 'present' (default is skipping).
It can be set globally or for a specific instance: --absent-problem='drive' or --absent-problem='drive,Disk.Bay.0:Enclosure.Internal.0-1:RAID.Integrated.1-1'.

=item B<--no-component>

Define the expected status if no components are found (default: critical).

=item B<--threshold-overload>

Use this option to override the status returned by the plugin when the status label matches a regular expression (syntax: section,[instance,]status,regexp).
Example: --threshold-overload='drive.state,WARNING,inTest'

=item B<--warning>

Set warning threshold for 'temperature', 'fan', 'psu', 'voltage', 'drive' (syntax: type,regexp,threshold).
Example: --warning='temperature,.*,30'

=item B<--critical>

Set critical threshold for 'temperature', 'fan', 'psu', 'voltage', 'drive' (syntax: type,regexp,threshold).
Example: --critical='temperature,.*,50'

=item B<--warning-count-*>

Define the warning threshold for the number of components of one type (replace '*' with the component type).

=item B<--critical-count-*>

Define the critical threshold for the number of components of one type (replace '*' with the component type).

=back

=cut
