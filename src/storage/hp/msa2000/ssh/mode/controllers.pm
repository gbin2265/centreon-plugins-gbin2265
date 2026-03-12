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

package storage::hp::msa2000::ssh::mode::controllers;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf('status: %s', $self->{result_values}->{status});
}

sub custom_write_cache_calc {
    my ($self, %options) = @_;

    my $diff_hits = ($options{new_datas}->{$self->{instance} . '_write-cache-hits'} - $options{old_datas}->{$self->{instance} . '_write-cache-hits'});
    my $total = $diff_hits
        + ($options{new_datas}->{$self->{instance} . '_write-cache-misses'} - $options{old_datas}->{$self->{instance} . '_write-cache-misses'});

    if ($total == 0) {
        $self->{error_msg} = "skipped";
        return -2;
    }

    $self->{result_values}->{'write-cache-hits_prct'} = $diff_hits * 100 / $total;
    return 0;
}

sub custom_read_cache_calc {
    my ($self, %options) = @_;

    my $diff_hits = ($options{new_datas}->{$self->{instance} . '_read-cache-hits'} - $options{old_datas}->{$self->{instance} . '_read-cache-hits'});
    my $total = $diff_hits
        + ($options{new_datas}->{$self->{instance} . '_read-cache-misses'} - $options{old_datas}->{$self->{instance} . '_read-cache-misses'});

    if ($total == 0) {
        $self->{error_msg} = "skipped";
        return -2;
    }

    $self->{result_values}->{'read-cache-hits_prct'} = $diff_hits * 100 / $total;
    return 0;
}

sub controller_long_output {
    my ($self, %options) = @_;

    return "checking controller '" . $options{instance_value}->{name} . "'";
}

