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

package network::brocade::restapi::mode::sfp;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [vendor: %s] [part: %s]",
        $self->{result_values}->{status},
        $self->{result_values}->{vendor},
        $self->{result_values}->{part_number}
    );
}

sub prefix_sfp_output {
    my ($self, %options) = @_;

    return "SFP port '" . $options{instance_value}->{display} . "' ";
}

sub sfp_long_output {
    my ($self, %options) = @_;

    return "checking SFP port '" . $options{instance_value}->{display} . "'";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'sfps', type => 3, cb_prefix_output => 'prefix_sfp_output', cb_long_output => 'sfp_long_output',
          indent_long_output => '    ', message_multiple => 'All SFPs are ok',
            group => [
                { name => 'status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'metrics', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{status} = [
        {
            label => 'status',
            type => 2,
            warning_default => '%{status} =~ /warning/i',
            critical_default => '%{status} =~ /critical|failed/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'vendor' }, { name => 'part_number' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{metrics} = [
        { label => 'temperature', nlabel => 'sfp.temperature.celsius', set => {
                key_values => [ { name => 'temperature' }, { name => 'perfdata_display' } ],
                output_template => 'temperature: %.1f C',
                perfdatas => [
                    { template => '%.1f', unit => 'C', label_extra_instance => 1, instance_use => 'perfdata_display' }
                ]
            }
        },
        { label => 'voltage', nlabel => 'sfp.voltage.millivolt', set => {
                key_values => [ { name => 'voltage' }, { name => 'perfdata_display' } ],
                output_template => 'voltage: %.1f mV',
                perfdatas => [
                    { template => '%.1f', unit => 'mV', label_extra_instance => 1, instance_use => 'perfdata_display' }
                ]
            }
        },
        { label => 'tx-power', nlabel => 'sfp.tx.power.dbm', set => {
                key_values => [ { name => 'tx_power' }, { name => 'perfdata_display' } ],
                output_template => 'TX power: %.2f dBm',
                perfdatas => [
                    { template => '%.2f', unit => 'dBm', label_extra_instance => 1, instance_use => 'perfdata_display' }
                ]
            }
        },
        { label => 'rx-power', nlabel => 'sfp.rx.power.dbm', set => {
                key_values => [ { name => 'rx_power' }, { name => 'perfdata_display' } ],
                output_template => 'RX power: %.2f dBm',
                perfdatas => [
                    { template => '%.2f', unit => 'dBm', label_extra_instance => 1, instance_use => 'perfdata_display' }
                ]
            }
        },
        { label => 'current', nlabel => 'sfp.current.milliampere', set => {
                key_values => [ { name => 'current' }, { name => 'perfdata_display' } ],
                output_template => 'current: %.2f mA',
                perfdatas => [
                    { template => '%.2f', unit => 'mA', label_extra_instance => 1, instance_use => 'perfdata_display' }
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
        'filter-port-name:s'  => { name => 'filter_port_name' },
        'filter-port-index:s' => { name => 'filter_port_index' },
        'exclude-port-name:s'  => { name => 'exclude_port_name' },
        'exclude-port-index:s' => { name => 'exclude_port_index' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $media = $options{custom}->get_media_info();

    $self->{sfps} = {};

    my $media_data = $media->{'Response'}->{'media-rdp'} // $media->{'brocade-media'}->{'media-rdp'} // [];
    $media_data = [$media_data] if (ref($media_data) ne 'ARRAY');

    foreach my $sfp (@{$media_data}) {
        my $port_name = $sfp->{'name'} // next;
        my $port_index = $sfp->{'port-index'} // $sfp->{'index'} // '';

        if (defined($self->{option_results}->{filter_port_name}) && $self->{option_results}->{filter_port_name} ne '' &&
            $port_name !~ /$self->{option_results}->{filter_port_name}/) {
            next;
        }

        if (defined($self->{option_results}->{filter_port_index}) && $self->{option_results}->{filter_port_index} ne '' &&
            $port_index !~ /^$self->{option_results}->{filter_port_index}$/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_port_name}) && $self->{option_results}->{exclude_port_name} ne '' &&
            $port_name =~ /$self->{option_results}->{exclude_port_name}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_port_index}) && $self->{option_results}->{exclude_port_index} ne '' &&
            $port_index =~ /^$self->{option_results}->{exclude_port_index}$/) {
            next;
        }

        # Skip if no media present
        next if (!defined($sfp->{'media-speed-capability'}) && !defined($sfp->{'vendor-name'}));

        # Determine status
        my $status = 'ok';
        if (defined($sfp->{'remote-media-temperature-alert'})) {
            my $alert = $sfp->{'remote-media-temperature-alert'};
            if (defined($alert->{'high-alarm'}) && $alert->{'high-alarm'}) {
                $status = 'critical';
            } elsif (defined($alert->{'high-warning'}) && $alert->{'high-warning'}) {
                $status = 'warning';
            } elsif (defined($alert->{'low-alarm'}) && $alert->{'low-alarm'}) {
                $status = 'critical';
            } elsif (defined($alert->{'low-warning'}) && $alert->{'low-warning'}) {
                $status = 'warning';
            }
        }

        # Check power alerts
        if ($status eq 'ok' && defined($sfp->{'remote-media-rx-power-alert'})) {
            my $alert = $sfp->{'remote-media-rx-power-alert'};
            if (defined($alert->{'high-alarm'}) && $alert->{'high-alarm'}) {
                $status = 'critical';
            } elsif (defined($alert->{'low-alarm'}) && $alert->{'low-alarm'}) {
                $status = 'critical';
            } elsif (defined($alert->{'high-warning'}) && $alert->{'high-warning'}) {
                $status = 'warning';
            } elsif (defined($alert->{'low-warning'}) && $alert->{'low-warning'}) {
                $status = 'warning';
            }
        }

        my $vendor = $sfp->{'vendor-name'} // $sfp->{'identifier'} // 'unknown';
        my $part_number = $sfp->{'part-number'} // $sfp->{'vendor-oui'} // 'unknown';

        # Get temperature
        my $temp = $sfp->{'remote-media-temperature'} // $sfp->{'temperature'};

        # Get voltage (convert from millivolts if needed)
        my $voltage_alert = $sfp->{'remote-media-voltage-alert'};
        my $voltage = (defined($voltage_alert) ? $voltage_alert->{'current-value'} : undef) // $sfp->{'voltage'};

        # Get TX/RX power
        my $tx_power = $sfp->{'remote-media-tx-power'} // $sfp->{'tx-power'};
        my $rx_power = $sfp->{'remote-media-rx-power'} // $sfp->{'rx-power'};

        # Get current (bias current)
        my $current_alert = $sfp->{'remote-media-current-alert'};
        my $current = (defined($current_alert) ? $current_alert->{'current-value'} : undef) // $sfp->{'current'};

        # Build display name with port-index
        my $display_name = $port_name;
        if ($port_index ne '') {
            $display_name = $port_name . ' - idx/' . $port_index;
        }

        $self->{sfps}->{$port_name} = {
            display => $display_name,
            status => {
                display => $display_name,
                status => $status,
                vendor => $vendor,
                part_number => $part_number
            },
            metrics => {
                display => $display_name,
                perfdata_display => $port_name,
                temperature => $temp,
                voltage => $voltage,
                tx_power => $tx_power,
                rx_power => $rx_power,
                current => $current
            }
        };
    }

    if (scalar(keys %{$self->{sfps}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No SFPs found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check SFP/transceiver health and metrics.

=over 8

=item B<--filter-port-name>

Filter SFPs by port name (can be a regexp).

=item B<--filter-port-index>

Filter ports by index (can be a regexp).

=item B<--exclude-port-name>

Exclude ports by name (can be a regexp).

=item B<--exclude-port-index>

Exclude ports by index (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{vendor}, %{part_number}, %{display}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{status} =~ /warning/i').
You can use the following variables: %{status}, %{vendor}, %{part_number}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} =~ /critical|failed/i').
You can use the following variables: %{status}, %{vendor}, %{part_number}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'temperature', 'voltage', 'tx-power', 'rx-power', 'current'.

=back

=cut
