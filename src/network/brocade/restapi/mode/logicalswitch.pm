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

package network::brocade::restapi::mode::logicalswitch;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_switch_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s, default: %s, logical-isl: %s, ports: %d",
        $self->{result_values}->{status},
        $self->{result_values}->{default_switch},
        $self->{result_values}->{logical_isl},
        $self->{result_values}->{port_count}
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Logical switches: ';
}

sub prefix_switch_output {
    my ($self, %options) = @_;

    return "Logical switch 'FID-" . $options{instance_value}->{fabric_id} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'switches', type => 1, cb_prefix_output => 'prefix_switch_output', message_multiple => 'All logical switches are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'switches-total', nlabel => 'logical.switches.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'switches-enabled', nlabel => 'logical.switches.enabled.count', set => {
                key_values => [ { name => 'enabled' } ],
                output_template => 'enabled: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'switches-disabled', nlabel => 'logical.switches.disabled.count', set => {
                key_values => [ { name => 'disabled' } ],
                output_template => 'disabled: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{switches} = [
        {
            label => 'switch-status',
            type => 2,
            warning_default => '%{status} eq "disabled"',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'default_switch' },
                    { name => 'logical_isl' }, { name => 'port_count' },
                    { name => 'fabric_id' }, { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_switch_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'switch-ports', nlabel => 'logical.switch.ports.count', set => {
                key_values => [ { name => 'port_count' }, { name => 'display' } ],
                output_template => 'ports: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'switch-ge-ports', nlabel => 'logical.switch.ge.ports.count', set => {
                key_values => [ { name => 'ge_port_count' }, { name => 'display' } ],
                output_template => 'GE ports: %s',
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
        'filter-fabric-id:s'   => { name => 'filter_fabric_id' },
        'exclude-fabric-id:s'  => { name => 'exclude_fabric_id' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $ls_data = $options{custom}->get_logical_switch();

    $self->{global} = { total => 0, enabled => 0, disabled => 0 };
    $self->{switches} = {};

    my $ls_list = $ls_data->{'Response'}->{'fibrechannel-logical-switch'} // 
                  $ls_data->{'brocade-fibrechannel-logical-switch'}->{'fibrechannel-logical-switch'} // [];
    $ls_list = [$ls_list] if (ref($ls_list) ne 'ARRAY');

    foreach my $ls (@{$ls_list}) {
        my $fabric_id = $ls->{'fabric-id'} // next;

        # Apply filters
        if (defined($self->{option_results}->{filter_fabric_id}) && $self->{option_results}->{filter_fabric_id} ne '' &&
            $fabric_id !~ /$self->{option_results}->{filter_fabric_id}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_fabric_id}) && $self->{option_results}->{exclude_fabric_id} ne '' &&
            $fabric_id =~ /$self->{option_results}->{exclude_fabric_id}/) {
            next;
        }

        $self->{global}->{total}++;

        # Get port counts from port-member-list
        my $port_members = $ls->{'port-member-list'}->{'port-member'} // [];
        $port_members = [$port_members] if (ref($port_members) ne 'ARRAY');
        # Filter out empty strings
        my @valid_ports = grep { defined($_) && $_ ne '' } @{$port_members};
        my $port_count = scalar(@valid_ports);
        
        # Get GE port counts
        my $ge_port_members = $ls->{'ge-port-member-list'}->{'port-member'} // [];
        $ge_port_members = [$ge_port_members] if (ref($ge_port_members) ne 'ARRAY');
        my @valid_ge_ports = grep { defined($_) && $_ ne '' } @{$ge_port_members};
        my $ge_port_count = scalar(@valid_ge_ports);

        # Determine status - a logical switch is "enabled" if it has ports assigned
        my $status = ($port_count > 0 || $ge_port_count > 0) ? 'enabled' : 'disabled';
        
        if ($status eq 'enabled') {
            $self->{global}->{enabled}++;
        } else {
            $self->{global}->{disabled}++;
        }

        # Get other properties
        my $default_switch = $ls->{'default-switch'} // $ls->{'default-switch-status'} // 0;
        $default_switch = ($default_switch && $default_switch ne '0') ? 'yes' : 'no';
        
        my $logical_isl = $ls->{'logical-isl-enabled'} // $ls->{'logical-isl-enabled-v2'} // 0;
        $logical_isl = ($logical_isl && $logical_isl ne '0') ? 'enabled' : 'disabled';
        
        my $base_switch = $ls->{'base-switch-enabled'} // $ls->{'base-switch-enabled-v2'} // 0;
        $base_switch = ($base_switch && $base_switch ne '0') ? 'yes' : 'no';
        
        my $switch_wwn = $ls->{'switch-wwn'} // '';

        my $display = 'FID-' . $fabric_id;
        
        $self->{switches}->{$display} = {
            display => $display,
            fabric_id => $fabric_id,
            status => $status,
            default_switch => $default_switch,
            logical_isl => $logical_isl,
            base_switch => $base_switch,
            switch_wwn => $switch_wwn,
            port_count => $port_count,
            ge_port_count => $ge_port_count
        };
    }

    if (scalar(keys %{$self->{switches}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No logical switches found (Virtual Fabrics not enabled).");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check logical switch (Virtual Fabrics) status.

=over 8

=item B<--filter-fabric-id>

Filter logical switches by Fabric ID (can be a regexp).

=item B<--exclude-fabric-id>

Exclude logical switches by Fabric ID (can be a regexp).

=item B<--unknown-switch-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{default_switch}, %{logical_isl}, %{port_count}, %{fabric_id}, %{display}

=item B<--warning-switch-status>

Define the conditions to match for the status to be WARNING (default: '%{status} eq "disabled"').
You can use the following variables: %{status}, %{default_switch}, %{logical_isl}, %{port_count}, %{fabric_id}, %{display}

=item B<--critical-switch-status>

Define the conditions to match for the status to be CRITICAL.
You can use the following variables: %{status}, %{default_switch}, %{logical_isl}, %{port_count}, %{fabric_id}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'switches-total', 'switches-enabled', 'switches-disabled',
'switch-ports', 'switch-ge-ports'.

=back

=cut
