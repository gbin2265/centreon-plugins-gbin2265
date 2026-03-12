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

package hardware::server::hp::oneview::restapi::mode::uplinksets;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [reachability: %s] [type: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{reachability},
        $self->{result_values}->{uplink_type}
    );
}

sub custom_port_status_output {
    my ($self, %options) = @_;
    return sprintf('link: %s [type: %s]',
        $self->{result_values}->{port_status},
        $self->{result_values}->{uplink_type}
    );
}

sub custom_traffic_in_output {
    my ($self, %options) = @_;
    my ($value, $unit) = $self->{perfdata}->change_bytes(
        value   => $self->{result_values}->{traffic_in} * 1000 / 8,
        network => 1
    );
    return sprintf('traffic in: %s/s', $value . ' ' . $unit);
}

sub custom_traffic_out_output {
    my ($self, %options) = @_;
    my ($value, $unit) = $self->{perfdata}->change_bytes(
        value   => $self->{result_values}->{traffic_out} * 1000 / 8,
        network => 1
    );
    return sprintf('traffic out: %s/s', $value . ' ' . $unit);
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'uplinks', type => 1, cb_prefix_output => 'prefix_uplink_output',
          message_multiple => 'All uplink sets are ok', skipped_code => { -10 => 1 } },
        { name => 'ports', type => 2,
          cb_prefix_output => 'prefix_port_output',
          cb_long_output   => 'port_long_output',
          message_multiple => 'All uplink ports are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'uplinks-total', nlabel => 'uplink.sets.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total: %d',
                perfdatas       => [ { value => 'total', template => '%d', min => 0 } ],
            }
        },
        { label => 'uplinks-status-ok', nlabel => 'uplink.sets.status.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_ok' } ],
                output_template => 'health ok: %d',
                perfdatas       => [ { value => 'status_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'uplinks-status-warning', nlabel => 'uplink.sets.status.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_warning' } ],
                output_template => 'health warning: %d',
                perfdatas       => [ { value => 'status_warning', template => '%d', min => 0 } ],
            }
        },
        { label => 'uplinks-status-critical', nlabel => 'uplink.sets.status.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_critical' } ],
                output_template => 'health critical: %d',
                perfdatas       => [ { value => 'status_critical', template => '%d', min => 0 } ],
            }
        },
        { label => 'uplinks-reachable', nlabel => 'uplink.sets.reachable.count', display_ok => 0, set => {
                key_values      => [ { name => 'reachable' } ],
                output_template => 'reachable: %d',
                perfdatas       => [ { value => 'reachable', template => '%d', min => 0 } ],
            }
        },
        { label => 'uplinks-not-reachable', nlabel => 'uplink.sets.notreachable.count', display_ok => 0, set => {
                key_values      => [ { name => 'not_reachable' } ],
                output_template => 'not reachable: %d',
                perfdatas       => [ { value => 'not_reachable', template => '%d', min => 0 } ],
            }
        },
        { label => 'uplinks-redundantly-reachable', nlabel => 'uplink.sets.redundantlyreachable.count', display_ok => 0, set => {
                key_values      => [ { name => 'redundantly_reachable' } ],
                output_template => 'redundantly reachable: %d',
                perfdatas       => [ { value => 'redundantly_reachable', template => '%d', min => 0 } ],
            }
        },
        { label => 'ports-total', nlabel => 'uplink.sets.ports.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_total' } ],
                output_template => 'ports total: %d',
                perfdatas       => [ { value => 'ports_total', template => '%d', min => 0 } ],
            }
        },
        { label => 'ports-linked', nlabel => 'uplink.sets.ports.linked.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_linked' } ],
                output_template => 'ports linked: %d',
                perfdatas       => [ { value => 'ports_linked', template => '%d', min => 0 } ],
            }
        },
        { label => 'ports-unlinked', nlabel => 'uplink.sets.ports.unlinked.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_unlinked' } ],
                output_template => 'ports unlinked: %d',
                perfdatas       => [ { value => 'ports_unlinked', template => '%d', min => 0 } ],
            }
        },
    ];

    # ---- Per uplink set ----
    $self->{maps_counters}->{uplinks} = [
        { label => 'uplink-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'reachability' },
                    { name => 'uplink_type' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'uplink-ports-total', nlabel => 'uplink.set.ports.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_total' }, { name => 'display' } ],
                output_template => 'ports total: %d',
                perfdatas       => [
                    { value => 'ports_total', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'uplink-ports-linked', nlabel => 'uplink.set.ports.linked.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_linked' }, { name => 'display' } ],
                output_template => 'ports linked: %d',
                perfdatas       => [
                    { value => 'ports_linked', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'uplink-ports-unlinked', nlabel => 'uplink.set.ports.unlinked.count', display_ok => 0, set => {
                key_values      => [ { name => 'ports_unlinked' }, { name => 'display' } ],
                output_template => 'ports unlinked: %d',
                perfdatas       => [
                    { value => 'ports_unlinked', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'uplink-networks', nlabel => 'uplink.set.networks.count', display_ok => 0, set => {
                key_values      => [ { name => 'network_count' }, { name => 'display' } ],
                output_template => 'networks: %d',
                perfdatas       => [
                    { value => 'network_count', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Aggregate traffic in (Kb/s) — sum over all uplink ports
        { label => 'uplink-traffic-in', nlabel => 'uplink.set.traffic.in.kilobits.second', display_ok => 0, set => {
                key_values            => [ { name => 'traffic_in' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_traffic_in_output'),
                perfdatas             => [
                    { value => 'traffic_in', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'uplink-traffic-out', nlabel => 'uplink.set.traffic.out.kilobits.second', display_ok => 0, set => {
                key_values            => [ { name => 'traffic_out' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_traffic_out_output'),
                perfdatas             => [
                    { value => 'traffic_out', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'uplink-errors', nlabel => 'uplink.set.errors.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'errors' }, { name => 'display' } ],
                output_template => 'errors: %.2f /s',
                perfdatas       => [
                    { value => 'errors', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'uplink-drops', nlabel => 'uplink.set.drops.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'drops' }, { name => 'display' } ],
                output_template => 'drops: %.2f /s',
                perfdatas       => [
                    { value => 'drops', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];

    # ---- Per uplink port ----
    $self->{maps_counters}->{ports} = [
        { label => 'port-status', threshold => 0, set => {
                key_values => [
                    { name => 'port_status' },
                    { name => 'uplink_type' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_port_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'port-traffic-in', nlabel => 'uplink.port.traffic.in.kilobits.second', display_ok => 0, set => {
                key_values            => [ { name => 'traffic_in' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_traffic_in_output'),
                perfdatas             => [
                    { value => 'traffic_in', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-traffic-out', nlabel => 'uplink.port.traffic.out.kilobits.second', display_ok => 0, set => {
                key_values            => [ { name => 'traffic_out' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_traffic_out_output'),
                perfdatas             => [
                    { value => 'traffic_out', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-packets-in', nlabel => 'uplink.port.packets.in.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'packets_in' }, { name => 'display' } ],
                output_template => 'packets in: %.2f /s',
                perfdatas       => [
                    { value => 'packets_in', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-packets-out', nlabel => 'uplink.port.packets.out.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'packets_out' }, { name => 'display' } ],
                output_template => 'packets out: %.2f /s',
                perfdatas       => [
                    { value => 'packets_out', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-errors-in', nlabel => 'uplink.port.errors.in.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'errors_in' }, { name => 'display' } ],
                output_template => 'errors in: %.2f /s',
                perfdatas       => [
                    { value => 'errors_in', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-errors-out', nlabel => 'uplink.port.errors.out.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'errors_out' }, { name => 'display' } ],
                output_template => 'errors out: %.2f /s',
                perfdatas       => [
                    { value => 'errors_out', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-drops-in', nlabel => 'uplink.port.drops.in.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'drops_in' }, { name => 'display' } ],
                output_template => 'drops in: %.2f /s',
                perfdatas       => [
                    { value => 'drops_in', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'port-drops-out', nlabel => 'uplink.port.drops.out.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'drops_out' }, { name => 'display' } ],
                output_template => 'drops out: %.2f /s',
                perfdatas       => [
                    { value => 'drops_out', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

# -------------------------------------------------------------------------
# Prefix / long output callbacks
# -------------------------------------------------------------------------

sub prefix_uplink_output {
    my ($self, %options) = @_;
    return "Uplink set '" . $options{instance_value}->{display} . "' ";
}

sub prefix_port_output {
    my ($self, %options) = @_;
    return "Uplink port '" . $options{instance_value}->{display} . "' ";
}

sub port_long_output {
    my ($self, %options) = @_;
    return "checking uplink port '" . $options{instance_value}->{display} . "'";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'                    => { name => 'filter_name' },
        'filter-type:s'                    => { name => 'filter_type' },
        'filter-enclosure-group:s'         => { name => 'filter_enclosure_group' },
        'filter-port-name:s'               => { name => 'filter_port_name' },
        'filter-logical-interconnect:s'    => { name => 'filter_logical_interconnect' },
        'no-statistics'               => { name => 'no_statistics' },
        'unknown-uplink-status:s'     => { name => 'unknown_uplink_status',
            default => '%{status} =~ /unknown/i' },
        'warning-uplink-status:s'     => { name => 'warning_uplink_status',
            default => '%{status} =~ /warning/i' },
        'critical-uplink-status:s'    => { name => 'critical_uplink_status',
            default => '%{status} =~ /critical/i' },
        'unknown-reachability:s'      => { name => 'unknown_reachability',  default => '' },
        'warning-reachability:s'      => { name => 'warning_reachability',  default => '' },
        'critical-reachability:s'     => { name => 'critical_reachability',
            default => '%{reachability} =~ /NotReachable/i' },
        'unknown-port-status:s'       => { name => 'unknown_port_status',  default => '' },
        'warning-port-status:s'       => { name => 'warning_port_status',  default => '' },
        'critical-port-status:s'      => { name => 'critical_port_status',
            default => '%{port_status} =~ /unlinked/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_uplink_status',  'critical_uplink_status',  'unknown_uplink_status',
        'warning_reachability',   'critical_reachability',   'unknown_reachability',
        'warning_port_status',    'critical_port_status',    'unknown_port_status',
    ]);
}

# -------------------------------------------------------------------------
# Utility: parse port statistics from an interconnect statistics response
# -------------------------------------------------------------------------

sub _get_port_stats {
    my ($self, %options) = @_;
    # options: custom, interconnect_uri, port_name
    my %stats = (
        traffic_in  => undef, traffic_out  => undef,
        packets_in  => undef, packets_out  => undef,
        errors_in   => undef, errors_out   => undef,
        drops_in    => undef, drops_out    => undef,
    );

    return %stats unless (defined($options{interconnect_uri}) && $options{interconnect_uri} ne '');

    my $stat_data = $options{custom}->request_api(
        url_path      => $options{interconnect_uri} . '/statistics',
        ignore_errors => 1
    );
    return %stats unless (defined($stat_data));

    foreach my $pstat (@{$stat_data->{portStatistics} // []}) {
        next unless (defined($pstat->{portName}) && $pstat->{portName} eq $options{port_name});
        my $cs = $pstat->{commonStatistics}  // {};
        my $as = $pstat->{advancedStatistics} // {};
        $stats{traffic_in}  = $cs->{receiveKilobitsPerSec}    if (defined($cs->{receiveKilobitsPerSec}));
        $stats{traffic_out} = $cs->{transmitKilobitsPerSec}   if (defined($cs->{transmitKilobitsPerSec}));
        $stats{packets_in}  = $cs->{receivePacketsPerSecond}  if (defined($cs->{receivePacketsPerSecond}));
        $stats{packets_out} = $cs->{transmitPacketsPerSecond} if (defined($cs->{transmitPacketsPerSecond}));
        $stats{errors_in}   = $as->{receiveFrameErrors}       if (defined($as->{receiveFrameErrors}));
        $stats{errors_out}  = $as->{transmitFrameErrors}      if (defined($as->{transmitFrameErrors}));
        $stats{drops_in}    = $as->{receiveFrameDiscards}     if (defined($as->{receiveFrameDiscards}));
        $stats{drops_out}   = $as->{transmitFrameDiscards}    if (defined($as->{transmitFrameDiscards}));
        last;
    }
    return %stats;
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/uplink-sets');

    # Cache interconnect statistics per interconnect URI to avoid duplicate calls
    my %ic_stats_cache;

    $self->{global} = {
        total                => 0,
        status_ok            => 0,
        status_warning       => 0,
        status_critical      => 0,
        reachable            => 0,
        not_reachable        => 0,
        redundantly_reachable => 0,
        ports_total          => 0,
        ports_linked         => 0,
        ports_unlinked       => 0,
    };
    $self->{uplinks} = {};
    $self->{ports}   = {};

    foreach my $us (@{$results->{members}}) {
        my $name        = defined($us->{name})        ? $us->{name}        : $us->{uri};
        my $uplink_type = defined($us->{networkType}) ? $us->{networkType} : 'Unknown';

        # ---- Filters ----
        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(
                long_msg => "skipping uplink set '$name': no matching filter.", debug => 1
            );
            next;
        }

        if (defined($self->{option_results}->{filter_type}) && $self->{option_results}->{filter_type} ne '' &&
            $uplink_type !~ /$self->{option_results}->{filter_type}/i) {
            $self->{output}->output_add(
                long_msg => "skipping uplink set '$name': type '$uplink_type' no matching filter.", debug => 1
            );
            next;
        }

        my $li_uri  = $us->{logicalInterconnectUri} // '';
        my $eg_name = '';
        if ($li_uri ne '') {
            ($eg_name) = $li_uri =~ m{/([^/]+)$};
            $eg_name //= '';
        }
        if (defined($self->{option_results}->{filter_enclosure_group}) && $self->{option_results}->{filter_enclosure_group} ne '' &&
            $eg_name !~ /$self->{option_results}->{filter_enclosure_group}/) {
            $self->{output}->output_add(
                long_msg => "skipping uplink set '$name': enclosure group '$eg_name' no matching filter.", debug => 1
            );
            next;
        }

        my $li_name = $eg_name;   # logicalInterconnectUri last segment serves as LI name
        if (defined($self->{option_results}->{filter_logical_interconnect}) && $self->{option_results}->{filter_logical_interconnect} ne '' &&
            $li_name !~ /$self->{option_results}->{filter_logical_interconnect}/i) {
            $self->{output}->output_add(
                long_msg => "skipping uplink set '$name': logical interconnect '$li_name' no matching filter.", debug => 1
            );
            next;
        }

        my $status       = defined($us->{status})       ? lc($us->{status})       : 'unknown';
        my $reachability = defined($us->{reachability}) ? $us->{reachability}      : 'Unknown';

        # Count network URIs (Ethernet networks or FC networks)
        my $network_count = 0;
        $network_count += scalar(@{$us->{networkUris}})   if (defined($us->{networkUris}));
        $network_count += scalar(@{$us->{fcNetworkUris}}) if (defined($us->{fcNetworkUris}));
        $network_count += scalar(@{$us->{fcoeNetworkUris}}) if (defined($us->{fcoeNetworkUris}));

        # Count and enumerate uplink ports
        my ($ports_total, $ports_linked, $ports_unlinked) = (0, 0, 0);
        my @port_entries;

        foreach my $port_uri_entry (@{$us->{portConfigInfos} // []}) {
            # portConfigInfos: [{ portUri, desiredSpeed }]
            # The actual port status comes from the interconnect port list
            # We use uplink port status from the uplink set's portConfigInfos cross-referenced
            # with the interconnectUri embedded in the portUri
            my $port_uri    = $port_uri_entry->{portUri} // '';
            my $port_status = 'unknown';

            # Extract interconnect URI and port name from portUri
            # portUri format: /rest/interconnects/{id}/ports/{portName}
            my ($ic_uri, $port_name) = ('', '');
            if ($port_uri =~ m{(/rest/interconnects/[^/]+)/ports/(.+)$}) {
                $ic_uri    = $1;
                $port_name = $2;
            }

            # Get port status from interconnect if available
            if ($ic_uri ne '' && !defined($ic_stats_cache{$ic_uri . '_ports'})) {
                my $ic_data = $options{custom}->request_api(
                    url_path      => $ic_uri,
                    ignore_errors => 1
                );
                $ic_stats_cache{$ic_uri . '_ports'} = defined($ic_data) ? { map { $_->{portName} => $_ } @{$ic_data->{ports} // []} } : {};
            }
            if ($ic_uri ne '' && defined($ic_stats_cache{$ic_uri . '_ports'}->{$port_name})) {
                $port_status = lc($ic_stats_cache{$ic_uri . '_ports'}->{$port_name}->{portStatus} // 'unknown');
            }

            $ports_total++;
            if ($port_status eq 'linked') {
                $ports_linked++;
            } else {
                $ports_unlinked++;
            }

            push @port_entries, {
                port_name   => $port_name,
                port_status => $port_status,
                uplink_type => $uplink_type,
                ic_uri      => $ic_uri,
            };
        }

        # ---- Global counters ----
        $self->{global}->{total}++;
        $self->{global}->{'status_' . $status}++
            if (exists $self->{global}->{'status_' . $status});

        my $reach_key = lc($reachability);
        $reach_key =~ s/\s+/_/g;
        if    ($reach_key eq 'reachable')             { $self->{global}->{reachable}++; }
        elsif ($reach_key eq 'notreachable')          { $self->{global}->{not_reachable}++; }
        elsif ($reach_key eq 'redundantlyreachable')  { $self->{global}->{redundantly_reachable}++; }

        $self->{global}->{ports_total}   += $ports_total;
        $self->{global}->{ports_linked}  += $ports_linked;
        $self->{global}->{ports_unlinked}+= $ports_unlinked;

        $self->{uplinks}->{$name} = {
            display       => $name,
            status        => $status,
            reachability  => $reachability,
            uplink_type   => $uplink_type,
            ports_total   => $ports_total,
            ports_linked  => $ports_linked,
            ports_unlinked => $ports_unlinked,
            network_count => $network_count,
            traffic_in    => undef,
            traffic_out   => undef,
            errors        => undef,
            drops         => undef,
        };

        # ---- Per-port statistics ----
        if (!defined($self->{option_results}->{no_statistics})) {
            my ($agg_tin, $agg_tout, $agg_err, $agg_drop) = (0, 0, 0, 0);
            my $got_stats = 0;

            foreach my $pe (@port_entries) {
                next if ($pe->{ic_uri} eq '' || $pe->{port_name} eq '');

                if (defined($self->{option_results}->{filter_port_name}) && $self->{option_results}->{filter_port_name} ne '' &&
                    $pe->{port_name} !~ /$self->{option_results}->{filter_port_name}/) {
                    next;
                }

                # Cache statistics per interconnect
                if (!defined($ic_stats_cache{$pe->{ic_uri} . '_stats'})) {
                    my $stat_data = $options{custom}->request_api(
                        url_path      => $pe->{ic_uri} . '/statistics',
                        ignore_errors => 1
                    );
                    $ic_stats_cache{$pe->{ic_uri} . '_stats'} = defined($stat_data) ?
                        { map { $_->{portName} => $_ } @{$stat_data->{portStatistics} // []} } : {};
                }

                my $pstat = $ic_stats_cache{$pe->{ic_uri} . '_stats'}->{$pe->{port_name}} // {};
                my $cs    = $pstat->{commonStatistics}  // {};
                my $as    = $pstat->{advancedStatistics} // {};

                my $tin    = $cs->{receiveKilobitsPerSec}    // undef;
                my $tout   = $cs->{transmitKilobitsPerSec}   // undef;
                my $pin    = $cs->{receivePacketsPerSecond}  // undef;
                my $pout   = $cs->{transmitPacketsPerSecond} // undef;
                my $ein    = $as->{receiveFrameErrors}       // undef;
                my $eout   = $as->{transmitFrameErrors}      // undef;
                my $din    = $as->{receiveFrameDiscards}     // undef;
                my $dout   = $as->{transmitFrameDiscards}    // undef;

                if (defined($tin)) { $agg_tin  += $tin;  $got_stats = 1; }
                if (defined($tout)){ $agg_tout += $tout; $got_stats = 1; }
                if (defined($ein)) { $agg_err  += $ein; }
                if (defined($eout)){ $agg_err  += $eout; }
                if (defined($din)) { $agg_drop += $din; }
                if (defined($dout)){ $agg_drop += $dout; }

                my $port_key = $name . ':' . $pe->{port_name};
                $self->{ports}->{$port_key} = {
                    display     => $port_key,
                    port_status => $pe->{port_status},
                    uplink_type => $pe->{uplink_type},
                    traffic_in  => $tin,
                    traffic_out => $tout,
                    packets_in  => $pin,
                    packets_out => $pout,
                    errors_in   => $ein,
                    errors_out  => $eout,
                    drops_in    => $din,
                    drops_out   => $dout,
                };
            }

            if ($got_stats) {
                $self->{uplinks}->{$name}->{traffic_in}  = $agg_tin;
                $self->{uplinks}->{$name}->{traffic_out} = $agg_tout;
                $self->{uplinks}->{$name}->{errors}      = $agg_err;
                $self->{uplinks}->{$name}->{drops}       = $agg_drop;
            }
        }
    }

    if (scalar(keys %{$self->{uplinks}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No uplink sets found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView uplink sets: status, reachability and port statistics.

Port status and statistics are retrieved by cross-referencing the uplink set's
portConfigInfos with interconnect port data. Interconnect data is cached per
interconnect module to minimise API calls.

Global perfdata: total uplink sets, health/reachability counts, port total/linked/unlinked.
Per-uplink-set perfdata: port counts, network count,
aggregate traffic in/out (Kb/s), errors (/s), drops (/s).
Per-port perfdata: traffic in/out (Kb/s), packets in/out (/s),
errors in/out (/s), drops in/out (/s).

=over 8

=item B<--filter-name>

Filter uplink set by name (can be a regexp).

=item B<--filter-type>

Filter uplink sets by network type (can be a regexp).
Common values: Ethernet, FibreChannel, FCoE.

=item B<--filter-enclosure-group>

Filter uplink sets by their parent logical interconnect name (can be a regexp).

=item B<--filter-logical-interconnect>

Filter uplink sets by their parent logical interconnect name (can be a regexp).
The name is derived from the last segment of the logicalInterconnectUri.
Example: --filter-logical-interconnect='LI-Production'.

=item B<--filter-port-name>

Filter individual uplink ports by name (can be a regexp).
Only effective when B<--no-statistics> is not set.

=item B<--no-statistics>

Disable per-port statistics (traffic, packets, errors, drops) and
aggregate uplink set traffic perfdata.
By default the plugin fetches statistics for each interconnect module
that owns uplink ports.

=item B<--unknown-uplink-status>

Conditions for UNKNOWN health status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{reachability}, %{uplink_type}, %{display}

=item B<--warning-uplink-status>

Conditions for WARNING health status (default: '%{status} =~ /warning/i').

=item B<--critical-uplink-status>

Conditions for CRITICAL health status (default: '%{status} =~ /critical/i').

=item B<--unknown-reachability>

Conditions for UNKNOWN reachability (default: '').
Variables: %{reachability}, %{display}

=item B<--warning-reachability>

Conditions for WARNING reachability (default: '').

=item B<--critical-reachability>

Conditions for CRITICAL reachability
(default: '%{reachability} =~ /NotReachable/i').

=item B<--unknown-port-status>

Conditions for UNKNOWN port status (default: '').
Variables: %{port_status}, %{uplink_type}, %{display}

=item B<--warning-port-status>

Conditions for WARNING port status (default: '').

=item B<--critical-port-status>

Conditions for CRITICAL port status
(default: '%{port_status} =~ /unlinked/i').

=item B<--warning-*> B<--critical-*>

Global thresholds:
'uplinks-total', 'uplinks-status-ok/warning/critical',
'uplinks-reachable', 'uplinks-not-reachable', 'uplinks-redundantly-reachable',
'ports-total', 'ports-linked', 'ports-unlinked'.

Per-uplink-set thresholds:
'uplink-ports-total', 'uplink-ports-linked', 'uplink-ports-unlinked',
'uplink-networks', 'uplink-traffic-in/out' (Kb/s),
'uplink-errors' (/s), 'uplink-drops' (/s).

Per-port thresholds:
'port-traffic-in/out' (Kb/s), 'port-packets-in/out' (/s),
'port-errors-in/out' (/s), 'port-drops-in/out' (/s).

=back

=cut
