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

package network::brocade::restapi::mode::accessgateway;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_nport_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s, attached F-ports: %s, failover: %s, failback: %s",
        $self->{result_values}->{status},
        $self->{result_values}->{fport_count},
        $self->{result_values}->{failover},
        $self->{result_values}->{failback}
    );
}

sub custom_fport_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s, N-port: %s",
        $self->{result_values}->{status},
        $self->{result_values}->{nport}
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Access Gateway: ';
}

sub prefix_nport_output {
    my ($self, %options) = @_;

    return "N-port '" . $options{instance_value}->{display} . "' ";
}

sub prefix_fport_output {
    my ($self, %options) = @_;

    return "F-port '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'nports', type => 1, cb_prefix_output => 'prefix_nport_output', message_multiple => 'All N-ports are ok' },
        { name => 'fports', type => 1, cb_prefix_output => 'prefix_fport_output', message_multiple => 'All F-ports are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'nports-total', nlabel => 'accessgateway.nports.total.count', set => {
                key_values => [ { name => 'nports_total' } ],
                output_template => 'N-ports: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'nports-online', nlabel => 'accessgateway.nports.online.count', set => {
                key_values => [ { name => 'nports_online' } ],
                output_template => 'N-ports online: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'nports-offline', nlabel => 'accessgateway.nports.offline.count', set => {
                key_values => [ { name => 'nports_offline' } ],
                output_template => 'N-ports offline: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'fports-total', nlabel => 'accessgateway.fports.total.count', set => {
                key_values => [ { name => 'fports_total' } ],
                output_template => 'F-ports: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'fports-online', nlabel => 'accessgateway.fports.online.count', set => {
                key_values => [ { name => 'fports_online' } ],
                output_template => 'F-ports online: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{nports} = [
        {
            label => 'nport-status',
            type => 2,
            critical_default => '%{status} !~ /online/i',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'fport_count' },
                    { name => 'failover' }, { name => 'failback' }, { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_nport_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'nport-fports', nlabel => 'nport.fports.attached.count', set => {
                key_values => [ { name => 'fport_count' }, { name => 'display' } ],
                output_template => 'attached F-ports: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{fports} = [
        {
            label => 'fport-status',
            type => 2,
            critical_default => '%{status} !~ /online/i',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'nport' }, { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_fport_status_output'),
                closure_custom_perfdata => sub { return 0; },
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
        'filter-nport:s' => { name => 'filter_nport' },
        'filter-fport:s' => { name => 'filter_fport' },
        'exclude-nport:s' => { name => 'exclude_nport' },
        'exclude-fport:s' => { name => 'exclude_fport' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $nport_data = $options{custom}->get_ag_nport_map();
    my $fport_data = $options{custom}->get_ag_fport_list();

    $self->{global} = { 
        nports_total => 0, nports_online => 0, nports_offline => 0,
        fports_total => 0, fports_online => 0
    };
    $self->{nports} = {};
    $self->{fports} = {};

    # Parse N-port map
    my $nport_list = $nport_data->{'Response'}->{'n-port-map'} // 
                     $nport_data->{'brocade-access-gateway'}->{'n-port-map'} // [];
    $nport_list = [$nport_list] if (ref($nport_list) ne 'ARRAY');

    foreach my $nport (@{$nport_list}) {
        my $nport_name = $nport->{'n-port'} // $nport->{'n-port-id'} // next;
        my $status = $nport->{'n-port-status'} // $nport->{'status'} // 'unknown';
        my $failover = $nport->{'failover-enabled'} // 0;
        my $failback = $nport->{'failback-enabled'} // 0;
        $failover = $failover ? 'enabled' : 'disabled';
        $failback = $failback ? 'enabled' : 'disabled';

        # Count attached F-ports
        my $fports = $nport->{'attached-f-port-list'}->{'f-port'} // 
                     $nport->{'configured-f-port-list'}->{'f-port'} // [];
        $fports = [$fports] if (ref($fports) ne 'ARRAY');
        my $fport_count = scalar(@{$fports});

        # Apply filters
        if (defined($self->{option_results}->{filter_nport}) && $self->{option_results}->{filter_nport} ne '' &&
            $nport_name !~ /$self->{option_results}->{filter_nport}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_nport}) && $self->{option_results}->{exclude_nport} ne '' &&
            $nport_name =~ /$self->{option_results}->{exclude_nport}/) {
            next;
        }

        $self->{global}->{nports_total}++;
        
        # Map status
        if ($status =~ /^\d+$/) {
            my %status_map = ( 2 => 'online', 3 => 'offline' );
            $status = $status_map{$status} // 'unknown';
        }
        
        if ($status =~ /online/i) {
            $self->{global}->{nports_online}++;
        } else {
            $self->{global}->{nports_offline}++;
        }

        $self->{nports}->{$nport_name} = {
            display => $nport_name,
            status => lc($status),
            fport_count => $fport_count,
            failover => $failover,
            failback => $failback
        };
    }

    # Parse F-port list
    my $fport_list = $fport_data->{'Response'}->{'f-port-list'} // 
                     $fport_data->{'brocade-access-gateway'}->{'f-port-list'} // [];
    $fport_list = [$fport_list] if (ref($fport_list) ne 'ARRAY');

    foreach my $fport (@{$fport_list}) {
        my $fport_name = $fport->{'f-port'} // $fport->{'f-port-id'} // next;
        my $status = $fport->{'f-port-status'} // $fport->{'status'} // 'unknown';
        my $nport = $fport->{'n-port'} // $fport->{'attached-n-port'} // 'none';

        # Apply filters
        if (defined($self->{option_results}->{filter_fport}) && $self->{option_results}->{filter_fport} ne '' &&
            $fport_name !~ /$self->{option_results}->{filter_fport}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_fport}) && $self->{option_results}->{exclude_fport} ne '' &&
            $fport_name =~ /$self->{option_results}->{exclude_fport}/) {
            next;
        }

        $self->{global}->{fports_total}++;
        
        # Map status
        if ($status =~ /^\d+$/) {
            my %status_map = ( 2 => 'online', 3 => 'offline' );
            $status = $status_map{$status} // 'unknown';
        }
        
        if ($status =~ /online/i) {
            $self->{global}->{fports_online}++;
        }

        $self->{fports}->{$fport_name} = {
            display => $fport_name,
            status => lc($status),
            nport => $nport
        };
    }

    if (scalar(keys %{$self->{nports}}) <= 0 && scalar(keys %{$self->{fports}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No Access Gateway data found (AG mode not enabled).");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check Access Gateway (AG) mode status, N-port and F-port mappings.

=over 8

=item B<--filter-nport>

Filter N-ports by name (can be a regexp).

=item B<--filter-fport>

Filter F-ports by name (can be a regexp).

=item B<--exclude-nport>

Exclude N-ports by name (can be a regexp).

=item B<--exclude-fport>

Exclude F-ports by name (can be a regexp).

=item B<--unknown-nport-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{fport_count}, %{failover}, %{failback}, %{display}

=item B<--warning-nport-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{fport_count}, %{failover}, %{failback}, %{display}

=item B<--critical-nport-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /online/i').
You can use the following variables: %{status}, %{fport_count}, %{failover}, %{failback}, %{display}

=item B<--unknown-fport-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{nport}, %{display}

=item B<--warning-fport-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{nport}, %{display}

=item B<--critical-fport-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /online/i').
You can use the following variables: %{status}, %{nport}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'nports-total', 'nports-online', 'nports-offline',
'fports-total', 'fports-online', 'nport-fports'.

=back

=cut
