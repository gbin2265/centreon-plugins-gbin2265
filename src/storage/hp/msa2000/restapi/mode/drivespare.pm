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

package storage::hp::msa2000::restapi::mode::drivespare;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Spare drives ';
}

sub prefix_spare_output {
    my ($self, %options) = @_;

    return sprintf(
        "spare drive '%s' [controller: %s, location: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{controller},
        $options{instance_value}->{location}
    );
}

sub custom_spare_output {
    my ($self, %options) = @_;

    return sprintf(
        "type: %s, status: %s [state: %s, media: %s]",
        $self->{result_values}->{hotspare_type},
        $self->{result_values}->{health},
        $self->{result_values}->{state},
        $self->{result_values}->{media_type}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'spares', type => 1, cb_prefix_output => 'prefix_spare_output', message_multiple => 'All spare drives are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'drives-spare-total', nlabel => 'drives.spare.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'drives-spare-global', nlabel => 'drives.spare.global.count', display_ok => 0, set => {
                key_values => [ { name => 'global' } ],
                output_template => 'global: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'drives-spare-dedicated', nlabel => 'drives.spare.dedicated.count', display_ok => 0, set => {
                key_values => [ { name => 'dedicated' } ],
                output_template => 'dedicated: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{spares} = [
        {
            label => 'spare-status',
            type => 2,
            critical_default => '%{health} =~ /critical|fault|failed/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'controller' }, { name => 'media_type' }, { name => 'location' },
                    { name => 'hotspare_type' }
                ],
                closure_custom_output => $self->can('custom_spare_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'spare-capacity', nlabel => 'drive.spare.capacity.bytes', set => {
                key_values => [ { name => 'capacity' }, { name => 'name' } ],
                output_template => 'capacity: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'name' }
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
        'filter-enclosure-id:s'  => { name => 'filter_enclosure_id' },
        'exclude-controller-id:s' => { name => 'exclude_controller_id' },
        'exclude-enclosure-id:s' => { name => 'exclude_enclosure_id' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0, global => 0, dedicated => 0 };
    $self->{spares} = {};

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

        next if (!defined($storage_data->{Drives}) || ref($storage_data->{Drives}) ne 'ARRAY');

        foreach my $drive_ref (@{$storage_data->{Drives}}) {
            next if (!defined($drive_ref->{'@odata.id'}));
            
            my $drive_data = $options{custom}->request_api(
                url_path => $drive_ref->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($drive_data));

            my $drive_id;
            if (defined($drive_data->{Id})) {
                $drive_id = $drive_data->{Id};
            } elsif ($drive_ref->{'@odata.id'} =~ /\/Drives\/([^\/]+)/) {
                $drive_id = $1;
            } else {
                next;
            }

            # Determine hotspare type
            my $hotspare_type = 'None';
            if (defined($drive_data->{HotspareType})) {
                $hotspare_type = $drive_data->{HotspareType};
            } elsif (defined($drive_data->{StatusIndicator}) && $drive_data->{StatusIndicator} =~ /Hotspare/i) {
                $hotspare_type = 'Global';
            }

            # Skip non-spare drives
            next if ($hotspare_type =~ /^None$/i);

            my $drive_name = defined($drive_data->{Name}) ? $drive_data->{Name} : $drive_id;
            my $drive_full_id = $controller_id . '_' . $drive_id;

            my $location = $drive_id;
            my $enclosure_id = '';
            if ($drive_id =~ /^(\d+)\.(\d+)$/) {
                $enclosure_id = $1;
                $location = $drive_id;
            }

            if (defined($self->{option_results}->{filter_enclosure_id}) && $self->{option_results}->{filter_enclosure_id} ne '' &&
                $enclosure_id !~ /$self->{option_results}->{filter_enclosure_id}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_enclosure_id}) && $self->{option_results}->{exclude_enclosure_id} ne '' &&
                $enclosure_id =~ /$self->{option_results}->{exclude_enclosure_id}/) {
                next;
            }

            my $health = 'n/a';
            my $state = 'n/a';
            if (defined($drive_data->{Status})) {
                $health = defined($drive_data->{Status}->{Health}) ? $drive_data->{Status}->{Health} : 'n/a';
                $state = defined($drive_data->{Status}->{State}) ? $drive_data->{Status}->{State} : 'n/a';
            }
            next if ($state =~ /^Absent$/i);

            my $media_type = defined($drive_data->{MediaType}) ? $drive_data->{MediaType} : 'n/a';
            my $capacity = defined($drive_data->{CapacityBytes}) ? $drive_data->{CapacityBytes} : 0;

            $self->{spares}->{$drive_full_id} = {
                name           => $drive_name,
                controller     => $controller_id,
                health         => $health,
                state          => $state,
                media_type     => $media_type,
                location       => $location,
                hotspare_type  => $hotspare_type,
                capacity       => $capacity,
            };

            $self->{global}->{total}++;
            if ($hotspare_type =~ /^Global$/i) {
                $self->{global}->{global}++;
            } elsif ($hotspare_type =~ /^Dedicated$/i) {
                $self->{global}->{dedicated}++;
            }
        }
    }



    $options{custom}->logout();
}

1;

__END__

=head1 MODE

Check HPE MSA spare (hotspare) drives via Redfish API.

Reports the number of global and dedicated spare drives with their health status.

=over 8

=item B<--filter-controller-id>

Filter by controller id (can be a regexp).

=item B<--filter-enclosure-id>

Filter by enclosure id (can be a regexp).

=item B<--exclude-controller-id>

Exclude by controller id (can be a regexp).

=item B<--exclude-enclosure-id>

Exclude by enclosure id (can be a regexp).

=item B<--warning-spare-status> B<--critical-spare-status>

Set warning/critical threshold for spare drive status.
Available macros: %{health}, %{state}, %{hotspare_type}, %{media_type}, %{controller}, %{location}.
Default critical: '%{health} =~ /critical|fault|failed/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'drives-spare-total', 'drives-spare-global', 'drives-spare-dedicated', 'spare-capacity'.

=back

=cut
