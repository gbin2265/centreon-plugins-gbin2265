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

package network::brocade::restapi::mode::isl;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use Digest::MD5 qw(md5_hex);

sub custom_isl_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [speed: %s Gbps] [neighbor: %s - %s]",
        $self->{result_values}->{status},
        $self->{result_values}->{speed},
        $self->{result_values}->{neighbor_switch},
        $self->{result_values}->{neighbor_port}
    );
}

sub prefix_isl_output {
    my ($self, %options) = @_;

    return "ISL '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ' },
        { name => 'isls', type => 1, cb_prefix_output => 'prefix_isl_output', message_multiple => 'All ISLs are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'isls-total', nlabel => 'isl.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total ISLs: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'isls-online', nlabel => 'isl.online.count', set => {
                key_values => [ { name => 'online' } ],
                output_template => 'online: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'isls-offline', nlabel => 'isl.offline.count', set => {
                key_values => [ { name => 'offline' } ],
                output_template => 'offline: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{isls} = [
        {
            label => 'isl-status',
            type => 2,
            critical_default => '%{status} !~ /online|up/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'speed' }, 
                               { name => 'neighbor_switch' }, { name => 'neighbor_port' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_isl_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'isl-traffic-in', nlabel => 'isl.traffic.in.bitspersecond', set => {
                key_values => [ { name => 'traffic_in', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic in: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'isl-traffic-out', nlabel => 'isl.traffic.out.bitspersecond', set => {
                key_values => [ { name => 'traffic_out', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic out: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-port:s'            => { name => 'filter_port' },
        'filter-neighbor-switch:s' => { name => 'filter_neighbor_switch' },
        'exclude-port:s'           => { name => 'exclude_port' },
        'exclude-neighbor-switch:s' => { name => 'exclude_neighbor_switch' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $ports = $options{custom}->get_fcport_info();
    my $stats = $options{custom}->get_fcport_statistics();

    $self->{global} = { total => 0, online => 0, offline => 0 };
    $self->{isls} = {};
    $self->{cache_name} = 'brocade_restapi_' . $options{custom}->get_hostname() . '_' . $options{custom}->get_port() . '_' .
        $self->{mode} . '_' . (defined($self->{option_results}->{filter_port}) ? md5_hex($self->{option_results}->{filter_port}) : md5_hex('all'));

    # Parse port data
    my $port_list = $ports->{'Response'}->{'fibrechannel'} // $ports->{'brocade-interface'}->{'fibrechannel'} // [];
    $port_list = [$port_list] if (ref($port_list) ne 'ARRAY');

    # Parse statistics
    my $stats_list = $stats->{'Response'}->{'fibrechannel-statistics'} // $stats->{'brocade-interface'}->{'fibrechannel-statistics'} // [];
    $stats_list = [$stats_list] if (ref($stats_list) ne 'ARRAY');

    # Create stats lookup
    my %stats_lookup;
    foreach my $stat (@{$stats_list}) {
        my $name = $stat->{'name'} // next;
        $stats_lookup{$name} = $stat;
    }

    foreach my $port (@{$port_list}) {
        my $port_name = $port->{'name'} // next;
        my $port_type = $port->{'port-type'} // '';
        
        # Only process E-ports (ISL ports)
        # Port type 7 = E_PORT, 16 = EX_PORT, 19 = VE_PORT
        next if ($port_type !~ /^(7|16|19|E_PORT|EX_PORT|VE_PORT)$/i && 
                 $port_type !~ /e.port/i);

        if (defined($self->{option_results}->{filter_port}) && $self->{option_results}->{filter_port} ne '' &&
            $port_name !~ /$self->{option_results}->{filter_port}/) {
            next;
        }

        my $neighbor = $port->{'neighbor'};
        my $neighbor_switch = (defined($neighbor) ? $neighbor->{'wwn'} : undef) // $port->{'neighbor-wwn'} // 'unknown';
        my $neighbor_port = (defined($neighbor) ? $neighbor->{'port-name'} : undef) // $port->{'neighbor-port'} // 'unknown';

        if (defined($self->{option_results}->{filter_neighbor_switch}) && $self->{option_results}->{filter_neighbor_switch} ne '' &&
            $neighbor_switch !~ /$self->{option_results}->{filter_neighbor_switch}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_port}) && $self->{option_results}->{exclude_port} ne '' &&
            $port_name =~ /$self->{option_results}->{exclude_port}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_neighbor_switch}) && $self->{option_results}->{exclude_neighbor_switch} ne '' &&
            $neighbor_switch =~ /$self->{option_results}->{exclude_neighbor_switch}/) {
            next;
        }

        $self->{global}->{total}++;

        # Get operational status
        my $oper_status = $port->{'operational-status'} // 0;
        my %oper_map = ( 0 => 'unknown', 2 => 'online', 3 => 'offline', 5 => 'faulty' );
        my $status = $oper_map{$oper_status} // lc($oper_status);

        if ($status eq 'online') {
            $self->{global}->{online}++;
        } else {
            $self->{global}->{offline}++;
        }

        # Get speed
        my $speed = $port->{'speed'} // 0;
        my $speed_gbps = ($speed > 1000000000) ? $speed / 1000000000 : $speed;

        # Get statistics
        my $stat = $stats_lookup{$port_name} // {};
        my $in_bytes = $stat->{'in-octets'} // 0;
        my $out_bytes = $stat->{'out-octets'} // 0;

        $self->{isls}->{$port_name} = {
            display => $port_name,
            status => $status,
            speed => $speed_gbps,
            neighbor_switch => $neighbor_switch,
            neighbor_port => $neighbor_port,
            traffic_in => $in_bytes * 8,
            traffic_out => $out_bytes * 8
        };
    }

    if (scalar(keys %{$self->{isls}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No ISL ports found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check ISL (Inter-Switch Link) status and traffic.

=over 8

=item B<--filter-port>

Filter ISL ports by name (can be a regexp).

=item B<--filter-neighbor-switch>

Filter by neighbor switch WWN (can be a regexp).

=item B<--exclude-port>

Exclude ISL ports by name (can be a regexp).

=item B<--exclude-neighbor-switch>

Exclude by neighbor switch WWN (can be a regexp).

=item B<--unknown-isl-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{speed}, %{neighbor_switch}, %{neighbor_port}, %{display}

=item B<--warning-isl-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{speed}, %{neighbor_switch}, %{neighbor_port}, %{display}

=item B<--critical-isl-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /online|up/i').
You can use the following variables: %{status}, %{speed}, %{neighbor_switch}, %{neighbor_port}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'isls-total', 'isls-online', 'isls-offline',
'isl-traffic-in', 'isl-traffic-out'.

=back

=cut
