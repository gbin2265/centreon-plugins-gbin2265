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

package network::paloalto::snmp::mode::panstorage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_storage_output {
    my ($self, %options) = @_;
    return "Storage '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'storage', type => 1, cb_prefix_output => 'prefix_storage_output',
          message_multiple => 'All storage partitions are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{storage} = [
        { label => 'usage-prct', nlabel => 'storage.usage.percentage', set => {
                key_values => [ { name => 'usage_prct' }, { name => 'display' } ],
                output_template => 'usage: %.1f%%',
                perfdatas => [
                    { template => '%.1f', min => 0, max => 100, unit => '%', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'available', nlabel => 'storage.available.bytes', display_ok => 0, set => {
                key_values => [ { name => 'available' }, { name => 'display' } ],
                output_template => 'available: %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'used', nlabel => 'storage.used.bytes', display_ok => 0, set => {
                key_values => [ { name => 'used' }, { name => 'display' } ],
                output_template => 'used: %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'allocation-failures', nlabel => 'storage.allocation.failures.count', set => {
                key_values => [ { name => 'alloc_failures' }, { name => 'display' } ],
                output_template => 'allocation failures: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
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
        'filter-storage-name:s' => { name => 'filter_storage_name' }
    });

    return $self;
}

# panhrStorage = .1.3.6.1.4.1.25461.2.1.2.12
my $mapping = {
    display         => { oid => '.1.3.6.1.4.1.25461.2.1.2.12.1.1.2' }, # panhrStorageDescr
    alloc_units     => { oid => '.1.3.6.1.4.1.25461.2.1.2.12.1.1.4' }, # panhrStorageAllocationUnits
    available       => { oid => '.1.3.6.1.4.1.25461.2.1.2.12.1.1.5' }, # panhrStorageAvailable (in alloc units)
    used            => { oid => '.1.3.6.1.4.1.25461.2.1.2.12.1.1.6' }, # panhrStorageUsed (in alloc units)
    usage_prct      => { oid => '.1.3.6.1.4.1.25461.2.1.2.12.1.1.7' }, # panhrStorageUsage (0-100%)
    alloc_failures  => { oid => '.1.3.6.1.4.1.25461.2.1.2.12.1.1.8' }  # panhrStorageAllocationFailures
};

sub manage_selection {
    my ($self, %options) = @_;

    my $oid_table = '.1.3.6.1.4.1.25461.2.1.2.12.1';
    my $snmp_result = $options{snmp}->get_table(oid => $oid_table, nothing_quit => 1);

    $self->{storage} = {};
    foreach my $oid (keys %$snmp_result) {
        next if ($oid !~ /^$mapping->{display}->{oid}\.(.*)$/);
        my $instance = $1;
        my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => $instance);

        if (defined($self->{option_results}->{filter_storage_name}) && $self->{option_results}->{filter_storage_name} ne '' &&
            $result->{display} !~ /$self->{option_results}->{filter_storage_name}/) {
            $self->{output}->output_add(long_msg => "skipping storage '" . $result->{display} . "'.", debug => 1);
            next;
        }

        # Convert alloc units to bytes
        my $unit_size = defined($result->{alloc_units}) && $result->{alloc_units} > 0 ? $result->{alloc_units} : 1;
        $result->{available} = (defined($result->{available}) ? $result->{available} : 0) * $unit_size;
        $result->{used} = (defined($result->{used}) ? $result->{used} : 0) * $unit_size;

        $self->{storage}->{$result->{display}} = $result;
    }

    if (scalar(keys %{$self->{storage}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No PAN storage entries found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check PAN-OS native storage table (panhrStorage).
Provides usage percentage, available/used space, and allocation failures.
Richer than HOST-RESOURCES-MIB storage — includes PAN-specific metrics.

=over 8

=item B<--filter-storage-name>

Filter storage partitions by name (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'usage-prct' (%), 'available' (B), 'used' (B), 'allocation-failures'.

=back

=cut
