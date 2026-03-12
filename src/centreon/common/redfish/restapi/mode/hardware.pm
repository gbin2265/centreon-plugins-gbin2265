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

package centreon::common::redfish::restapi::mode::hardware;

use base qw(centreon::plugins::templates::hardware);

use strict;
use warnings;

sub set_system {
    my ($self, %options) = @_;
        
    $self->{regexp_threshold_numeric_check_section_option} = '^(?:fan|temperature|psu|psu\.power|memory|manager|network|nic|nvme|firmware|cpu|cpu\.temperature|drive|drive\.lifeleft|volume|sc|system|smcdrive|smcdrive\.endurance|smcdrive\.temperature|smcldrive|smcenclosure|smcstorage|smcraid)$';

    $self->{cb_hook2} = 'execute_custom';

    $self->{thresholds} = {
        status => [
            ['ok', 'OK'],
            ['warning', 'WARNING'],
            ['critical', 'CRITICAL'],
            ['n/a', 'OK']
        ],
        state => [
            ['updating', 'WARNING'],
            ['.*', 'OK']
        ],
        'default.powerstate' => [
            ['On', 'OK'],
            ['.*', 'CRITICAL']
        ]
    };

    $self->{components_exec_load} = 0;

    $self->{components_path} = 'centreon::common::redfish::restapi::mode::components';
    $self->{components_module} = [
        'chassis', 'cpu', 'device', 'drive', 'fan', 'firmware', 'health', 'manager', 'memory', 
        'network', 'nic', 'nvme', 'powerstate', 'psu', 'sc', 'storage', 'system', 'temperature', 'volume',
        'smcstorage', 'smcdrive', 'smcldrive', 'smcenclosure', 'smcraid'
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, no_absent => 1, force_new_perfdata => 1);
    bless $self, $class;
    
    $options{options}->add_options(arguments => {});
    
    return $self;
}

sub get_power {
    my ($self, %options) = @_;

    return {} if (!defined($options{chassis}->{Power}->{'@odata.id'}));
    return $self->{custom}->request_api(url_path => $options{chassis}->{Power}->{'@odata.id'});
}

sub get_thermal {
    my ($self, %options) = @_;

    return {} if (!defined($options{chassis}->{Thermal}->{'@odata.id'}));
    return $self->{custom}->request_api(url_path => $options{chassis}->{Thermal}->{'@odata.id'});
}

