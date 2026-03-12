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

package storage::hp::msa2000::restapi::mode::systemhealth;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_system_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "system '%s' health: %s [state: %s]",
        $self->{result_values}->{name},
        $self->{result_values}->{health},
        $self->{result_values}->{state}
    );
}

sub custom_controller_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state}
    );
}

sub prefix_controller_output {
    my ($self, %options) = @_;

    return "Controller '" . $options{instance_value}->{name} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'system', type => 0, skipped_code => { -10 => 1 } },
        { name => 'controllers', type => 1, cb_prefix_output => 'prefix_controller_output', message_multiple => 'All controllers are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'overall-health', nlabel => 'system.health.status', set => {
                key_values => [ { name => 'overall_status' } ],
                output_template => 'overall health status: %s',
                perfdatas => [
                    { template => '%s', min => 0, max => 3 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{system} = [
        {
            label => 'system-health',
            type => 2,
            warning_default => '%{health} =~ /degraded/i',
            critical_default => '%{health} =~ /fault|failed/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' }
                ],
                closure_custom_output => $self->can('custom_system_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{controllers} = [
        {
            label => 'controller-status',
            type => 2,
            warning_default => '%{health} =~ /degraded/i',
            critical_default => '%{health} =~ /fault|failed/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' }
                ],
                closure_custom_output => $self->can('custom_controller_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-controller-id:s' => { name => 'filter_controller_id' },
        'exclude-controller-id:s' => { name => 'exclude_controller_id' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { overall_status => 0 };
    $self->{system} = {};
    $self->{controllers} = {};

    # Try /redfish/v1/Systems for overall system health first
    my $systems_result = $options{custom}->request_api(
        url_path => '/redfish/v1/Systems',
        ignore_codes => { 404 => 1 }
    );
    if (defined($systems_result) && defined($systems_result->{Members})) {
        foreach my $system (@{$systems_result->{Members}}) {
            next if (!defined($system->{'@odata.id'}));
            
            my $system_data = $options{custom}->request_api(
                url_path => $system->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($system_data));

            my $health = defined($system_data->{Status}) && defined($system_data->{Status}->{Health})
                ? $system_data->{Status}->{Health} : 'n/a';
            my $state = defined($system_data->{Status}) && defined($system_data->{Status}->{State})
                ? $system_data->{Status}->{State} : 'n/a';
            next if ($state =~ /^Absent$/i);

            
            my $status = ($health =~ /^OK$/i) ? 0 : ($health =~ /degraded|warning/i) ? 1 : ($health =~ /fault|failed|critical/i) ? 2 : 3;
            
            $self->{system} = {
                name   => defined($system_data->{Name}) ? $system_data->{Name} : 'System',
                health => $health,
                state  => $state,
            };
            
            $self->{global}->{overall_status} = $status if ($status > $self->{global}->{overall_status});
            last;
        }
    }

    # Fallback to Chassis if Systems didn't provide data
    if (!defined($self->{system}->{name})) {
        my $chassis_result = $options{custom}->request_api(url_path => '/redfish/v1/Chassis');
        if (defined($chassis_result) && defined($chassis_result->{Members})) {
            foreach my $chassis (@{$chassis_result->{Members}}) {
                next if (!defined($chassis->{'@odata.id'}));
                
                my $chassis_data = $options{custom}->request_api(
                    url_path => $chassis->{'@odata.id'},
                    ignore_codes => { 404 => 1 }
                );
                next if (!defined($chassis_data));

                my $chassis_type = defined($chassis_data->{ChassisType}) ? $chassis_data->{ChassisType} : '';
                if ($chassis_type =~ /StorageEnclosure|Enclosure|RackMount/i || 
                    (defined($chassis_data->{Name}) && $chassis_data->{Name} =~ /system|enclosure/i)) {
                    
                    my $health = defined($chassis_data->{Status}) && defined($chassis_data->{Status}->{Health}) 
                        ? $chassis_data->{Status}->{Health} : 'n/a';
                    my $state = defined($chassis_data->{Status}) && defined($chassis_data->{Status}->{State})
                        ? $chassis_data->{Status}->{State} : 'n/a';
                    next if ($state =~ /^Absent$/i);

                    
                    my $status = ($health =~ /^OK$/i) ? 0 : ($health =~ /degraded|warning/i) ? 1 : ($health =~ /fault|failed|critical/i) ? 2 : 3;
                    
                    $self->{system} = {
                        name   => defined($chassis_data->{Name}) ? $chassis_data->{Name} : 'System',
                        health => $health,
                        state  => $state,
                    };
                    
                    $self->{global}->{overall_status} = $status if ($status > $self->{global}->{overall_status});
                    last;
                }
            }
        }
    }

    my $storage_result = $options{custom}->request_api(url_path => '/redfish/v1/Storage');
    if (defined($storage_result) && defined($storage_result->{Members})) {
        foreach my $storage (@{$storage_result->{Members}}) {
            next if (!defined($storage->{'@odata.id'}));
            
            my $storage_data = $options{custom}->request_api(
                url_path => $storage->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($storage_data));

            # MSA uses StorageControllers array directly in the Storage resource
            if (defined($storage_data->{StorageControllers}) && ref($storage_data->{StorageControllers}) eq 'ARRAY') {
                foreach my $ctrl (@{$storage_data->{StorageControllers}}) {
                    my $ctrl_id = defined($ctrl->{MemberId}) ? $ctrl->{MemberId} : 
                        (defined($ctrl->{Id}) ? $ctrl->{Id} : 
                        (defined($storage_data->{Id}) ? $storage_data->{Id} : 'unknown'));

                    if (defined($self->{option_results}->{filter_controller_id}) && $self->{option_results}->{filter_controller_id} ne '' &&
                        $ctrl_id !~ /$self->{option_results}->{filter_controller_id}/) {
                        next;
                    }


                    if (defined($self->{option_results}->{exclude_controller_id}) && $self->{option_results}->{exclude_controller_id} ne '' &&
                        $ctrl_id =~ /$self->{option_results}->{exclude_controller_id}/) {
                        next;
                    }

                    my $health = defined($ctrl->{Status}) && defined($ctrl->{Status}->{Health})
                        ? $ctrl->{Status}->{Health} : 'n/a';
                    my $state = defined($ctrl->{Status}) && defined($ctrl->{Status}->{State})
                        ? $ctrl->{Status}->{State} : 'n/a';
                    next if ($state =~ /^Absent$/i);

                    
                    my $status = ($health =~ /^OK$/i) ? 0 : ($health =~ /degraded|warning/i) ? 1 : ($health =~ /fault|failed|critical/i) ? 2 : 3;

                    $self->{controllers}->{$ctrl_id} = {
                        name   => defined($ctrl->{Name}) ? $ctrl->{Name} : $ctrl_id,
                        health => $health,
                        state  => $state,
                    };
                    
                    $self->{global}->{overall_status} = $status if ($status > $self->{global}->{overall_status});
                }
            }
            
            # Also support Controllers collection (standard Redfish)
            if (defined($storage_data->{Controllers})) {
                my $controllers_ref = $storage_data->{Controllers};
                my @controller_links;

                if (defined($controllers_ref->{'@odata.id'})) {
                    my $controllers_collection = $options{custom}->request_api(
                        url_path => $controllers_ref->{'@odata.id'},
                        ignore_codes => { 404 => 1 }
                    );
                    if (defined($controllers_collection) && defined($controllers_collection->{Members})) {
                        @controller_links = @{$controllers_collection->{Members}};
                    }
                } elsif (ref($controllers_ref) eq 'ARRAY') {
                    @controller_links = @{$controllers_ref};
                }

                foreach my $ctrl (@controller_links) {
                    next if (!defined($ctrl->{'@odata.id'}));
                    
                    my $ctrl_data = $options{custom}->request_api(
                        url_path => $ctrl->{'@odata.id'},
                        ignore_codes => { 404 => 1 }
                    );
                    next if (!defined($ctrl_data));

                    my $ctrl_id = defined($ctrl_data->{Id}) ? $ctrl_data->{Id} : 
                        ($ctrl->{'@odata.id'} =~ /\/Controllers\/([^\/]+)/ ? $1 : 'unknown');

                    # Skip if already added via StorageControllers
                    next if (exists($self->{controllers}->{$ctrl_id}));

                    if (defined($self->{option_results}->{filter_controller_id}) && $self->{option_results}->{filter_controller_id} ne '' &&
                        $ctrl_id !~ /$self->{option_results}->{filter_controller_id}/) {
                        next;
                    }


                    if (defined($self->{option_results}->{exclude_controller_id}) && $self->{option_results}->{exclude_controller_id} ne '' &&
                        $ctrl_id =~ /$self->{option_results}->{exclude_controller_id}/) {
                        next;
                    }

                    my $health = defined($ctrl_data->{Status}) && defined($ctrl_data->{Status}->{Health})
                        ? $ctrl_data->{Status}->{Health} : 'n/a';
                    my $state = defined($ctrl_data->{Status}) && defined($ctrl_data->{Status}->{State})
                        ? $ctrl_data->{Status}->{State} : 'n/a';
                    next if ($state =~ /^Absent$/i);

                    
                    my $status = ($health =~ /^OK$/i) ? 0 : ($health =~ /degraded|warning/i) ? 1 : ($health =~ /fault|failed|critical/i) ? 2 : 3;

                    $self->{controllers}->{$ctrl_id} = {
                        name   => defined($ctrl_data->{Name}) ? $ctrl_data->{Name} : $ctrl_id,
                        health => $health,
                        state  => $state,
                    };
                    
                    $self->{global}->{overall_status} = $status if ($status > $self->{global}->{overall_status});
                }
            }
        }
    }

    if (!defined($self->{system}->{name}) && scalar(keys %{$self->{controllers}}) == 0) {
        $self->{output}->add_option_msg(short_msg => "No system health data found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check overall HPE MSA system health via Redfish API.

The overall health status perfdata (system.health.status) provides:
- 0: System OK
- 1: System Warning/Degraded
- 2: System Critical/Failed
- 3: System Unknown

=over 8

=item B<--filter-controller-id>

Filter by controller id (can be a regexp).

=item B<--exclude-controller-id>

Exclude by controller id (can be a regexp).

=item B<--warning-system-health> B<--critical-system-health>

Set warning/critical threshold for system health.
Default warning: '%{health} =~ /degraded/i'
Default critical: '%{health} =~ /fault|failed/i'

=item B<--warning-controller-status> B<--critical-controller-status>

Set warning/critical threshold for controller status.
Default warning: '%{health} =~ /degraded/i'
Default critical: '%{health} =~ /fault|failed/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'overall-health'.

=back

=cut
