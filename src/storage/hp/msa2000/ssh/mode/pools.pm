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

package storage::hp::msa2000::ssh::mode::pools;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
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

sub prefix_pool_output {
    my ($self, %options) = @_;

    return "Pool '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'pool', type => 1, cb_prefix_output => 'prefix_pool_output', message_multiple => 'All pools are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{pool} = [
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
        { label => 'usage', nlabel => 'pool.space.usage.bytes', set => {
                key_values => [ { name => 'used_space' }, { name => 'free_space' }, { name => 'prct_used_space' }, { name => 'prct_free_space' }, { name => 'total_space' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'usage-free', display_ok => 0, nlabel => 'pool.space.free.bytes', set => {
                key_values => [ { name => 'free_space' }, { name => 'used_space' }, { name => 'prct_used_space' }, { name => 'prct_free_space' }, { name => 'total_space' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'usage-prct', display_ok => 0, nlabel => 'pool.space.usage.percentage', set => {
                key_values => [ { name => 'prct_used_space' }, { name => 'display' } ],
                output_template => 'used: %.2f %%',
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'pages-alloc-per-minute', nlabel => 'pool.pages.allocated.perminute', display_ok => 0, set => {
                key_values => [ { name => 'pages_alloc_min' }, { name => 'display' } ],
                output_template => 'pages alloc/min: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'pages-dealloc-per-minute', nlabel => 'pool.pages.deallocated.perminute', display_ok => 0, set => {
                key_values => [ { name => 'pages_dealloc_min' }, { name => 'display' } ],
                output_template => 'pages dealloc/min: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'pages-unmap-per-minute', nlabel => 'pool.pages.unmapped.perminute', display_ok => 0, set => {
                key_values => [ { name => 'pages_unmap_min' }, { name => 'display' } ],
                output_template => 'pages unmap/min: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'hot-page-moves', nlabel => 'pool.pages.hot.moves.count', display_ok => 0, set => {
                key_values => [ { name => 'hot_page_moves' }, { name => 'display' } ],
                output_template => 'hot page moves: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'cold-page-moves', nlabel => 'pool.pages.cold.moves.count', display_ok => 0, set => {
                key_values => [ { name => 'cold_page_moves' }, { name => 'display' } ],
                output_template => 'cold page moves: %s',
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
        cmd => 'show pools',
        base_type => 'pools',
        properties_name => '^(?:name|serial-number|total-size|total-size-numeric|total-avail|total-avail-numeric|snap-size|snap-size-numeric|allocated-size|allocated-size-numeric|health|health-numeric|health-reason|health-recommendation|owner|raidtype|num-disk-groups|num-drives|pool-sector-format)$'
    );

    $self->{pool} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $pool (@items) {
        my $name = defined($pool->{'name'}) ? $pool->{'name'} : 'unknown';

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping pool '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_name}) && $self->{option_results}->{exclude_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_name}/) {
            $self->{output}->output_add(long_msg => "skipping pool '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $health = defined($pool->{'health-numeric'}) ?
            ($map_health->{ $pool->{'health-numeric'} } // 'unknown') :
            (defined($pool->{'health'}) ? lc($pool->{'health'}) : 'unknown');

        # Size in 512-byte blocks
        my $total = defined($pool->{'total-size-numeric'}) ? $pool->{'total-size-numeric'} * 512 : 0;
        my $free = defined($pool->{'total-avail-numeric'}) ? $pool->{'total-avail-numeric'} * 512 : 0;
        my $used = $total - $free;

        $self->{pool}->{$name} = {
            display => $name,
            health => $health,
            owner => defined($pool->{'owner'}) ? $pool->{'owner'} : '-',
            reason => defined($pool->{'health-reason'}) ? $pool->{'health-reason'} : '',
            recommendation => defined($pool->{'health-recommendation'}) ? $pool->{'health-recommendation'} : '',
            total_space => $total,
            used_space => $used > 0 ? $used : 0,
            free_space => $free,
            prct_used_space => $total > 0 ? ($used * 100 / $total) : 0,
            prct_free_space => $total > 0 ? ($free * 100 / $total) : 0,
            pages_alloc_min => undef,
            pages_dealloc_min => undef,
            pages_unmap_min => undef,
            hot_page_moves => undef,
            cold_page_moves => undef,
        };
    }

    # Fetch pool-statistics
    my ($stats_result) = $options{custom}->get_infos(
        cmd => 'show pool-statistics',
        base_type => 'pool-statistics',
        properties_name => '^(?:pool|serial-number|pages-alloc-per-minute|pages-dealloc-per-minute|pages-unmap-per-minute|num-hot-page-moves|num-cold-page-moves|num-page-allocations|num-page-deallocations|num-page-unmaps)$',
        no_quit => 1
    );

    if (defined($stats_result)) {
        my @stat_items = ref($stats_result) eq 'ARRAY' ? @$stats_result : values %$stats_result;

        foreach my $stat (@stat_items) {
            my $pool_letter = defined($stat->{'pool'}) ? $stat->{'pool'} : next;

            # Match pool-statistics 'pool' (A/B) to pools 'name'
            # Try exact match first, then match by owner
            my $matched;
            foreach my $pname (keys %{$self->{pool}}) {
                if ($pname eq $pool_letter || (defined($self->{pool}->{$pname}->{owner}) && uc($self->{pool}->{$pname}->{owner}) eq uc($pool_letter))) {
                    $matched = $pname;
                    last;
                }
            }
            next if (!defined($matched));

            $self->{pool}->{$matched}->{pages_alloc_min} = defined($stat->{'pages-alloc-per-minute'}) ? $stat->{'pages-alloc-per-minute'} : undef;
            $self->{pool}->{$matched}->{pages_dealloc_min} = defined($stat->{'pages-dealloc-per-minute'}) ? $stat->{'pages-dealloc-per-minute'} : undef;
            $self->{pool}->{$matched}->{pages_unmap_min} = defined($stat->{'pages-unmap-per-minute'}) ? $stat->{'pages-unmap-per-minute'} : undef;
            $self->{pool}->{$matched}->{hot_page_moves} = defined($stat->{'num-hot-page-moves'}) ? $stat->{'num-hot-page-moves'} : undef;
            $self->{pool}->{$matched}->{cold_page_moves} = defined($stat->{'num-cold-page-moves'}) ? $stat->{'num-cold-page-moves'} : undef;
        }
    }

    if (scalar(keys %{$self->{pool}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No pool found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check storage pools health and space usage.

=over 8

=item B<--filter-name>

Filter pool name (can be a regexp).

=item B<--exclude-name>

Exclude pool name (can be a regexp).

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
Can be: 'usage' (B), 'usage-free' (B), 'usage-prct' (%),
'pages-alloc-per-minute', 'pages-dealloc-per-minute', 'pages-unmap-per-minute',
'hot-page-moves', 'cold-page-moves'.

=back

=cut
