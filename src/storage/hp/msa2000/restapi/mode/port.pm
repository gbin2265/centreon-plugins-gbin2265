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

package storage::hp::msa2000::restapi::mode::port;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state}
    );
}

sub prefix_port_output {
    my ($self, %options) = @_;

    return sprintf(
        "Port '%s' [Fabric: %s, Protocol: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{fabric},
        $options{instance_value}->{protocol}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'ports', type => 1, cb_prefix_output => 'prefix_port_output', message_multiple => 'All ports are ok' }
    ];

    $self->{maps_counters}->{global} = [];

    $self->{maps_counters}->{ports} = [
        {
            label => 'port-status',
            type => 2,
            warning_default => '%{health} =~ /warning/i',
            critical_default => '%{health} =~ /critical/i || %{state} !~ /Enabled/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'fabric' }, { name => 'protocol' }, { name => 'wwn' }
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
        'filter-fabric:s'   => { name => 'filter_fabric' },
        'filter-port-id:s'  => { name => 'filter_port_id' },
        'filter-protocol:s' => { name => 'filter_protocol' },
        'filter-port-name:s' => { name => 'filter_port_name' },
        'exclude-fabric:s' => { name => 'exclude_fabric' },
        'exclude-port-id:s' => { name => 'exclude_port_id' },
        'exclude-port-name:s' => { name => 'exclude_port_name' },
        'exclude-protocol:s' => { name => 'exclude_protocol' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = {};
    $self->{ports} = {};

    my $fabrics_result = $options{custom}->request_api(url_path => '/redfish/v1/Fabrics');
    return if (!defined($fabrics_result) || !defined($fabrics_result->{Members}));

    foreach my $fabric (@{$fabrics_result->{Members}}) {
        next if (!defined($fabric->{'@odata.id'}));
        
        my $fabric_data = $options{custom}->request_api(
            url_path => $fabric->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($fabric_data));

        my $fabric_id;
        if (defined($fabric_data->{Id})) {
            $fabric_id = $fabric_data->{Id};
        } elsif ($fabric->{'@odata.id'} =~ /\/Fabrics\/([^\/]+)/) {
            $fabric_id = $1;
        } else {
            next;
        }

        my $fabric_type = defined($fabric_data->{FabricType}) ? $fabric_data->{FabricType} : $fabric_id;

        if (defined($self->{option_results}->{filter_fabric}) && $self->{option_results}->{filter_fabric} ne '' &&
            $fabric_id !~ /$self->{option_results}->{filter_fabric}/) {
            next;
        }


        if (defined($self->{option_results}->{exclude_fabric}) && $self->{option_results}->{exclude_fabric} ne '' &&
            $fabric_id =~ /$self->{option_results}->{exclude_fabric}/) {
            next;
        }

        if (defined($self->{option_results}->{filter_protocol}) && $self->{option_results}->{filter_protocol} ne '' &&
            $fabric_type !~ /$self->{option_results}->{filter_protocol}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_protocol}) && $self->{option_results}->{exclude_protocol} ne '' &&
            $fabric_type =~ /$self->{option_results}->{exclude_protocol}/) {
            next;
        }

        next if (!defined($fabric_data->{Endpoints}) || !defined($fabric_data->{Endpoints}->{'@odata.id'}));

        my $endpoints_result = $options{custom}->request_api(
            url_path => $fabric_data->{Endpoints}->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($endpoints_result) || !defined($endpoints_result->{Members}) || ref($endpoints_result->{Members}) ne 'ARRAY');

        foreach my $endpoint_ref (@{$endpoints_result->{Members}}) {
            next if (!defined($endpoint_ref->{'@odata.id'}));
            
            my $endpoint_data = $options{custom}->request_api(
                url_path => $endpoint_ref->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($endpoint_data));

            my $port_id;
            if (defined($endpoint_data->{Id})) {
                $port_id = $endpoint_data->{Id};
            } elsif ($endpoint_ref->{'@odata.id'} =~ /\/Endpoints\/([^\/]+)/) {
                $port_id = $1;
            } else {
                next;
            }

            my $description = defined($endpoint_data->{Description}) ? $endpoint_data->{Description} : '';
            next if ($description =~ /initiator/i);

            my $port_full_id = $fabric_id . '_' . $port_id;

            if (defined($self->{option_results}->{filter_port_id}) && $self->{option_results}->{filter_port_id} ne '' &&
                $port_id !~ /$self->{option_results}->{filter_port_id}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_port_id}) && $self->{option_results}->{exclude_port_id} ne '' &&
                $port_id =~ /$self->{option_results}->{exclude_port_id}/) {
                next;
            }

            my $port_name = defined($endpoint_data->{Name}) ? $endpoint_data->{Name} : $port_id;

            if (defined($self->{option_results}->{filter_port_name}) && $self->{option_results}->{filter_port_name} ne '' &&
                $port_name !~ /$self->{option_results}->{filter_port_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_port_name}) && $self->{option_results}->{exclude_port_name} ne '' &&
                $port_name =~ /$self->{option_results}->{exclude_port_name}/) {
                next;
            }

            my $health = 'n/a';
            my $state = 'n/a';
            if (defined($endpoint_data->{Status})) {
                $health = defined($endpoint_data->{Status}->{Health}) ? $endpoint_data->{Status}->{Health} : 'n/a';
                $state = defined($endpoint_data->{Status}->{State}) ? $endpoint_data->{Status}->{State} : 'n/a';
            }
            next if ($state =~ /^Absent$/i);

            my $wwn = 'n/a';
            if (defined($endpoint_data->{Identifiers}) && ref($endpoint_data->{Identifiers}) eq 'ARRAY') {
                foreach my $ident (@{$endpoint_data->{Identifiers}}) {
                    if (defined($ident->{DurableName})) {
                        $wwn = $ident->{DurableName};
                        last;
                    }
                }
            }

            $self->{ports}->{$port_full_id} = {
                name      => $port_name,
                fabric    => $fabric_id,
                protocol  => $fabric_type,
                health    => $health,
                state     => $state,
                wwn       => $wwn,
            };
        }
    }

    if (scalar(keys %{$self->{ports}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No ports found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA FC and SAS fabric ports status via Redfish API.

=over 8

=item B<--filter-fabric>

Filter by fabric (can be a regexp).

=item B<--filter-port-id>

Filter by port id (can be a regexp).

=item B<--filter-port-name>

Filter by port name (can be a regexp).

=item B<--filter-protocol>

Filter by protocol (can be a regexp).

=item B<--exclude-fabric>

Exclude by fabric (can be a regexp).

=item B<--exclude-port-id>

Exclude by port id (can be a regexp).

=item B<--exclude-port-name>

Exclude by port name (can be a regexp).

=item B<--exclude-protocol>

Exclude by protocol (can be a regexp).

=item B<--warning-port-status> B<--critical-port-status>

Set warning/critical threshold for port status.
Default warning: '%{health} =~ /warning/i'
Default critical: '%{health} =~ /critical/i || %{state} !~ /Enabled/i'

=back

=cut
