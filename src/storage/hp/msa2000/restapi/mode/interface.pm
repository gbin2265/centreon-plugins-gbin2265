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

package storage::hp::msa2000::restapi::mode::interface;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s, link: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state},
        $self->{result_values}->{link_status}
    );
}

sub prefix_interface_output {
    my ($self, %options) = @_;

    return sprintf(
        "Interface '%s' [Controller: %s, MAC: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{controller},
        $options{instance_value}->{mac}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'interfaces', type => 1, cb_prefix_output => 'prefix_interface_output', message_multiple => 'All interfaces are ok' }
    ];

    $self->{maps_counters}->{global} = [];

    $self->{maps_counters}->{interfaces} = [
        {
            label => 'interface-status',
            type => 2,
            warning_default => '%{health} =~ /warning/i',
            critical_default => '%{health} =~ /critical/i || %{link_status} !~ /LinkUp/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'controller' }, { name => 'mac' }, { name => 'link_status' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'interface-speed', nlabel => 'interface.speed.mbps', set => {
                key_values => [ { name => 'speed' }, { name => 'name' } ],
                output_template => 'speed: %s Mbps',
                perfdatas => [
                    { template => '%s', unit => 'Mbps', min => 0, label_extra_instance => 1, instance_use => 'name' }
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
        'filter-interface-id:s'  => { name => 'filter_interface_id' },
        'filter-interface-name:s' => { name => 'filter_interface_name' },
        'exclude-controller-id:s' => { name => 'exclude_controller_id' },
        'exclude-interface-id:s' => { name => 'exclude_interface_id' },
        'exclude-interface-name:s' => { name => 'exclude_interface_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = {};
    $self->{interfaces} = {};

    my $managers_result = $options{custom}->request_api(url_path => '/redfish/v1/Managers');
    return if (!defined($managers_result) || !defined($managers_result->{Members}));

    foreach my $manager (@{$managers_result->{Members}}) {
        next if (!defined($manager->{'@odata.id'}));
        
        my $manager_data = $options{custom}->request_api(
            url_path => $manager->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($manager_data));

        my $controller_id;
        if (defined($manager_data->{Id})) {
            $controller_id = $manager_data->{Id};
        } elsif ($manager->{'@odata.id'} =~ /\/Managers\/([^\/]+)/) {
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

        next if (!defined($manager_data->{EthernetInterfaces}) || !defined($manager_data->{EthernetInterfaces}->{'@odata.id'}));

        my $interfaces_result = $options{custom}->request_api(
            url_path => $manager_data->{EthernetInterfaces}->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($interfaces_result) || !defined($interfaces_result->{Members}) || ref($interfaces_result->{Members}) ne 'ARRAY');

        foreach my $iface_ref (@{$interfaces_result->{Members}}) {
            next if (!defined($iface_ref->{'@odata.id'}));
            
            my $iface_data = $options{custom}->request_api(
                url_path => $iface_ref->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($iface_data));

            my $iface_id;
            if (defined($iface_data->{Id})) {
                $iface_id = $iface_data->{Id};
            } elsif ($iface_ref->{'@odata.id'} =~ /\/EthernetInterfaces\/([^\/]+)/) {
                $iface_id = $1;
            } else {
                next;
            }

            my $iface_full_id = $controller_id . '_' . $iface_id;

            if (defined($self->{option_results}->{filter_interface_id}) && $self->{option_results}->{filter_interface_id} ne '' &&
                $iface_full_id !~ /$self->{option_results}->{filter_interface_id}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_interface_id}) && $self->{option_results}->{exclude_interface_id} ne '' &&
                $iface_full_id =~ /$self->{option_results}->{exclude_interface_id}/) {
                next;
            }

            my $iface_name = defined($iface_data->{Name}) ? $iface_data->{Name} : $iface_id;

            if (defined($self->{option_results}->{filter_interface_name}) && $self->{option_results}->{filter_interface_name} ne '' &&
                $iface_name !~ /$self->{option_results}->{filter_interface_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_interface_name}) && $self->{option_results}->{exclude_interface_name} ne '' &&
                $iface_name =~ /$self->{option_results}->{exclude_interface_name}/) {
                next;
            }

            my $health = 'n/a';
            my $state = 'n/a';
            if (defined($iface_data->{Status})) {
                $health = defined($iface_data->{Status}->{Health}) ? $iface_data->{Status}->{Health} : 'n/a';
                $state = defined($iface_data->{Status}->{State}) ? $iface_data->{Status}->{State} : 'n/a';
            }
            next if ($state =~ /^Absent$/i);

            my $link_status = defined($iface_data->{LinkStatus}) ? $iface_data->{LinkStatus} : 'n/a';

            $self->{interfaces}->{$iface_full_id} = {
                name        => $iface_name,
                controller  => $controller_id,
                health      => $health,
                state       => $state,
                link_status => $link_status,
                mac         => defined($iface_data->{MACAddress}) ? $iface_data->{MACAddress} : 'n/a',
                speed       => defined($iface_data->{SpeedMbps}) ? $iface_data->{SpeedMbps} : undef,
            };
        }
    }

    if (scalar(keys %{$self->{interfaces}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No interfaces found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA network interfaces status via Redfish API.

=over 8

=item B<--filter-controller-id>

Filter by controller id (can be a regexp).

=item B<--filter-interface-id>

Filter by interface id (can be a regexp).

=item B<--filter-interface-name>

Filter by interface name (can be a regexp).

=item B<--exclude-controller-id>

Exclude by controller id (can be a regexp).

=item B<--exclude-interface-id>

Exclude by interface id (can be a regexp).

=item B<--exclude-interface-name>

Exclude by interface name (can be a regexp).

=item B<--warning-interface-status> B<--critical-interface-status>

Set warning/critical threshold for interface status.
Default warning: '%{health} =~ /warning/i'
Default critical: '%{health} =~ /critical/i || %{link_status} !~ /LinkUp/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'interface-speed'.

=back

=cut
