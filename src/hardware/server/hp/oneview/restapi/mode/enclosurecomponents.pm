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

package hardware::server::hp::oneview::restapi::mode::enclosurecomponents;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_fan_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [model: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{model}
    );
}

sub custom_psu_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [model: %s] [capacity: %s W]',
        $self->{result_values}->{status},
        $self->{result_values}->{model},
        defined($self->{result_values}->{capacity}) ? $self->{result_values}->{capacity} : 'n/a'
    );
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'fans', type => 1,
          cb_prefix_output => 'prefix_fan_output',
          message_multiple => 'All fans are ok', skipped_code => { -10 => 1 } },
        { name => 'psus', type => 1,
          cb_prefix_output => 'prefix_psu_output',
          message_multiple => 'All power supplies are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'fans-total', nlabel => 'enclosure.fans.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'fans_total' } ],
                output_template => 'fans total: %d',
                perfdatas       => [ { value => 'fans_total', template => '%d', min => 0 } ],
            }
        },
        { label => 'fans-ok', nlabel => 'enclosure.fans.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'fans_ok' } ],
                output_template => 'fans ok: %d',
                perfdatas       => [ { value => 'fans_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'fans-warning', nlabel => 'enclosure.fans.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'fans_warning' } ],
                output_template => 'fans warning: %d',
                perfdatas       => [ { value => 'fans_warning', template => '%d', min => 0 } ],
            }
        },
        { label => 'fans-critical', nlabel => 'enclosure.fans.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'fans_critical' } ],
                output_template => 'fans critical: %d',
                perfdatas       => [ { value => 'fans_critical', template => '%d', min => 0 } ],
            }
        },
        { label => 'psus-total', nlabel => 'enclosure.psus.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'psus_total' } ],
                output_template => 'psus total: %d',
                perfdatas       => [ { value => 'psus_total', template => '%d', min => 0 } ],
            }
        },
        { label => 'psus-ok', nlabel => 'enclosure.psus.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'psus_ok' } ],
                output_template => 'psus ok: %d',
                perfdatas       => [ { value => 'psus_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'psus-warning', nlabel => 'enclosure.psus.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'psus_warning' } ],
                output_template => 'psus warning: %d',
                perfdatas       => [ { value => 'psus_warning', template => '%d', min => 0 } ],
            }
        },
        { label => 'psus-critical', nlabel => 'enclosure.psus.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'psus_critical' } ],
                output_template => 'psus critical: %d',
                perfdatas       => [ { value => 'psus_critical', template => '%d', min => 0 } ],
            }
        },
    ];

    # ---- Per fan ----
    $self->{maps_counters}->{fans} = [
        { label => 'fan-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'model' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_fan_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'fan-speed', nlabel => 'enclosure.fan.speed.percentage', set => {
                key_values      => [ { name => 'fan_speed' }, { name => 'display' } ],
                output_template => 'speed: %d %%',
                perfdatas       => [
                    { value => 'fan_speed', template => '%d', unit => '%', min => 0, max => 100,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];

    # ---- Per PSU ----
    $self->{maps_counters}->{psus} = [
        { label => 'psu-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'model' },
                    { name => 'capacity' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_psu_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'psu-capacity', nlabel => 'enclosure.psu.capacity.watts', display_ok => 0, set => {
                key_values      => [ { name => 'capacity' }, { name => 'display' } ],
                output_template => 'capacity: %d W',
                perfdatas       => [
                    { value => 'capacity', template => '%d', unit => 'W', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Output wattage from utilization (filled if --with-utilization, default ON)
        { label => 'psu-power', nlabel => 'enclosure.psu.power.watts', display_ok => 0, set => {
                key_values      => [ { name => 'power_watts' }, { name => 'display' } ],
                output_template => 'power output: %d W',
                perfdatas       => [
                    { value => 'power_watts', template => '%d', unit => 'W', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

# -------------------------------------------------------------------------
# Prefix / long output callbacks
# -------------------------------------------------------------------------

sub prefix_fan_output {
    my ($self, %options) = @_;
    return "Fan '" . $options{instance_value}->{display} . "' ";
}

sub fan_long_output {
    my ($self, %options) = @_;
    return "checking fan '" . $options{instance_value}->{display} . "'";
}

sub prefix_psu_output {
    my ($self, %options) = @_;
    return "PSU '" . $options{instance_value}->{display} . "' ";
}

sub psu_long_output {
    my ($self, %options) = @_;
    return "checking PSU '" . $options{instance_value}->{display} . "'";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-enclosure:s'         => { name => 'filter_enclosure' },
        'filter-enclosure-group:s'   => { name => 'filter_enclosure_group' },
        'filter-fan-bay:s'           => { name => 'filter_fan_bay' },
        'filter-psu-bay:s'           => { name => 'filter_psu_bay' },
        'filter-model:s'             => { name => 'filter_model' },
        'no-utilization'             => { name => 'no_utilization' },
        # Fan status thresholds
        'unknown-fan-status:s'   => { name => 'unknown_fan_status',
            default => '%{status} =~ /unknown/i' },
        'warning-fan-status:s'   => { name => 'warning_fan_status',
            default => '%{status} =~ /warning/i' },
        'critical-fan-status:s'  => { name => 'critical_fan_status',
            default => '%{status} =~ /critical|error/i' },
        # PSU status thresholds
        'unknown-psu-status:s'   => { name => 'unknown_psu_status',
            default => '%{status} =~ /unknown/i' },
        'warning-psu-status:s'   => { name => 'warning_psu_status',
            default => '%{status} =~ /warning/i' },
        'critical-psu-status:s'  => { name => 'critical_psu_status',
            default => '%{status} =~ /critical|error/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_fan_status',  'critical_fan_status',  'unknown_fan_status',
        'warning_psu_status',  'critical_psu_status',  'unknown_psu_status',
    ]);
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/enclosures');

    $self->{global} = {
        fans_total    => 0, fans_ok    => 0, fans_warning    => 0, fans_critical    => 0,
        psus_total    => 0, psus_ok    => 0, psus_warning    => 0, psus_critical    => 0,
    };
    $self->{fans} = {};
    $self->{psus} = {};

    foreach my $enc (@{$results->{members}}) {
        my $enc_name = defined($enc->{name}) ? $enc->{name} : ($enc->{uuid} // $enc->{uri});

        if (defined($self->{option_results}->{filter_enclosure}) && $self->{option_results}->{filter_enclosure} ne '' &&
            $enc_name !~ /$self->{option_results}->{filter_enclosure}/) {
            $self->{output}->output_add(
                long_msg => "skipping enclosure '$enc_name': no matching filter.", debug => 1
            );
            next;
        }

        my $eg_name = '';
        if (defined($enc->{enclosureGroupUri}) && $enc->{enclosureGroupUri} ne '') {
            ($eg_name) = $enc->{enclosureGroupUri} =~ m{/([^/]+)$};
            $eg_name //= '';
        }
        if (defined($self->{option_results}->{filter_enclosure_group}) && $self->{option_results}->{filter_enclosure_group} ne '' &&
            $eg_name !~ /$self->{option_results}->{filter_enclosure_group}/) {
            $self->{output}->output_add(
                long_msg => "skipping enclosure '$enc_name': enclosure group '$eg_name' no matching filter.", debug => 1
            );
            next;
        }

        # ---- Optionally fetch utilization for per-PSU wattage ----
        my %psu_power_map;
        if (!defined($self->{option_results}->{no_utilization}) && defined($enc->{uri})) {
            my $util = $options{custom}->request_api(
                url_path      => $enc->{uri} . '/utilization',
                ignore_errors => 1
            );
            if (defined($util) && defined($util->{metricList})) {
                foreach my $metric (@{$util->{metricList}}) {
                    # Look for per-PSU power metrics: metricName like 'PsuPowerOutput<n>'
                    if ($metric->{metricName} =~ /^PsuPowerOutput(\d+)$/i) {
                        my $bay_num = $1;
                        my $val = $metric->{metricSamples}->[-1]->[1]
                            if (defined($metric->{metricSamples}) && scalar(@{$metric->{metricSamples}}) > 0);
                        $psu_power_map{$bay_num} = $val if (defined($val));
                    }
                }
            }
        }

        # ---- Fan bays ----
        foreach my $fan (@{$enc->{fanBays} // []}) {
            next if (defined($fan->{devicePresence}) && lc($fan->{devicePresence}) eq 'absent');

            my $bay_num  = $fan->{bayNumber} // '?';
            my $fan_key  = $enc_name . ':fan:' . $bay_num;

            if (defined($self->{option_results}->{filter_fan_bay}) && $self->{option_results}->{filter_fan_bay} ne '' &&
                $bay_num !~ /$self->{option_results}->{filter_fan_bay}/) {
                $self->{output}->output_add(
                    long_msg => "skipping fan bay $bay_num in '$enc_name': no matching filter.", debug => 1
                );
                next;
            }

            my $status    = defined($fan->{status})    ? lc($fan->{status})    : 'unknown';
            my $model     = defined($fan->{model})     ? $fan->{model}         : 'n/a';
            my $fan_speed = defined($fan->{fanSpeed})  ? $fan->{fanSpeed}      : undef;

            if (defined($self->{option_results}->{filter_model}) && $self->{option_results}->{filter_model} ne '' &&
                $model !~ /$self->{option_results}->{filter_model}/i) {
                $self->{output}->output_add(long_msg => "skipping fan '$fan_key': model '$model' no matching filter.", debug => 1);
                next;
            }

            # Global counters
            $self->{global}->{fans_total}++;
            if    ($status eq 'ok')       { $self->{global}->{fans_ok}++; }
            elsif ($status eq 'warning')  { $self->{global}->{fans_warning}++; }
            elsif ($status =~ /critical|error/) { $self->{global}->{fans_critical}++; }

            $self->{fans}->{$fan_key} = {
                display   => $fan_key,
                status    => $status,
                model     => $model,
                fan_speed => $fan_speed,
            };

            $self->{output}->output_add(
                long_msg => sprintf(
                    "fan '%s' status: %s [model: %s]%s",
                    $fan_key, $status, $model,
                    defined($fan_speed) ? " [speed: $fan_speed%]" : ''
                )
            );
        }

        # ---- PSU bays ----
        foreach my $psu (@{$enc->{powerSupplyBays} // []}) {
            next if (defined($psu->{devicePresence}) && lc($psu->{devicePresence}) eq 'absent');

            my $bay_num = $psu->{bayNumber} // '?';
            my $psu_key = $enc_name . ':psu:' . $bay_num;

            if (defined($self->{option_results}->{filter_psu_bay}) && $self->{option_results}->{filter_psu_bay} ne '' &&
                $bay_num !~ /$self->{option_results}->{filter_psu_bay}/) {
                $self->{output}->output_add(
                    long_msg => "skipping PSU bay $bay_num in '$enc_name': no matching filter.", debug => 1
                );
                next;
            }

            my $status     = defined($psu->{status})   ? lc($psu->{status})   : 'unknown';
            my $model      = defined($psu->{model})    ? $psu->{model}        : 'n/a';
            my $capacity   = defined($psu->{capacity}) ? $psu->{capacity}     : undef;
            $capacity      =~ s/[^0-9.]//g if (defined($capacity));

            if (defined($self->{option_results}->{filter_model}) && $self->{option_results}->{filter_model} ne '' &&
                $model !~ /$self->{option_results}->{filter_model}/i) {
                $self->{output}->output_add(long_msg => "skipping PSU '$psu_key': model '$model' no matching filter.", debug => 1);
                next;
            }

            my $power_watts = $psu_power_map{$bay_num} // undef;

            # Global counters
            $self->{global}->{psus_total}++;
            if    ($status eq 'ok')       { $self->{global}->{psus_ok}++; }
            elsif ($status eq 'warning')  { $self->{global}->{psus_warning}++; }
            elsif ($status =~ /critical|error/) { $self->{global}->{psus_critical}++; }

            $self->{psus}->{$psu_key} = {
                display     => $psu_key,
                status      => $status,
                model       => $model,
                capacity    => $capacity,
                power_watts => $power_watts,
            };

            $self->{output}->output_add(
                long_msg => sprintf(
                    "PSU '%s' status: %s [model: %s]%s%s",
                    $psu_key, $status, $model,
                    defined($capacity)    ? " [capacity: ${capacity}W]" : '',
                    defined($power_watts) ? " [output: ${power_watts}W]" : ''
                )
            );
        }
    }

    if ($self->{global}->{fans_total} == 0 && $self->{global}->{psus_total} == 0) {
        $self->{output}->add_option_msg(short_msg => 'No fan or PSU components found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView enclosure fans and power supply units individually.

Each present fan and PSU bay is reported with its health status and —
where available — fan speed (%) and PSU output wattage (W).

PSU output wattage requires a per-enclosure B</utilization> API call
(one call per enclosure). Disable with B<--no-utilization> if not needed.

Global perfdata: fans and PSUs total/ok/warning/critical counts.

Per-fan perfdata: speed (%).
Per-PSU perfdata: capacity (W), output power (W).

=over 8

=item B<--filter-enclosure>

Filter by enclosure name (can be a regexp).

=item B<--filter-enclosure-group>

Filter by enclosure group name (can be a regexp).

=item B<--filter-fan-bay>

Filter fan bays by bay number (can be a regexp).
Example: --filter-fan-bay='^[12]$' to check only bay 1 and 2.

=item B<--filter-psu-bay>

Filter PSU bays by bay number (can be a regexp).

=item B<--filter-model>

Filter fans and PSUs by model name (can be a regexp).
Example: --filter-model='2650W' to only check 2650W PSU models.

=item B<--no-utilization>

Do not fetch per-enclosure utilization.
PSU output wattage perfdata will not be available.

=item B<--unknown-fan-status>

Conditions for UNKNOWN fan status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{model}, %{display}

=item B<--warning-fan-status>

Conditions for WARNING fan status (default: '%{status} =~ /warning/i').

=item B<--critical-fan-status>

Conditions for CRITICAL fan status
(default: '%{status} =~ /critical|error/i').

=item B<--unknown-psu-status>

Conditions for UNKNOWN PSU status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{model}, %{capacity}, %{display}

=item B<--warning-psu-status>

Conditions for WARNING PSU status (default: '%{status} =~ /warning/i').

=item B<--critical-psu-status>

Conditions for CRITICAL PSU status
(default: '%{status} =~ /critical|error/i').

=item B<--warning-*> B<--critical-*>

Global thresholds:
'fans-total', 'fans-ok', 'fans-warning', 'fans-critical',
'psus-total', 'psus-ok', 'psus-warning', 'psus-critical'.

Per-fan thresholds: 'fan-speed' (%).

Per-PSU thresholds: 'psu-capacity' (W), 'psu-power' (W).

=back

=cut
