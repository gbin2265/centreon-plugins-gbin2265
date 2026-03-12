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

package storage::hp::msa2000::restapi::mode::fcinitiator;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s, type: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state},
        $self->{result_values}->{endpoint_type}
    );
}

sub prefix_initiator_output {
    my ($self, %options) = @_;

    return sprintf(
        "FC Initiator '%s' [WWPN: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{wwpn}
    );
}

sub prefix_port_output {
    my ($self, %options) = @_;

    return sprintf(
        "FC Port '%s' ",
        $options{instance_value}->{name}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'initiators', type => 1, cb_prefix_output => 'prefix_initiator_output', message_multiple => 'All FC initiators are ok' },
        { name => 'ports', type => 1, cb_prefix_output => 'prefix_port_output', message_multiple => 'All FC ports are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'initiators-total', nlabel => 'fc.initiators.total.count', set => {
                key_values => [ { name => 'total_initiators' } ],
                output_template => 'total FC initiators: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'initiators-ok', nlabel => 'fc.initiators.ok.count', display_ok => 0, set => {
                key_values => [ { name => 'initiators_ok' } ],
                output_template => 'FC initiators ok: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'initiators-degraded', nlabel => 'fc.initiators.degraded.count', display_ok => 0, set => {
                key_values => [ { name => 'initiators_degraded' } ],
                output_template => 'FC initiators degraded: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'ports-total', nlabel => 'fc.ports.total.count', set => {
                key_values => [ { name => 'total_ports' } ],
                output_template => 'total FC ports: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'ports-ok', nlabel => 'fc.ports.ok.count', display_ok => 0, set => {
                key_values => [ { name => 'ports_ok' } ],
                output_template => 'FC ports ok: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{initiators} = [
        {
            label => 'initiator-status',
            type => 2,
            warning_default => '%{health} =~ /warning|degraded/i',
            critical_default => '%{health} =~ /critical/i || %{state} !~ /enabled/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'wwpn' }, { name => 'endpoint_type' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{ports} = [
        {
            label => 'port-status',
            type => 2,
            warning_default => '%{health} =~ /warning|degraded/i',
            critical_default => '%{health} =~ /critical/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'endpoint_type' }
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
        'filter-initiator-name:s' => { name => 'filter_initiator_name' },
        'filter-initiator-wwpn:s' => { name => 'filter_initiator_wwpn' },
        'filter-port-name:s'      => { name => 'filter_port_name' },
        'exclude-ports'           => { name => 'exclude_ports' },
        'exclude-initiators'      => { name => 'exclude_initiators' },
        'exclude-initiator-name:s' => { name => 'exclude_initiator_name' },
        'exclude-initiator-wwpn:s' => { name => 'exclude_initiator_wwpn' },
        'exclude-port-name:s' => { name => 'exclude_port_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { 
        total_initiators => 0, 
        initiators_ok => 0, 
        initiators_degraded => 0,
        total_ports => 0,
        ports_ok => 0
    };
    $self->{initiators} = {};
    $self->{ports} = {};

    # Controller port IDs
    my %controller_ports = map { $_ => 1 } ('A1','A2','A3','A4','B1','B2','B3','B4');

    # Get FC Fabric endpoints
    my $fabrics_result = $options{custom}->request_api(
        url_path => '/redfish/v1/Fabrics',
        ignore_codes => { 404 => 1 }
    );
    
    return if (!defined($fabrics_result) || !defined($fabrics_result->{Members}));

    foreach my $fabric (@{$fabrics_result->{Members}}) {
        next if (!defined($fabric->{'@odata.id'}));
        
        my $fabric_data = $options{custom}->request_api(
            url_path => $fabric->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($fabric_data));

        # Get endpoints collection
        my $endpoints_path;
        if (defined($fabric_data->{Endpoints}) && defined($fabric_data->{Endpoints}->{'@odata.id'})) {
            $endpoints_path = $fabric_data->{Endpoints}->{'@odata.id'};
        } else {
            $endpoints_path = $fabric->{'@odata.id'} . '/Endpoints';
        }

        my $endpoints_result = $options{custom}->request_api(
            url_path => $endpoints_path,
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($endpoints_result) || !defined($endpoints_result->{Members}));

        foreach my $endpoint_ref (@{$endpoints_result->{Members}}) {
            next if (!defined($endpoint_ref->{'@odata.id'}));
            
            my $endpoint_data = $options{custom}->request_api(
                url_path => $endpoint_ref->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            next if (!defined($endpoint_data));

            my $endpoint_id = defined($endpoint_data->{Id}) ? $endpoint_data->{Id} : 'unknown';
            my $endpoint_name = defined($endpoint_data->{Name}) ? $endpoint_data->{Name} : $endpoint_id;
            
            my $health = 'n/a';
            my $state = 'n/a';
            if (defined($endpoint_data->{Status})) {
                $health = defined($endpoint_data->{Status}->{Health}) ? $endpoint_data->{Status}->{Health} : 'n/a';
                $state = defined($endpoint_data->{Status}->{State}) ? $endpoint_data->{Status}->{State} : 'n/a';
            }
            next if ($state =~ /^Absent$/i);

            my $endpoint_type = 'unknown';
            
            # Determine if this is a controller port or host initiator
            if (exists($controller_ports{$endpoint_id})) {
                # This is a controller FC port
                $endpoint_type = 'port';
                
                next if (defined($self->{option_results}->{exclude_ports}));
                
                if (defined($self->{option_results}->{filter_port_name}) && $self->{option_results}->{filter_port_name} ne '' &&
                    $endpoint_name !~ /$self->{option_results}->{filter_port_name}/) {
                    next;
                }

                
                if (defined($self->{option_results}->{exclude_port_name}) && $self->{option_results}->{exclude_port_name} ne '' &&
                    $endpoint_name =~ /$self->{option_results}->{exclude_port_name}/) {
                    next;
                }

                $self->{ports}->{$endpoint_id} = {
                    name          => $endpoint_name,
                    health        => $health,
                    state         => $state,
                    endpoint_type => $endpoint_type,
                };
                
                $self->{global}->{total_ports}++;
                if ($health =~ /^OK$/i) {
                    $self->{global}->{ports_ok}++;
                }
            } else {
                # This is a host FC initiator
                $endpoint_type = 'initiator';
                
                next if (defined($self->{option_results}->{exclude_initiators}));
                
                if (defined($self->{option_results}->{filter_initiator_name}) && $self->{option_results}->{filter_initiator_name} ne '' &&
                    $endpoint_name !~ /$self->{option_results}->{filter_initiator_name}/) {
                    next;
                }

                
                if (defined($self->{option_results}->{exclude_initiator_name}) && $self->{option_results}->{exclude_initiator_name} ne '' &&
                    $endpoint_name =~ /$self->{option_results}->{exclude_initiator_name}/) {
                    next;
                }

                if (defined($self->{option_results}->{filter_initiator_wwpn}) && $self->{option_results}->{filter_initiator_wwpn} ne '' &&
                    $endpoint_id !~ /$self->{option_results}->{filter_initiator_wwpn}/) {
                    next;
                }

                if (defined($self->{option_results}->{exclude_initiator_wwpn}) && $self->{option_results}->{exclude_initiator_wwpn} ne '' &&
                    $endpoint_id =~ /$self->{option_results}->{exclude_initiator_wwpn}/) {
                    next;
                }

                $self->{initiators}->{$endpoint_id} = {
                    name          => $endpoint_name,
                    wwpn          => $endpoint_id,
                    health        => $health,
                    state         => $state,
                    endpoint_type => $endpoint_type,
                };
                
                $self->{global}->{total_initiators}++;
                if ($health =~ /^OK$/i) {
                    $self->{global}->{initiators_ok}++;
                } elsif ($health =~ /degraded|warning/i) {
                    $self->{global}->{initiators_degraded}++;
                }
            }
        }
    }

    if (scalar(keys %{$self->{initiators}}) <= 0 && scalar(keys %{$self->{ports}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No FC endpoints found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA FC initiators and ports status via Redfish API.

Monitors Fibre Channel host initiators (HBAs) and controller FC ports.

=over 8

=item B<--filter-initiator-name>

Filter by initiator name (can be a regexp).

=item B<--filter-initiator-wwpn>

Filter by initiator wwpn (can be a regexp).

=item B<--filter-port-name>

Filter by port name (can be a regexp).

=item B<--exclude-initiators>

Exclude by initiators (can be a regexp).

=item B<--exclude-initiator-name>

Exclude by initiator name (can be a regexp).

=item B<--exclude-initiator-wwpn>

Exclude by initiator wwpn (can be a regexp).

=item B<--exclude-ports>

Exclude by ports (can be a regexp).

=item B<--exclude-port-name>

Exclude by port name (can be a regexp).

=item B<--warning-initiator-status> B<--critical-initiator-status>

Set warning/critical threshold for initiator status.
Available macros: %{health}, %{state}, %{name}.
Default warning: '%{health} =~ /warning|degraded/i'
Default critical: '%{health} =~ /critical/i || %{state} !~ /enabled/i'

=item B<--warning-port-status> B<--critical-port-status>

Set warning/critical threshold for port status.
Available macros: %{health}, %{state}, %{name}.
Default warning: '%{health} =~ /warning|degraded/i'
Default critical: '%{health} =~ /critical/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'initiators-degraded', 'initiators-ok', 'initiators-total', 'ports-ok', 'ports-total'.

=back

=cut
