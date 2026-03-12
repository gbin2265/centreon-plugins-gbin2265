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

package centreon::common::redfish::restapi::mode::components::sc;

use strict;
use warnings;

sub check {
    my ($self) = @_;

    $self->{output}->output_add(long_msg => 'checking storage controllers');
    $self->{components}->{sc} = { name => 'sc', total => 0, skip => 0 };
    return if ($self->check_filter(section => 'sc'));

    my @controllers = ();
    
    # Method 1 & 2: Try standard Redfish Storage (iLO4/iLO6/other vendors)
    $self->get_storages() if (!defined($self->{storages}));
    
    foreach my $storage (@{$self->{storages}}) {
        $storage->{'@odata.id'} =~ /Systems\/(\d+)\//;
        my $system_id = defined($1) ? $1 : '1';
        my $system_name = 'system:' . $system_id;
        my $storage_name = $storage->{Id};

        # Method 1: Embedded StorageControllers array (iLO4 / some vendors)
        if (defined($storage->{StorageControllers}) && ref($storage->{StorageControllers}) eq 'ARRAY') {
            foreach my $sc (@{$storage->{StorageControllers}}) {
                $sc->{_system_name} = $system_name;
                $sc->{_storage_name} = $storage_name;
                $sc->{_system_id} = $system_id;
                $sc->{_source} = 'embedded';
                push @controllers, $sc;
            }
        }
        
        # Method 2: Controllers link (iLO6 / Redfish 1.6+)
        if (defined($storage->{Controllers}) && defined($storage->{Controllers}->{'@odata.id'})) {
            my $controllers_collection = $self->{custom}->request_api(
                url_path => $storage->{Controllers}->{'@odata.id'},
                ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
            );
            if (defined($controllers_collection) && defined($controllers_collection->{Members})) {
                foreach my $member (@{$controllers_collection->{Members}}) {
                    next if (!defined($member->{'@odata.id'}));
                    my $sc = $self->{custom}->request_api(
                        url_path => $member->{'@odata.id'},
                        ignore_codes => { 400 => 1, 404 => 1, 500 => 1 }
                    );
                    if (defined($sc)) {
                        $sc->{_system_name} = $system_name;
                        $sc->{_storage_name} = $storage_name;
                        $sc->{_system_id} = $system_id;
                        $sc->{_source} = 'link';
                        $sc->{MemberId} = $sc->{Id} if (!defined($sc->{MemberId}) && defined($sc->{Id}));
                        push @controllers, $sc;
                    }
                }
            }
        }
    }
    
    # Method 3: HPE SmartStorage fallback (iLO5+)
    if (scalar(@controllers) == 0) {
        $self->get_smartstorage_controllers() if (!defined($self->{smartstorage_controllers}));
        if (defined($self->{smartstorage_controllers})) {
            foreach my $sc (@{$self->{smartstorage_controllers}}) {
                $sc->{_system_name} = 'system:1';
                $sc->{_storage_name} = 'SmartStorage';
                $sc->{_system_id} = '1';
                $sc->{_source} = 'smartstorage';
                $sc->{MemberId} = $sc->{Id} if (!defined($sc->{MemberId}) && defined($sc->{Id}));
                push @controllers, $sc;
            }
        }
    }
    
    # Process all found controllers
    foreach my $sc (@controllers) {
        my $sc_id = defined($sc->{MemberId}) ? $sc->{MemberId} : 
                    defined($sc->{Id}) ? $sc->{Id} : 'unknown';
        my $instance = $sc->{_system_id} . '.' . $sc->{_storage_name} . '.' . $sc_id;

        my $sc_name = defined($sc->{Name}) ? $sc->{Name} : 
                     defined($sc->{Model}) ? $sc->{Model} : 'Controller' . $sc_id;
        my $model = defined($sc->{Model}) ? $sc->{Model} : '';

        $sc->{Status}->{Health} = defined($sc->{Status}->{Health}) ? $sc->{Status}->{Health} : 'n/a';
        $sc->{Status}->{State} = defined($sc->{Status}->{State}) ? $sc->{Status}->{State} : 'n/a';
        next if ($self->check_filter(section => 'sc', instance => $instance));
        $self->{components}->{sc}->{total}++;
        
        # Get cache info (works for both standard Redfish and SmartStorage)
        my $cache_size_mib = '';
        if (defined($sc->{CacheSummary}) && defined($sc->{CacheSummary}->{TotalCacheSizeMiB})) {
            $cache_size_mib = $sc->{CacheSummary}->{TotalCacheSizeMiB};
        } elsif (defined($sc->{CacheMemorySizeMiB})) {
            # HPE SmartStorage uses CacheMemorySizeMiB
            $cache_size_mib = $sc->{CacheMemorySizeMiB};
        }
        
        $self->{output}->output_add(
            long_msg => sprintf(
                "storage controller '%s/%s/%s' status is '%s' [instance: %s, state: %s, model: %s, cache: %s MiB, source: %s]",
                $sc->{_system_name}, $sc->{_storage_name}, $sc_name, $sc->{Status}->{Health}, $instance, 
                $sc->{Status}->{State}, $model, $cache_size_mib, $sc->{_source}
            )
        );

        my $exit = $self->get_severity(label => 'state', section => 'sc.state', value => $sc->{Status}->{State});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Storage controller '%s/%s/%s' state is '%s'", $sc->{_system_name}, $sc->{_storage_name}, $sc_name, $sc->{Status}->{State})
            );
        }

        $exit = $self->get_severity(label => 'status', section => 'sc.status', value => $sc->{Status}->{Health});
        if (!$self->{output}->is_status(value => $exit, compare => 'ok', litteral => 1)) {
            $self->{output}->output_add(
                severity => $exit,
                short_msg => sprintf("Storage controller '%s/%s/%s' status is '%s'", $sc->{_system_name}, $sc->{_storage_name}, $sc_name, $sc->{Status}->{Health})
            );
        }
        
        # Cache size perfdata (if available)
        if ($cache_size_mib ne '' && $cache_size_mib =~ /\d/) {
            my $cache_bytes = $cache_size_mib * 1024 * 1024;
            $self->{output}->perfdata_add(
                nlabel => 'hardware.sc.cache.bytes',
                unit => 'B',
                instances => $sc_name,
                value => $cache_bytes,
                min => 0
            );
        }
    }
}


1;

__END__

=head1 DESCRIPTION

Check storage controller status, health and cache size.
Monitors storage controllers with a 3-method detection approach:
embedded StorageControllers array (iLO4), Controllers link (iLO6/Redfish 1.6+),
and HPE SmartStorage fallback (iLO5+).

=head2 Redfish Endpoint

/redfish/v1/Systems/{SystemId}/Storage/{StorageId} (StorageControllers or Controllers link)

=head2 Perfdata

hardware.sc.cache.bytes : Controller cache size in bytes

=cut
