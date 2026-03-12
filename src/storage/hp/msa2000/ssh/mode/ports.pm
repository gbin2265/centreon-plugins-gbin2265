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

package storage::hp::msa2000::ssh::mode::ports;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf('status: %s [type: %s, speed: %s, link: %s]',
        $self->{result_values}->{health},
        $self->{result_values}->{media},
        $self->{result_values}->{actual_speed},
        $self->{result_values}->{link_status}
    );
}

sub prefix_port_output {
    my ($self, %options) = @_;

    return "Port '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'port', type => 1, cb_prefix_output => 'prefix_port_output', message_multiple => 'All ports are ok' }
    ];

    $self->{maps_counters}->{port} = [
        {
            label => 'status',
            type => 2,
            unknown_default => '%{health} =~ /unknown/i',
            warning_default => '',
            critical_default => '%{health} =~ /degraded|fault|failed|error/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'display' }, { name => 'media' },
                    { name => 'actual_speed' }, { name => 'link_status' }, { name => 'reason' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'port-iops', nlabel => 'port.io.persecond', display_ok => 0, set => {
                key_values => [ { name => 'iops' }, { name => 'display' } ],
                output_template => 'IOPS: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'port-reads', nlabel => 'port.io.read.count', display_ok => 0, set => {
                key_values => [ { name => 'reads' }, { name => 'display' } ],
                output_template => 'reads: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'port-writes', nlabel => 'port.io.write.count', display_ok => 0, set => {
                key_values => [ { name => 'writes' }, { name => 'display' } ],
                output_template => 'writes: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'port-throughput', nlabel => 'port.throughput.bytespersecond', display_ok => 0, set => {
                key_values => [ { name => 'bps' }, { name => 'display' } ],
                output_template => 'throughput: %s B/s',
                perfdatas => [
                    { template => '%s', unit => 'B/s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'port-data-read', nlabel => 'port.data.read.bytes', display_ok => 0, set => {
                key_values => [ { name => 'data_read' }, { name => 'display' } ],
                output_template => 'data read: %s B',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'port-data-written', nlabel => 'port.data.written.bytes', display_ok => 0, set => {
                key_values => [ { name => 'data_written' }, { name => 'display' } ],
                output_template => 'data written: %s B',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'port-queue-depth', nlabel => 'port.queue.depth.count', display_ok => 0, set => {
                key_values => [ { name => 'queue_depth' }, { name => 'display' } ],
                output_template => 'queue depth: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'port-avg-response-time', nlabel => 'port.io.response.time.microseconds', display_ok => 0, set => {
                key_values => [ { name => 'avg_rsp' }, { name => 'display' } ],
                output_template => 'avg response time: %s us',
                perfdatas => [
                    { template => '%s', unit => 'us', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'port-avg-read-response-time', nlabel => 'port.io.read.response.time.microseconds', display_ok => 0, set => {
                key_values => [ { name => 'avg_read_rsp' }, { name => 'display' } ],
                output_template => 'avg read response time: %s us',
                perfdatas => [
                    { template => '%s', unit => 'us', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'port-avg-write-response-time', nlabel => 'port.io.write.response.time.microseconds', display_ok => 0, set => {
                key_values => [ { name => 'avg_write_rsp' }, { name => 'display' } ],
                output_template => 'avg write response time: %s us',
                perfdatas => [
                    { template => '%s', unit => 'us', min => 0, label_extra_instance => 1, instance_use => 'display' }
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
        'filter-port-name:s' => { name => 'filter_port_name' },
        'exclude-port-name:s' => { name => 'exclude_port_name' }
    });

    return $self;
}

my $map_health = {
    0 => 'ok', 1 => 'degraded',
    2 => 'fault', 3 => 'unknown',
    4 => 'not available',
};

sub manage_selection {
    my ($self, %options) = @_;

    my ($result) = $options{custom}->get_infos(
        cmd => 'show ports',
        base_type => 'port',
        properties_name => '^(?:durable-id|port|controller|port-type|media|target-id|status|status-numeric|actual-speed|configured-speed|health|health-numeric|health-reason|health-recommendation|fan-out)$'
    );

    $self->{port} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $port (@items) {
        my $name = defined($port->{'port'}) ? $port->{'port'} :
                   (defined($port->{'durable-id'}) ? $port->{'durable-id'} : 'unknown');

        if (defined($self->{option_results}->{filter_port_name}) && $self->{option_results}->{filter_port_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_port_name}/) {
            $self->{output}->output_add(long_msg => "skipping port '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_port_name}) && $self->{option_results}->{exclude_port_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_port_name}/) {
            $self->{output}->output_add(long_msg => "skipping port '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $health = defined($port->{'health-numeric'}) ?
            ($map_health->{ $port->{'health-numeric'} } // 'unknown') :
            (defined($port->{'health'}) ? lc($port->{'health'}) : 'unknown');

        my $link_status = defined($port->{'status'}) ? $port->{'status'} : '-';

        $self->{port}->{$name} = {
            display => $name,
            health => $health,
            media => defined($port->{'media'}) ? $port->{'media'} : '-',
            actual_speed => defined($port->{'actual-speed'}) ? $port->{'actual-speed'} : '-',
            link_status => $link_status,
            reason => defined($port->{'health-reason'}) ? $port->{'health-reason'} : '',
            iops => undef,
            reads => undef,
            writes => undef,
            bps => undef,
            data_read => undef,
            data_written => undef,
            queue_depth => undef,
            avg_rsp => undef,
            avg_read_rsp => undef,
            avg_write_rsp => undef,
        };

        $self->{output}->output_add(long_msg => sprintf(
            "port '%s' [controller: %s] [type: %s] [speed: %s] [configured: %s] [link: %s] [target: %s]",
            $name,
            defined($port->{'controller'}) ? $port->{'controller'} : '-',
            defined($port->{'media'}) ? $port->{'media'} : '-',
            defined($port->{'actual-speed'}) ? $port->{'actual-speed'} : '-',
            defined($port->{'configured-speed'}) ? $port->{'configured-speed'} : '-',
            $link_status,
            defined($port->{'target-id'}) ? $port->{'target-id'} : '-'
        ));
    }

    # Fetch host-port-statistics (durable-id: hostport_A1 -> port name: A1)
    my ($stats_result) = $options{custom}->get_infos(
        cmd => 'show host-port-statistics',
        base_type => 'host-port-statistics',
        properties_name => '^(?:durable-id|iops|number-of-reads|number-of-writes|data-read-numeric|data-written-numeric|bytes-per-second-numeric|queue-depth|avg-rsp-time|avg-read-rsp-time|avg-write-rsp-time)$',
        no_quit => 1
    );

    if (defined($stats_result)) {
        my @stat_items = ref($stats_result) eq 'ARRAY' ? @$stats_result : values %$stats_result;

        foreach my $stat (@stat_items) {
            my $durable_id = defined($stat->{'durable-id'}) ? $stat->{'durable-id'} : next;
            # hostport_A1 -> A1
            my $port_name = $durable_id;
            $port_name =~ s/^hostport_//;
            next if (!defined($self->{port}->{$port_name}));

            $self->{port}->{$port_name}->{iops} = defined($stat->{'iops'}) ? $stat->{'iops'} : undef;
            $self->{port}->{$port_name}->{reads} = defined($stat->{'number-of-reads'}) ? $stat->{'number-of-reads'} : undef;
            $self->{port}->{$port_name}->{writes} = defined($stat->{'number-of-writes'}) ? $stat->{'number-of-writes'} : undef;
            $self->{port}->{$port_name}->{bps} = defined($stat->{'bytes-per-second-numeric'}) ? $stat->{'bytes-per-second-numeric'} : undef;
            $self->{port}->{$port_name}->{data_read} = defined($stat->{'data-read-numeric'}) ? $stat->{'data-read-numeric'} * 512 : undef;
            $self->{port}->{$port_name}->{data_written} = defined($stat->{'data-written-numeric'}) ? $stat->{'data-written-numeric'} * 512 : undef;
            $self->{port}->{$port_name}->{queue_depth} = defined($stat->{'queue-depth'}) ? $stat->{'queue-depth'} : undef;
            $self->{port}->{$port_name}->{avg_rsp} = defined($stat->{'avg-rsp-time'}) ? $stat->{'avg-rsp-time'} : undef;
            $self->{port}->{$port_name}->{avg_read_rsp} = defined($stat->{'avg-read-rsp-time'}) ? $stat->{'avg-read-rsp-time'} : undef;
            $self->{port}->{$port_name}->{avg_write_rsp} = defined($stat->{'avg-write-rsp-time'}) ? $stat->{'avg-write-rsp-time'} : undef;
        }
    }

    if (scalar(keys %{$self->{port}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No port found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check ports health, link status and IO statistics.

Uses 'show ports' for health/status and 'show host-port-statistics' for IO counters.

=over 8

=item B<--filter-port-name>

Filter ports by name (can be a regexp, e.g. '^A').

=item B<--exclude-port-name>

Exclude ports by name (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{health} =~ /unknown/i').
You can use the following variables: %{health}, %{display}, %{media}, %{actual_speed}, %{link_status}, %{reason}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{health} =~ /degraded/i').
You can use the following variables: %{health}, %{display}, %{media}, %{actual_speed}, %{link_status}, %{reason}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{health} =~ /fault|failed|error/i').
You can use the following variables: %{health}, %{display}, %{media}, %{actual_speed}, %{link_status}, %{reason}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'port-iops', 'port-reads', 'port-writes',
'port-throughput' (B/s), 'port-data-read' (B), 'port-data-written' (B),
'port-queue-depth', 'port-avg-response-time' (us),
'port-avg-read-response-time' (us), 'port-avg-write-response-time' (us).

=back

=cut
