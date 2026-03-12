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

package network::f5::bigip::snmp::mode::hastatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use Time::HiRes qw(time);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "failover status: '%s' [device: %s]",
        $self->{result_values}->{failover_status},
        $self->{result_values}->{device_name}
    );
}

sub prefix_tg_output {
    my ($self, %options) = @_;

    return "Traffic group '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'traffic_groups', type => 1, cb_prefix_output => 'prefix_tg_output',
          message_multiple => 'All traffic groups are ok' }
    ];

    $self->{maps_counters}->{traffic_groups} = [
        {
            label => 'status',
            type  => 2,
            critical_default => '%{failover_status} =~ /offline|forcedOffline|unknown/',
            set => {
                key_values => [
                    { name => 'failover_status' },
                    { name => 'device_name' },
                    { name => 'display' }
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

sub run {
    my ($self, %options) = @_;

    $self->manage_selection(%options);

    foreach my $entry (@{$self->{maps_counters_type}}) {
        if ($entry->{type} == 0) {
            $self->run_global(config => $entry);
        } elsif ($entry->{type} == 1) {
            $self->run_instances(config => $entry);
        } elsif ($entry->{type} == 2) {
            $self->run_group(config => $entry);
        } elsif ($entry->{type} == 3) {
            $self->run_multiple(config => $entry);
        }
    }

    # Override OK message with rich summary
    if (defined($self->{output}->{global_short_outputs}->{OK}) &&
        scalar(@{$self->{output}->{global_short_outputs}->{OK}}) > 0) {

        my $summary = $self->build_summary();
        $self->{output}->{global_short_outputs}->{OK} = [ $summary ];
        $self->{output}->{global_short_concat_outputs}->{OK} = $summary;
    }

    $self->{output}->display();
    $self->{output}->exit();
}

sub build_summary {
    my ($self, %options) = @_;

    # Group by traffic group name
    my %by_tg;
    foreach my $key (keys %{$self->{traffic_groups}}) {
        my $entry = $self->{traffic_groups}->{$key};
        my $tg = $entry->{display};
        push @{$by_tg{$tg}}, $entry;
    }

    my @parts;
    foreach my $tg_name (sort keys %by_tg) {
        my @devices;
        foreach my $entry (sort { $b->{failover_status} cmp $a->{failover_status} } @{$by_tg{$tg_name}}) {
            push @devices, sprintf('%s (%s)', $entry->{device_name}, $entry->{failover_status});
        }
        push @parts, sprintf("'%s': %s", $tg_name, join(', ', @devices));
    }

    return join(' / ', @parts);
}

my %map_failover_status = (
    0 => 'unknown',
    1 => 'offline',
    2 => 'forcedOffline',
    3 => 'standby',
    4 => 'active',
);

# F5-BIGIP-SYSTEM-MIB::sysCmTrafficGroupStatusTable
my $mapping = {
    sysCmTrafficGroupStatusDeviceName     => { oid => '.1.3.6.1.4.1.3375.2.1.14.5.2.1.2' },
    sysCmTrafficGroupStatusFailoverStatus => { oid => '.1.3.6.1.4.1.3375.2.1.14.5.2.1.3', map => \%map_failover_status },
};
my $oid_sysCmTrafficGroupStatusEntry = '.1.3.6.1.4.1.3375.2.1.14.5.2.1';

sub decode_string_index {
    my ($self, %options) = @_;

    my @indexes = split(/\./, $options{index});
    my $length = shift(@indexes);
    my $name = join('', map(chr($_), splice(@indexes, 0, $length)));
    my $remaining = join('.', @indexes);

    return ($name, $remaining);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_table(
        oid          => $oid_sysCmTrafficGroupStatusEntry,
        nothing_quit => 1
    );

    $self->{traffic_groups} = {};
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result})) {
        next if ($oid !~ /^$mapping->{sysCmTrafficGroupStatusDeviceName}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping,
            results  => $snmp_result,
            instance => $instance
        );

        # Index: trafficGroupName (length-prefixed) + deviceName (length-prefixed)
        my ($tg_name, $remaining) = $self->decode_string_index(index => $instance);

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $tg_name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping traffic group '" . $tg_name . "'.", debug => 1);
            next;
        }

        my $key = $tg_name . '_' . $result->{sysCmTrafficGroupStatusDeviceName};
        $self->{traffic_groups}->{$key} = {
            display         => $tg_name,
            device_name     => $result->{sysCmTrafficGroupStatusDeviceName},
            failover_status => $result->{sysCmTrafficGroupStatusFailoverStatus}
        };
    }

    if (scalar(keys %{$self->{traffic_groups}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No traffic groups found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HA status on F5 BIG-IP devices.

Reports the failover status (active/standby/offline) and associated device
for each traffic group. Shows both devices and their roles in the OK output.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).

=item B<--filter-name>

Filter traffic group name (can be a regexp).

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{failover_status}, %{device_name}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{failover_status} =~ /offline|forcedOffline|unknown/').
You can use the following variables: %{failover_status}, %{device_name}, %{display}

=back

=cut
