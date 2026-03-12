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

package network::brocade::restapi::mode::blade;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    my $msg = sprintf("status: %s", $self->{result_values}->{status});
    
    if (defined($self->{result_values}->{blade_type}) && $self->{result_values}->{blade_type} ne '') {
        $msg .= sprintf(" [type: %s]", $self->{result_values}->{blade_type});
    }
    if (defined($self->{result_values}->{blade_id}) && $self->{result_values}->{blade_id} ne '') {
        $msg .= sprintf(" [id: %s]", $self->{result_values}->{blade_id});
    }
    
    return $msg;
}

sub custom_info_output {
    my ($self, %options) = @_;

    my $msg = '';
    my @parts;
    
    if (defined($self->{result_values}->{manufacturer}) && $self->{result_values}->{manufacturer} ne '') {
        push @parts, sprintf("manufacturer: %s", $self->{result_values}->{manufacturer});
    }
    if (defined($self->{result_values}->{part_number}) && $self->{result_values}->{part_number} ne '') {
        push @parts, sprintf("part: %s", $self->{result_values}->{part_number});
    }
    if (defined($self->{result_values}->{serial_number}) && $self->{result_values}->{serial_number} ne '') {
        push @parts, sprintf("serial: %s", $self->{result_values}->{serial_number});
    }
    
    $msg = join(', ', @parts) if (scalar(@parts) > 0);
    
    return $msg;
}

sub custom_firmware_output {
    my ($self, %options) = @_;

    my $msg = '';
    my @parts;
    
    if (defined($self->{result_values}->{primary_firmware}) && $self->{result_values}->{primary_firmware} ne '') {
        push @parts, sprintf("primary: %s", $self->{result_values}->{primary_firmware});
    }
    if (defined($self->{result_values}->{secondary_firmware}) && $self->{result_values}->{secondary_firmware} ne '') {
        push @parts, sprintf("secondary: %s", $self->{result_values}->{secondary_firmware});
    }
    
    $msg = join(', ', @parts) if (scalar(@parts) > 0);
    
    return $msg;
}

sub prefix_blade_output {
    my ($self, %options) = @_;

    return "Blade slot '" . $options{instance_value}->{slot} . "' ";
}

