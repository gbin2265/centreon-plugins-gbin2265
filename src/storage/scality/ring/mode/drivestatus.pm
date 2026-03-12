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

package storage::scality::ring::mode::drivestatus;
use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("state is '%s', status is '%s' [host: %s, ring: %s]",
        $self->{result_values}->{state},
        $self->{result_values}->{status},
        $self->{result_values}->{host},
        $self->{result_values}->{rings});
}

sub custom_usage_output {
    my ($self, %options) = @_;
    my ($used_v,  $used_u)  = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used});
    my ($free_v,  $free_u)  = $self->{perfdata}->change_bytes(value => $self->{result_values}->{free});
    my ($total_v, $total_u) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total});
    return sprintf("used: %s%s, free: %s%s, total: %s%s (%.1f%%)",
        $used_v, $used_u, $free_v, $free_u, $total_v, $total_u,
        $self->{result_values}->{prct_used});
}

sub set_counters {
    my ($self, %options) = @_;
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ', ' },
        { name => 'drives', type => 1, cb_prefix_output => 'prefix_drive_output',
          message_multiple => 'All disks are OK', skipped_code => { -10 => 1 } },
    ];
    $self->{maps_counters}->{global} = [
        { label => 'disks-ok', nlabel => 'disks.status.ok.count', set => {
            key_values => [ { name => 'ok' } ],
            output_template => '%d disk(s) OK',
            perfdatas => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'disks-warning', nlabel => 'disks.status.warning.count', set => {
            key_values => [ { name => 'warning' } ],
            output_template => '%d disk(s) WARNING',
            perfdatas => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'disks-critical', nlabel => 'disks.status.critical.count', set => {
            key_values => [ { name => 'critical' } ],
            output_template => '%d disk(s) CRITICAL',
            perfdatas => [ { template => '%d', min => 0 } ],
          }
        },
    ];
    $self->{maps_counters}->{drives} = [
        { label => 'status', type => 2,
          critical_default => '%{status} !~ /^ok$/i || %{state} !~ /^ok$/i',
          set => {
            key_values => [ { name => 'status' }, { name => 'state' },
                            { name => 'host' }, { name => 'rings' }, { name => 'name' } ],
            closure_custom_output => $self->can('custom_status_output'),
            closure_custom_perfdata => sub { return 0; },
            closure_custom_threshold_check => \&catalog_status_threshold_ng,
          }
        },
        { label => 'usage', nlabel => 'disk.storage.usage.bytes', set => {
            key_values => [ { name => 'used' }, { name => 'free' }, { name => 'total' },
                            { name => 'prct_used' }, { name => 'name' } ],
            closure_custom_output => $self->can('custom_usage_output'),
            perfdatas => [ { template => '%d', unit => 'B', min => 0, max => 'total',
                label_extra_instance => 1, instance_use => 'name', cast_int => 1 } ],
          }
        },
        { label => 'usage-prct', nlabel => 'disk.storage.usage.percentage', display_ok => 0, set => {
            key_values => [ { name => 'prct_used' }, { name => 'name' } ],
            output_template => 'used: %.2f %%',
            perfdatas => [ { template => '%.2f', unit => '%', min => 0, max => 100,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
        { label => 'inodes', nlabel => 'disk.inodes.count', set => {
            key_values => [ { name => 'inodes' }, { name => 'name' } ],
            output_template => '%d inode(s)',
            perfdatas => [ { template => '%d', min => 0,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
    ];
}

sub prefix_drive_output {
    my ($self, %options) = @_;
    return "Disk '" . $options{instance_value}->{name} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        'filter-name:s'    => { name => 'filter_name' },
        'filter-host:s'    => { name => 'filter_host' },
        'filter-ring:s'    => { name => 'filter_ring' },
        'filter-state:s'   => { name => 'filter_state' },
        'filter-status:s'  => { name => 'filter_status' },
        'exclude-name:s'   => { name => 'exclude_name'   },
        'exclude-host:s'   => { name => 'exclude_host'   },
        'exclude-ring:s'   => { name => 'exclude_ring'   },
        'exclude-state:s'  => { name => 'exclude_state'  },
        'exclude-status:s' => { name => 'exclude_status' },
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;
    my $items = $options{custom}->get_drives();

    $self->{global} = { ok => 0, warning => 0, critical => 0 };
    $self->{drives} = {};

    foreach my $disk (@{$items}) {
        my $name  = $disk->{name} // $disk->{id} // 'unknown';
        my $host  = $disk->{host} // 'n/a';
        my $state = ref($disk->{state}) eq 'ARRAY'
                  ? join(',', @{$disk->{state}}) : ($disk->{state} // 'unknown');
        my $rings = ref($disk->{rings}) eq 'ARRAY'
                  ? join(',', @{$disk->{rings}}) : ($disk->{rings} // 'n/a');
        my $status = $disk->{status} // 'unknown';

        # Filters
        next if (defined($self->{option_results}->{filter_name})   && $self->{option_results}->{filter_name}   ne '' && $name   !~ /$self->{option_results}->{filter_name}/);
        next if (defined($self->{option_results}->{filter_host})   && $self->{option_results}->{filter_host}   ne '' && $host   !~ /$self->{option_results}->{filter_host}/);
        next if (defined($self->{option_results}->{filter_ring})   && $self->{option_results}->{filter_ring}   ne '' && $rings  !~ /$self->{option_results}->{filter_ring}/);
        next if (defined($self->{option_results}->{filter_state})  && $self->{option_results}->{filter_state}  ne '' && $state  !~ /$self->{option_results}->{filter_state}/);
        next if (defined($self->{option_results}->{filter_status}) && $self->{option_results}->{filter_status} ne '' && $status !~ /$self->{option_results}->{filter_status}/i);
        # Excludes
        next if (defined($self->{option_results}->{exclude_name})   && $self->{option_results}->{exclude_name}   ne '' && $name   =~ /$self->{option_results}->{exclude_name}/);
        next if (defined($self->{option_results}->{exclude_host})   && $self->{option_results}->{exclude_host}   ne '' && $host   =~ /$self->{option_results}->{exclude_host}/);
        next if (defined($self->{option_results}->{exclude_ring})   && $self->{option_results}->{exclude_ring}   ne '' && $rings  =~ /$self->{option_results}->{exclude_ring}/);
        next if (defined($self->{option_results}->{exclude_state})  && $self->{option_results}->{exclude_state}  ne '' && $state  =~ /$self->{option_results}->{exclude_state}/i);
        next if (defined($self->{option_results}->{exclude_status}) && $self->{option_results}->{exclude_status} ne '' && $status =~ /$self->{option_results}->{exclude_status}/i);

        my $status_lc = lc($status);
        if    ($status_lc eq 'ok')       { $self->{global}->{ok}++;       }
        elsif ($status_lc eq 'warning')  { $self->{global}->{warning}++;  }
        elsif ($status_lc eq 'critical') { $self->{global}->{critical}++; }

        my $total = $disk->{diskspace_total}     // 0 || 0;
        my $used  = $disk->{diskspace_used}      // 0 || 0;
        my $free  = $disk->{diskspace_available} // ($total - $used);
        my $prct  = $total > 0 ? ($used / $total * 100) : 0;

        my $key = $host . ':' . $name;
        $self->{drives}->{$key} = {
            name      => $host . '/' . $name,
            state     => $state,
            status    => $status,
            host      => $host,
            rings     => $rings,
            total     => $total,
            used      => $used,
            free      => $free,
            prct_used => $prct,
            inodes    => ($disk->{number_inodes} // 0) || 0,
        };
    }
    if (scalar(keys %{$self->{drives}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No disks found.");
        $self->{output}->option_exit();
    }
}
1;

__END__

=head1 MODE

Check Scality RING disk/drive status and storage usage.

=over 8

=item B<--filter-name>

Filter disks by name (regexp).

=item B<--filter-host>

Filter disks by host (regexp).

=item B<--filter-ring>

Filter disks by ring (regexp).

=item B<--filter-state>

Filter disks by state (regexp).

=item B<--filter-status>

Filter disks by status (regexp).

=item B<--exclude-name>

Exclude disks by name (regexp).

=item B<--exclude-host>

Exclude disks by host (regexp).

=item B<--exclude-ring>

Exclude disks by ring (regexp).

=item B<--exclude-state>

Exclude disks by state (regexp).

=item B<--exclude-status>

Exclude disks by status (regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{state}, %{host}, %{rings}, %{name}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{state}, %{host}, %{rings}, %{name}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{status} !~ /^ok$/i || %{state} !~ /^ok$/i').
You can use the following variables: %{status}, %{state}, %{host}, %{rings}, %{name}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'disks-ok', 'disks-warning', 'disks-critical',
'usage', 'usage-prct', 'inodes'.

=back

=cut
