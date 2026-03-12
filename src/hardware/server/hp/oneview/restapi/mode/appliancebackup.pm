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

package hardware::server::hp::oneview::restapi::mode::appliancebackup;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

sub custom_backup_status_output {
    my ($self, %options) = @_;
    return sprintf(
        'status: %s [created: %s] [age: %d h]',
        $self->{result_values}->{backup_status},
        $self->{result_values}->{created_at},
        $self->{result_values}->{age_hours}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'backups', type => 1, cb_prefix_output => 'prefix_backup_output',
          message_multiple => 'All backups are ok', skipped_code => { -10 => 1 } },
    ];

    $self->{maps_counters}->{global} = [
        { label => 'backups-total', nlabel => 'appliance.backups.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total backups: %d',
                perfdatas       => [ { value => 'total', template => '%d', min => 0 } ],
            }
        },
        # Age of the most recent backup in hours
        { label => 'backup-last-age', nlabel => 'appliance.backup.last.age.hours', set => {
                key_values      => [ { name => 'last_age_hours' } ],
                output_template => 'last backup age: %d h',
                perfdatas       => [
                    { value => 'last_age_hours', template => '%d', unit => 'h', min => 0 },
                ],
            }
        },
        { label => 'backups-ok', nlabel => 'appliance.backups.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_ok' } ],
                output_template => 'ok: %d',
                perfdatas       => [ { value => 'status_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'backups-failed', nlabel => 'appliance.backups.failed.count', set => {
                key_values      => [ { name => 'status_failed' } ],
                output_template => 'failed: %d',
                perfdatas       => [ { value => 'status_failed', template => '%d', min => 0 } ],
            }
        },
    ];

    $self->{maps_counters}->{backups} = [
        { label => 'backup-status', threshold => 0, set => {
                key_values => [
                    { name => 'backup_status' },
                    { name => 'created_at' },
                    { name => 'age_hours' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_backup_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'backup-age', nlabel => 'appliance.backup.age.hours', display_ok => 0, set => {
                key_values      => [ { name => 'age_hours' }, { name => 'display' } ],
                output_template => 'age: %d h',
                perfdatas       => [
                    { value => 'age_hours', template => '%d', unit => 'h', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'backup-size', nlabel => 'appliance.backup.size.bytes', display_ok => 0, set => {
                key_values      => [ { name => 'size_bytes' }, { name => 'display' } ],
                output_template => 'size: %s',
                output_change_bytes => 1,
                perfdatas       => [
                    { value => 'size_bytes', template => '%d', unit => 'B', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

sub prefix_backup_output {
    my ($self, %options) = @_;
    return "Backup '" . $options{instance_value}->{display} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-id:s'                  => { name => 'filter_id' },
        'filter-status:s'              => { name => 'filter_status' },
        'unknown-backup-status:s'      => { name => 'unknown_backup_status',  default => '' },
        'warning-backup-status:s'      => { name => 'warning_backup_status',  default => '' },
        'critical-backup-status:s'     => { name => 'critical_backup_status',
            default => '%{backup_status} =~ /failed|error/i' },
        'warning-backup-last-age:s'    => { name => 'warning_backup_last_age',  default => 175 },
        'critical-backup-last-age:s'   => { name => 'critical_backup_last_age', default => 192 },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_backup_status', 'critical_backup_status', 'unknown_backup_status',
    ]);

    # Explicitly register the last-age thresholds so the counter system picks them up
    $self->{perfdata}->threshold_validate(
        label => 'warning-backup-last-age',
        value => $self->{option_results}->{warning_backup_last_age}
    );
    $self->{perfdata}->threshold_validate(
        label => 'critical-backup-last-age',
        value => $self->{option_results}->{critical_backup_last_age}
    );
}

sub _parse_iso8601 {
    my ($date_str) = @_;
    return undef unless (defined($date_str) && $date_str =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/);
    eval { require Time::Local; };
    return undef if $@;
    return eval { Time::Local::timegm($6, $5, $4, $3, $2 - 1, $1 - 1900); };
}

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/backups');

    my $now = time();
    my $last_age_hours = undef;

    $self->{global} = {
        total         => 0,
        status_ok     => 0,
        status_failed => 0,
        last_age_hours => undef,
    };
    $self->{backups} = {};

    foreach my $backup (@{$results->{members}}) {
        my $id     = $backup->{id}   // $backup->{uri} // 'unknown';
        $id =~ s{^.*/}{};   # keep short ID only

        if (defined($self->{option_results}->{filter_id}) && $self->{option_results}->{filter_id} ne '' &&
            $id !~ /$self->{option_results}->{filter_id}/) {
            $self->{output}->output_add(long_msg => "skipping backup '$id': no matching filter.", debug => 1);
            next;
        }

        my $status     = lc($backup->{status} // $backup->{taskState} // 'unknown');

        if (defined($self->{option_results}->{filter_status}) && $self->{option_results}->{filter_status} ne '' &&
            $status !~ /$self->{option_results}->{filter_status}/i) {
            $self->{output}->output_add(long_msg => "skipping backup '$id': status '$status' no matching filter.", debug => 1);
            next;
        }
        my $created_at = $backup->{created}   // $backup->{createdAt} // 'n/a';
        my $size_bytes = $backup->{fileSize}  // $backup->{size}      // undef;

        my $age_hours = undef;
        my $epoch = _parse_iso8601($created_at);
        if (defined($epoch)) {
            $age_hours = int(($now - $epoch) / 3600);
            $last_age_hours = $age_hours
                if (!defined($last_age_hours) || $age_hours < $last_age_hours);
        }

        $self->{global}->{total}++;
        if    ($status =~ /^ok|success|completed$/i) { $self->{global}->{status_ok}++; }
        elsif ($status =~ /fail|error/i)              { $self->{global}->{status_failed}++; }

        $self->{backups}->{$id} = {
            display       => $id,
            backup_status => $status,
            created_at    => $created_at,
            age_hours     => $age_hours // 0,
            size_bytes    => $size_bytes,
        };
    }

    $self->{global}->{last_age_hours} = $last_age_hours;

    if ($self->{global}->{total} == 0) {
        $self->{output}->add_option_msg(short_msg => 'No backups found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView appliance backup status and age.

Global perfdata: total backup count, last backup age (hours), ok/failed counts.
Per-backup perfdata: age (h), size (bytes).

=over 8

=item B<--filter-id>

Filter backups by ID (can be a regexp).

=item B<--filter-status>

Filter backups by status before reporting (can be a regexp).
Example: --filter-status='ok|completed' to only report successful backups.

=item B<--unknown-backup-status>

Conditions for UNKNOWN backup status (default: '').
Variables: %{backup_status}, %{created_at}, %{age_hours}, %{display}

=item B<--warning-backup-status>

Conditions for WARNING backup status (default: '').

=item B<--critical-backup-status>

Conditions for CRITICAL backup status
(default: '%{backup_status} =~ /failed|error/i').

=item B<--warning-*> B<--critical-*>

Thresholds:
'backups-total', 'backup-last-age' (h), 'backups-ok', 'backups-failed'.
Per-backup: 'backup-age' (h), 'backup-size' (B).

Default: warning at 175h, critical at 192h. Override with --warning-backup-last-age=N and --critical-backup-last-age=N.

=back

=cut
