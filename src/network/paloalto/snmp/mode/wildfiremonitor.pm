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

package network::paloalto::snmp::mode::wildfiremonitor;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_queue_output {
    my ($self, %options) = @_;
    return "Wildfire queue '" . $options{instance_value}->{display} . "' ";
}

sub prefix_utilization_output {
    my ($self, %options) = @_;
    return "Wildfire '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'queue', type => 1, cb_prefix_output => 'prefix_queue_output', message_multiple => 'All Wildfire queues are ok', skipped_code => { -10 => 1 } },
        { name => 'utilization', type => 1, cb_prefix_output => 'prefix_utilization_output', message_multiple => 'All Wildfire utilization metrics are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{queue} = [
        { label => 'archive-count', nlabel => 'wildfire.queue.archive.count', set => {
                key_values => [ { name => 'archive' }, { name => 'display' } ],
                output_template => 'archives: %s',
                perfdatas => [ { template => '%s', min => 0, label_extra_instance => 1 } ]
            }
        },
        { label => 'doc-count', nlabel => 'wildfire.queue.document.count', set => {
                key_values => [ { name => 'doc' }, { name => 'display' } ],
                output_template => 'documents: %s',
                perfdatas => [ { template => '%s', min => 0, label_extra_instance => 1 } ]
            }
        },
        { label => 'elink-count', nlabel => 'wildfire.queue.elink.count', set => {
                key_values => [ { name => 'elink' }, { name => 'display' } ],
                output_template => 'email links: %s',
                perfdatas => [ { template => '%s', min => 0, label_extra_instance => 1 } ]
            }
        },
        { label => 'pe-count', nlabel => 'wildfire.queue.pe.count', set => {
                key_values => [ { name => 'pe' }, { name => 'display' } ],
                output_template => 'portable executables: %s',
                perfdatas => [ { template => '%s', min => 0, label_extra_instance => 1 } ]
            }
        },
        { label => 'url-upload-count', nlabel => 'wildfire.queue.url.upload.count', set => {
                key_values => [ { name => 'url_upload' }, { name => 'display' } ],
                output_template => 'URL uploads: %s',
                perfdatas => [ { template => '%s', min => 0, label_extra_instance => 1 } ]
            }
        }
    ];

    $self->{maps_counters}->{utilization} = [
        { label => 'available', nlabel => 'wildfire.utilization.available.count', set => {
                key_values => [ { name => 'available' }, { name => 'display' } ],
                output_template => 'available: %s',
                perfdatas => [ { template => '%s', min => 0, label_extra_instance => 1 } ]
            }
        },
        { label => 'in-use', nlabel => 'wildfire.utilization.inuse.count', set => {
                key_values => [ { name => 'in_use' }, { name => 'display' } ],
                output_template => 'in use: %s',
                perfdatas => [ { template => '%s', min => 0, label_extra_instance => 1 } ]
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

    # panWFMonitor = .1.3.6.1.4.1.25461.2.1.2.10
    # Queue status table
    my $oid_qstatus = '.1.3.6.1.4.1.25461.2.1.2.10.1';
    my $snmp_q = $options{snmp}->get_table(oid => $oid_qstatus);

    my $mapping_q = {
        display    => { oid => '.1.3.6.1.4.1.25461.2.1.2.10.1.1.2' }, # name
        archive    => { oid => '.1.3.6.1.4.1.25461.2.1.2.10.1.1.3' }, # archiveCount
        doc        => { oid => '.1.3.6.1.4.1.25461.2.1.2.10.1.1.4' }, # docCount
        elink      => { oid => '.1.3.6.1.4.1.25461.2.1.2.10.1.1.5' }, # elinkCount
        pe         => { oid => '.1.3.6.1.4.1.25461.2.1.2.10.1.1.6' }, # portExecCount
        url_upload => { oid => '.1.3.6.1.4.1.25461.2.1.2.10.1.1.7' }  # urlUploadFileCount
    };

    $self->{queue} = {};
    if (defined($snmp_q) && scalar(keys %$snmp_q) > 0) {
        foreach my $oid (keys %$snmp_q) {
            next if ($oid !~ /^$mapping_q->{display}->{oid}\.(.*)$/);
            my $instance = $1;
            my $result = $options{snmp}->map_instance(mapping => $mapping_q, results => $snmp_q, instance => $instance);
            $self->{queue}->{$result->{display}} = $result;
        }
    }

    # Utilization tables (archive, doc, elink, PE) - all share same structure
    my @util_tables = (
        { oid => '.1.3.6.1.4.1.25461.2.1.2.10.2', prefix => 'archive' },
        { oid => '.1.3.6.1.4.1.25461.2.1.2.10.3', prefix => 'doc' },
        { oid => '.1.3.6.1.4.1.25461.2.1.2.10.4', prefix => 'elink' },
        { oid => '.1.3.6.1.4.1.25461.2.1.2.10.5', prefix => 'pe' }
    );

    $self->{utilization} = {};
    foreach my $tbl (@util_tables) {
        my $snmp_u = $options{snmp}->get_table(oid => $tbl->{oid});
        next if (!defined($snmp_u) || scalar(keys %$snmp_u) <= 0);

        my $map_u = {
            display   => { oid => $tbl->{oid} . '.1.2' },
            available => { oid => $tbl->{oid} . '.1.3' },
            in_use    => { oid => $tbl->{oid} . '.1.4' }
        };

        foreach my $oid (keys %$snmp_u) {
            next if ($oid !~ /^$map_u->{display}->{oid}\.(.*)$/);
            my $instance = $1;
            my $result = $options{snmp}->map_instance(mapping => $map_u, results => $snmp_u, instance => $instance);
            my $key = $tbl->{prefix} . '_' . ($result->{display} || $instance);
            $self->{utilization}->{$key} = {
                display   => $tbl->{prefix} . ' - ' . ($result->{display} || $instance),
                available => $result->{available},
                in_use    => $result->{in_use}
            };
        }
    }

    if (scalar(keys %{$self->{queue}}) <= 0 && scalar(keys %{$self->{utilization}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No Wildfire monitoring data found (WF-500 appliance required).');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check Wildfire monitoring queue status and utilization (panWFMonitor).
Monitors archive, document, email link, PE queue depths and VM utilization.
Available on WF-500 appliances.

=over 8

=item B<--warning-*> B<--critical-*>

Thresholds.
Queue: 'archive-count', 'doc-count', 'elink-count', 'pe-count', 'url-upload-count'.
Utilization: 'available', 'in-use'.

=back

=cut
