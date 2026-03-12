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

package storage::hp::msa2000::ssh::mode::volumes;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf('health: %s [owner: %s]', $self->{result_values}->{health}, $self->{result_values}->{owner});
}

sub custom_usage_output {
    my ($self, %options) = @_;

    my ($total_size_value, $total_size_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total_space});
    my ($total_used_value, $total_used_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used_space});
    my ($total_free_value, $total_free_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{free_space});
    return sprintf(
        "space usage total: %s used: %s (%.2f%%) free: %s (%.2f%%)",
        $total_size_value . " " . $total_size_unit,
        $total_used_value . " " . $total_used_unit, $self->{result_values}->{prct_used_space},
        $total_free_value . " " . $total_free_unit, $self->{result_values}->{prct_free_space}
    );
}

sub prefix_volume_output {
    my ($self, %options) = @_;

    return "Volume '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'volume', type => 1, cb_prefix_output => 'prefix_volume_output', message_multiple => 'All volumes are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{volume} = [
        {
            label => 'status',
            type => 2,
            unknown_default => '%{health} =~ /unknown/i',
            warning_default => '',
            critical_default => '%{health} =~ /degraded|fault|failed/i',
            set => {
                key_values => [ { name => 'health' }, { name => 'display' }, { name => 'owner' }, { name => 'reason' }, { name => 'recommendation' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'usage', nlabel => 'volume.space.usage.bytes', set => {
                key_values => [ { name => 'used_space' }, { name => 'free_space' }, { name => 'prct_used_space' }, { name => 'prct_free_space' }, { name => 'total_space' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'usage-free', display_ok => 0, nlabel => 'volume.space.free.bytes', set => {
                key_values => [ { name => 'free_space' }, { name => 'used_space' }, { name => 'prct_used_space' }, { name => 'prct_free_space' }, { name => 'total_space' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'usage-prct', display_ok => 0, nlabel => 'volume.space.usage.percentage', set => {
                key_values => [ { name => 'prct_used_space' }, { name => 'display' } ],
                output_template => 'used: %.2f %%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'read', nlabel => 'volume.io.read.usage.bytespersecond', display_ok => 0, set => {
                key_values => [ { name => 'data-read-numeric', per_second => 1 }, { name => 'display' } ],
                output_template => 'read i/o: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%d', unit => 'B/s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'write', nlabel => 'volume.io.write.usage.bytespersecond', display_ok => 0, set => {
                key_values => [ { name => 'data-written-numeric', per_second => 1 }, { name => 'display' } ],
                output_template => 'write i/o: %s %s/s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%d', unit => 'B/s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'iops', nlabel => 'volume.io.usage.iops', display_ok => 0, set => {
                key_values => [ { name => 'iops' }, { name => 'display' } ],
                output_template => 'iops: %s',
                perfdatas => [
                    { template => '%s', unit => 'iops', min => 0, label_extra_instance => 1, instance_use => 'display' }
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
        'filter-name:s' => { name => 'filter_name' },
        'exclude-name:s' => { name => 'exclude_name' }
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
        cmd => 'show volumes',
        base_type => 'volumes',
        properties_name => '^(?:volume-name|durable-id|size|size-numeric|total-size|total-size-numeric|allocated-size|allocated-size-numeric|health|health-numeric|health-reason|owner|volume-type|serial-number|storage-pool-name)$'
    );

    $self->{volume} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $vol (@items) {
        my $name = defined($vol->{'volume-name'}) ? $vol->{'volume-name'} :
                   (defined($vol->{'durable-id'}) ? $vol->{'durable-id'} : 'unknown');

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping volume '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_name}) && $self->{option_results}->{exclude_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_name}/) {
            $self->{output}->output_add(long_msg => "skipping volume '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $health = defined($vol->{'health-numeric'}) ?
            ($map_health->{ $vol->{'health-numeric'} } // 'unknown') :
            (defined($vol->{'health'}) ? lc($vol->{'health'}) : 'unknown');

        # Size in 512-byte blocks
        my $total = defined($vol->{'total-size-numeric'}) ? $vol->{'total-size-numeric'} * 512 :
                    (defined($vol->{'size-numeric'}) ? $vol->{'size-numeric'} * 512 : 0);
        my $allocated = defined($vol->{'allocated-size-numeric'}) ? $vol->{'allocated-size-numeric'} * 512 : 0;
        my $used = $allocated > 0 ? $allocated : 0;
        my $free = ($total - $used) > 0 ? ($total - $used) : 0;

        $self->{volume}->{$name} = {
            display => $name,
            health => $health,
            owner => defined($vol->{'owner'}) ? $vol->{'owner'} : '-',
            total_space => $total,
            used_space => $used,
            free_space => $free,
            prct_used_space => $total > 0 ? ($used * 100 / $total) : 0,
            prct_free_space => $total > 0 ? ($free * 100 / $total) : 0,
        };
    }

    if (scalar(keys %{$self->{volume}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No volume found.');
        $self->{output}->option_exit();
    }

    # Get volume statistics
    my ($stats) = $options{custom}->get_infos(
        cmd => 'show volume-statistics',
        base_type => 'volume-statistics',
        properties_name => '^(?:volume-name|data-read-numeric|data-written-numeric|iops|number-of-reads|number-of-writes|bytes-per-second-numeric)$',
        no_quit => 1
    );

    if (defined($stats)) {
        my @stat_items = ref($stats) eq 'ARRAY' ? @$stats : values %$stats;
        foreach my $stat (@stat_items) {
            my $name = defined($stat->{'volume-name'}) ? $stat->{'volume-name'} : next;
            next if (!defined($self->{volume}->{$name}));
            foreach my $key (keys %$stat) {
                $self->{volume}->{$name}->{$key} = $stat->{$key};
            }
        }
    }

    $self->{cache_name} = 'hp_msa2000_' . $options{custom}->{hostname} . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_name}) ? md5_hex($self->{option_results}->{filter_name}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check volumes health, space usage, and I/O statistics.

=over 8

=item B<--filter-name>

Filter volume name (can be a regexp).

=item B<--exclude-name>

Exclude volume name (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{health} =~ /unknown/i').
You can use the following variables: %{health}, %{display}, %{owner}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{health} =~ /degraded/i').
You can use the following variables: %{health}, %{display}, %{owner}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{health} =~ /fault|failed/i').
You can use the following variables: %{health}, %{display}, %{owner}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'usage' (B), 'usage-free' (B), 'usage-prct' (%), 'read' (B/s), 'write' (B/s), 'iops'.

=back

=cut
