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

package network::paloalto::snmp::mode::devicelogging;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_collector_status_output {
    my ($self, %options) = @_;
    return "status is '" . $self->{result_values}->{status} . "'";
}

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Logging ';
}

sub prefix_logusage_output {
    my ($self, %options) = @_;
    return "Log type '" . $options{instance_value}->{display} . "' ";
}

sub prefix_collector_output {
    my ($self, %options) = @_;
    return "Collector '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'logusage', type => 1, cb_prefix_output => 'prefix_logusage_output', message_multiple => 'All log types are ok', skipped_code => { -10 => 1 } },
        { name => 'collector', type => 1, cb_prefix_output => 'prefix_collector_output', message_multiple => 'All collector connections are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'incoming-log-rate', nlabel => 'logging.incoming.rate.logspersecond', set => {
                key_values => [ { name => 'incoming_rate' } ],
                output_template => 'incoming rate: %s logs/s',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'logs/s' }
                ]
            }
        },
        { label => 'write-log-rate', nlabel => 'logging.write.rate.logspersecond', set => {
                key_values => [ { name => 'write_rate' } ],
                output_template => 'write rate: %s logs/s',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'logs/s' }
                ]
            }
        }
    ];

    $self->{maps_counters}->{logusage} = [
        { label => 'log-disk-usage', nlabel => 'logging.type.disk.usage.megabytes', set => {
                key_values => [ { name => 'disk_usage' }, { name => 'display' } ],
                output_template => 'disk usage: %s MB',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'MB', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'log-retention', nlabel => 'logging.type.retention.days', set => {
                key_values => [ { name => 'retention' }, { name => 'display' } ],
                output_template => 'retention: %s days',
                perfdatas => [
                    { template => '%s', min => 0, unit => 'd', label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{collector} = [
        { label => 'collector-status', threshold => 0, set => {
                key_values => [ { name => 'status' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_collector_status_output'),
                closure_custom_perfdata => sub { return 0; },
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
        'warning-collector-status:s'  => { name => 'warning_collector_status', default => '' },
        'critical-collector-status:s' => { name => 'critical_collector_status', default => '%{status} !~ /connected/i' },
        'filter-log-type:s'           => { name => 'filter_log_type' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => ['warning_collector_status', 'critical_collector_status']);
}

sub manage_selection {
    my ($self, %options) = @_;

    # Log rates
    my $oid_incoming = '.1.3.6.1.4.1.25461.2.1.2.7.1.1.0'; # panDeviceIncomingLogRate
    my $oid_write    = '.1.3.6.1.4.1.25461.2.1.2.7.1.2.0'; # panDeviceWriteLogRate
    my $snmp_result = $options{snmp}->get_leef(
        oids => [$oid_incoming, $oid_write],
        nothing_quit => 1
    );
    $self->{global} = {
        incoming_rate => $snmp_result->{$oid_incoming},
        write_rate    => $snmp_result->{$oid_write}
    };

    # Log usage per type
    my $oid_logUsageTable = '.1.3.6.1.4.1.25461.2.1.2.7.3';
    $snmp_result = $options{snmp}->get_table(oid => $oid_logUsageTable);

    my $mapping_usage = {
        display    => { oid => '.1.3.6.1.4.1.25461.2.1.2.7.3.1.1' }, # panDeviceLoggingLogUsageLogType
        disk_usage => { oid => '.1.3.6.1.4.1.25461.2.1.2.7.3.1.2' }, # panDeviceLoggingDiskUsageDiskSpace
        retention  => { oid => '.1.3.6.1.4.1.25461.2.1.2.7.3.1.3' }  # panDeviceLoggingDiskUsageRetention
    };

    $self->{logusage} = {};
    if (defined($snmp_result) && scalar(keys %$snmp_result) > 0) {
        foreach my $oid (keys %$snmp_result) {
            next if ($oid !~ /^$mapping_usage->{display}->{oid}\.(.*)$/);
            my $instance = $1;
            my $result = $options{snmp}->map_instance(mapping => $mapping_usage, results => $snmp_result, instance => $instance);
            next if (!defined($result->{display}) || $result->{display} eq '');

            if (defined($self->{option_results}->{filter_log_type}) && $self->{option_results}->{filter_log_type} ne '' &&
                $result->{display} !~ /$self->{option_results}->{filter_log_type}/) {
                next;
            }
            # disk_usage is DisplayString, convert to number
            $result->{disk_usage} =~ s/[^0-9.]//g if (defined($result->{disk_usage}));
            $self->{logusage}->{$result->{display}} = $result;
        }
    }

    # Collector connections
    my $oid_collectorTable = '.1.3.6.1.4.1.25461.2.1.2.7.5';
    $snmp_result = $options{snmp}->get_table(oid => $oid_collectorTable);

    my $mapping_collector = {
        display => { oid => '.1.3.6.1.4.1.25461.2.1.2.7.5.1.3' }, # panDeviceLoggingCollectorConnectionHostname
        status  => { oid => '.1.3.6.1.4.1.25461.2.1.2.7.5.1.4' }  # panDeviceLoggingCollectorConnectionStatus
    };

    $self->{collector} = {};
    if (defined($snmp_result) && scalar(keys %$snmp_result) > 0) {
        foreach my $oid (keys %$snmp_result) {
            next if ($oid !~ /^$mapping_collector->{display}->{oid}\.(.*)$/);
            my $instance = $1;
            my $result = $options{snmp}->map_instance(mapping => $mapping_collector, results => $snmp_result, instance => $instance);
            next if (!defined($result->{display}) || $result->{display} eq '');
            $self->{collector}->{$result->{display}} = $result;
        }
    }
}

1;

__END__

=head1 MODE

Check device logging: log rates, disk usage per log type, and collector connection status.

=over 8

=item B<--filter-log-type>

Filter log types by name (can be a regexp).

=item B<--warning-collector-status>

Define the conditions to match for the status to be WARNING (default: '').
You can use the following variables: %{status}, %{display}

=item B<--critical-collector-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /connected/i').
You can use the following variables: %{status}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'incoming-log-rate' (logs/s), 'write-log-rate' (logs/s),
'log-disk-usage' (MB), 'log-retention' (days).

=back

=cut
