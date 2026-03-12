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

package storage::hp::msa2000::restapi::mode::firmware;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s, version: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state},
        $self->{result_values}->{version}
    );
}

sub prefix_firmware_output {
    my ($self, %options) = @_;

    return "Firmware '" . $options{instance_value}->{name} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'firmwares', type => 1, cb_prefix_output => 'prefix_firmware_output', message_multiple => 'All firmware bundles are ok' }
    ];

    $self->{maps_counters}->{global} = [];

    $self->{maps_counters}->{firmwares} = [
        {
            label => 'firmware-status',
            type => 2,
            warning_default => '%{health} =~ /warning/i',
            critical_default => '%{health} =~ /critical/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'version' }, { name => 'updateable' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
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
        'filter-firmware-id:s' => { name => 'filter_firmware_id' },
        'filter-firmware-name:s' => { name => 'filter_firmware_name' },
        'exclude-firmware-id:s' => { name => 'exclude_firmware_id' },
        'exclude-firmware-name:s' => { name => 'exclude_firmware_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = {};
    $self->{firmwares} = {};

    my $update_service = $options{custom}->request_api(
        url_path => '/redfish/v1/UpdateService',
        ignore_codes => { 404 => 1 }
    );
    return if (!defined($update_service) || !defined($update_service->{FirmwareInventory}) || !defined($update_service->{FirmwareInventory}->{'@odata.id'}));

    my $firmware_result = $options{custom}->request_api(
        url_path => $update_service->{FirmwareInventory}->{'@odata.id'},
        ignore_codes => { 404 => 1 }
    );
    return if (!defined($firmware_result) || !defined($firmware_result->{Members}) || ref($firmware_result->{Members}) ne 'ARRAY');

    foreach my $fw_ref (@{$firmware_result->{Members}}) {
        next if (!defined($fw_ref->{'@odata.id'}));
        
        my $fw_data = $options{custom}->request_api(
            url_path => $fw_ref->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($fw_data));

        my $fw_id;
        if (defined($fw_data->{Id})) {
            $fw_id = $fw_data->{Id};
        } elsif ($fw_ref->{'@odata.id'} =~ /\/FirmwareInventory\/([^\/]+)/) {
            $fw_id = $1;
        } else {
            next;
        }

        if (defined($self->{option_results}->{filter_firmware_id}) && $self->{option_results}->{filter_firmware_id} ne '' &&
            $fw_id !~ /$self->{option_results}->{filter_firmware_id}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_firmware_id}) && $self->{option_results}->{exclude_firmware_id} ne '' &&
            $fw_id =~ /$self->{option_results}->{exclude_firmware_id}/) {
            next;
        }

        my $firmware_name = defined($fw_data->{Name}) ? $fw_data->{Name} : $fw_id;

        if (defined($self->{option_results}->{filter_firmware_name}) && $self->{option_results}->{filter_firmware_name} ne '' &&
            $firmware_name !~ /$self->{option_results}->{filter_firmware_name}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_firmware_name}) && $self->{option_results}->{exclude_firmware_name} ne '' &&
            $firmware_name =~ /$self->{option_results}->{exclude_firmware_name}/) {
            next;
        }

        my $health = 'n/a';
        my $state = 'n/a';
        if (defined($fw_data->{Status})) {
            $health = defined($fw_data->{Status}->{Health}) ? $fw_data->{Status}->{Health} : 'n/a';
            $state = defined($fw_data->{Status}->{State}) ? $fw_data->{Status}->{State} : 'n/a';
        }
        next if ($state =~ /^Absent$/i);

        $self->{firmwares}->{$fw_id} = {
            name       => $firmware_name,
            health     => $health,
            state      => $state,
            version    => defined($fw_data->{Version}) ? $fw_data->{Version} : 'n/a',
            updateable => defined($fw_data->{Updateable}) ? ($fw_data->{Updateable} ? 'true' : 'false') : 'n/a',
        };
    }

    if (scalar(keys %{$self->{firmwares}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No firmware bundles found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA firmware status via Redfish API.

=over 8

=item B<--filter-firmware-id>

Filter by firmware id (can be a regexp).

=item B<--filter-firmware-name>

Filter by firmware name (can be a regexp).

=item B<--exclude-firmware-id>

Exclude by firmware id (can be a regexp).

=item B<--exclude-firmware-name>

Exclude by firmware name (can be a regexp).

=item B<--warning-firmware-status> B<--critical-firmware-status>

Set warning/critical threshold for firmware status.
Default warning: '%{health} =~ /warning/i'
Default critical: '%{health} =~ /critical/i'

=back

=cut