sub blade_long_output {
    my ($self, %options) = @_;

    return "checking blade slot '" . $options{instance_value}->{slot} . "'";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'blades', type => 3, cb_prefix_output => 'prefix_blade_output', cb_long_output => 'blade_long_output',
          indent_long_output => '    ', message_multiple => 'All blades are ok',
            group => [
                { name => 'status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'info', type => 0, skipped_code => { -10 => 1 } },
                { name => 'firmware', type => 0, skipped_code => { -10 => 1 } },
                { name => 'metrics', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{status} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{status} !~ /enabled|on/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'blade_type' }, { name => 'blade_id' }, { name => 'slot' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{info} = [
        {
            label => 'info',
            type => 0,
            set => {
                key_values => [ { name => 'manufacturer' }, { name => 'part_number' }, { name => 'serial_number' }, { name => 'slot' } ],
                closure_custom_output => $self->can('custom_info_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];

    $self->{maps_counters}->{firmware} = [
        {
            label => 'firmware',
            type => 0,
            set => {
                key_values => [ { name => 'primary_firmware' }, { name => 'secondary_firmware' }, { name => 'slot' } ],
                closure_custom_output => $self->can('custom_firmware_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];

    $self->{maps_counters}->{metrics} = [
        { label => 'power-consumption', nlabel => 'blade.power.consumption.watt', set => {
                key_values => [ { name => 'power_consumption' }, { name => 'slot' } ],
                output_template => 'power consumption: %s W',
                perfdatas => [
                    { template => '%s', unit => 'W', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'time-alive', nlabel => 'blade.time.alive.seconds', set => {
                key_values => [ { name => 'time_alive' }, { name => 'slot' } ],
                output_template => 'time alive: %s s',
                perfdatas => [
                    { template => '%s', unit => 's', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'time-awake', nlabel => 'blade.time.awake.seconds', set => {
                key_values => [ { name => 'time_awake' }, { name => 'slot' } ],
                output_template => 'time awake: %s s',
                perfdatas => [
                    { template => '%s', unit => 's', min => 0, label_extra_instance => 1 }
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
        'filter-slot:s'       => { name => 'filter_slot' },
        'filter-blade-type:s' => { name => 'filter_blade_type' },
        'exclude-slot:s'       => { name => 'exclude_slot' },
        'exclude-blade-type:s' => { name => 'exclude_blade_type' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $blade_data = $options{custom}->get_blade_info();

    $self->{blades} = {};

    my $blades = $blade_data->{'Response'}->{'blade'} // $blade_data->{'brocade-fru'}->{'blade'} // [];
    $blades = [$blades] if (ref($blades) ne 'ARRAY');

    foreach my $blade (@{$blades}) {
        my $slot = $blade->{'slot-number'};
        next if (!defined($slot));

        my $blade_type = $blade->{'blade-type'} // '';

        # Apply filters
        if (defined($self->{option_results}->{filter_slot}) && $self->{option_results}->{filter_slot} ne '' &&
            $slot !~ /$self->{option_results}->{filter_slot}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_blade_type}) && $self->{option_results}->{filter_blade_type} ne '' &&
            $blade_type !~ /$self->{option_results}->{filter_blade_type}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_slot}) && $self->{option_results}->{exclude_slot} ne '' &&
            $slot =~ /$self->{option_results}->{exclude_slot}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_blade_type}) && $self->{option_results}->{exclude_blade_type} ne '' &&
            $blade_type =~ /$self->{option_results}->{exclude_blade_type}/) {
            next;
        }

        my $slot_name = 'slot' . $slot;
        
        # Get status
        my $status = $blade->{'blade-state'} // $blade->{'power-state'} // 'unknown';
        
        # Get identification info
        my $blade_id = $blade->{'blade-id'} // '';
        my $manufacturer = $blade->{'manufacturer'} // $blade->{'vendor-name'} // '';
        my $part_number = $blade->{'part-number'} // '';
        my $serial_number = $blade->{'serial-number'} // '';
        
        # Get firmware info
        my $primary_fw = $blade->{'primary-firmware-version'} // $blade->{'firmware-version'} // '';
        my $secondary_fw = $blade->{'secondary-firmware-version'} // '';
        
        # Get metrics
        my $power = $blade->{'power-consumption'} // $blade->{'power-usage'};
        my $time_alive = $blade->{'time-alive'};
        my $time_awake = $blade->{'time-awake'};
        
        # Get extension info
        my $extension_enabled = $blade->{'extension-enabled'};
        my $extension_ve_mode = $blade->{'extension-ve-mode'};
        my $extension_ge_mode = $blade->{'extension-ge-mode'};

        $self->{blades}->{$slot_name} = {
            slot => $slot,
            status => {
                slot => $slot,
                status => lc($status),
                blade_type => $blade_type,
                blade_id => $blade_id
            },
            info => {
                slot => $slot,
                manufacturer => $manufacturer,
                part_number => $part_number,
                serial_number => $serial_number
            },
            firmware => {
                slot => $slot,
                primary_firmware => $primary_fw,
                secondary_firmware => $secondary_fw
            },
            metrics => {
                slot => $slot,
                power_consumption => $power,
                time_alive => $time_alive,
                time_awake => $time_awake
            }
        };
    }

    if (scalar(keys %{$self->{blades}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No blades found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check blade status and details.

=over 8

=item B<--filter-slot>

Filter blades by slot number (can be a regexp).

=item B<--filter-blade-type>

Filter blades by type (can be a regexp, e.g. 'CP' for control processors, 'FC' for port blades).

=item B<--exclude-slot>

Exclude blades by slot number (can be a regexp).

=item B<--exclude-blade-type>

Exclude blades by type (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{blade_type}, %{blade_id}, %{slot}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{blade_type}, %{blade_id}, %{slot}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /enabled|on/i').
You can use the following variables: %{status}, %{blade_type}, %{blade_id}, %{slot}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'power-consumption', 'time-alive', 'time-awake'.

=back

=cut
