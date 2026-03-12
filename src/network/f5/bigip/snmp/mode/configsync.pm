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

package network::f5::bigip::snmp::mode::configsync;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "Config sync status is '%s' (color: %s) - %s",
        $self->{result_values}->{syncstatus},
        $self->{result_values}->{color},
        $self->{result_values}->{summary}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 }
    ];

    $self->{maps_counters}->{global} = [
        {
            label  => 'sync-status',
            type   => 2,
            critical_default => '%{syncstatus} =~ /unknown|syncFailed|syncDisconnected|incompatibleVersion/',
            warning_default  => '%{syncstatus} =~ /needManualSync|awaitingInitialSync|partialSync/',
            set => {
                key_values => [
                    { name => 'syncstatus' },
                    { name => 'color' },
                    { name => 'summary' }
                ],
                closure_custom_output         => $self->can('custom_status_output'),
                closure_custom_perfdata       => sub { return 0; },
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
        'display-details' => { name => 'display_details' }
    });

    return $self;
}

my %map_sync_status = (
    0 => 'unknown',
    1 => 'syncing',
    2 => 'needManualSync',
    3 => 'inSync',
    4 => 'syncFailed',
    5 => 'syncDisconnected',
    6 => 'standalone',
    7 => 'awaitingInitialSync',
    8 => 'incompatibleVersion',
    9 => 'partialSync',
);

my %map_sync_color = (
    0 => 'green',
    1 => 'yellow',
    2 => 'red',
    3 => 'blue',
    4 => 'gray',
    5 => 'black',
);

my $mapping = {
    sysCmSyncStatusId      => { oid => '.1.3.6.1.4.1.3375.2.1.14.1.1', map => \%map_sync_status },
    sysCmSyncStatusColor   => { oid => '.1.3.6.1.4.1.3375.2.1.14.1.3', map => \%map_sync_color },
    sysCmSyncStatusSummary => { oid => '.1.3.6.1.4.1.3375.2.1.14.1.4' },
};

my $mapping_details = {
    sysCmSyncStatusDetailsDetails => { oid => '.1.3.6.1.4.1.3375.2.1.14.2.1.3' },
};
my $oid_sysCmSyncStatusDetailsEntry = '.1.3.6.1.4.1.3375.2.1.14.2.1';

sub manage_selection {
    my ($self, %options) = @_;

    my @oids_to_fetch = (
        $mapping->{sysCmSyncStatusId}->{oid} . '.0',
        $mapping->{sysCmSyncStatusColor}->{oid} . '.0',
        $mapping->{sysCmSyncStatusSummary}->{oid} . '.0'
    );

    my $snmp_result = $options{snmp}->get_leef(
        oids         => \@oids_to_fetch,
        nothing_quit => 1
    );

    my $result = $options{snmp}->map_instance(
        mapping  => $mapping,
        results  => $snmp_result,
        instance => '0'
    );

    $self->{global} = {
        syncstatus => $result->{sysCmSyncStatusId},
        color      => $result->{sysCmSyncStatusColor},
        summary    => $result->{sysCmSyncStatusSummary}
    };

    # Optionally fetch and display details table
    if (defined($self->{option_results}->{display_details})) {
        my $details_result = $options{snmp}->get_table(
            oid => $oid_sysCmSyncStatusDetailsEntry,
            nothing_quit => 0
        );

        if (defined($details_result)) {
            foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$details_result})) {
                next if ($oid !~ /^$mapping_details->{sysCmSyncStatusDetailsDetails}->{oid}\.(.*)$/);
                my $instance = $1;
                my $detail = $options{snmp}->map_instance(
                    mapping  => $mapping_details,
                    results  => $details_result,
                    instance => $instance
                );
                $self->{output}->output_add(
                    long_msg => sprintf(
                        'sync detail [%s]: %s',
                        $instance,
                        $detail->{sysCmSyncStatusDetailsDetails}
                    )
                );
            }
        }
    }
}

1;

__END__

=head1 MODE

Check configuration synchronization status on F5 BIG-IP devices.

Monitors the config sync state, color, and summary. Useful for HA (active/standby)
configurations to ensure configuration is properly synchronized between peers.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).

=item B<--display-details>

Display synchronization detail messages in long output.

=item B<--warning-sync-status>

Define the conditions to match for the status to be WARNING
(default: '%{syncstatus} =~ /needManualSync|awaitingInitialSync|partialSync/').
You can use the following variables: %{syncstatus}, %{color}, %{summary}

=item B<--critical-sync-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{syncstatus} =~ /unknown|syncFailed|syncDisconnected|incompatibleVersion/').
You can use the following variables: %{syncstatus}, %{color}, %{summary}

=back

=cut