sub prefix_controller_output {
    my ($self, %options) = @_;

    return "Controller '" . $options{instance_value}->{name} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'controllers', type => 3, cb_prefix_output => 'prefix_controller_output', cb_long_output => 'controller_long_output', indent_long_output => '    ', message_multiple => 'All controllers are ok',
            group => [
                { name => 'controller_status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'controller_stats', type => 0, skipped_code => { -10 => 1 } },
            ]
        }
    ];

    $self->{maps_counters}->{controller_status} = [
        {
            label => 'controller-status',
            type => 2,
            unknown_default => '%{status} =~ /unknown/i',
            warning_default => '',
            critical_default => '%{status} =~ /degraded|fault|failed/i',
            set => {
                key_values => [
                    { name => 'status' }, { name => 'name' },
                    { name => 'reason' }, { name => 'recommendation' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{controller_stats} = [
        { label => 'cpu-utilization', nlabel => 'controller.cpu.utilization.percentage', set => {
                key_values => [ { name => 'cpu-load' } ],
                output_template => 'cpu utilization: %.2f%%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'read', nlabel => 'controller.io.read.usage.bytespersecond', set => {
                key_values => [ { name => 'data-read-numeric', per_second => 1 } ],
                output_template => 'read i/o: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%d', unit => 'B/s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'write', nlabel => 'controller.io.write.usage.bytespersecond', set => {
                key_values => [ { name => 'data-written-numeric', per_second => 1 } ],
                output_template => 'write i/o: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%d', unit => 'B/s', min => 0, label_extra_instance => 1 },
                ]
            }
        },
        { label => 'read-cache-hits', nlabel => 'controller.cache.read.hits.percentage', set => {
                key_values => [ { name => 'read-cache-hits', diff => 1 }, { name => 'read-cache-misses', diff => 1 } ],
                closure_custom_calc => $self->can('custom_read_cache_calc'),
                output_template => 'read cache hits: %.2f %%',
                output_use => 'read-cache-hits_prct', threshold_use => 'read-cache-hits_prct',
                perfdatas => [
                    { value => 'read-cache-hits_prct', template => '%.2f',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'write-cache-hits', nlabel => 'controller.cache.write.hits.percentage', set => {
                key_values => [ { name => 'write-cache-hits', diff => 1 }, { name => 'write-cache-misses', diff => 1 } ],
                closure_custom_calc => $self->can('custom_write_cache_calc'),
                output_template => 'write cache hits: %.2f %%',
                output_use => 'write-cache-hits_prct', threshold_use => 'write-cache-hits_prct',
                perfdatas => [
                    { value => 'write-cache-hits_prct', template => '%.2f',
                      unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'iops', nlabel => 'controller.io.usage.iops', set => {
                key_values => [ { name => 'iops' } ],
                output_template => 'iops: %s',
                perfdatas => [
                    { template => '%s', unit => 'iops', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-controller-name:s' => { name => 'filter_controller_name' },
        'exclude-controller-name:s' => { name => 'exclude_controller_name' }
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
        cmd => 'show controllers',
        base_type => 'controllers',
        properties_name => '^(?:durable-id|controller-id|serial-number|health|health-numeric|health-reason|health-recommendation|status|model|position|ip-address)$'    );

    $self->{controllers} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $ctrl (@items) {
        my $name = defined($ctrl->{'durable-id'}) ? lc($ctrl->{'durable-id'}) :
                   (defined($ctrl->{'controller-id'}) ? lc($ctrl->{'controller-id'}) : 'unknown');

        if (defined($self->{option_results}->{filter_controller_name}) && $self->{option_results}->{filter_controller_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_controller_name}/) {
            $self->{output}->output_add(long_msg => "skipping controller '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_controller_name}) && $self->{option_results}->{exclude_controller_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_controller_name}/) {
            $self->{output}->output_add(long_msg => "skipping controller '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $health = defined($ctrl->{'health-numeric'}) ?
            ($map_health->{ $ctrl->{'health-numeric'} } // 'unknown') :
            (defined($ctrl->{'health'}) ? lc($ctrl->{'health'}) : 'unknown');

        $self->{controllers}->{$name} = {
            name => $name,
            controller_status => {
                name => $name,
                status => $health,
                reason => defined($ctrl->{'health-reason'}) ? $ctrl->{'health-reason'} : '',
                recommendation => defined($ctrl->{'health-recommendation'}) ? $ctrl->{'health-recommendation'} : '',
            },
            controller_stats => {}
        };
    }

    if (scalar(keys %{$self->{controllers}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No controller found.');
        $self->{output}->option_exit();
    }

    # Get controller statistics
    my ($stats) = $options{custom}->get_infos(
        cmd => 'show controller-statistics',
        base_type => 'controller-statistics',
        properties_name => '^(?:durable-id|cpu-load|data-read-numeric|data-written-numeric|write-cache-hits|write-cache-misses|read-cache-hits|read-cache-misses|iops|bytes-per-second-numeric|number-of-reads|number-of-writes)$',
        no_quit => 1
    );

    if (defined($stats)) {
        my @stat_items = ref($stats) eq 'ARRAY' ? @$stats : values %$stats;
        foreach my $stat (@stat_items) {
            my $name = defined($stat->{'durable-id'}) ? lc($stat->{'durable-id'}) : next;
            next if (!defined($self->{controllers}->{$name}));
            $self->{controllers}->{$name}->{controller_stats} = $stat;
        }
    }

    $self->{cache_name} = 'hp_msa2000_' . $options{custom}->{hostname} . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_controller_name}) ? md5_hex($self->{option_results}->{filter_controller_name}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check controllers status and performance statistics.

=over 8

=item B<--filter-controller-name>

Filter controllers by name (can be a regexp).

=item B<--exclude-controller-name>

Exclude controllers by name (can be a regexp).

=item B<--unknown-controller-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{status} =~ /unknown/i').
You can use the following variables: %{status}, %{name}, %{reason}

=item B<--warning-controller-status>

Define the conditions to match for the status to be WARNING (default: '%{status} =~ /degraded/i').
You can use the following variables: %{status}, %{name}, %{reason}

=item B<--critical-controller-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} =~ /fault|failed/i').
You can use the following variables: %{status}, %{name}, %{reason}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'cpu-utilization', 'read', 'write', 'iops', 'write-cache-hits', 'read-cache-hits'.

=back

=cut
