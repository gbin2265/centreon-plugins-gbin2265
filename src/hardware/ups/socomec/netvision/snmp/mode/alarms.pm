#
# Copyright 2026 Centreon (http://www.centreon.com/)
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

package hardware::ups::socomec::netvision::snmp::mode::alarms;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_alarm_output {
    my ($self, %options) = @_;
    return sprintf("alarm '%s' [id: %s] status is %s",
        $self->{result_values}->{description},
        $self->{result_values}->{alarm_id},
        $self->{result_values}->{state}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0,                                         skipped_code => { -10 => 1 } },
        { name => 'alarms', type => 1, message_multiple => 'No active alarms', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'alarms-current', nlabel => 'alarms.current.count', set => {
                key_values      => [ { name => 'count' } ],
                output_template => 'current alarms: %s',
                perfdatas       => [ { template => '%s', min => 0 } ]
            }
        }
    ];

    $self->{maps_counters}->{alarms} = [
        {
            label            => 'alarm-status',
            type             => 2,
            critical_default => '%{state} eq "active"',
            set => {
                key_values => [
                    { name => 'state'       },
                    { name => 'alarm_id'    },
                    { name => 'description' }
                ],
                closure_custom_output          => $self->can('custom_alarm_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        # Filtering: include only specific IDs (comma-sep) or matching description (regex)
        'filter-alarm-id:s'   => { name => 'filter_alarm_id'   }, # e.g. --filter-alarm-id=1,5,38
        'filter-alarm-desc:s' => { name => 'filter_alarm_desc' }, # e.g. --filter-alarm-desc=battery
        # Exclusion: skip specific IDs or descriptions
        'exclude-alarm-id:s'  => { name => 'exclude_alarm_id'  }, # e.g. --exclude-alarm-id=10,26
        'exclude-alarm-desc:s'=> { name => 'exclude_alarm_desc'}, # e.g. --exclude-alarm-desc=bypass
        # By default only active alarms are shown; this flag also reports inactive ones
        'show-inactive'       => { name => 'show_inactive'     },
    });
    return $self;
}

# ----------------------------------------------------------------
# Alarm descriptions — NV5/NV6/NV7 common set
# ----------------------------------------------------------------
my %alarm_desc = (
    1  => 'Battery discharged',
    2  => 'Battery failure',
    3  => 'Battery communication failure',
    4  => 'Battery test failed',
    5  => 'Battery low',
    6  => 'Battery not present',
    7  => 'Battery temperature high',
    8  => 'Bypass contactor failure',
    9  => 'Bypass frequency out of range',
    10 => 'Bypass in use',
    11 => 'Bypass voltage out of range',
    12 => 'Charger failure',
    13 => 'Communication failure',
    14 => 'DC bus overvoltage',
    15 => 'DC link voltage low',
    16 => 'EPO activated',
    17 => 'Fan failure',
    18 => 'Fuse blown',
    19 => 'High ambient temperature',
    20 => 'Input breaker open',
    21 => 'Input frequency out of range',
    22 => 'Input voltage out of range',
    23 => 'Inverter abnormal',
    24 => 'Inverter overloaded',
    25 => 'Inverter voltage out of range',
    26 => 'Load on bypass',
    27 => 'Low battery warning',
    28 => 'Maintenance bypass closed',
    29 => 'Module failure',
    30 => 'No utility input',
    31 => 'Output breaker open',
    32 => 'Output overloaded',
    33 => 'Output short circuit',
    34 => 'Output voltage out of range',
    35 => 'Overtemperature',
    36 => 'Rectifier failure',
    37 => 'Site wiring fault',
    38 => 'System on battery',
    39 => 'UPS off',
    40 => 'UPS shutdown pending',
    41 => 'Utility power restored',
    42 => 'Wrong battery',
);

my $oid_alarms_count_nv5 = '.1.3.6.1.4.1.4555.1.1.1.1.6.1';
my $oid_alarms_count_nv6 = '.1.3.6.1.4.1.4555.1.1.7.1.6.1';
my $oid_alarm_flags_nv5  = '.1.3.6.1.4.1.4555.1.1.1.1.6.3';
my $oid_alarm_flags_nv6  = '.1.3.6.1.4.1.4555.1.1.7.1.6.3';

sub _build_filter_set {
    my ($opt) = @_;
    return {} unless (defined($opt) && $opt ne '');
    return { map { $_ => 1 } split(/\s*,\s*/, $opt) };
}

sub manage_selection {
    my ($self, %options) = @_;

    # Detect firmware generation
    my $snmp_counts = $options{snmp}->get_leef(
        oids => [ $oid_alarms_count_nv6 . '.0', $oid_alarms_count_nv5 . '.0' ]
    );
    my ($oid_count, $oid_flags, $label);
    if (defined($snmp_counts->{ $oid_alarms_count_nv6 . '.0' })) {
        $oid_count = $oid_alarms_count_nv6;
        $oid_flags = $oid_alarm_flags_nv6;
        $label     = 'netvision6/7';
    } else {
        $oid_count = $oid_alarms_count_nv5;
        $oid_flags = $oid_alarm_flags_nv5;
        $label     = 'netvision5';
    }

    my $count = $snmp_counts->{ $oid_count . '.0' } // 0;
    $self->{global} = { count => $count };

    # Build filter/exclude sets for IDs
    my %filter_ids  = %{ _build_filter_set($self->{option_results}->{filter_alarm_id})  };
    my %exclude_ids = %{ _build_filter_set($self->{option_results}->{exclude_alarm_id}) };

    # Regex patterns for descriptions
    my $filter_desc  = $self->{option_results}->{filter_alarm_desc}  // '';
    my $exclude_desc = $self->{option_results}->{exclude_alarm_desc} // '';

    my $flags = $options{snmp}->get_table(oid => $oid_flags);

    $self->{alarms} = {};
    foreach my $oid (sort keys %$flags) {
        next unless ($oid =~ /^$oid_flags\.(\d+)\.0$/);
        my $alarm_id = $1;
        my $desc     = $alarm_desc{$alarm_id} // "Alarm $alarm_id";
        my $flag     = $flags->{$oid} // 0;
        my $state    = ($flag != 0) ? 'active' : 'inactive';

        # ---- include filters ----
        next if (%filter_ids  && !$filter_ids{$alarm_id});
        next if ($filter_desc ne '' && $desc !~ /$filter_desc/i);

        # ---- exclude filters ----
        if ($exclude_ids{$alarm_id}) {
            $self->{output}->output_add(long_msg => "skipping alarm $alarm_id ($desc): excluded by id", debug => 1);
            next;
        }
        if ($exclude_desc ne '' && $desc =~ /$exclude_desc/i) {
            $self->{output}->output_add(long_msg => "skipping alarm $alarm_id ($desc): excluded by desc", debug => 1);
            next;
        }

        # ---- default: skip inactive unless --show-inactive or a filter is active ----
        next if ($state eq 'inactive'
            && !defined($self->{option_results}->{show_inactive})
            && !%filter_ids
            && $filter_desc eq '');

        $self->{alarms}->{$alarm_id} = {
            alarm_id    => $alarm_id,
            description => $desc,
            state       => $state
        };
    }
}

1;

__END__

=head1 MODE

Check UPS alarms. Supports Net Vision 5, 6 and 7.

Uses individual flag OIDs (.6.3.N.0 = 0/1) — up to 87 on NV5, 62 on NV6/7.
By default only active alarms are reported.

=over 8

=item B<--filter-alarm-id>

Only check specific alarm IDs (comma-separated).
Example: --filter-alarm-id=1,5,30,38

=item B<--filter-alarm-desc>

Only check alarms whose description matches this regex (case-insensitive).
Example: --filter-alarm-desc=battery

=item B<--exclude-alarm-id>

Exclude specific alarm IDs from checking (comma-separated).
Example: --exclude-alarm-id=10,26  (ignore "Bypass in use" and "Load on bypass")

=item B<--exclude-alarm-desc>

Exclude alarms whose description matches this regex.
Example: --exclude-alarm-desc=bypass

=item B<--show-inactive>

Also report alarms that are currently inactive.
Useful to confirm specific alarms are cleared.

=item B<--warning-alarms-current>

Warning threshold for total number of active alarms.

=item B<--critical-alarms-current>

Critical threshold for total number of active alarms.

=item B<--warning-alarm-status>

Warning threshold per alarm. Variables: %{state}, %{alarm_id}, %{description}.

=item B<--critical-alarm-status>

Critical threshold per alarm (default: '%{state} eq "active"').
Variables: %{state}, %{alarm_id}, %{description}.

=back

=cut
