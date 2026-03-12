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

package storage::hp::msa2000::restapi::mode::controller;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s, redundancy: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state},
        $self->{result_values}->{redundancy_health}
    );
}

sub prefix_controller_output {
    my ($self, %options) = @_;

    return sprintf(
        "Controller '%s' [Model: %s, FW: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{model},
        $options{instance_value}->{firmware}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'controllers', type => 1, cb_prefix_output => 'prefix_controller_output', message_multiple => 'All controllers are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'controllers-total', nlabel => 'controllers.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total controllers: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'controllers-ok', nlabel => 'controllers.ok.count', display_ok => 0, set => {
                key_values => [ { name => 'ok' } ],
                output_template => 'controllers ok: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'controllers-degraded', nlabel => 'controllers.degraded.count', display_ok => 0, set => {
                key_values => [ { name => 'degraded' } ],
                output_template => 'controllers degraded: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{controllers} = [
        {
            label => 'controller-status',
            type => 2,
            warning_default => '%{health} =~ /warning|degraded/i || %{redundancy_health} =~ /warning|degraded/i',
            critical_default => '%{health} =~ /critical/i || %{redundancy_health} =~ /critical/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'model' }, { name => 'firmware' }, { name => 'redundancy_mode' },
                    { name => 'redundancy_health' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'controller-redundancy-status', nlabel => 'controller.redundancy.status', set => {
                key_values => [ { name => 'redundancy_status' }, { name => 'name' } ],
                output_template => 'redundancy status: %s',
                perfdatas => [
                    { template => '%s', min => 0, max => 1, label_extra_instance => 1, instance_use => 'name' }
                ]
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
        'filter-controller-name:s' => { name => 'filter_controller_name' },
        'exclude-controller-id:s' => { name => 'exclude_controller_id' },
        'exclude-controller-name:s' => { name => 'exclude_controller_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0, ok => 0, degraded => 0 };
    $self->{controllers} = {};

    my $storage_result = $options{custom}->request_api(url_path => '/redfish/v1/Storage');
    return if (!defined($storage_result) || !defined($storage_result->{Members}));

    foreach my $storage (@{$storage_result->{Members}}) {
        next if (!defined($storage->{'@odata.id'}));
        
        my $storage_data = $options{custom}->request_api(
            url_path => $storage->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($storage_data));

        my $controller_id;
        if (defined($storage_data->{Id})) {
            $controller_id = $storage_data->{Id};
        } elsif ($storage->{'@odata.id'} =~ /\/Storage\/([^\/]+)/) {
            $controller_id = $1;
        } else {
            next;
        }

        if (defined($self->{option_results}->{filter_controller_id}) && $self->{option_results}->{filter_controller_id} ne '' &&
            $controller_id !~ /$self->{option_results}->{filter_controller_id}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_controller_id}) && $self->{option_results}->{exclude_controller_id} ne '' &&
            $controller_id =~ /$self->{option_results}->{exclude_controller_id}/) {
            next;
        }

        my $controller_name = defined($storage_data->{Name}) ? $storage_data->{Name} : $controller_id;

        if (defined($self->{option_results}->{filter_controller_name}) && $self->{option_results}->{filter_controller_name} ne '' &&
            $controller_name !~ /$self->{option_results}->{filter_controller_name}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_controller_name}) && $self->{option_results}->{exclude_controller_name} ne '' &&
            $controller_name =~ /$self->{option_results}->{exclude_controller_name}/) {
            next;
        }

        my $health = 'n/a';
        my $state = 'n/a';
        if (defined($storage_data->{Status})) {
            $health = defined($storage_data->{Status}->{Health}) ? $storage_data->{Status}->{Health} : 'n/a';
            $state = defined($storage_data->{Status}->{State}) ? $storage_data->{Status}->{State} : 'n/a';
        }
        next if ($state =~ /^Absent$/i);

        # Get controller details from StorageControllers array
        my $model = 'n/a';
        my $firmware = 'n/a';
        my $redundancy_mode = 'n/a';
        my $redundancy_health = 'n/a';
        my $redundancy_status = 1;  # 1 = OK, 0 = degraded

        if (defined($storage_data->{StorageControllers}) && ref($storage_data->{StorageControllers}) eq 'ARRAY' 
            && scalar(@{$storage_data->{StorageControllers}}) > 0) {
            my $ctrl = $storage_data->{StorageControllers}->[0];
            $model = defined($ctrl->{Model}) ? $ctrl->{Model} : 'n/a';
            $firmware = defined($ctrl->{FirmwareVersion}) ? $ctrl->{FirmwareVersion} : 'n/a';
        }

        # Get redundancy information
        if (defined($storage_data->{Redundancy}) && ref($storage_data->{Redundancy}) eq 'ARRAY' 
            && scalar(@{$storage_data->{Redundancy}}) > 0) {
            my $redundancy = $storage_data->{Redundancy}->[0];
            $redundancy_mode = defined($redundancy->{Mode}) ? $redundancy->{Mode} : 'n/a';
            
            if (defined($redundancy->{Status})) {
                $redundancy_health = defined($redundancy->{Status}->{Health}) ? $redundancy->{Status}->{Health} : 'n/a';
                # Set redundancy_status: 1 = OK, 0 = not OK
                if ($redundancy_health =~ /^OK$/i) {
                    $redundancy_status = 1;
                } else {
                    $redundancy_status = 0;
                }
            }
        }

        $self->{controllers}->{$controller_id} = {
            name              => $controller_name,
            health            => $health,
            state             => $state,
            model             => $model,
            firmware          => $firmware,
            redundancy_mode   => $redundancy_mode,
            redundancy_health => $redundancy_health,
            redundancy_status => $redundancy_status,
        };
        
        $self->{global}->{total}++;
        if ($health =~ /^OK$/i && $redundancy_health =~ /^OK$/i) {
            $self->{global}->{ok}++;
        } elsif ($health =~ /degraded|warning/i || $redundancy_health =~ /degraded|warning/i) {
            $self->{global}->{degraded}++;
        }
    }

    if (scalar(keys %{$self->{controllers}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No controllers found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA controllers status via Redfish API.

Redundancy status: 1 = OK, 0 = degraded/failed.

=over 8

=item B<--filter-controller-id>

Filter by controller id (can be a regexp).

=item B<--filter-controller-name>

Filter by controller name (can be a regexp).

=item B<--exclude-controller-id>

Exclude by controller id (can be a regexp).

=item B<--exclude-controller-name>

Exclude by controller name (can be a regexp).

=item B<--warning-controller-status> B<--critical-controller-status>

Set warning/critical threshold for controller status.
Default warning: '%{health} =~ /warning|degraded/i || %{redundancy_health} =~ /warning|degraded/i'
Default critical: '%{health} =~ /critical/i || %{redundancy_health} =~ /critical/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'controller-redundancy-status', 'controllers-degraded', 'controllers-ok', 'controllers-total'.

=back

=cut
