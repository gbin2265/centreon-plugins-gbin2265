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

package apps::backup::commvault::commserve::restapi::mode::libraryusage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [type: %s]', $self->{result_values}->{status}, $self->{result_values}->{library_type});
}

sub custom_usage_output {
    my ($self, %options) = @_;
    my ($total_value, $total_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total_space});
    my ($used_value, $used_unit)   = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used_space});
    my ($free_value, $free_unit)   = $self->{perfdata}->change_bytes(value => $self->{result_values}->{free_space});
    return sprintf(
        'space usage total: %s used: %s (%.2f%%) free: %s (%.2f%%)',
        $total_value . " " . $total_unit,
        $used_value . " " . $used_unit, $self->{result_values}->{prct_used_space},
        $free_value . " " . $free_unit, $self->{result_values}->{prct_free_space}
    );
}

sub prefix_library_output {
    my ($self, %options) = @_;
    return "Library '" . $options{instance_value}->{display} . "' [id: " . $options{instance_value}->{library_id} . "] ";
}

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Libraries ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'libraries', type => 1, cb_prefix_output => 'prefix_library_output', message_multiple => 'All libraries are ok', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'libraries-total', nlabel => 'libraries.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'libraries-online', nlabel => 'libraries.online.count', display_ok => 0, set => {
                key_values => [ { name => 'online' }, { name => 'total' } ],
                output_template => 'online: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        },
        { label => 'libraries-offline', nlabel => 'libraries.offline.count', display_ok => 0, set => {
                key_values => [ { name => 'offline' }, { name => 'total' } ],
                output_template => 'offline: %s',
                perfdatas => [ { template => '%s', min => 0, max => 'total' } ]
            }
        }
    ];

    $self->{maps_counters}->{libraries} = [
        {
            label => 'status', type => 2,
            critical_default => '%{status} !~ /online/i',
            set => {
                key_values => [
                    { name => 'display' }, { name => 'library_id' },
                    { name => 'status' }, { name => 'library_type' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'usage', nlabel => 'library.space.usage.bytes', set => {
                key_values => [ { name => 'used_space' }, { name => 'free_space' }, { name => 'prct_used_space' }, { name => 'prct_free_space' }, { name => 'total_space' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'usage-free', nlabel => 'library.space.free.bytes', display_ok => 0, set => {
                key_values => [ { name => 'free_space' }, { name => 'used_space' }, { name => 'prct_used_space' }, { name => 'prct_free_space' }, { name => 'total_space' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%d', min => 0, max => 'total_space', unit => 'B', cast_int => 1, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'usage-prct', nlabel => 'library.space.usage.percentage', display_ok => 0, set => {
                key_values => [ { name => 'prct_used_space' }, { name => 'used_space' }, { name => 'free_space' }, { name => 'prct_free_space' }, { name => 'total_space' } ],
                closure_custom_output => $self->can('custom_usage_output'),
                perfdatas => [
                    { template => '%.2f', min => 0, max => 100, unit => '%', label_extra_instance => 1 }
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
        'filter-library-name:s' => { name => 'filter_library_name' }
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_internal(
        endpoint => '/Library'
    );

    $self->{global} = { total => 0, online => 0, offline => 0 };
    $self->{libraries} = {};

    my $entries = $results->{libraryList} // $results->{response} // [];
    foreach my $entry (@{$entries}) {
        my $entity = $entry->{mediaLibrary} // $entry->{libraryEntity} // {};
        my $lib_name = $entity->{libraryName} // '';
        my $lib_id   = $entity->{libraryId}   // '';
        next if ($lib_name eq '');

        if (defined($self->{option_results}->{filter_library_name}) && $self->{option_results}->{filter_library_name} ne '' &&
            $lib_name !~ /$self->{option_results}->{filter_library_name}/) {
            next;
        }

        my $status = 'online';
        if (defined($entry->{status})) {
            if ($entry->{status} =~ /^\d+$/) {
                $status = $entry->{status} == 0 ? 'online' : 'offline';
            } else {
                $status = lc($entry->{status});
            }
        }

        my $lib_type = 'unknown';
        if (defined($entry->{isDisabledLibrary}) || defined($entity->{libraryType})) {
            my %type_map = (1 => 'Disk', 2 => 'Tape', 3 => 'Optical', 4 => 'NAS', 5 => 'Cloud');
            $lib_type = $type_map{ $entity->{libraryType} // 0 } // 'Disk';
        }

        # Commvault API returns totalCapacity and totalFreeSpace in megabytes (MB).
        my $total_cap  = ($entry->{totalCapacity}  // 0) * 1024 * 1024;
        my $free_space = ($entry->{totalFreeSpace} // 0) * 1024 * 1024;
        my $used_space = $total_cap - $free_space;

        my ($prct_used, $prct_free) = (0, 0);
        if ($total_cap > 0) {
            $prct_used = 100 - ($free_space * 100 / $total_cap);
            $prct_free = $free_space * 100 / $total_cap;
        }

        $self->{libraries}->{$lib_name} = {
            display         => $lib_name,
            library_id      => $lib_id,
            status          => $status,
            library_type    => $lib_type,
            total_space     => $total_cap,
            used_space      => $used_space,
            free_space      => $free_space,
            prct_used_space => $prct_used,
            prct_free_space => $prct_free
        };

        $self->{global}->{$status}++ if defined($self->{global}->{$status});
        $self->{global}->{total}++;
    }

    if (scalar(keys %{$self->{libraries}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No libraries found");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check library status and space usage.

=over 8

=item B<--filter-library-name>

Filter libraries by name (can be a regexp).

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{display}, %{library_id}, %{status}, %{library_type}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /online/i').
You can use the following variables: %{display}, %{library_id}, %{status}, %{library_type}

=item B<--warning-usage>

Threshold in bytes.

=item B<--critical-usage>

Threshold in bytes.

=item B<--warning-usage-free>

Threshold in bytes.

=item B<--critical-usage-free>

Threshold in bytes.

=item B<--warning-usage-prct>

Threshold in percentage.

=item B<--critical-usage-prct>

Threshold in percentage.

=item B<--warning-libraries-total>

Thresholds.

=item B<--critical-libraries-total>

Thresholds.

=item B<--warning-libraries-online>

Thresholds.

=item B<--critical-libraries-online>

Thresholds.

=item B<--warning-libraries-offline>

Thresholds.

=item B<--critical-libraries-offline>

Thresholds.

=back

=cut
