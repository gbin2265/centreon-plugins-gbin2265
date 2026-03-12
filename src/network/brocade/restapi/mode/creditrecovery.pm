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

package network::brocade::restapi::mode::creditrecovery;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_cr_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "credit recovery mode: %s [backend: %s] [link reset: %s] [fault option: %s]",
        $self->{result_values}->{mode},
        $self->{result_values}->{backend},
        $self->{result_values}->{link_reset},
        $self->{result_values}->{fault_option}
    );
}

sub custom_port_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [recoveries: %d]",
        $self->{result_values}->{status},
        $self->{result_values}->{recovery_count}
    );
}

sub prefix_port_output {
    my ($self, %options) = @_;

    return "Port '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'ports', type => 1, cb_prefix_output => 'prefix_port_output', message_multiple => 'All ports credit recovery ok' }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'cr-status',
            type => 2,
            set => {
                key_values => [ { name => 'mode' }, { name => 'backend' }, 
                               { name => 'link_reset' }, { name => 'fault_option' } ],
                closure_custom_output => $self->can('custom_cr_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'total-recoveries', nlabel => 'creditrecovery.total.count', set => {
                key_values => [ { name => 'total_recoveries' } ],
                output_template => 'total recoveries: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'ports-in-recovery', nlabel => 'creditrecovery.ports.count', set => {
                key_values => [ { name => 'ports_in_recovery' } ],
                output_template => 'ports in recovery: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{ports} = [
        {
            label => 'port-cr-status',
            type => 2,
            warning_default => '%{recovery_count} > 0',
            set => {
                key_values => [ { name => 'status' }, { name => 'recovery_count' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_port_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'port-recovery-count', nlabel => 'port.creditrecovery.count', set => {
                key_values => [ { name => 'recovery_count' }, { name => 'display' } ],
                output_template => 'recovery count: %s',
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
        'filter-port:s'      => { name => 'filter_port' },
        'exclude-port:s'     => { name => 'exclude_port' },
        'show-only-problems' => { name => 'show_only_problems' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $cr_data = $options{custom}->get_credit_recovery();

    $self->{global} = {};
    $self->{ports} = {};

    my $cr_info = $cr_data->{'Response'}->{'credit-recovery'} // $cr_data->{'brocade-chassis'}->{'credit-recovery'} // {};
    $cr_info = $cr_info->[0] if (ref($cr_info) eq 'ARRAY');

    # Global CR configuration
    my $mode = $cr_info->{'mode'} // 'unknown';
    my $backend = $cr_info->{'backend-credit-loss-enabled'} // $cr_info->{'backend'} // 'unknown';
    $backend = $backend ? 'enabled' : 'disabled' if ($backend =~ /^[01]$/);
    my $link_reset = $cr_info->{'link-reset-credit-loss-enabled'} // $cr_info->{'link-reset'} // 'unknown';
    $link_reset = $link_reset ? 'enabled' : 'disabled' if ($link_reset =~ /^[01]$/);
    my $fault_option = $cr_info->{'fault-option'} // 'unknown';

    $self->{global} = {
        mode => $mode,
        backend => $backend,
        link_reset => $link_reset,
        fault_option => $fault_option,
        total_recoveries => 0,
        ports_in_recovery => 0
    };

    # Get per-port credit recovery status from port statistics
    my $ports = $options{custom}->get_fcport_info();
    my $stats = $options{custom}->get_fcport_statistics();

    my $port_list = $ports->{'Response'}->{'fibrechannel'} // $ports->{'brocade-interface'}->{'fibrechannel'} // [];
    $port_list = [$port_list] if (ref($port_list) ne 'ARRAY');

    my $stats_list = $stats->{'Response'}->{'fibrechannel-statistics'} // $stats->{'brocade-interface'}->{'fibrechannel-statistics'} // [];
    $stats_list = [$stats_list] if (ref($stats_list) ne 'ARRAY');

    my %stats_lookup;
    foreach my $stat (@{$stats_list}) {
        my $name = $stat->{'name'} // next;
        $stats_lookup{$name} = $stat;
    }

    foreach my $port (@{$port_list}) {
        my $port_name = $port->{'name'} // next;

        if (defined($self->{option_results}->{filter_port}) && $self->{option_results}->{filter_port} ne '' &&
            $port_name !~ /$self->{option_results}->{filter_port}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_port}) && $self->{option_results}->{exclude_port} ne '' &&
            $port_name =~ /$self->{option_results}->{exclude_port}/) {
            next;
        }

        my $stat = $stats_lookup{$port_name} // {};
        my $bb_credit_zero = $stat->{'bb-credit-zero'} // 0;
        my $cr_count = $stat->{'credit-recovery'} // $stat->{'loss-of-sync'} // 0;
        
        # Skip ports with no issues if filter enabled
        next if (defined($self->{option_results}->{show_only_problems}) && $cr_count == 0);

        my $status = $cr_count > 0 ? 'recovering' : 'normal';
        
        $self->{global}->{total_recoveries} += $cr_count;
        $self->{global}->{ports_in_recovery}++ if ($cr_count > 0);

        $self->{ports}->{$port_name} = {
            display => $port_name,
            status => $status,
            recovery_count => $cr_count
        };
    }
}

1;

__END__

=head1 MODE

Check credit recovery status and per-port recovery events.

=over 8

=item B<--filter-port>

Filter ports by name (can be a regexp).

=item B<--exclude-port>

Exclude ports by name (can be a regexp).

=item B<--show-only-problems>

Only show ports with credit recovery events.

=item B<--unknown-cr-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{mode}, %{backend}, %{link_reset}, %{fault_option}

=item B<--warning-cr-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{mode}, %{backend}, %{link_reset}, %{fault_option}

=item B<--critical-cr-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{mode}, %{backend}, %{link_reset}, %{fault_option}

=item B<--unknown-port-cr-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{recovery_count}, %{display}

=item B<--warning-port-cr-status>

Define the conditions to match for the status to be WARNING (default: '%{recovery_count} > 0').
You can use the following variables: %{status}, %{recovery_count}, %{display}

=item B<--critical-port-cr-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{status}, %{recovery_count}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'total-recoveries', 'ports-in-recovery', 'port-recovery-count'.

=back

=cut
