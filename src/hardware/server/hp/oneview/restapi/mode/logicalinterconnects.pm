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

package hardware::server::hp::oneview::restapi::mode::logicalinterconnects;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [compliance: %s] [stacking: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{compliance_state},
        $self->{result_values}->{stacking_health}
    );
}

sub custom_compliance_output {
    my ($self, %options) = @_;
    return sprintf('compliance: %s', $self->{result_values}->{compliance_state});
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'lis', type => 1, cb_prefix_output => 'prefix_li_output',
          message_multiple => 'All logical interconnects are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'lis-total', nlabel => 'logical.interconnects.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total: %d',
                perfdatas       => [
                    { value => 'total', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'lis-status-ok', nlabel => 'logical.interconnects.status.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_ok' } ],
                output_template => 'health ok: %d',
                perfdatas       => [
                    { value => 'status_ok', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'lis-status-warning', nlabel => 'logical.interconnects.status.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_warning' } ],
                output_template => 'health warning: %d',
                perfdatas       => [
                    { value => 'status_warning', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'lis-status-critical', nlabel => 'logical.interconnects.status.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_critical' } ],
                output_template => 'health critical: %d',
                perfdatas       => [
                    { value => 'status_critical', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'lis-compliant', nlabel => 'logical.interconnects.compliant.count', display_ok => 0, set => {
                key_values      => [ { name => 'compliant' } ],
                output_template => 'compliant: %d',
                perfdatas       => [
                    { value => 'compliant', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'lis-noncompliant', nlabel => 'logical.interconnects.noncompliant.count', display_ok => 0, set => {
                key_values      => [ { name => 'noncompliant' } ],
                output_template => 'non-compliant: %d',
                perfdatas       => [
                    { value => 'noncompliant', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'lis-stacking-connected', nlabel => 'logical.interconnects.stacking.connected.count', display_ok => 0, set => {
                key_values      => [ { name => 'stacking_connected' } ],
                output_template => 'stacking connected: %d',
                perfdatas       => [
                    { value => 'stacking_connected', template => '%d', min => 0 },
                ],
            }
        },
        { label => 'lis-stacking-disconnected', nlabel => 'logical.interconnects.stacking.disconnected.count', display_ok => 0, set => {
                key_values      => [ { name => 'stacking_disconnected' } ],
                output_template => 'stacking disconnected: %d',
                perfdatas       => [
                    { value => 'stacking_disconnected', template => '%d', min => 0 },
                ],
            }
        },
    ];

    # ---- Per logical interconnect ----
    $self->{maps_counters}->{lis} = [
        # Status / compliance / stacking (drives OK/WARN/CRIT)
        { label => 'li-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'compliance_state' },
                    { name => 'stacking_health' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },

        # Number of member interconnects
        { label => 'li-members', nlabel => 'logical.interconnect.members.count', display_ok => 0, set => {
                key_values      => [ { name => 'member_count' }, { name => 'display' } ],
                output_template => 'member interconnects: %d',
                perfdatas       => [
                    { value => 'member_count', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # Aggregate traffic in (Kb/s) - sum of all member module statistics
        { label => 'li-traffic-in', nlabel => 'logical.interconnect.traffic.in.kilobits.second', display_ok => 0, set => {
                key_values      => [ { name => 'traffic_in' }, { name => 'display' } ],
                output_template => 'aggregate traffic in: %.2f Kb/s',
                perfdatas       => [
                    { value => 'traffic_in', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # Aggregate traffic out (Kb/s)
        { label => 'li-traffic-out', nlabel => 'logical.interconnect.traffic.out.kilobits.second', display_ok => 0, set => {
                key_values      => [ { name => 'traffic_out' }, { name => 'display' } ],
                output_template => 'aggregate traffic out: %.2f Kb/s',
                perfdatas       => [
                    { value => 'traffic_out', template => '%.2f', unit => 'Kb/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # Aggregate errors in (/s)
        { label => 'li-errors-in', nlabel => 'logical.interconnect.errors.in.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'errors_in' }, { name => 'display' } ],
                output_template => 'aggregate errors in: %.2f /s',
                perfdatas       => [
                    { value => 'errors_in', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # Aggregate errors out (/s)
        { label => 'li-errors-out', nlabel => 'logical.interconnect.errors.out.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'errors_out' }, { name => 'display' } ],
                output_template => 'aggregate errors out: %.2f /s',
                perfdatas       => [
                    { value => 'errors_out', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },

        # Aggregate drops (/s)
        { label => 'li-drops', nlabel => 'logical.interconnect.drops.persecond', display_ok => 0, set => {
                key_values      => [ { name => 'drops' }, { name => 'display' } ],
                output_template => 'aggregate drops: %.2f /s',
                perfdatas       => [
                    { value => 'drops', template => '%.2f', unit => '/s', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

sub prefix_li_output {
    my ($self, %options) = @_;
    return "Logical Interconnect '" . $options{instance_value}->{display} . "' ";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'               => { name => 'filter_name' },
        'filter-enclosure-group:s'    => { name => 'filter_enclosure_group' },
        'no-statistics'           => { name => 'no_statistics' },
        'unknown-li-status:s'     => { name => 'unknown_li_status',  default => '%{status} =~ /unknown/i' },
        'warning-li-status:s'     => { name => 'warning_li_status',  default => '%{status} =~ /warning/i' },
        'critical-li-status:s'    => { name => 'critical_li_status', default => '%{status} =~ /critical/i' },
        'unknown-compliance:s'    => { name => 'unknown_compliance',  default => '' },
        'warning-compliance:s'    => { name => 'warning_compliance',  default => '' },
        'critical-compliance:s'   => { name => 'critical_compliance',
            default => '%{compliance_state} =~ /inconsistent/i' },
        'unknown-stacking:s'      => { name => 'unknown_stacking',  default => '' },
        'warning-stacking:s'      => { name => 'warning_stacking',  default => '' },
        'critical-stacking:s'     => { name => 'critical_stacking',
            default => '%{stacking_health} =~ /disconnected|degraded/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_li_status',  'critical_li_status',  'unknown_li_status',
        'warning_compliance', 'critical_compliance', 'unknown_compliance',
        'warning_stacking',   'critical_stacking',   'unknown_stacking',
    ]);
}

# -------------------------------------------------------------------------
# Utility: aggregate port statistics from a statistics response
# -------------------------------------------------------------------------

sub _aggregate_port_stats {
    my ($self, %options) = @_;
    my %totals = (traffic_in => 0, traffic_out => 0, errors_in => 0, errors_out => 0, drops => 0);

    return %totals unless (defined($options{data}) && defined($options{data}->{portStatistics}));

    foreach my $pstat (@{$options{data}->{portStatistics}}) {
        my $cs = $pstat->{commonStatistics}  // {};
        my $as = $pstat->{advancedStatistics} // {};

        $totals{traffic_in}  += $cs->{receiveKilobitsPerSec}   // 0;
        $totals{traffic_out} += $cs->{transmitKilobitsPerSec}  // 0;
        $totals{errors_in}   += $as->{receiveFrameErrors}      // 0;
        $totals{errors_out}  += $as->{transmitFrameErrors}     // 0;
        $totals{drops}       += ($as->{receiveFrameDiscards}   // 0)
                              + ($as->{transmitFrameDiscards}  // 0);
    }
    return %totals;
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/logical-interconnects');

    $self->{global} = {
        total                => 0,
        status_ok            => 0,
        status_warning       => 0,
        status_critical      => 0,
        compliant            => 0,
        noncompliant         => 0,
        stacking_connected   => 0,
        stacking_disconnected => 0,
    };
    $self->{lis} = {};

    foreach my $li (@{$results->{members}}) {
        my $name = defined($li->{name}) ? $li->{name} : $li->{uri};

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(
                long_msg => "skipping logical interconnect '$name': no matching filter.", debug => 1
            );
            next;
        }

        my $eg_name = '';
        if (defined($li->{enclosureGroupUri}) && $li->{enclosureGroupUri} ne '') {
            ($eg_name) = $li->{enclosureGroupUri} =~ m{/([^/]+)$};
            $eg_name //= $li->{enclosureGroupUri};
        }
        if (defined($self->{option_results}->{filter_enclosure_group}) && $self->{option_results}->{filter_enclosure_group} ne '' &&
            $eg_name !~ /$self->{option_results}->{filter_enclosure_group}/) {
            $self->{output}->output_add(
                long_msg => "skipping logical interconnect '$name': enclosure group '$eg_name' no matching filter.", debug => 1
            );
            next;
        }

        my $status           = defined($li->{status})           ? lc($li->{status})           : 'unknown';
        my $compliance_state = defined($li->{complianceState})  ? lc($li->{complianceState})  : 'unknown';
        my $stacking_health  = defined($li->{stackingHealth})   ? lc($li->{stackingHealth})   : 'unknown';
        my $member_count     = defined($li->{interconnectUris}) ? scalar(@{$li->{interconnectUris}}) : 0;

        # Global counters
        $self->{global}->{total}++;
        $self->{global}->{'status_' . $status}++
            if (exists $self->{global}->{'status_' . $status});

        if ($compliance_state =~ /consistent/i && $compliance_state !~ /in/i) {
            $self->{global}->{compliant}++;
        } elsif ($compliance_state =~ /inconsistent/i) {
            $self->{global}->{noncompliant}++;
        }

        if ($stacking_health =~ /^connected$/i) {
            $self->{global}->{stacking_connected}++;
        } elsif ($stacking_health =~ /disconnected/i) {
            $self->{global}->{stacking_disconnected}++;
        }

        $self->{lis}->{$name} = {
            display          => $name,
            status           => $status,
            compliance_state => $compliance_state,
            stacking_health  => $stacking_health,
            member_count     => $member_count,
            traffic_in       => undef,
            traffic_out      => undef,
            errors_in        => undef,
            errors_out       => undef,
            drops            => undef,
        };

        # ---- Optional aggregate statistics (summed over all member interconnects) ----
        if (!defined($self->{option_results}->{no_statistics}) && defined($li->{interconnectUris})) {
            my %totals = (traffic_in => 0, traffic_out => 0, errors_in => 0, errors_out => 0, drops => 0);
            my $got_any = 0;

            foreach my $ic_uri (@{$li->{interconnectUris}}) {
                my $stat_data = $options{custom}->request_api(
                    url_path      => $ic_uri . '/statistics',
                    ignore_errors => 1
                );
                next unless (defined($stat_data));
                $got_any = 1;
                my %ic_totals = $self->_aggregate_port_stats(data => $stat_data);
                $totals{$_} += $ic_totals{$_} for keys %ic_totals;
            }

            if ($got_any) {
                $self->{lis}->{$name}->{traffic_in}  = $totals{traffic_in};
                $self->{lis}->{$name}->{traffic_out} = $totals{traffic_out};
                $self->{lis}->{$name}->{errors_in}   = $totals{errors_in};
                $self->{lis}->{$name}->{errors_out}  = $totals{errors_out};
                $self->{lis}->{$name}->{drops}       = $totals{drops};
            }
        }
    }

    if (scalar(keys %{$self->{lis}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No logical interconnects found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView logical interconnects: health status, compliance and stacking health.

Global perfdata: total count, health/compliance/stacking counts.
Per-LI perfdata: member count.
By default also aggregates port statistics (traffic, errors, drops) across all physical member interconnects.
Use B<--no-statistics> to disable those extra API calls.

=over 8

=item B<--filter-name>

Filter logical interconnect by name (can be a regexp).

=item B<--filter-enclosure-group>

Filter logical interconnects by their enclosure group name (can be a regexp).

=item B<--no-statistics>

Disable aggregation of port statistics (traffic, errors, drops) across physical member interconnects.
By default the plugin fetches statistics for each physical member. One API call per member.

=item B<--unknown-li-status>

Conditions for UNKNOWN health status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{compliance_state}, %{stacking_health}, %{display}

=item B<--warning-li-status>

Conditions for WARNING health status (default: '%{status} =~ /warning/i').

=item B<--critical-li-status>

Conditions for CRITICAL health status (default: '%{status} =~ /critical/i').

=item B<--unknown-compliance>

Conditions for UNKNOWN compliance (default: '').
Variables: %{compliance_state}, %{display}

=item B<--warning-compliance>

Conditions for WARNING compliance (default: '').

=item B<--critical-compliance>

Conditions for CRITICAL compliance
(default: '%{compliance_state} =~ /inconsistent/i').

=item B<--unknown-stacking>

Conditions for UNKNOWN stacking health (default: '').
Variables: %{stacking_health}, %{display}

=item B<--warning-stacking>

Conditions for WARNING stacking health (default: '').

=item B<--critical-stacking>

Conditions for CRITICAL stacking health
(default: '%{stacking_health} =~ /disconnected|degraded/i').

=item B<--warning-*> B<--critical-*>

Global thresholds:
'lis-total', 'lis-status-ok/warning/critical',
'lis-compliant', 'lis-noncompliant',
'lis-stacking-connected', 'lis-stacking-disconnected'.

Per-LI thresholds:
'li-members',
'li-traffic-in/out' (Kb/s),
'li-errors-in/out' (/s),
'li-drops' (/s).

=back

=cut
