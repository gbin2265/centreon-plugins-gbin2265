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

package storage::hp::msa2000::restapi::mode::storagegroup;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s, exposed: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state},
        $self->{result_values}->{exposed}
    );
}

sub prefix_storagegroup_output {
    my ($self, %options) = @_;

    return sprintf(
        "Storage group '%s' [Controller: %s, LUNs: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{controller},
        $options{instance_value}->{lun_count}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'storagegroups', type => 1, cb_prefix_output => 'prefix_storagegroup_output', message_multiple => 'All storage groups are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'storagegroups-total', nlabel => 'storagegroups.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'Total storage groups: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{storagegroups} = [
        {
            label => 'storagegroup-status',
            type => 2,
            warning_default => '%{health} =~ /warning/i',
            critical_default => '%{health} =~ /critical/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'controller' }, { name => 'exposed' }, { name => 'lun_count' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'storagegroup-luns', nlabel => 'storagegroup.luns.count', set => {
                key_values => [ { name => 'lun_count' }, { name => 'name' } ],
                output_template => 'mapped LUNs: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'name' }
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
        'filter-controller-id:s'     => { name => 'filter_controller_id' },
        'filter-storagegroup-id:s'   => { name => 'filter_storagegroup_id' },
        'filter-storagegroup-name:s' => { name => 'filter_storagegroup_name' },
        'exclude-controller-id:s' => { name => 'exclude_controller_id' },
        'exclude-storagegroup-id:s' => { name => 'exclude_storagegroup_id' },
        'exclude-storagegroup-name:s' => { name => 'exclude_storagegroup_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0 };
    $self->{storagegroups} = {};

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

        next if (!defined($storage_data->{StorageGroups}) || !defined($storage_data->{StorageGroups}->{'@odata.id'}));

        my $groups_result = $options{custom}->request_api(
            url_path => $storage_data->{StorageGroups}->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($groups_result) || !defined($groups_result->{Members}) || ref($groups_result->{Members}) ne 'ARRAY');

        foreach my $group_ref (@{$groups_result->{Members}}) {
            next if (!defined($group_ref->{'@odata.id'}));
            
            my $group_data = $options{custom}->request_api(
                url_path => $group_ref->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($group_data));

            my $group_id;
            if (defined($group_data->{Id})) {
                $group_id = $group_data->{Id};
            } elsif ($group_ref->{'@odata.id'} =~ /\/StorageGroups\/([^\/]+)/) {
                $group_id = $1;
            } else {
                next;
            }

            my $group_name = defined($group_data->{Name}) ? $group_data->{Name} : $group_id;
            my $group_full_id = $controller_id . '_' . $group_id;

            if (defined($self->{option_results}->{filter_storagegroup_id}) && $self->{option_results}->{filter_storagegroup_id} ne '' &&
                $group_id !~ /$self->{option_results}->{filter_storagegroup_id}/) {
                next;
            }


            if (defined($self->{option_results}->{exclude_storagegroup_id}) && $self->{option_results}->{exclude_storagegroup_id} ne '' &&
                $group_id =~ /$self->{option_results}->{exclude_storagegroup_id}/) {
                next;
            }

            if (defined($self->{option_results}->{filter_storagegroup_name}) && $self->{option_results}->{filter_storagegroup_name} ne '' &&
                $group_name !~ /$self->{option_results}->{filter_storagegroup_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_storagegroup_name}) && $self->{option_results}->{exclude_storagegroup_name} ne '' &&
                $group_name =~ /$self->{option_results}->{exclude_storagegroup_name}/) {
                next;
            }

            my $health = 'n/a';
            my $state = 'n/a';
            if (defined($group_data->{Status})) {
                $health = defined($group_data->{Status}->{Health}) ? $group_data->{Status}->{Health} : 'n/a';
                $state = defined($group_data->{Status}->{State}) ? $group_data->{Status}->{State} : 'n/a';
            }
            next if ($state =~ /^Absent$/i);

            my $lun_count = 0;
            if (defined($group_data->{MappedVolumes}) && ref($group_data->{MappedVolumes}) eq 'ARRAY') {
                $lun_count = scalar(@{$group_data->{MappedVolumes}});
            }

            my $exposed = 'n/a';
            if (defined($group_data->{VolumesAreExposed})) {
                $exposed = $group_data->{VolumesAreExposed} ? 'true' : 'false';
            }

            $self->{global}->{total}++;

            $self->{storagegroups}->{$group_full_id} = {
                name       => $group_name,
                controller => $controller_id,
                health     => $health,
                state      => $state,
                exposed    => $exposed,
                lun_count  => $lun_count,
            };
        }
    }

    if (scalar(keys %{$self->{storagegroups}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No storage groups found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA storage groups (volume-to-host mappings) via Redfish API.

=over 8

=item B<--filter-controller-id>

Filter by controller id (can be a regexp).

=item B<--filter-storagegroup-id>

Filter by storagegroup id (can be a regexp).

=item B<--filter-storagegroup-name>

Filter by storagegroup name (can be a regexp).

=item B<--exclude-controller-id>

Exclude by controller id (can be a regexp).

=item B<--exclude-storagegroup-id>

Exclude by storagegroup id (can be a regexp).

=item B<--exclude-storagegroup-name>

Exclude by storagegroup name (can be a regexp).

=item B<--warning-storagegroup-status> B<--critical-storagegroup-status>

Set warning/critical threshold for storagegroup status.
Default warning: '%{health} =~ /warning/i'
Default critical: '%{health} =~ /critical/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'storagegroup-luns', 'storagegroups-total'.

=back

=cut
