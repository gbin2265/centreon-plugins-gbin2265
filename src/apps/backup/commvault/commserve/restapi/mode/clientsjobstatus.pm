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

package apps::backup::commvault::commserve::restapi::mode::clientsjobstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::misc;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'last job status: %s [id: %s][type: %s][started: %s][ended: %s][duration: %s]',
        $self->{result_values}->{last_job_status},
        $self->{result_values}->{last_job_id},
        $self->{result_values}->{last_job_type},
        $self->{result_values}->{last_job_start},
        $self->{result_values}->{last_job_end},
        $self->{result_values}->{last_job_duration}
    );
}

sub prefix_client_output {
    my ($self, %options) = @_;

    return "Client '" . $options{instance_value}->{display} . "' [id: " . $options{instance_value}->{client_id} . "] ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'clients', type => 1, cb_prefix_output => 'prefix_client_output', message_multiple => 'All client jobs are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'clients-total', nlabel => 'clients.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'Total clients with jobs: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{clients} = [
        {
            label => 'status',
            type => 2,
            warning_default => '%{last_job_status} =~ /abnormal|warning/i',
            critical_default => '%{last_job_status} =~ /errors|failed|killed/i',
            set => {
                key_values => [
                    { name => 'display' }, { name => 'client_id' },
                    { name => 'last_job_id' }, { name => 'last_job_status' },
                    { name => 'last_job_type' }, { name => 'last_job_start' },
                    { name => 'last_job_end' }, { name => 'last_job_duration' },
                    { name => 'last_job_size' }, { name => 'last_job_backup_level' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'job-duration', nlabel => 'client.job.last.duration.seconds', display_ok => 0, set => {
                key_values => [ { name => 'last_job_duration_seconds' }, { name => 'display' } ],
                output_template => 'last job duration: %ss',
                perfdatas => [
                    { template => '%s', unit => 's', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'job-size', nlabel => 'client.job.last.size.bytes', display_ok => 0, set => {
                key_values => [ { name => 'last_job_size_bytes' }, { name => 'display' } ],
                output_template => 'last job size: %s B',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1 }
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
        'filter-client-name:s' => { name => 'filter_client_name' },
        'filter-client-id:s'   => { name => 'filter_client_id' },
        'filter-type:s'        => { name => 'filter_type' },
        'timeframe:s'          => { name => 'timeframe', default => 86400 }
    });

    return $self;
}

sub is_exact_filter {
    my ($self, %options) = @_;

    my $filter = $options{filter};
    return 0 if (!defined($filter) || $filter eq '');

    if ($filter =~ /^\^([^^.\$\*\+\?\(\)\[\]\{\}\|\\]+)\$$/) {
        return $1;
    }
    if ($filter !~ /[\^\$\.\*\+\?\(\)\[\]\{\}\|\\]/) {
        return $filter;
    }
    return 0;
}

sub has_any_filter {
    my ($self) = @_;

    my $fn = $self->{option_results}->{filter_client_name};
    my $fi = $self->{option_results}->{filter_client_id};

    return 1 if (defined($fn) && $fn ne '');
    return 1 if (defined($fi) && $fi ne '');
    return 0;
}

sub lookup_client_by_name_from_list {
    my ($self, %options) = @_;

    my $entries = $options{entries} // [];
    my $search  = lc($options{name});

    foreach my $entry (@{$entries}) {
        my $ce = ($entry->{client} // {})->{clientEntity} // {};
        my $name = $ce->{clientName} // '';
        if (lc($name) eq $search) {
            return { id => $ce->{clientId} // '', name => $name };
        }
    }
    return undef;
}

sub get_full_client_list_raw {
    my ($self, %options) = @_;

    if (!defined($self->{_full_client_entries})) {
        $self->{output}->output_add(long_msg => "Fetching full client list from /Client.", debug => 1);
        my $results = $options{custom}->request(
            type => 'client',
            endpoint => '/Client'
        );
        $self->{_full_client_entries} = $results->{clientProperties} // [];
    }
    return $self->{_full_client_entries};
}

sub get_lookup_time {
    my ($self) = @_;

    my $lt = $self->{option_results}->{timeframe};
    return ($lt && $lt =~ /(\d+)/) ? $1 : 86400;
}

# =========================================================================
# CLIENT RESOLUTION — returns { mode => 'filtered'|'bulk', clients => [...] }
# =========================================================================
sub resolve_clients {
    my ($self, %options) = @_;

    my $filter_name = $self->{option_results}->{filter_client_name};
    my $filter_id   = $self->{option_results}->{filter_client_id};

    # -------------------------------------------------------------------
    # NO FILTER → bulk mode (1 big /Job call, group in Perl)
    # -------------------------------------------------------------------
    if (!$self->has_any_filter()) {
        # We still need the client list to map clientId → clientName
        my $entries = $self->get_full_client_list_raw(%options);
        my @list;
        foreach my $entry (@{$entries}) {
            my $ce = ($entry->{client} // {})->{clientEntity} // {};
            my $cid   = $ce->{clientId}   // '';
            my $cname = $ce->{clientName}  // '';
            next if ($cname eq '' || $cid eq '');
            push @list, { id => $cid, name => $cname };
        }
        return { mode => 'bulk', clients => \@list };
    }

    # -------------------------------------------------------------------
    # EXACT CLIENT ID → skip /Client, go straight to /Job
    # -------------------------------------------------------------------
    my $exact_id = $self->is_exact_filter(filter => $filter_id);
    if ($exact_id) {
        $self->{output}->output_add(long_msg => "Exact client ID: " . $exact_id, debug => 1);
        return { mode => 'filtered', clients => [ { id => $exact_id, name => 'clientid_' . $exact_id } ] };
    }

    # -------------------------------------------------------------------
    # EXACT CLIENT NAME → try /Client/byName, fallback to full list
    # -------------------------------------------------------------------
    my $exact_name = $self->is_exact_filter(filter => $filter_name);
    if ($exact_name) {
        $self->{output}->output_add(long_msg => "Looking up client '" . $exact_name . "'.", debug => 1);

        my $found;
        eval {
            my $results = $options{custom}->request(
                type => 'client_byname',
                endpoint => "/Client/byName(clientName='" . $exact_name . "')"
            );
            my $entries = $results->{clientProperties} // [];
            if (scalar(@{$entries}) > 0) {
                my $ce = ($entries->[0]->{client} // {})->{clientEntity} // {};
                $found = { id => $ce->{clientId} // '', name => $ce->{clientName} // $exact_name }
                    if ($ce->{clientId} // '') ne '';
            }
        };

        if (!defined($found)) {
            $self->{output}->output_add(long_msg => "/Client/byName not available, falling back to full list.", debug => 1);
            my $entries = $self->get_full_client_list_raw(%options);
            $found = $self->lookup_client_by_name_from_list(entries => $entries, name => $exact_name);
        }

        if (defined($found) && $found->{id} ne '') {
            return { mode => 'filtered', clients => [ $found ] };
        }

        $self->{output}->add_option_msg(short_msg => "Client '" . $exact_name . "' not found.");
        $self->{output}->option_exit();
    }

    # -------------------------------------------------------------------
    # REGEXP FILTER → get full list, filter locally, then per-client calls
    # -------------------------------------------------------------------
    my $entries = $self->get_full_client_list_raw(%options);
    my @list;

    foreach my $entry (@{$entries}) {
        my $ce = ($entry->{client} // {})->{clientEntity} // {};
        my $cid   = $ce->{clientId}   // '';
        my $cname = $ce->{clientName}  // '';
        next if ($cname eq '' || $cid eq '');

        if (defined($filter_name) && $filter_name ne '' && $cname !~ /$filter_name/) { next; }
        if (defined($filter_id)   && $filter_id ne ''   && $cid   !~ /$filter_id/)   { next; }

        push @list, { id => $cid, name => $cname };
    }

    return { mode => 'filtered', clients => \@list };
}

# =========================================================================
# STRATEGY: FILTERED — per client, fetch only latest job (limit:1)
#   Connection is reused by curl backend, so this is fast enough.
# =========================================================================
sub get_latest_job_for_client {
    my ($self, %options) = @_;

    my $lookup_time = $self->get_lookup_time();

    my $content = $options{custom}->request_internal(
        endpoint => '/Job',
        get_param => [
            'clientId=' . $options{client_id},
            'completedJobLookupTime=' . $lookup_time
        ],
        header => [ 'limit: 1', 'offset: 0' ]
    );

    my $jobs = $content->{jobs};
    return undef if (!defined($jobs) || scalar(@{$jobs}) == 0);

    my $job = $jobs->[0]->{jobSummary};
    return undef if (!defined($job));

    # If type filter is set and first job doesn't match, fetch a small batch
    if (defined($self->{option_results}->{filter_type}) && $self->{option_results}->{filter_type} ne '') {
        my $ft = $self->{option_results}->{filter_type};
        return $job if (defined($job->{jobType}) && $job->{jobType} =~ /$ft/);

        $content = $options{custom}->request_internal(
            endpoint => '/Job',
            get_param => [
                'clientId=' . $options{client_id},
                'completedJobLookupTime=' . $lookup_time
            ],
            header => [ 'limit: 50', 'offset: 0' ]
        );

        foreach (@{$content->{jobs} // []}) {
            my $j = $_->{jobSummary};
            next if (!defined($j));
            return $j if (defined($j->{jobType}) && $j->{jobType} =~ /$ft/);
        }
        return undef;
    }

    return $job;
}

# =========================================================================
# STRATEGY: BULK — 1 paginated /Job call for ALL jobs, group by client
# =========================================================================
sub get_all_jobs_bulk {
    my ($self, %options) = @_;

    my $lookup_time = $self->get_lookup_time();
    my $offset = 0;
    my @all_jobs;

    $self->{output}->output_add(long_msg => "Bulk fetching all jobs (timeframe: " . $lookup_time . "s)...", debug => 1);

    while (1) {
        my $content = $options{custom}->request_internal(
            endpoint => '/Job',
            get_param => [ 'completedJobLookupTime=' . $lookup_time ],
            header => [ 'limit: 100', "offset: $offset" ]
        );

        my $jobs = $content->{jobs};
        last if (!defined($jobs) || scalar(@{$jobs}) == 0);

        push @all_jobs, @{$jobs};

        my $total = $content->{totalRecordsWithoutPaging} // 0;
        last if scalar(@all_jobs) >= $total;
        $offset += 100;

        $self->{output}->output_add(long_msg => "Fetched " . scalar(@all_jobs) . " / " . $total . " jobs...", debug => 1);
    }

    $self->{output}->output_add(long_msg => "Total jobs fetched: " . scalar(@all_jobs), debug => 1);
    return \@all_jobs;
}

sub extract_latest_per_client {
    my ($self, %options) = @_;

    my $all_jobs      = $options{jobs};
    my $client_lookup = $options{client_lookup};  # hashref { clientId => clientName }
    my $filter_type   = $self->{option_results}->{filter_type};

    my %latest;

    foreach (@{$all_jobs}) {
        my $job = $_->{jobSummary};
        next if (!defined($job));

        my $client_name = $job->{subclient}->{clientName} // $job->{destClientName} // 'notAvailable';
        my $client_id   = $job->{subclient}->{clientId}   // '';

        # Only include clients we know about
        if (defined($client_lookup) && !defined($client_lookup->{$client_id})) {
            next;
        }

        if (defined($filter_type) && $filter_type ne '' &&
            defined($job->{jobType}) && $job->{jobType} !~ /$filter_type/) {
            next;
        }

        my $job_start = $job->{jobStartTime} // 0;
        my $key = $client_id ne '' ? $client_id : $client_name;

        if (!defined($latest{$key}) || $job_start > ($latest{$key}->{job}->{jobStartTime} // 0)) {
            $latest{$key} = {
                client_id   => $client_id,
                client_name => defined($client_lookup->{$client_id})
                                 ? $client_lookup->{$client_id} : $client_name,
                job         => $job
            };
        }
    }

    return \%latest;
}

# =========================================================================
# COMMON: add a client result to the output
# =========================================================================
sub add_client_result {
    my ($self, %options) = @_;

    my $job          = $options{job};
    my $client_id    = $options{client_id};
    my $display_name = $options{display_name};
    my $current_time = $options{current_time};

    my $start_str = $job->{jobStartTime} ? scalar(localtime($job->{jobStartTime})) : '-';
    my $end_str   = $job->{jobEndTime}   ? scalar(localtime($job->{jobEndTime}))   : '-';

    my $duration_seconds = 0;
    if ($job->{jobEndTime} && $job->{jobStartTime} && $job->{jobEndTime} > $job->{jobStartTime}) {
        $duration_seconds = $job->{jobEndTime} - $job->{jobStartTime};
    } elsif ($job->{jobElapsedTime}) {
        $duration_seconds = $job->{jobElapsedTime};
    } elsif ($job->{jobStartTime}) {
        $duration_seconds = $current_time - $job->{jobStartTime};
    }

    $self->{clients}->{$display_name} = {
        display                   => $display_name,
        client_id                 => $client_id,
        last_job_id               => $job->{jobId} // '-',
        last_job_status           => $job->{status} // 'unknown',
        last_job_type             => $job->{jobType} // '-',
        last_job_backup_level     => $job->{backupLevelName} // '-',
        last_job_start            => $start_str,
        last_job_end              => $end_str,
        last_job_duration         => centreon::plugins::misc::change_seconds(value => $duration_seconds),
        last_job_duration_seconds => $duration_seconds,
        last_job_size             => $job->{sizeOfApplication} // 0,
        last_job_size_bytes       => $job->{sizeOfApplication} // 0
    };
    $self->{global}->{total}++;
}

# =========================================================================
# MAIN
# =========================================================================
sub manage_selection {
    my ($self, %options) = @_;

    my $resolved = $self->resolve_clients(%options);
    my $client_list = $resolved->{clients};

    if (scalar(@{$client_list}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No clients found (check filters)");
        $self->{output}->option_exit();
    }

    $self->{output}->output_add(long_msg => "Strategy: " . $resolved->{mode} . ", clients: " . scalar(@{$client_list}), debug => 1);

    $self->{global} = { total => 0 };
    $self->{clients} = {};
    my $current_time = time();

    if ($resolved->{mode} eq 'filtered') {
        # ---------------------------------------------------------------
        # FILTERED: per client, 1 fast call with limit:1
        #   curl backend reuses the TCP+SSL connection across calls.
        # ---------------------------------------------------------------
        foreach my $client (@{$client_list}) {
            $self->{output}->output_add(
                long_msg => "Fetching latest job for '" . $client->{name} . "' (id: " . $client->{id} . ")",
                debug => 1
            );

            my $job = $self->get_latest_job_for_client(%options, client_id => $client->{id});
            next if (!defined($job));

            my $display_name = $client->{name};
            if ($display_name =~ /^clientid_/) {
                my $jn = $job->{subclient}->{clientName} // $job->{destClientName} // '';
                $display_name = $jn if $jn ne '';
            }

            $self->add_client_result(
                job => $job, client_id => $client->{id},
                display_name => $display_name, current_time => $current_time
            );
        }
    } else {
        # ---------------------------------------------------------------
        # BULK (no filter): 1 paginated /Job call for everything,
        #   then group by client in Perl. Much fewer round-trips.
        # ---------------------------------------------------------------
        my %client_lookup;
        foreach (@{$client_list}) {
            $client_lookup{ $_->{id} } = $_->{name};
        }

        my $all_jobs = $self->get_all_jobs_bulk(%options);
        my $latest = $self->extract_latest_per_client(
            jobs => $all_jobs,
            client_lookup => \%client_lookup
        );

        foreach my $key (keys %{$latest}) {
            my $entry = $latest->{$key};
            $self->add_client_result(
                job => $entry->{job}, client_id => $entry->{client_id},
                display_name => $entry->{client_name}, current_time => $current_time
            );
        }
    }

    if (scalar(keys %{$self->{clients}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No jobs found for any client in the timeframe");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check the last job status per client.

Compatible with both /webconsole/api (default) and /commandcenter/api (via --url-path).

Two strategies for optimal performance:

B<With filter> (--filter-client-name or --filter-client-id):
Per client, fetches only the latest job (limit=1) via /Job?clientId=XX.
The curl backend reuses the TCP+SSL connection, so this is fast.

B<Without filter> (all clients):
One bulk /Job API call (paginated) that fetches all jobs at once, then groups
by client in Perl to find the latest job per client. Avoids hundreds of round-trips.

=over 8

=item B<--filter-client-name>

Filter clients by name (can be a regexp).
For best performance with a single client, use exact match: --filter-client-name='^SERVER01$'

=item B<--filter-client-id>

Filter clients by ID (can be a regexp).
For best performance with a single client, use exact match: --filter-client-id='^42$'

=item B<--filter-type>

Filter jobs by type (can be a regexp, e.g. 'Backup', 'Snap Backup', 'Restore').

=item B<--timeframe>

Set timeframe in seconds to look back for completed jobs (default: 86400 = 24 hours).

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{last_job_status} =~ /abnormal|warning/i').
You can use the following variables: %{display}, %{client_id}, %{last_job_id},
%{last_job_status}, %{last_job_type}, %{last_job_backup_level}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{last_job_status} =~ /errors|failed|killed/i').
You can use the following variables: %{display}, %{client_id}, %{last_job_id},
%{last_job_status}, %{last_job_type}, %{last_job_backup_level}

=item B<--warning-job-duration>

Warning threshold for last job duration in seconds.

=item B<--critical-job-duration>

Critical threshold for last job duration in seconds.

=item B<--warning-job-size>

Warning threshold for last job size in bytes.

=item B<--critical-job-size>

Critical threshold for last job size in bytes.

=item B<--warning-clients-total>

Thresholds.

=item B<--critical-clients-total>

Thresholds.

=back

=cut
