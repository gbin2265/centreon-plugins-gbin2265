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

package hardware::server::hp::oneview::restapi::mode::enclosures;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [state: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{state}
    );
}

sub custom_power_output {
    my ($self, %options) = @_;
    return sprintf('power: allocated %.0f W / available %.0f W',
        $self->{result_values}->{power_allocated},
        $self->{result_values}->{power_available}
    );
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'enclosures', type => 1, cb_prefix_output => 'prefix_enclosure_output',
          message_multiple => 'All enclosures are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'enclosures-total', nlabel => 'enclosures.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total: %d',
                perfdatas       => [ { value => 'total', template => '%d', min => 0 } ],
            }
        },
        { label => 'enclosures-status-ok', nlabel => 'enclosures.status.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_ok' } ],
                output_template => 'health ok: %d',
                perfdatas       => [ { value => 'status_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'enclosures-status-warning', nlabel => 'enclosures.status.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_warning' } ],
                output_template => 'health warning: %d',
                perfdatas       => [ { value => 'status_warning', template => '%d', min => 0 } ],
            }
        },
        { label => 'enclosures-status-critical', nlabel => 'enclosures.status.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_critical' } ],
                output_template => 'health critical: %d',
                perfdatas       => [ { value => 'status_critical', template => '%d', min => 0 } ],
            }
        },
    ];

    # ---- Per enclosure ----
    $self->{maps_counters}->{enclosures} = [
        # Health status + state
        { label => 'enclosure-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'state' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },

        # Server bays occupied vs total
        { label => 'enclosure-server-bays-total', nlabel => 'enclosure.server.bays.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'server_bays_total' }, { name => 'display' } ],
                output_template => 'server bays total: %d',
                perfdatas       => [
                    { value => 'server_bays_total', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'enclosure-server-bays-used', nlabel => 'enclosure.server.bays.used.count', display_ok => 0, set => {
                key_values      => [ { name => 'server_bays_used' }, { name => 'display' } ],
                output_template => 'server bays used: %d',
                perfdatas       => [
                    { value => 'server_bays_used', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # Fans ok vs total
        { label => 'enclosure-fans-total', nlabel => 'enclosure.fans.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'fans_total' }, { name => 'display' } ],
                output_template => 'fans total: %d',
                perfdatas       => [
                    { value => 'fans_total', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'enclosure-fans-ok', nlabel => 'enclosure.fans.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'fans_ok' }, { name => 'display' } ],
                output_template => 'fans ok: %d',
                perfdatas       => [
                    { value => 'fans_ok', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'enclosure-fans-failed', nlabel => 'enclosure.fans.failed.count', display_ok => 0, set => {
                key_values      => [ { name => 'fans_failed' }, { name => 'display' } ],
                output_template => 'fans failed: %d',
                perfdatas       => [
                    { value => 'fans_failed', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # PSU ok vs total
        { label => 'enclosure-psus-total', nlabel => 'enclosure.psus.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'psus_total' }, { name => 'display' } ],
                output_template => 'psus total: %d',
                perfdatas       => [
                    { value => 'psus_total', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'enclosure-psus-ok', nlabel => 'enclosure.psus.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'psus_ok' }, { name => 'display' } ],
                output_template => 'psus ok: %d',
                perfdatas       => [
                    { value => 'psus_ok', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'enclosure-psus-failed', nlabel => 'enclosure.psus.failed.count', display_ok => 0, set => {
                key_values      => [ { name => 'psus_failed' }, { name => 'display' } ],
                output_template => 'psus failed: %d',
                perfdatas       => [
                    { value => 'psus_failed', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # Power: allocated & available (Watts)
        { label => 'enclosure-power-allocated', nlabel => 'enclosure.power.allocated.watts', display_ok => 0, set => {
                key_values            => [
                    { name => 'power_allocated' },
                    { name => 'power_available' },
                    { name => 'display' },
                ],
                closure_custom_output => $self->can('custom_power_output'),
                perfdatas             => [
                    { value => 'power_allocated', template => '%.0f', unit => 'W', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'enclosure-power-available', nlabel => 'enclosure.power.available.watts', display_ok => 0, set => {
                key_values      => [ { name => 'power_available' }, { name => 'display' } ],
                output_template => 'power available: %.0f W',
                perfdatas       => [
                    { value => 'power_available', template => '%.0f', unit => 'W', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # Ambient temperature (from utilization)
        { label => 'enclosure-temperature', nlabel => 'enclosure.temperature.celsius', display_ok => 0, set => {
                key_values      => [ { name => 'temperature' }, { name => 'display' } ],
                output_template => 'temperature: %.1f C',
                perfdatas       => [
                    { value => 'temperature', template => '%.1f', unit => 'C',
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # Interconnect bays
        { label => 'enclosure-interconnect-bays-total', nlabel => 'enclosure.interconnect.bays.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'ic_bays_total' }, { name => 'display' } ],
                output_template => 'interconnect bays total: %d',
                perfdatas       => [
                    { value => 'ic_bays_total', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'enclosure-interconnect-bays-used', nlabel => 'enclosure.interconnect.bays.used.count', display_ok => 0, set => {
                key_values      => [ { name => 'ic_bays_used' }, { name => 'display' } ],
                output_template => 'interconnect bays used: %d',
                perfdatas       => [
                    { value => 'ic_bays_used', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

sub prefix_enclosure_output {
    my ($self, %options) = @_;
    return "Enclosure '" . $options{instance_value}->{display} . "' ";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'                => { name => 'filter_name' },
        'filter-enclosure-group:s'    => { name => 'filter_enclosure_group' },
        'no-utilization'              => { name => 'no_utilization' },
        'unknown-enclosure-status:s'  => { name => 'unknown_enclosure_status',
            default => '%{status} =~ /unknown/i' },
        'warning-enclosure-status:s'  => { name => 'warning_enclosure_status',
            default => '%{status} =~ /warning/i' },
        'critical-enclosure-status:s' => { name => 'critical_enclosure_status',
            default => '%{status} =~ /critical/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_enclosure_status', 'critical_enclosure_status', 'unknown_enclosure_status',
    ]);
}

# -------------------------------------------------------------------------
# Utility: parse utilization metricList
# -------------------------------------------------------------------------

sub _parse_utilization {
    my ($self, %options) = @_;
    my %metrics;
    return %metrics unless (defined($options{data}) && defined($options{data}->{metricList}));
    foreach my $metric (@{$options{data}->{metricList}}) {
        my $name = $metric->{metricName};
        if (defined($metric->{metricSamples}) && scalar(@{$metric->{metricSamples}}) > 0) {
            my $last = $metric->{metricSamples}->[-1];
            $metrics{$name} = $last->[1] if (defined($last->[1]));
        }
    }
    return %metrics;
}

# -------------------------------------------------------------------------
# Helper: count bay states
# -------------------------------------------------------------------------

sub _count_bays {
    my ($self, %options) = @_;
    # options: bays => arrayref, present_key => 'devicePresence', status_key => 'status'
    my ($total, $present, $ok, $failed) = (0, 0, 0, 0);
    foreach my $bay (@{$options{bays} // []}) {
        $total++;
        my $presence = lc($bay->{$options{present_key}} // 'absent');
        next if ($presence eq 'absent');
        $present++;
        my $st = lc($bay->{$options{status_key}} // 'unknown');
        if ($st eq 'ok') {
            $ok++;
        } elsif ($st =~ /critical|error/) {
            $failed++;
        }
    }
    return ($total, $present, $ok, $failed);
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/enclosures');

    $self->{global} = {
        total           => 0,
        status_ok       => 0,
        status_warning  => 0,
        status_critical => 0,
    };
    $self->{enclosures} = {};

    foreach my $enc (@{$results->{members}}) {
        my $name = defined($enc->{name}) ? $enc->{name} : ($enc->{uuid} // $enc->{uri});

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(
                long_msg => "skipping enclosure '$name': no matching filter.", debug => 1
            );
            next;
        }

        my $enclosure_group = defined($enc->{enclosureGroupUri}) ? $enc->{enclosureGroupUri} : '';
        $enclosure_group =~ s{^.*/}{};  # keep only last URI segment as readable name
        if (defined($self->{option_results}->{filter_enclosure_group}) && $self->{option_results}->{filter_enclosure_group} ne '' &&
            $enclosure_group !~ /$self->{option_results}->{filter_enclosure_group}/) {
            $self->{output}->output_add(
                long_msg => "skipping enclosure '$name': enclosure group '$enclosure_group' no matching filter.", debug => 1
            );
            next;
        }

        my $status = defined($enc->{status}) ? lc($enc->{status}) : 'unknown';
        my $state  = defined($enc->{state})  ? lc($enc->{state})  : 'unknown';

        # Global counters
        $self->{global}->{total}++;
        $self->{global}->{'status_' . $status}++
            if (exists $self->{global}->{'status_' . $status});

        # --- Fan bays ---
        my ($fans_total, $fans_present, $fans_ok, $fans_failed) = $self->_count_bays(
            bays        => $enc->{fanBays},
            present_key => 'devicePresence',
            status_key  => 'status'
        );

        # --- PSU bays ---
        my ($psus_total, $psus_present, $psus_ok, $psus_failed) = $self->_count_bays(
            bays        => $enc->{powerSupplyBays},
            present_key => 'devicePresence',
            status_key  => 'status'
        );

        # --- Server bays ---
        my $server_bays_total = scalar(@{$enc->{deviceBays} // []});
        my $server_bays_used  = 0;
        foreach my $bay (@{$enc->{deviceBays} // []}) {
            $server_bays_used++ if (defined($bay->{devicePresence}) && lc($bay->{devicePresence}) ne 'absent');
        }

        # --- Interconnect bays ---
        my $ic_bays_total = scalar(@{$enc->{interconnectBays} // []});
        my $ic_bays_used  = 0;
        foreach my $bay (@{$enc->{interconnectBays} // []}) {
            $ic_bays_used++ if (defined($bay->{interconnectUri}) && $bay->{interconnectUri} ne '');
        }

        # --- Power capacity ---
        my $power_allocated = $enc->{powerAvailable} // undef;
        my $power_available = undef;
        if (defined($enc->{powerCapacity}) && defined($enc->{powerAllocatedCapacity})) {
            $power_allocated = $enc->{powerAllocatedCapacity};
            $power_available = $enc->{powerCapacity} - $enc->{powerAllocatedCapacity};
        }

        $self->{enclosures}->{$name} = {
            display           => $name,
            status            => $status,
            state             => $state,
            server_bays_total => $server_bays_total,
            server_bays_used  => $server_bays_used,
            fans_total        => $fans_present,
            fans_ok           => $fans_ok,
            fans_failed       => $fans_failed,
            psus_total        => $psus_present,
            psus_ok           => $psus_ok,
            psus_failed       => $psus_failed,
            power_allocated   => $power_allocated,
            power_available   => $power_available,
            ic_bays_total     => $ic_bays_total,
            ic_bays_used      => $ic_bays_used,
            temperature       => undef,
        };

        # --- Optional utilization (temperature) ---
        if (!defined($self->{option_results}->{no_utilization}) && defined($enc->{uri})) {
            my $util = $options{custom}->request_api(
                url_path      => $enc->{uri} . '/utilization?fields=AmbientTemperature&view=native',
                ignore_errors => 1
            );
            if (defined($util)) {
                my %metrics = $self->_parse_utilization(data => $util);
                $self->{enclosures}->{$name}->{temperature} = $metrics{AmbientTemperature}
                    if (defined($metrics{AmbientTemperature}));
            }
        }
    }

    if (scalar(keys %{$self->{enclosures}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No enclosures found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView enclosures with full component and capacity perfdata.

Global perfdata: total count, health status counts.
Per-enclosure perfdata: server bay occupancy, fan counts (total/ok/failed),
PSU counts (total/ok/failed), power allocated/available (W),
interconnect bay occupancy, ambient temperature (C).

=over 8

=item B<--filter-name>

Filter enclosure by name (can be a regexp).

=item B<--filter-enclosure-group>

Filter enclosures by their enclosure group name (can be a regexp).
Useful to scope checks to a specific enclosure group.

=item B<--no-utilization>

Disable the ambient temperature API call per enclosure.
By default the plugin fetches utilization for each enclosure.

=item B<--unknown-enclosure-status>

Conditions for UNKNOWN status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{state}, %{display}

=item B<--warning-enclosure-status>

Conditions for WARNING status (default: '%{status} =~ /warning/i').

=item B<--critical-enclosure-status>

Conditions for CRITICAL status (default: '%{status} =~ /critical/i').

=item B<--warning-*> B<--critical-*>

Global thresholds:
'enclosures-total', 'enclosures-status-ok/warning/critical'.

Per-enclosure thresholds:
'enclosure-server-bays-total', 'enclosure-server-bays-used',
'enclosure-fans-total', 'enclosure-fans-ok', 'enclosure-fans-failed',
'enclosure-psus-total', 'enclosure-psus-ok', 'enclosure-psus-failed',
'enclosure-power-allocated' (W), 'enclosure-power-available' (W),
'enclosure-temperature' (C),
'enclosure-interconnect-bays-total', 'enclosure-interconnect-bays-used'.

=back

=cut
