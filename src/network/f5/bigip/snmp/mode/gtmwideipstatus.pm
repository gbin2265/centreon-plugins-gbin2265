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

package network::f5::bigip::snmp::mode::gtmwideipstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s] [reason: %s]",
        $self->{result_values}->{status},
        $self->{result_values}->{state},
        $self->{result_values}->{reason}
    );
}

sub prefix_wideip_output {
    my ($self, %options) = @_;

    return "Wide IP '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'wideips', type => 1, cb_prefix_output => 'prefix_wideip_output', message_multiple => 'All Wide IPs are ok' }
    ];

    $self->{maps_counters}->{wideips} = [
        {
            label => 'status',
            type  => 2,
            warning_default  => '%{state} eq "enabled" and %{status} eq "yellow"',
            critical_default => '%{state} eq "enabled" and %{status} eq "red"',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'state' },
                    { name => 'reason' }, { name => 'display' }
                ],
                closure_custom_output          => $self->can('custom_status_output'),
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
        'filter-name:s' => { name => 'filter_name' }
    });

    return $self;
}

my $map_avail_state = {
    0 => 'none',
    1 => 'green',
    2 => 'yellow',
    3 => 'red',
    4 => 'blue',
    5 => 'gray',
};

my $map_enabled_state = {
    0 => 'none',
    1 => 'enabled',
    2 => 'disabled',
    3 => 'disabledbyparent',
};

# F5-BIGIP-GLOBAL-MIB::gtmWideipStatusTable
my $mapping = {
    gtmWideipStatusAvailState    => { oid => '.1.3.6.1.4.1.3375.2.3.12.2.3.1.2', map => $map_avail_state },
    gtmWideipStatusEnabledState  => { oid => '.1.3.6.1.4.1.3375.2.3.12.2.3.1.3', map => $map_enabled_state },
    gtmWideipStatusDetailReason  => { oid => '.1.3.6.1.4.1.3375.2.3.12.2.3.1.5' },
};
my $oid_gtmWideipStatusEntry = '.1.3.6.1.4.1.3375.2.3.12.2.3.1';

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_table(
        oid          => $oid_gtmWideipStatusEntry,
        nothing_quit => 1
    );

    $self->{wideips} = {};
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result})) {
        next if ($oid !~ /^$mapping->{gtmWideipStatusAvailState}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping,
            results  => $snmp_result,
            instance => $instance
        );

        # Decode the name from the SNMP index (length-prefixed string)
        my @indexes = split(/\./, $instance);
        my $name_length = shift(@indexes);
        my $name = join('', map(chr($_), splice(@indexes, 0, $name_length)));

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping Wide IP '" . $name . "'.", debug => 1);
            next;
        }

        $self->{wideips}->{$name} = {
            display => $name,
            status  => $result->{gtmWideipStatusAvailState},
            state   => $result->{gtmWideipStatusEnabledState},
            reason  => defined($result->{gtmWideipStatusDetailReason}) ? $result->{gtmWideipStatusDetailReason} : '-'
        };
    }

    if (scalar(keys %{$self->{wideips}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No Wide IPs found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check GTM Wide IP status on F5 BIG-IP devices.

Monitors the availability and enabled state of all Wide IPs configured in the
Global Traffic Manager (GTM / BIG-IP DNS).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).

=item B<--filter-name>

Filter Wide IP name (can be a regexp).

=item B<--warning-status>

Define the conditions to match for the status to be WARNING
(default: '%{state} eq "enabled" and %{status} eq "yellow"').
You can use the following variables: %{status}, %{state}, %{reason}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{state} eq "enabled" and %{status} eq "red"').
You can use the following variables: %{status}, %{state}, %{reason}, %{display}

=back

=cut
