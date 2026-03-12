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

package network::brocade::restapi::mode::trunk;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use Digest::MD5 qw(md5_hex);

sub custom_trunk_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [members: %d, neighbor: %s]",
        $self->{result_values}->{status},
        $self->{result_values}->{members_count},
        $self->{result_values}->{neighbor_switch}
    );
}

sub prefix_trunk_output {
    my ($self, %options) = @_;

    return "Trunk group '" . $options{instance_value}->{display} . "' ";
}

sub trunk_long_output {
    my ($self, %options) = @_;

    return "checking trunk group '" . $options{instance_value}->{display} . "'";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ' },
        { name => 'trunks', type => 3, cb_prefix_output => 'prefix_trunk_output', cb_long_output => 'trunk_long_output',
          indent_long_output => '    ', message_multiple => 'All trunk groups are ok',
            group => [
                { name => 'status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'performance', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'trunks-total', nlabel => 'trunks.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total trunk groups: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'trunks-up', nlabel => 'trunks.up.count', set => {
                key_values => [ { name => 'up' } ],
                output_template => 'up: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'trunks-down', nlabel => 'trunks.down.count', set => {
                key_values => [ { name => 'down' } ],
                output_template => 'down: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{status} = [
        {
            label => 'trunk-status',
            type => 2,
            critical_default => '%{status} !~ /up/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'members_count' }, 
                               { name => 'neighbor_switch' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_trunk_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{performance} = [
        { label => 'trunk-traffic-in', nlabel => 'trunk.traffic.in.bitspersecond', set => {
                key_values => [ { name => 'traffic_in' }, { name => 'display' } ],
                output_template => 'traffic in: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'trunk-traffic-out', nlabel => 'trunk.traffic.out.bitspersecond', set => {
                key_values => [ { name => 'traffic_out' }, { name => 'display' } ],
                output_template => 'traffic out: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'trunk-throughput', nlabel => 'trunk.throughput.percentage', set => {
                key_values => [ { name => 'throughput_prct' }, { name => 'display' } ],
                output_template => 'throughput: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'trunk-bandwidth', nlabel => 'trunk.bandwidth.gbps', set => {
                key_values => [ { name => 'bandwidth' }, { name => 'display' } ],
                output_template => 'bandwidth: %s Gbps',
                perfdatas => [
                    { template => '%s', unit => 'Gbps', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'trunk-members', nlabel => 'trunk.members.count', set => {
                key_values => [ { name => 'members_count' }, { name => 'display' } ],
                output_template => 'members: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
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
        'filter-trunk-group:s'    => { name => 'filter_trunk_group' },
        'filter-neighbor-switch:s' => { name => 'filter_neighbor_switch' },
        'exclude-trunk-group:s'    => { name => 'exclude_trunk_group' },
        'exclude-neighbor-switch:s' => { name => 'exclude_neighbor_switch' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $trunk_data = $options{custom}->get_trunk_info();
    my $trunk_perf = $options{custom}->get_trunk_performance();

    $self->{global} = { total => 0, up => 0, down => 0 };
    $self->{trunks} = {};

    # Parse trunk info - aggregate members per group
    my $trunks = $trunk_data->{'Response'}->{'trunk'} // $trunk_data->{'brocade-fibrechannel-trunk'}->{'trunk'} // [];
    $trunks = [$trunks] if (ref($trunks) ne 'ARRAY');

    # Group trunk members by group number
    my %trunk_groups;
    foreach my $member (@{$trunks}) {
        my $group = $member->{'group'} // next;
        
        if (!defined($trunk_groups{$group})) {
            $trunk_groups{$group} = {
                members => [],
                neighbor_switch => $member->{'neighbor-switch-name'} // 'unknown',
                neighbor_wwn => $member->{'neighbor-wwn'} // '',
                neighbor_domain => $member->{'neighbor-domain-id'} // '',
                trunk_type => $member->{'trunk-type'} // 'unknown'
            };
        }
        
        push @{$trunk_groups{$group}->{members}}, {
            source_port => $member->{'source-port'},
            dest_port => $member->{'destination-port'},
            master => $member->{'master'} // 0,
            deskew => $member->{'deskew'} // 0
        };
    }

    # Parse performance data - create lookup by group
    my $perf_list = $trunk_perf->{'Response'}->{'performance'} // $trunk_perf->{'brocade-fibrechannel-trunk'}->{'performance'} // [];
    $perf_list = [$perf_list] if (ref($perf_list) ne 'ARRAY');

    my %perf_lookup;
    foreach my $perf (@{$perf_list}) {
        my $group = $perf->{'group'} // next;
        $perf_lookup{$group} = $perf;
    }

    # Process each trunk group
    foreach my $group (sort { $a <=> $b } keys %trunk_groups) {
        my $trunk_info = $trunk_groups{$group};
        my $neighbor_switch = $trunk_info->{neighbor_switch};
        
        # Apply filters
        if (defined($self->{option_results}->{filter_trunk_group}) && $self->{option_results}->{filter_trunk_group} ne '' &&
            $group !~ /$self->{option_results}->{filter_trunk_group}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_neighbor_switch}) && $self->{option_results}->{filter_neighbor_switch} ne '' &&
            $neighbor_switch !~ /$self->{option_results}->{filter_neighbor_switch}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_trunk_group}) && $self->{option_results}->{exclude_trunk_group} ne '' &&
            $group =~ /$self->{option_results}->{exclude_trunk_group}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_neighbor_switch}) && $self->{option_results}->{exclude_neighbor_switch} ne '' &&
            $neighbor_switch =~ /$self->{option_results}->{exclude_neighbor_switch}/) {
            next;
        }

        $self->{global}->{total}++;

        my $trunk_name = 'group' . $group;
        my $members_count = scalar(@{$trunk_info->{members}});

        # Trunk is UP if it has members and performance data
        my $status = 'up';
        my $has_perf = defined($perf_lookup{$group});
        
        if ($members_count == 0) {
            $status = 'down';
            $self->{global}->{down}++;
        } else {
            $self->{global}->{up}++;
        }

        # Get performance data for this group
        my $perf = $perf_lookup{$group} // {};
        
        # tx-throughput and rx-throughput are already in bits/s
        my $tx_throughput = $perf->{'tx-throughput'} // 0;
        my $rx_throughput = $perf->{'rx-throughput'} // 0;
        
        # txrx-percentage is the utilization percentage (string like "3.24")
        my $throughput_prct = $perf->{'txrx-percentage'} // 0;
        $throughput_prct =~ s/[^\d.]//g;  # Remove any non-numeric chars
        $throughput_prct = 0 if ($throughput_prct eq '');
        
        # Bandwidth in Gbps
        my $bandwidth = $perf->{'txrx-bandwidth'} // 0;

        $self->{trunks}->{$trunk_name} = {
            display => $trunk_name,
            status => {
                display => $trunk_name,
                status => $status,
                members_count => $members_count,
                neighbor_switch => $neighbor_switch
            },
            performance => {
                display => $trunk_name,
                traffic_in => $rx_throughput,
                traffic_out => $tx_throughput,
                throughput_prct => $throughput_prct,
                bandwidth => $bandwidth,
                members_count => $members_count
            }
        };
    }

    if (scalar(keys %{$self->{trunks}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No trunk groups found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check trunk group status and performance metrics.

=over 8

=item B<--filter-trunk-group>

Filter trunk groups by group number (can be a regexp).

=item B<--filter-neighbor-switch>

Filter trunk groups by neighbor switch name (can be a regexp).

=item B<--exclude-trunk-group>

Exclude trunk groups by group number (can be a regexp).

=item B<--exclude-neighbor-switch>

Exclude trunk groups by neighbor switch name (can be a regexp).

=item B<--unknown-trunk-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{members_count}, %{neighbor_switch}, %{display}

=item B<--warning-trunk-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{members_count}, %{neighbor_switch}, %{display}

=item B<--critical-trunk-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /up/i').
You can use the following variables: %{status}, %{members_count}, %{neighbor_switch}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'trunks-total', 'trunks-up', 'trunks-down',
'trunk-traffic-in', 'trunk-traffic-out', 'trunk-throughput', 'trunk-bandwidth', 'trunk-members'.

=back

=cut
