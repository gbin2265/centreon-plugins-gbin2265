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

package network::brocade::restapi::mode::firmware;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_firmware_output {
    my ($self, %options) = @_;

    my $msg = sprintf("firmware: %s", $self->{result_values}->{primary_version});
    if (defined($self->{result_values}->{secondary_version}) && $self->{result_values}->{secondary_version} ne '') {
        $msg .= sprintf(" [secondary: %s]", $self->{result_values}->{secondary_version});
    }
    return $msg;
}

sub custom_fw_mismatch_output {
    my ($self, %options) = @_;

    return sprintf(
        "firmware mismatch: %s",
        $self->{result_values}->{mismatch_status}
    );
}

sub prefix_component_output {
    my ($self, %options) = @_;

    return $options{instance_value}->{type} . " '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'components', type => 1, cb_prefix_output => 'prefix_component_output', message_multiple => 'All firmware versions are ok' }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'firmware-mismatch',
            type => 2,
            critical_default => '%{mismatch_status} eq "yes"',
            set => {
                key_values => [ { name => 'mismatch_status' } ],
                closure_custom_output => $self->can('custom_fw_mismatch_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'components-total', nlabel => 'firmware.components.total.count', display_ok => 0, set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total components: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{components} = [
        {
            label => 'component-firmware',
            type => 2,
            set => {
                key_values => [ { name => 'primary_version' }, { name => 'secondary_version' }, 
                               { name => 'type' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_firmware_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-type:s' => { name => 'filter_type' },
        'filter-slot:s' => { name => 'filter_slot' },
        'exclude-type:s' => { name => 'exclude_type' },
        'exclude-slot:s' => { name => 'exclude_slot' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $switch_data = $options{custom}->get_switch_info();
    my $blade_data = $options{custom}->get_blade_info();

    $self->{global} = { total => 0, mismatch_status => 'no' };
    $self->{components} = {};

    my %all_versions;

    # Get switch firmware
    my $switch_info = $switch_data->{'Response'}->{'fibrechannel-switch'} // 
                      $switch_data->{'brocade-fibrechannel-switch'}->{'fibrechannel-switch'} // {};
    $switch_info = $switch_info->[0] if (ref($switch_info) eq 'ARRAY');

    my $switch_fw = $switch_info->{'firmware-version'} // '';
    if ($switch_fw ne '') {
        $self->{global}->{total}++;
        $all_versions{$switch_fw} = 1;
        
        my $switch_name = $switch_info->{'name'} // $switch_info->{'switch-name'} // 'switch';
        
        if (!defined($self->{option_results}->{filter_type}) || $self->{option_results}->{filter_type} eq '' ||
            'switch' =~ /$self->{option_results}->{filter_type}/i) {
            $self->{components}->{$switch_name} = {
                display => $switch_name,
                type => 'Switch',
                primary_version => $switch_fw,
                secondary_version => ''
            };
        }
    }

    # Get blade firmware
    my $blades = $blade_data->{'Response'}->{'blade'} // $blade_data->{'brocade-fru'}->{'blade'} // [];
    $blades = [$blades] if (ref($blades) ne 'ARRAY');

    foreach my $blade (@{$blades}) {
        my $slot = $blade->{'slot-number'};
        next if (!defined($slot));

        if (defined($self->{option_results}->{filter_slot}) && $self->{option_results}->{filter_slot} ne '' &&
            $slot !~ /$self->{option_results}->{filter_slot}/) {
            next;
        }

        my $blade_type = $blade->{'blade-type'} // 'blade';
        
        if (defined($self->{option_results}->{filter_type}) && $self->{option_results}->{filter_type} ne '' &&
            $blade_type !~ /$self->{option_results}->{filter_type}/i) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_slot}) && $self->{option_results}->{exclude_slot} ne '' &&
            $slot =~ /$self->{option_results}->{exclude_slot}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_type}) && $self->{option_results}->{exclude_type} ne '' &&
            $blade_type =~ /$self->{option_results}->{exclude_type}/i) {
            next;
        }

        my $primary_fw = $blade->{'primary-firmware-version'} // $blade->{'firmware-version'} // '';
        my $secondary_fw = $blade->{'secondary-firmware-version'} // '';

        next if ($primary_fw eq '');

        $self->{global}->{total}++;
        $all_versions{$primary_fw} = 1;

        my $component_name = 'slot' . $slot;
        
        $self->{components}->{$component_name} = {
            display => $component_name,
            type => $blade_type,
            primary_version => $primary_fw,
            secondary_version => $secondary_fw
        };
    }

    # Check for firmware mismatch
    if (scalar(keys %all_versions) > 1) {
        $self->{global}->{mismatch_status} = 'yes';
    }

    if (scalar(keys %{$self->{components}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No firmware information found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check firmware versions across switch components.

=over 8

=item B<--filter-type>

Filter by component type (can be a regexp, e.g. 'CP' or 'FC').

=item B<--filter-slot>

Filter by slot number (can be a regexp).

=item B<--exclude-type>

Exclude by component type (can be a regexp).

=item B<--exclude-slot>

Exclude by slot number (can be a regexp).

=item B<--unknown-firmware-mismatch>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{mismatch_status}

=item B<--warning-firmware-mismatch>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{mismatch_status}

=item B<--critical-firmware-mismatch>

Define the conditions to match for the status to be CRITICAL (default: '%{mismatch_status} eq "yes"').
You can use the following variables: %{mismatch_status}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'components-total'.

=back

=cut
