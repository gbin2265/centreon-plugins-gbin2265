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

package storage::hp::msa2000::ssh::mode::disks;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf('status: %s [usage: %s, type: %s, size: %s]',
        $self->{result_values}->{health},
        $self->{result_values}->{usage},
        $self->{result_values}->{type},
        $self->{result_values}->{size}
    );
}

sub prefix_disk_output {
    my ($self, %options) = @_;

    return "Disk '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'disk', type => 1, cb_prefix_output => 'prefix_disk_output', message_multiple => 'All disks are ok' }
    ];

    $self->{maps_counters}->{disk} = [
        {
            label => 'status',
            type => 2,
            unknown_default => '%{health} =~ /unknown/i',
            warning_default => '',
            critical_default => '%{health} =~ /degraded|fault|failed/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'display' }, { name => 'usage' },
                    { name => 'type' }, { name => 'size' }, { name => 'reason' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'temperature', nlabel => 'disk.temperature.celsius', set => {
                key_values => [ { name => 'temperature' }, { name => 'display' } ],
                output_template => 'temperature: %s C',
                perfdatas => [
                    { template => '%s', unit => 'C', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-power-on-hours', nlabel => 'disk.power.on.hours.count', display_ok => 0, set => {
                key_values => [ { name => 'power_on_hours' }, { name => 'display' } ],
                output_template => 'power on hours: %s h',
                perfdatas => [
                    { template => '%s', unit => 'h', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-errors', nlabel => 'disk.errors.count', display_ok => 0, set => {
                key_values => [ { name => 'errors' }, { name => 'display' } ],
                output_template => 'errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-iops', nlabel => 'disk.io.total.count', display_ok => 0, set => {
                key_values => [ { name => 'iops' }, { name => 'display' } ],
                output_template => 'total IOs: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-data-transferred', nlabel => 'disk.data.transferred.bytes', display_ok => 0, set => {
                key_values => [ { name => 'data_transferred_bytes' }, { name => 'display' } ],
                output_template => 'data transferred: %s B',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-avg-response-time', nlabel => 'disk.io.average.response.time.microseconds', display_ok => 0, set => {
                key_values => [ { name => 'avg_rsp_time' }, { name => 'display' } ],
                output_template => 'avg response time: %s us',
                perfdatas => [
                    { template => '%s', unit => 'us', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-ssd-life', nlabel => 'disk.ssd.life.remaining.percentage', display_ok => 0, set => {
                key_values => [ { name => 'ssd_life' }, { name => 'display' } ],
                output_template => 'SSD life remaining: %s%%',
                perfdatas => [
                    { template => '%s', unit => '%', min => 0, max => 100, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-spin-down-count', nlabel => 'disk.spin.down.count', display_ok => 0, set => {
                key_values => [ { name => 'spin_down_count' }, { name => 'display' } ],
                output_template => 'spin down count: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        # From show disk-statistics
        { label => 'disk-iops-current', nlabel => 'disk.io.persecond', display_ok => 0, set => {
                key_values => [ { name => 'stat_iops' }, { name => 'display' } ],
                output_template => 'current IOPS: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-reads', nlabel => 'disk.io.read.count', display_ok => 0, set => {
                key_values => [ { name => 'stat_reads' }, { name => 'display' } ],
                output_template => 'reads: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-writes', nlabel => 'disk.io.write.count', display_ok => 0, set => {
                key_values => [ { name => 'stat_writes' }, { name => 'display' } ],
                output_template => 'writes: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-throughput', nlabel => 'disk.throughput.bytespersecond', display_ok => 0, set => {
                key_values => [ { name => 'stat_bps' }, { name => 'display' } ],
                output_template => 'throughput: %s B/s',
                perfdatas => [
                    { template => '%s', unit => 'B/s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-data-read', nlabel => 'disk.data.read.bytes', display_ok => 0, set => {
                key_values => [ { name => 'stat_data_read' }, { name => 'display' } ],
                output_template => 'data read: %s B',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-data-written', nlabel => 'disk.data.written.bytes', display_ok => 0, set => {
                key_values => [ { name => 'stat_data_written' }, { name => 'display' } ],
                output_template => 'data written: %s B',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-queue-depth', nlabel => 'disk.queue.depth.count', display_ok => 0, set => {
                key_values => [ { name => 'queue_depth' }, { name => 'display' } ],
                output_template => 'queue depth: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-smart-events', nlabel => 'disk.smart.events.count', display_ok => 0, set => {
                key_values => [ { name => 'smart_count' }, { name => 'display' } ],
                output_template => 'SMART events: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-media-errors', nlabel => 'disk.media.errors.count', display_ok => 0, set => {
                key_values => [ { name => 'media_errors' }, { name => 'display' } ],
                output_template => 'media errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-nonmedia-errors', nlabel => 'disk.nonmedia.errors.count', display_ok => 0, set => {
                key_values => [ { name => 'nonmedia_errors' }, { name => 'display' } ],
                output_template => 'non-media errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-bad-blocks', nlabel => 'disk.bad.blocks.count', display_ok => 0, set => {
                key_values => [ { name => 'bad_blocks' }, { name => 'display' } ],
                output_template => 'bad blocks: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'disk-io-timeouts', nlabel => 'disk.io.timeouts.count', display_ok => 0, set => {
                key_values => [ { name => 'io_timeouts' }, { name => 'display' } ],
                output_template => 'IO timeouts: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
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
        'filter-disk-name:s' => { name => 'filter_disk_name' },
        'exclude-disk-name:s' => { name => 'exclude_disk_name' }
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
        cmd => 'show disks',
        base_type => 'drives',
        properties_name => '^(?:durable-id|location|serial-number|vendor|model|revision|size|size-numeric|health|health-numeric|health-reason|health-recommendation|temperature|temperature-numeric|temperature-status|usage|type|description|architecture|interface|disk-group|storage-pool-name|storage-tier|power-on-hours|error|number-of-ios|total-data-transferred|total-data-transferred-numeric|avg-rsp-time|ssd-life-left|ssd-life-left-numeric|rpm|transfer-rate|sector-format|slot|enclosure-id|recon-state|copyback-state|state|job-running|current-job-completion|fde-state|disk-dsd-count)$'
    );

    $self->{disk} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $disk (@items) {
        my $name = defined($disk->{'location'}) ? $disk->{'location'} :
                   (defined($disk->{'durable-id'}) ? $disk->{'durable-id'} :
                   (defined($disk->{'slot'}) ? 'slot_' . $disk->{'slot'} : 'unknown'));

        if (defined($self->{option_results}->{filter_disk_name}) && $self->{option_results}->{filter_disk_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_disk_name}/) {
            $self->{output}->output_add(long_msg => "skipping disk '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_disk_name}) && $self->{option_results}->{exclude_disk_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_disk_name}/) {
            $self->{output}->output_add(long_msg => "skipping disk '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $health = defined($disk->{'health-numeric'}) ?
            ($map_health->{ $disk->{'health-numeric'} } // 'unknown') :
            (defined($disk->{'health'}) ? lc($disk->{'health'}) : 'unknown');

        # Temperature
        my $temperature = defined($disk->{'temperature-numeric'}) ? $disk->{'temperature-numeric'} :
                          (defined($disk->{'temperature'}) ? $disk->{'temperature'} : undef);
        if (defined($temperature)) {
            $temperature =~ s/[^\d.-]//g;
            $temperature = undef if ($temperature eq '' || $temperature == 0);
        }

        # SSD life remaining (255 = N/A)
        my $ssd_life = defined($disk->{'ssd-life-left-numeric'}) ? $disk->{'ssd-life-left-numeric'} : undef;
        $ssd_life = undef if (defined($ssd_life) && $ssd_life >= 255);

        # Errors
        my $errors = defined($disk->{'error'}) ? $disk->{'error'} : undef;

        # IO count
        my $iops = defined($disk->{'number-of-ios'}) ? $disk->{'number-of-ios'} : undef;

        # Size human readable
        my $size = defined($disk->{'size'}) ? $disk->{'size'} : '-';

        $self->{disk}->{$name} = {
            display => $name,
            health => $health,
            usage => defined($disk->{'usage'}) ? $disk->{'usage'} : '-',
            type => defined($disk->{'description'}) ? $disk->{'description'} :
                    (defined($disk->{'type'}) ? $disk->{'type'} : '-'),
            size => $size,
            reason => defined($disk->{'health-reason'}) ? $disk->{'health-reason'} : '',
            temperature => $temperature,
            power_on_hours => defined($disk->{'power-on-hours'}) ? $disk->{'power-on-hours'} : undef,
            errors => $errors,
            iops => $iops,
            data_transferred_bytes => defined($disk->{'total-data-transferred-numeric'}) ?
                $disk->{'total-data-transferred-numeric'} * 512 : undef,
            avg_rsp_time => defined($disk->{'avg-rsp-time'}) ? $disk->{'avg-rsp-time'} : undef,
            ssd_life => $ssd_life,
            spin_down_count => defined($disk->{'disk-dsd-count'}) ? $disk->{'disk-dsd-count'} : undef,
            # From disk-statistics (populated later)
            stat_iops => undef,
            stat_reads => undef,
            stat_writes => undef,
            stat_bps => undef,
            stat_data_read => undef,
            stat_data_written => undef,
            queue_depth => undef,
            smart_count => undef,
            media_errors => undef,
            nonmedia_errors => undef,
            bad_blocks => undef,
            io_timeouts => undef,
        };

        # Verbose output with all details
        my $long = sprintf(
            "disk '%s' [encl: %s, slot: %s] [vendor: %s, model: %s, rev: %s, serial: %s]" .
            " [size: %s, type: %s, arch: %s, interface: %s, rpm: %s, transfer: %s]" .
            " [usage: %s, state: %s, disk-group: %s, pool: %s, tier: %s]" .
            " [health: %s, temp: %s, temp-status: %s, power-on: %sh, errors: %s, IOs: %s, data: %s, avg-rsp: %sus]" .
            " [recon: %s, copyback: %s, job: %s %s]" .
            " [SSD life: %s, FDE: %s, sector: %s]",
            $name,
            defined($disk->{'enclosure-id'}) ? $disk->{'enclosure-id'} : '-',
            defined($disk->{'slot'}) ? $disk->{'slot'} : '-',
            defined($disk->{'vendor'}) ? $disk->{'vendor'} : '-',
            defined($disk->{'model'}) ? $disk->{'model'} : '-',
            defined($disk->{'revision'}) ? $disk->{'revision'} : '-',
            defined($disk->{'serial-number'}) ? $disk->{'serial-number'} : '-',
            $size,
            defined($disk->{'description'}) ? $disk->{'description'} : '-',
            defined($disk->{'architecture'}) ? $disk->{'architecture'} : '-',
            defined($disk->{'interface'}) ? $disk->{'interface'} : '-',
            defined($disk->{'rpm'}) ? $disk->{'rpm'} . 'k' : '-',
            defined($disk->{'transfer-rate'}) ? $disk->{'transfer-rate'} . ' Gbps' : '-',
            defined($disk->{'usage'}) ? $disk->{'usage'} : '-',
            defined($disk->{'state'}) ? $disk->{'state'} : '-',
            defined($disk->{'disk-group'}) ? $disk->{'disk-group'} : '-',
            defined($disk->{'storage-pool-name'}) ? $disk->{'storage-pool-name'} : '-',
            defined($disk->{'storage-tier'}) ? $disk->{'storage-tier'} : '-',
            $health,
            defined($disk->{'temperature'}) ? $disk->{'temperature'} : '-',
            defined($disk->{'temperature-status'}) ? $disk->{'temperature-status'} : '-',
            defined($disk->{'power-on-hours'}) ? $disk->{'power-on-hours'} : '-',
            defined($disk->{'error'}) ? $disk->{'error'} : '0',
            defined($disk->{'number-of-ios'}) ? $disk->{'number-of-ios'} : '-',
            defined($disk->{'total-data-transferred'}) ? $disk->{'total-data-transferred'} : '-',
            defined($disk->{'avg-rsp-time'}) ? $disk->{'avg-rsp-time'} : '-',
            defined($disk->{'recon-state'}) ? $disk->{'recon-state'} : '-',
            defined($disk->{'copyback-state'}) ? $disk->{'copyback-state'} : '-',
            defined($disk->{'job-running'}) ? $disk->{'job-running'} : '-',
            defined($disk->{'current-job-completion'}) ? $disk->{'current-job-completion'} : '',
            defined($disk->{'ssd-life-left'}) ? $disk->{'ssd-life-left'} : '-',
            defined($disk->{'fde-state'}) ? $disk->{'fde-state'} : '-',
            defined($disk->{'sector-format'}) ? $disk->{'sector-format'} : '-'
        );
        $self->{output}->output_add(long_msg => $long);
    }

    # Fetch disk-statistics for IOPS, throughput, errors, SMART events
    my ($stats_result) = $options{custom}->get_infos(
        cmd => 'show disk-statistics',
        base_type => 'disk-statistics',
        properties_name => '^(?:location|durable-id|iops|number-of-reads|number-of-writes|data-read-numeric|data-written-numeric|bytes-per-second-numeric|queue-depth|smart-count-1|smart-count-2|io-timeout-count-1|io-timeout-count-2|no-response-count-1|no-response-count-2|number-of-media-errors-1|number-of-media-errors-2|number-of-nonmedia-errors-1|number-of-nonmedia-errors-2|number-of-block-reassigns-1|number-of-block-reassigns-2|number-of-bad-blocks-1|number-of-bad-blocks-2)$',
        no_quit => 1
    );

    if (defined($stats_result)) {
        my @stat_items = ref($stats_result) eq 'ARRAY' ? @$stats_result : values %$stats_result;

        foreach my $stat (@stat_items) {
            my $name = defined($stat->{'location'}) ? $stat->{'location'} : next;
            next if (!defined($self->{disk}->{$name}));

            $self->{disk}->{$name}->{stat_iops} = defined($stat->{'iops'}) ? $stat->{'iops'} : undef;
            $self->{disk}->{$name}->{stat_reads} = defined($stat->{'number-of-reads'}) ? $stat->{'number-of-reads'} : undef;
            $self->{disk}->{$name}->{stat_writes} = defined($stat->{'number-of-writes'}) ? $stat->{'number-of-writes'} : undef;
            $self->{disk}->{$name}->{stat_bps} = defined($stat->{'bytes-per-second-numeric'}) ? $stat->{'bytes-per-second-numeric'} : undef;
            $self->{disk}->{$name}->{stat_data_read} = defined($stat->{'data-read-numeric'}) ? $stat->{'data-read-numeric'} * 512 : undef;
            $self->{disk}->{$name}->{stat_data_written} = defined($stat->{'data-written-numeric'}) ? $stat->{'data-written-numeric'} * 512 : undef;
            $self->{disk}->{$name}->{queue_depth} = defined($stat->{'queue-depth'}) ? $stat->{'queue-depth'} : undef;

            # Sum port 1 + port 2 for error counters
            my $smart = (defined($stat->{'smart-count-1'}) ? $stat->{'smart-count-1'} : 0)
                      + (defined($stat->{'smart-count-2'}) ? $stat->{'smart-count-2'} : 0);
            my $media = (defined($stat->{'number-of-media-errors-1'}) ? $stat->{'number-of-media-errors-1'} : 0)
                      + (defined($stat->{'number-of-media-errors-2'}) ? $stat->{'number-of-media-errors-2'} : 0);
            my $nonmedia = (defined($stat->{'number-of-nonmedia-errors-1'}) ? $stat->{'number-of-nonmedia-errors-1'} : 0)
                         + (defined($stat->{'number-of-nonmedia-errors-2'}) ? $stat->{'number-of-nonmedia-errors-2'} : 0);
            my $bad = (defined($stat->{'number-of-bad-blocks-1'}) ? $stat->{'number-of-bad-blocks-1'} : 0)
                    + (defined($stat->{'number-of-bad-blocks-2'}) ? $stat->{'number-of-bad-blocks-2'} : 0);
            my $timeouts = (defined($stat->{'io-timeout-count-1'}) ? $stat->{'io-timeout-count-1'} : 0)
                         + (defined($stat->{'io-timeout-count-2'}) ? $stat->{'io-timeout-count-2'} : 0);

            $self->{disk}->{$name}->{smart_count} = $smart;
            $self->{disk}->{$name}->{media_errors} = $media;
            $self->{disk}->{$name}->{nonmedia_errors} = $nonmedia;
            $self->{disk}->{$name}->{bad_blocks} = $bad;
            $self->{disk}->{$name}->{io_timeouts} = $timeouts;
        }
    }

    if (scalar(keys %{$self->{disk}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No disk found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check physical disks health, temperature, power-on hours, errors, IO statistics, and SSD life.

Uses 'show disks' for health/status and 'show disk-statistics' for IO and error counters.

=over 8

=item B<--filter-disk-name>

Filter disks by name/location (can be a regexp).

=item B<--exclude-disk-name>

Exclude disks by name/location (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{health} =~ /unknown/i').
You can use the following variables: %{health}, %{display}, %{usage}, %{type}, %{size}, %{reason}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{health} =~ /degraded/i').
You can use the following variables: %{health}, %{display}, %{usage}, %{type}, %{size}, %{reason}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{health} =~ /fault|failed/i').
You can use the following variables: %{health}, %{display}, %{usage}, %{type}, %{size}, %{reason}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'temperature' (C), 'disk-power-on-hours' (h), 'disk-errors',
'disk-iops', 'disk-data-transferred' (B), 'disk-avg-response-time' (us),
'disk-ssd-life' (%), 'disk-spin-down-count',
'disk-iops-current', 'disk-reads', 'disk-writes',
'disk-throughput' (B/s), 'disk-data-read' (B), 'disk-data-written' (B),
'disk-queue-depth', 'disk-smart-events', 'disk-media-errors',
'disk-nonmedia-errors', 'disk-bad-blocks', 'disk-io-timeouts'.

=back

=cut
