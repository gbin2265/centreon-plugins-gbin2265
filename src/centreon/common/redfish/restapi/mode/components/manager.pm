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

package centreon::common::redfish::restapi::mode::components::manager;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking managers');
    $self->{components}->{manager} = { name => 'manager', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'manager'));

    $self->get_managers() if (!defined($self->{managers}));
    return if (!defined($self->{managers}) || scalar(@{$self->{managers}}) == 0);

    foreach my $manager (@{$self->{managers}}) {
        my $manager_id = defined($manager->{Id}) ? $manager->{Id} : 'unknown';
        my $manager_name = defined($manager->{Name}) ? $manager->{Name} : 
                          defined($manager->{Model}) ? $manager->{Model} : 'Manager' . $manager_id;
        my $model = defined($manager->{Model}) ? $manager->{Model} : '';
        my $fw_version = defined($manager->{FirmwareVersion}) ? $manager->{FirmwareVersion} : '';
        
        my $state = defined($manager->{Status}->{State}) ? $manager->{Status}->{State} : 'n/a';
        my $health = defined($manager->{Status}->{Health}) ? $manager->{Status}->{Health} : 'n/a';
        
        my $instance = $manager_id;
        next if ($self->check_filter(section => 'manager', instance => $instance));
        $self->{components}->{manager}->{total}++;
        
        $self->{output}->output_add(
            long_msg => sprintf(
                "manager '%s' status is '%s' [instance: %s, state: %s, model: %s, firmware: %s]",
                $manager_name, $health, $instance, $state, $model, $fw_version
            )
        );
        
        my $exit = $self->get_severity(label => 'state', section => 'manager.state', value => $state);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Manager '%s' state is '%s'", $manager_name, $state)
            );
        }
        
        $exit = $self->get_severity(label => 'status', section => 'manager.status', value => $health);
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Manager '%s' status is '%s'", $manager_name, $health)
            );
        }
        
        # Check HPE iLO Self-Test Results
        my $selftests_passed = 0;
        my $selftests_failed = 0;
        my $selftests_total = 0;
        
        if (defined($manager->{Oem}) && defined($manager->{Oem}->{Hpe}) && 
            defined($manager->{Oem}->{Hpe}->{iLOSelfTestResults})) {
            my $tests = $manager->{Oem}->{Hpe}->{iLOSelfTestResults};
            
            foreach my $test (@$tests) {
                $selftests_total++;
                my $test_name = defined($test->{SelfTestName}) ? $test->{SelfTestName} : 'unknown';
                my $test_status = defined($test->{Status}) ? $test->{Status} : 'Unknown';
                
                if ($test_status eq 'OK' || $test_status eq 'Informational') {
                    $selftests_passed++;
                } else {
                    $selftests_failed++;
                    $self->{output}->output_add(
                        severity => 'WARNING',
                        short_msg => sprintf("Manager '%s' self-test '%s' status is '%s'", $manager_name, $test_name, $test_status)
                    );
                }
                
                $self->{output}->output_add(
                    long_msg => sprintf(
                        "  self-test '%s' status is '%s'",
                        $test_name, $test_status
                    )
                );
            }
        }
        
        # Self-test perfdata
        if ($selftests_total > 0) {
            $self->{output}->perfdata_add(
                nlabel => 'hardware.manager.selftests.passed.count',
                instances => $manager_name,
                value => $selftests_passed,
                min => 0,
                max => $selftests_total
            );
            $self->{output}->perfdata_add(
                nlabel => 'hardware.manager.selftests.failed.count',
                instances => $manager_name,
                value => $selftests_failed,
                min => 0,
                max => $selftests_total,
                warning => '0:0',
                critical => '1:'
            );
        }
        
        # Check HPE License info
        if (defined($manager->{Oem}) && defined($manager->{Oem}->{Hpe}) && 
            defined($manager->{Oem}->{Hpe}->{License})) {
            my $license = $manager->{Oem}->{Hpe}->{License};
            my $lic_string = defined($license->{LicenseString}) ? $license->{LicenseString} : '';
            my $lic_type = defined($license->{LicenseType}) ? $license->{LicenseType} : '';
            
            $self->{output}->output_add(
                long_msg => sprintf(
                    "  license: %s (%s)",
                    $lic_string, $lic_type
                )
            );
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check BMC/iLO manager status, health and self-tests.
Monitors the Redfish Managers resource for manager state/health,
firmware version, and HPE OEM self-test results.

=head2 Redfish Endpoint

/redfish/v1/Managers/{ManagerId}

=head2 Perfdata

hardware.manager.selftests.passed.count : Number of passed self-tests (HPE OEM)
hardware.manager.selftests.failed.count : Number of failed self-tests (HPE OEM)

=cut