sub get_devices {
    my ($self, %options) = @_;

    $self->get_chassis() if (!defined($self->{chassis}));
    foreach my $chassis (@{$self->{chassis}}) {
        $chassis->{Devices} = [];
        
        # Method 1: Try standard Redfish Devices link (iLO4 / other vendors)
        my $devices_path = undef;
        if (defined($chassis->{Links}) && defined($chassis->{Links}->{Devices})) {
            $devices_path = $chassis->{Links}->{Devices}->{'@odata.id'};
        }
        
        # Method 2: Try HPE OEM Devices link (iLO5+)
        if (!defined($devices_path) && defined($chassis->{Oem}) && defined($chassis->{Oem}->{Hpe}) &&
            defined($chassis->{Oem}->{Hpe}->{Links}) && defined($chassis->{Oem}->{Hpe}->{Links}->{Devices})) {
            $devices_path = $chassis->{Oem}->{Hpe}->{Links}->{Devices}->{'@odata.id'};
        }
        
        # Method 3: Try direct path as fallback
        if (!defined($devices_path)) {
            $devices_path = $chassis->{'@odata.id'} . '/Devices/';
        }
        
        my $result = $self->{custom}->request_api(
            url_path => $devices_path,
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        next if (!defined($result) || !defined($result->{Members}));

        foreach (@{$result->{Members}}) {
            my $device_detailed = $self->{custom}->request_api(
                url_path => $_->{'@odata.id'},
                ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
            );
            push @{$chassis->{Devices}}, $device_detailed if (defined($device_detailed));
        }
    }
}

sub get_chassis {
    my ($self, %options) = @_;

    $self->{chassis} = [];
    my $result = $self->{custom}->request_api(url_path => '/redfish/v1/chassis/');
    foreach (@{$result->{Members}}) {
        my $chassis_detailed = $self->{custom}->request_api(url_path => $_->{'@odata.id'});
        push @{$self->{chassis}}, $chassis_detailed;
    }
}

sub get_drive {
    my ($self, %options) = @_;

    return {} if (!defined($options{drive}->{'@odata.id'}));
    return $self->{custom}->request_api(url_path => $options{drive}->{'@odata.id'});
}

sub get_drive_metrics {
    my ($self, %options) = @_;

    return undef if (!defined($options{drive}));
    
    # Check if Metrics link exists
    if (defined($options{drive}->{Metrics}) && defined($options{drive}->{Metrics}->{'@odata.id'})) {
        return $self->{custom}->request_api(
            url_path => $options{drive}->{Metrics}->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
    }
    
    return undef;
}

sub get_volumes {
    my ($self, %options) = @_;

    return [] if (!defined($options{storage}->{Volumes}->{'@odata.id'}));

    my $volumes = $self->{custom}->request_api(url_path => $options{storage}->{Volumes}->{'@odata.id'});

    my $result = [];
    foreach my $volume (@{$volumes->{Members}}) {
        my $volume_detailed = $self->{custom}->request_api(url_path => $volume->{'@odata.id'});
        push @$result, $volume_detailed;
    }

    return $result;
}

sub get_storages {
    my ($self, %options) = @_;

    $self->{storages} = [];
    my $systems = $self->{custom}->request_api(url_path => '/redfish/v1/Systems');
    foreach my $system (@{$systems->{Members}}) {
        my $storages = $self->{custom}->request_api(
            url_path => $system->{'@odata.id'} . '/Storage/',
            ignore_codes => { 400 => 1, 404 => 1 }
        );
        next if (!defined($storages));

        foreach my $storage (@{$storages->{Members}}) {
            my $storage_detailed = $self->{custom}->request_api(url_path => $storage->{'@odata.id'});
            push @{$self->{storages}}, $storage_detailed;
        }
    }
}

sub get_systems {
    my ($self, %options) = @_;

    return if (defined($self->{systems}));
    
    $self->{systems} = [];
    
    my $result = $self->{custom}->request_api(
        url_path => '/redfish/v1/Systems',
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    
    return if (!defined($result) || !defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        
        my $system = $self->{custom}->request_api(
            url_path => $member->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        next if (!defined($system));
        
        push @{$self->{systems}}, $system;
    }
}

sub get_processors {
    my ($self, %options) = @_;

    return if (defined($self->{processors}));
    
    $self->{processors} = [];
    
    $self->get_systems() if (!defined($self->{systems}));
    return if (!defined($self->{systems}));

    foreach my $system (@{$self->{systems}}) {
        my $processors_path = $system->{'@odata.id'};
        $processors_path =~ s/\/$//;
        $processors_path .= '/Processors/';
        
        my $result = $self->{custom}->request_api(
            url_path => $processors_path,
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        
        next if (!defined($result) || !defined($result->{Members}));

        foreach my $member (@{$result->{Members}}) {
            next if (!defined($member->{'@odata.id'}));
            
            my $processor = $self->{custom}->request_api(
                url_path => $member->{'@odata.id'},
                ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
            );
            next if (!defined($processor));
            
            push @{$self->{processors}}, $processor;
        }
    }
}

sub get_smartstorage_controllers {
    my ($self, %options) = @_;

    return if (defined($self->{smartstorage_controllers}));
    
    $self->{smartstorage_controllers} = [];
    
    my $result = $self->{custom}->request_api(
        url_path => '/redfish/v1/Systems/1/SmartStorage/ArrayControllers/',
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    
    return if (!defined($result) || !defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        
        my $controller = $self->{custom}->request_api(
            url_path => $member->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        next if (!defined($controller));
        
        $controller->{_odata_id} = $member->{'@odata.id'};
        push @{$self->{smartstorage_controllers}}, $controller;
    }
}

sub get_smartstorage_diskdrives {
    my ($self, %options) = @_;

    return [] if (!defined($options{controller}->{_odata_id}));
    
    my $drives_path = $options{controller}->{_odata_id};
    $drives_path =~ s/\/$//;
    $drives_path .= '/DiskDrives/';
    
    my $result = $self->{custom}->request_api(
        url_path => $drives_path,
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    
    return [] if (!defined($result) || !defined($result->{Members}));

    my $drives = [];
    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        
        my $drive = $self->{custom}->request_api(
            url_path => $member->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        next if (!defined($drive));
        
        push @$drives, $drive;
    }
    
    return $drives;
}

sub get_smartstorage_logicaldrives {
    my ($self, %options) = @_;

    return [] if (!defined($options{controller}->{_odata_id}));
    
    my $ldrives_path = $options{controller}->{_odata_id};
    $ldrives_path =~ s/\/$//;
    $ldrives_path .= '/LogicalDrives/';
    
    my $result = $self->{custom}->request_api(
        url_path => $ldrives_path,
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    
    return [] if (!defined($result) || !defined($result->{Members}));

    my $ldrives = [];
    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        
        my $ldrive = $self->{custom}->request_api(
            url_path => $member->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        next if (!defined($ldrive));
        
        $ldrive->{_odata_id} = $member->{'@odata.id'};
        push @$ldrives, $ldrive;
    }
    
    return $ldrives;
}

sub get_smartstorage_enclosures {
    my ($self, %options) = @_;

    return [] if (!defined($options{controller}->{_odata_id}));
    
    my $enclosures_path = $options{controller}->{_odata_id};
    $enclosures_path =~ s/\/$//;
    $enclosures_path .= '/StorageEnclosures/';
    
    my $result = $self->{custom}->request_api(
        url_path => $enclosures_path,
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    
    return [] if (!defined($result) || !defined($result->{Members}));

    my $enclosures = [];
    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        
        my $enclosure = $self->{custom}->request_api(
            url_path => $member->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        next if (!defined($enclosure));
        
        push @$enclosures, $enclosure;
    }
    
    return $enclosures;
}

sub get_smartstorage_datadrives {
    my ($self, %options) = @_;

    return [] if (!defined($options{logicaldrive}->{_odata_id}));
    
    my $datadrives_path = $options{logicaldrive}->{_odata_id};
    $datadrives_path =~ s/\/$//;
    $datadrives_path .= '/DataDrives/';
    
    my $result = $self->{custom}->request_api(
        url_path => $datadrives_path,
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    
    return [] if (!defined($result) || !defined($result->{Members}));

    return $result->{Members};
}

sub get_cpu_temperatures {
    my ($self) = @_;
    
    my $cpu_temps = {};
    
    # Make sure we have thermal data
    $self->get_chassis() if (!defined($self->{chassis}));
    return $cpu_temps if (!defined($self->{chassis}));
    
    foreach my $chassis (@{$self->{chassis}}) {
        my $thermal = $self->get_thermal(chassis => $chassis);
        next if (!defined($thermal) || !defined($thermal->{Temperatures}));
        
        foreach my $temp (@{$thermal->{Temperatures}}) {
            # Match CPU temperature sensors (various naming conventions)
            my $temp_name = defined($temp->{Name}) ? $temp->{Name} : '';
            my $context = defined($temp->{PhysicalContext}) ? $temp->{PhysicalContext} : '';
            
            # Match CPU sensors by name or physical context
            if ($temp_name =~ /CPU\s*(\d+)/i || $temp_name =~ /Proc\s*(\d+)/i || $context eq 'CPU') {
                my $cpu_id = $1;
                # Try to extract CPU number from name
                if (!defined($cpu_id) && $temp_name =~ /(\d+)/) {
                    $cpu_id = $1;
                }
                $cpu_id = 1 if (!defined($cpu_id));
                
                # Skip absent CPUs
                my $state = defined($temp->{Status}->{State}) ? $temp->{Status}->{State} : '';
                next if ($state eq 'Absent');
                
                # Skip package temp sensors if we have direct CPU sensors
                next if ($temp_name =~ /PkgTmp/i && defined($cpu_temps->{$cpu_id}));
                
                $cpu_temps->{$cpu_id} = {
                    reading => $temp->{ReadingCelsius},
                    critical => $temp->{UpperThresholdCritical},
                    fatal => $temp->{UpperThresholdFatal}
                };
            }
        }
    }
    
    return $cpu_temps;
}

sub get_cpu_power_metrics {
    my ($self) = @_;
    
    my $cpu_power = {};
    
    # Make sure we have chassis/power data
    $self->get_chassis() if (!defined($self->{chassis}));
    return $cpu_power if (!defined($self->{chassis}));
    
    foreach my $chassis (@{$self->{chassis}}) {
        my $power = $self->get_power(chassis => $chassis);
        next if (!defined($power));
        
        # Check HPE OEM PowerMetric data (iLO6 style)
        if (defined($power->{Oem}) && defined($power->{Oem}->{Hpe})) {
            my $hpe = $power->{Oem}->{Hpe};
            
            if (defined($hpe->{PowerMetric})) {
                $cpu_power->{cpu_watts} = $hpe->{PowerMetric}->{CpuWatts}
                    if defined($hpe->{PowerMetric}->{CpuWatts});
                $cpu_power->{dimm_watts} = $hpe->{PowerMetric}->{DimmWatts}
                    if defined($hpe->{PowerMetric}->{DimmWatts});
                $cpu_power->{gpu_watts} = $hpe->{PowerMetric}->{GpuWatts}
                    if defined($hpe->{PowerMetric}->{GpuWatts});
            }
        }
        
        # Check PowerMeter link (iLO5 style with history)
        if (defined($power->{Oem}) && defined($power->{Oem}->{Hpe}) && 
            defined($power->{Oem}->{Hpe}->{Links}) && defined($power->{Oem}->{Hpe}->{Links}->{PowerMeter})) {
            my $meter_link = $power->{Oem}->{Hpe}->{Links}->{PowerMeter}->{'@odata.id'};
            if (defined($meter_link)) {
                my $meter = $self->{custom}->request_api(
                    url_path => $meter_link,
                    ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
                );
                if (defined($meter) && defined($meter->{PowerDetail}) && 
                    ref($meter->{PowerDetail}) eq 'ARRAY' && scalar(@{$meter->{PowerDetail}}) > 0) {
                    my $latest = $meter->{PowerDetail}->[-1];
                    $cpu_power->{cpu_watts} = $latest->{CpuWatts} if defined($latest->{CpuWatts});
                    $cpu_power->{dimm_watts} = $latest->{DimmWatts} if defined($latest->{DimmWatts});
                    $cpu_power->{gpu_watts} = $latest->{GpuWatts} if defined($latest->{GpuWatts});
                }
            }
        }
    }
    
    return $cpu_power;
}

sub execute_custom {
    my ($self, %options) = @_;

    $self->{custom} = $options{custom};
}

1;


sub get_memory {
    my ($self, %options) = @_;

    return if (defined($self->{memory}));
    $self->{memory} = [];
    
    $self->get_systems() if (!defined($self->{systems}));
    return if (!defined($self->{systems}));

    foreach my $system (@{$self->{systems}}) {
        my $memory_path = $system->{'@odata.id'} . '/Memory/';
        my $result = $self->{custom}->request_api(
            url_path => $memory_path,
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        next if (!defined($result) || !defined($result->{Members}));

        foreach my $member (@{$result->{Members}}) {
            next if (!defined($member->{'@odata.id'}));
            my $dimm = $self->{custom}->request_api(
                url_path => $member->{'@odata.id'},
                ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
            );
            push @{$self->{memory}}, $dimm if (defined($dimm));
        }
    }
}

sub get_network_interfaces {
    my ($self, %options) = @_;

    return if (defined($self->{network_interfaces}));
    $self->{network_interfaces} = [];
    
    $self->get_managers() if (!defined($self->{managers}));
    return if (!defined($self->{managers}));

    foreach my $manager (@{$self->{managers}}) {
        next if (!defined($manager->{EthernetInterfaces}));
        my $eth_path = $manager->{EthernetInterfaces}->{'@odata.id'};
        next if (!defined($eth_path));
        
        my $result = $self->{custom}->request_api(
            url_path => $eth_path,
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        next if (!defined($result) || !defined($result->{Members}));

        foreach my $member (@{$result->{Members}}) {
            next if (!defined($member->{'@odata.id'}));
            my $iface = $self->{custom}->request_api(
                url_path => $member->{'@odata.id'},
                ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
            );
            push @{$self->{network_interfaces}}, $iface if (defined($iface));
        }
    }
}

sub get_network_adapters {
    my ($self, %options) = @_;

    return if (defined($self->{network_adapters}));
    $self->{network_adapters} = [];
    
    $self->get_systems() if (!defined($self->{systems}));
    return if (!defined($self->{systems}));

    foreach my $system (@{$self->{systems}}) {
        # Try BaseNetworkAdapters (HPE)
        my $adapters_path = $system->{'@odata.id'} . '/BaseNetworkAdapters/';
        my $result = $self->{custom}->request_api(
            url_path => $adapters_path,
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        
        # Fallback to NetworkInterfaces (standard Redfish)
        if (!defined($result) || !defined($result->{Members})) {
            $adapters_path = $system->{'@odata.id'} . '/NetworkInterfaces/';
            $result = $self->{custom}->request_api(
                url_path => $adapters_path,
                ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
            );
        }
        next if (!defined($result) || !defined($result->{Members}));

        foreach my $member (@{$result->{Members}}) {
            next if (!defined($member->{'@odata.id'}));
            my $adapter = $self->{custom}->request_api(
                url_path => $member->{'@odata.id'},
                ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
            );
            push @{$self->{network_adapters}}, $adapter if (defined($adapter));
        }
    }
}

sub get_managers {
    my ($self, %options) = @_;

    return if (defined($self->{managers}));
    $self->{managers} = [];
    
    my $result = $self->{custom}->request_api(
        url_path => '/redfish/v1/Managers/',
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    return if (!defined($result) || !defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        my $manager = $self->{custom}->request_api(
            url_path => $member->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        push @{$self->{managers}}, $manager if (defined($manager));
    }
}

sub get_firmware_inventory {
    my ($self, %options) = @_;

    return if (defined($self->{firmware_inventory}));
    $self->{firmware_inventory} = [];
    
    my $result = $self->{custom}->request_api(
        url_path => '/redfish/v1/UpdateService/FirmwareInventory/',
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    return if (!defined($result) || !defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        my $fw = $self->{custom}->request_api(
            url_path => $member->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        push @{$self->{firmware_inventory}}, $fw if (defined($fw));
    }
}

sub get_memory_dimms {
    my ($self, %options) = @_;

    my $system = $options{system};
    my @dimms = ();
    
    return \@dimms if (!defined($system->{'@odata.id'}));
    
    my $memory_path = $system->{'@odata.id'} . '/Memory/';
    my $result = $self->{custom}->request_api(
        url_path => $memory_path,
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    return \@dimms if (!defined($result) || !defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        my $dimm = $self->{custom}->request_api(
            url_path => $member->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        push @dimms, $dimm if (defined($dimm));
    }
    
    return \@dimms;
}

sub get_ethernet_interfaces {
    my ($self, %options) = @_;

    my $parent = $options{parent};
    my $type = $options{type}; # 'manager' or 'system'
    my @interfaces = ();
    
    return \@interfaces if (!defined($parent->{'@odata.id'}));
    
    # Try EthernetInterfaces link first
    my $eth_path = undef;
    if (defined($parent->{EthernetInterfaces}) && defined($parent->{EthernetInterfaces}->{'@odata.id'})) {
        $eth_path = $parent->{EthernetInterfaces}->{'@odata.id'};
    } else {
        # Try direct path
        $eth_path = $parent->{'@odata.id'} . '/EthernetInterfaces/';
    }
    
    my $result = $self->{custom}->request_api(
        url_path => $eth_path,
        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
    );
    return \@interfaces if (!defined($result) || !defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        my $iface = $self->{custom}->request_api(
            url_path => $member->{'@odata.id'},
            ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
        );
        push @interfaces, $iface if (defined($iface));
    }
    
    return \@interfaces;
}

sub get_nvme_drives {
    my ($self, %options) = @_;

    return if (defined($self->{nvme_drives}));
    $self->{nvme_drives} = [];
    
    $self->get_storages() if (!defined($self->{storages}));
    return if (!defined($self->{storages}) || ref($self->{storages}) ne 'ARRAY');

    foreach my $storage (@{$self->{storages}}) {
        next if (!defined($storage->{Drives}));
        next if (ref($storage->{Drives}) ne 'ARRAY');
        
        foreach my $drive_ref (@{$storage->{Drives}}) {
            next if (!defined($drive_ref->{'@odata.id'}));
            
            my $drive = $self->{custom}->request_api(
                url_path => $drive_ref->{'@odata.id'},
                ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
            );
            next if (!defined($drive));
            
            # Check if it's an NVMe drive
            my $media_type = defined($drive->{MediaType}) ? $drive->{MediaType} : '';
            my $protocol = defined($drive->{Protocol}) ? $drive->{Protocol} : '';
            
            # Include NVMe drives or SSDs that might be NVMe
            next if ($protocol ne 'NVMe' && $media_type ne 'SSD' && $protocol ne 'PCIe');
            
            # Try to get metrics
            if (defined($drive->{'@odata.id'})) {
                my $metrics_path = $drive->{'@odata.id'} . '/Metrics';
                my $metrics = $self->{custom}->request_api(
                    url_path => $metrics_path,
                    ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
                );
                $drive->{_metrics} = $metrics if (defined($metrics));
            }
            
            push @{$self->{nvme_drives}}, $drive;
        }
    }
    
    # Also check Chassis for NVMe drives (some implementations)
    $self->get_chassis() if (!defined($self->{chassis}));
    return if (!defined($self->{chassis}) || ref($self->{chassis}) ne 'ARRAY');
    
    foreach my $chassis (@{$self->{chassis}}) {
        next if (!defined($chassis->{Drives}));
        next if (ref($chassis->{Drives}) ne 'ARRAY');
        
        foreach my $drive_ref (@{$chassis->{Drives}}) {
            next if (!defined($drive_ref->{'@odata.id'}));
            
            my $drive = $self->{custom}->request_api(
                url_path => $drive_ref->{'@odata.id'},
                ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
            );
            next if (!defined($drive));
            
            my $protocol = defined($drive->{Protocol}) ? $drive->{Protocol} : '';
            next if ($protocol ne 'NVMe' && $protocol ne 'PCIe');
            
            # Try to get metrics
            if (defined($drive->{'@odata.id'})) {
                my $metrics_path = $drive->{'@odata.id'} . '/Metrics';
                my $metrics = $self->{custom}->request_api(
                    url_path => $metrics_path,
                    ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
                );
                $drive->{_metrics} = $metrics if (defined($metrics));
            }
            
            # Avoid duplicates
            my $found = 0;
            foreach my $existing (@{$self->{nvme_drives}}) {
                if (defined($existing->{'@odata.id'}) && defined($drive->{'@odata.id'}) &&
                    $existing->{'@odata.id'} eq $drive->{'@odata.id'}) {
                    $found = 1;
                    last;
                }
            }
            push @{$self->{nvme_drives}}, $drive if (!$found);
        }
    }
}

=head1 MODE

Check hardware.

=over 8

=item B<--component>

Which component to check (default: '.*').
Can be: 'chassis', 'cpu', 'device', 'drive', 'fan', 'firmware', 'health', 'manager', 'memory',
        'network', 'nic', 'nvme', 'powerstate', 'psu', 'sc', 'storage', 'system', 'temperature', 'volume',
        'smcstorage', 'smcdrive', 'smcldrive', 'smcenclosure', 'smcraid'.

=item B<--filter>

Exclude some parts (comma separated list)
You can also exclude items from specific instances: --filter='fan,1.2'

=item B<--no-component>

Define the expected status if no components are found (default: critical).

=item B<--threshold-overload>

Use this option to override the status returned by the plugin when the status label matches a regular expression (syntax: section,[instance,]status,regexp).
Example: --threshold-overload='chassis.state,WARNING,inTest'

=item B<--warning>

Set warning threshold for numeric metrics (syntax: type,regexp,threshold)
Supported types: 'fan', 'temperature', 'psu', 'psu.power', 'cpu.temperature', 'drive.lifeleft',
                 'smcdrive.endurance', 'smcdrive.temperature'.
Example: --warning='temperature,.*,30' --warning='cpu.temperature,.*,80'

=item B<--critical>

Set critical threshold for numeric metrics (syntax: type,regexp,threshold)
Supported types: 'fan', 'temperature', 'psu', 'psu.power', 'cpu.temperature', 'drive.lifeleft',
                 'smcdrive.endurance', 'smcdrive.temperature'.
Example: --critical='temperature,.*,50' --critical='cpu.temperature,.*,95'

=back

=cut
