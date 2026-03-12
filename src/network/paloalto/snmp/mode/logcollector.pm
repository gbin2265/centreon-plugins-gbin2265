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

package network::paloalto::snmp::mode::logcollector;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Log collector ';
}

sub prefix_disk_output {
    my ($self, %options) = @_;
    return "Disk '" . $options{instance_value}->{display} . "' ";
}

sub prefix_retention_output {
    my ($self, %options) = @_;
    return "Log type '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'disk', type => 1, cb_prefix_output => 'prefix_disk_output', message_multiple => 'All disks are ok', skipped_code => { -10 => 1 } },
        { name => 'retention', type => 1, cb_prefix_output => 'prefix_retention_output', message_multiple => 'All log retention values are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'log-rate', nlabel => 'logcollector.write.rate.logspersecond', set => {
                key_values => [ { name => 'log_rate' } ],
                output_template => 'write rate: %s logs/s',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'logs/s' }
                ]
            }
        },
        { label => 'redundancy-status', threshold => 0, set => {
                key_values => [ { name => 'redundancy' } ],
                output_template => 'redundancy member: %s',
                closure_custom_perfdata => sub { return 0; }
            }
        }
    ];

    $self->{maps_counters}->{disk} = [
        { label => 'disk-usage', nlabel => 'logcollector.disk.usage.megabytes', set => {
                key_values => [ { name => 'usage_mb' }, { name => 'display' } ],
                output_template => 'usage: %s MB',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'MB', label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{retention} = [
        { label => 'log-retention', nlabel => 'logcollector.log.retention.days', set => {
                key_values => [ { name => 'days' }, { name => 'display' } ],
                output_template => 'retention: %s days',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'd', label_extra_instance => 1 }
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
        'filter-log-type:s' => { name => 'filter_log_type' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # PAN-LC-MIB
    my $oid_log_rate   = '.1.3.6.1.4.1.25461.1.1.8.1.1.0'; # panLcLogRate
    my $oid_redundancy = '.1.3.6.1.4.1.25461.1.1.8.1.5.0'; # panLcIsRedundancyMember

    my $snmp_result = $options{snmp}->get_leef(
        oids => [$oid_log_rate, $oid_redundancy],
        nothing_quit => 1
    );

    my $map_redundancy = { 0 => 'no', 1 => 'yes' };
    $self->{global} = {
        log_rate   => $snmp_result->{$oid_log_rate},
        redundancy => $map_redundancy->{$snmp_result->{$oid_redundancy}} || 'unknown'
    };

    # Disk usage (4 logical disks)
    # panLcDiskUsage1-4 = .1.3.6.1.4.1.25461.1.1.8.1.2.1 - .4
    $self->{disk} = {};
    for my $i (1..4) {
        my $oid = ".1.3.6.1.4.1.25461.1.1.8.1.2.$i.0";
        my $result = $options{snmp}->get_leef(oids => [$oid]);
        if (defined($result->{$oid})) {
            $self->{disk}->{'disk-' . $i} = {
                display  => 'disk-' . $i,
                usage_mb => $result->{$oid}
            };
        }
    }

    # Log retention per type (16 types)
    my $oid_retention_table = '.1.3.6.1.4.1.25461.1.1.8.1.4';
    $snmp_result = $options{snmp}->get_table(oid => $oid_retention_table);

    my $mapping_ret = {
        display => { oid => '.1.3.6.1.4.1.25461.1.1.8.1.4.1.1' }, # panLcLogDurationType
        days    => { oid => '.1.3.6.1.4.1.25461.1.1.8.1.4.1.2' }  # panLcLogDurationDays
    };

    $self->{retention} = {};
    if (defined($snmp_result) && scalar(keys %$snmp_result) > 0) {
        foreach my $oid (keys %$snmp_result) {
            next if ($oid !~ /^$mapping_ret->{display}->{oid}\.(.*)$/);
            my $instance = $1;
            my $result = $options{snmp}->map_instance(mapping => $mapping_ret, results => $snmp_result, instance => $instance);
            next if (!defined($result->{display}) || $result->{display} eq '');

            if (defined($self->{option_results}->{filter_log_type}) && $self->{option_results}->{filter_log_type} ne '' &&
                $result->{display} !~ /$self->{option_results}->{filter_log_type}/) {
                next;
            }
            $self->{retention}->{$result->{display}} = $result;
        }
    }
}

1;

__END__

=head1 MODE

Check Panorama Log Collector specific metrics (PAN-LC-MIB).
Monitors write rate, disk usage, log retention, and redundancy status.
Only available on Panorama Log Collector appliances.

=over 8

=item B<--filter-log-type>

Filter log types by name (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'log-rate' (logs/s), 'disk-usage' (MB), 'log-retention' (days).

=back

=cut
