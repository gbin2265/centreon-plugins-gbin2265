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

package network::paloalto::snmp::mode::entitypower;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_power_output {
    my ($self, %options) = @_;

    return sprintf(
        'power used: %s W / %s W available (%.1f%%)',
        $self->{result_values}->{power_used},
        $self->{result_values}->{power_available},
        $self->{result_values}->{power_available} > 0 ?
            $self->{result_values}->{power_used} * 100 / $self->{result_values}->{power_available} : 0
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Chassis ';
}

sub prefix_psu_output {
    my ($self, %options) = @_;
    return "PSU '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'psu', type => 1, cb_prefix_output => 'prefix_psu_output', message_multiple => 'All PSUs are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'power-used', nlabel => 'chassis.power.used.watt', set => {
                key_values => [ { name => 'power_used' }, { name => 'power_available' } ],
                closure_custom_output => $self->can('custom_power_output'),
                perfdatas => [
                    { template => '%s', min => 0, max => 'power_available', unit => 'W' }
                ]
            }
        },
        { label => 'power-usage-prct', nlabel => 'chassis.power.usage.percentage', display_ok => 0, set => {
                key_values => [ { name => 'power_prct' } ],
                output_template => 'power usage: %.1f%%',
                perfdatas => [
                    { template => '%.1f', min => 0, max => 100, unit => '%' }
                ]
            }
        }
    ];

    $self->{maps_counters}->{psu} = [
        { label => 'psu-capacity', nlabel => 'psu.power.capacity.watt', set => {
                key_values => [ { name => 'capacity' }, { name => 'display' } ],
                output_template => 'capacity: %s W',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'W', label_extra_instance => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {});
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # PAN-ENTITY-EXT-MIB
    my $oid_power_avail = '.1.3.6.1.4.1.25461.1.1.7.1.1.1.0'; # panEntityTotalPowerAvail
    my $oid_power_used  = '.1.3.6.1.4.1.25461.1.1.7.1.1.2.0'; # panEntityTotalPowerUsed

    my $snmp_result = $options{snmp}->get_leef(
        oids => [$oid_power_avail, $oid_power_used],
        nothing_quit => 1
    );

    my $avail = $snmp_result->{$oid_power_avail} || 0;
    my $used = $snmp_result->{$oid_power_used} || 0;

    $self->{global} = {
        power_available => $avail,
        power_used      => $used,
        power_prct      => $avail > 0 ? ($used * 100 / $avail) : 0
    };

    # PSU table
    my $oid_psu_table = '.1.3.6.1.4.1.25461.1.1.7.1.4.1'; # panEntityPowerSupplyTable
    $snmp_result = $options{snmp}->get_table(oid => $oid_psu_table);

    my $mapping_psu = {
        capacity => { oid => '.1.3.6.1.4.1.25461.1.1.7.1.4.1.1.1' } # panEntryPowerSupplyPowerCapacity
    };

    $self->{psu} = {};
    if (defined($snmp_result)) {
        foreach my $oid (keys %$snmp_result) {
            next if ($oid !~ /^$mapping_psu->{capacity}->{oid}\.(.*)$/);
            my $instance = $1;
            $self->{psu}->{$instance} = {
                display  => 'PSU-' . $instance,
                capacity => $snmp_result->{$oid}
            };
        }
    }
}

1;

__END__

=head1 MODE

Check chassis power usage and PSU capacity (PAN-ENTITY-EXT-MIB).
Available on PA-5400, PA-7000 and similar chassis-based models.

=over 8

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'power-used' (W), 'power-usage-prct' (%), 'psu-capacity' (W).

=back

=cut
