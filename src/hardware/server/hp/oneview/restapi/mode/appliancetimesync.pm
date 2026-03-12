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

package hardware::server::hp::oneview::restapi::mode::appliancetimesync;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);
use POSIX qw(floor);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_sync_status_output {
    my ($self, %options) = @_;
    return sprintf(
        'NTP sync: %s [timezone: %s] [appliance time: %s]',
        $self->{result_values}->{sync_status},
        $self->{result_values}->{timezone},
        $self->{result_values}->{appliance_time}
    );
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'timesync', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'ntpservers', type => 1, cb_prefix_output => 'prefix_ntp_output',
          message_multiple => 'All NTP servers reachable', skipped_code => { -10 => 1 } },
    ];

    # ---- Global time sync ----
    $self->{maps_counters}->{timesync} = [
        # NTP synchronisation status
        { label => 'ntp-sync-status', threshold => 0, set => {
                key_values => [
                    { name => 'sync_status' },
                    { name => 'timezone' },
                    { name => 'appliance_time' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_sync_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        # Clock drift: difference in seconds between appliance time and monitoring host
        { label => 'time-offset', nlabel => 'appliance.time.offset.seconds', set => {
                key_values      => [ { name => 'time_offset_seconds' } ],
                output_template => 'time offset with monitoring host: %d s',
                perfdatas       => [
                    { value => 'time_offset_seconds', template => '%d', unit => 's' },
                ],
            }
        },
        # Number of configured NTP servers
        { label => 'ntp-servers-count', nlabel => 'appliance.ntp.servers.count', display_ok => 0, set => {
                key_values      => [ { name => 'ntp_servers_count' } ],
                output_template => 'NTP servers configured: %d',
                perfdatas       => [
                    { value => 'ntp_servers_count', template => '%d', min => 0 },
                ],
            }
        },
    ];

    # ---- Per NTP server ----
    $self->{maps_counters}->{ntpservers} = [
        { label => 'ntp-server-status', threshold => 0, set => {
                key_values => [
                    { name => 'server_status' },
                    { name => 'stratum' },
                    { name => 'display' },
                ],
                closure_custom_calc   => \&catalog_status_calc,
                closure_custom_output => sub {
                    my ($self, %options) = @_;
                    return sprintf('status: %s [stratum: %s]',
                        $self->{result_values}->{server_status},
                        defined($self->{result_values}->{stratum}) ? $self->{result_values}->{stratum} : 'n/a'
                    );
                },
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        # Per-server poll interval in seconds
        { label => 'ntp-server-poll-interval', nlabel => 'appliance.ntp.server.poll.interval.seconds',
          display_ok => 0, set => {
                key_values      => [ { name => 'poll_interval' }, { name => 'display' } ],
                output_template => 'poll interval: %d s',
                perfdatas       => [
                    { value => 'poll_interval', template => '%d', unit => 's', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Offset reported by NTP for this server (milliseconds)
        { label => 'ntp-server-offset', nlabel => 'appliance.ntp.server.offset.milliseconds',
          display_ok => 0, set => {
                key_values      => [ { name => 'ntp_offset_ms' }, { name => 'display' } ],
                output_template => 'NTP offset: %.2f ms',
                perfdatas       => [
                    { value => 'ntp_offset_ms', template => '%.2f', unit => 'ms',
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Jitter reported by NTP for this server (milliseconds)
        { label => 'ntp-server-jitter', nlabel => 'appliance.ntp.server.jitter.milliseconds',
          display_ok => 0, set => {
                key_values      => [ { name => 'ntp_jitter_ms' }, { name => 'display' } ],
                output_template => 'jitter: %.2f ms',
                perfdatas       => [
                    { value => 'ntp_jitter_ms', template => '%.2f', unit => 'ms', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

# -------------------------------------------------------------------------
# Prefix callbacks
# -------------------------------------------------------------------------

sub prefix_ntp_output {
    my ($self, %options) = @_;
    return "NTP server '" . $options{instance_value}->{display} . "' ";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-ntp-server:s'            => { name => 'filter_ntp_server' },
        'unknown-ntp-sync-status:s'      => { name => 'unknown_ntp_sync_status',
            default => '' },
        'warning-ntp-sync-status:s'      => { name => 'warning_ntp_sync_status',
            default => '' },
        'critical-ntp-sync-status:s'     => { name => 'critical_ntp_sync_status',
            default => '%{sync_status} =~ /unsynchronized|notsynced|false/i' },
        'unknown-ntp-server-status:s'    => { name => 'unknown_ntp_server_status',  default => '' },
        'warning-ntp-server-status:s'    => { name => 'warning_ntp_server_status',  default => '' },
        'critical-ntp-server-status:s'   => { name => 'critical_ntp_server_status',
            default => '%{server_status} =~ /unreachable|error/i' },
        'warning-time-offset:s'          => { name => 'warning_time_offset',         default => 30 },
        'critical-time-offset:s'         => { name => 'critical_time_offset',        default => 60 },
        'warning-ntp-server-offset:s'    => { name => 'warning_ntp_server_offset',   default => 500 },
        'critical-ntp-server-offset:s'   => { name => 'critical_ntp_server_offset',  default => 1000 },
        'warning-ntp-server-jitter:s'    => { name => 'warning_ntp_server_jitter',   default => 200 },
        'critical-ntp-server-jitter:s'   => { name => 'critical_ntp_server_jitter',  default => 500 },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_ntp_sync_status',  'critical_ntp_sync_status',  'unknown_ntp_sync_status',
        'warning_ntp_server_status', 'critical_ntp_server_status', 'unknown_ntp_server_status',
    ]);

    # Explicitly register numeric thresholds so the counter system picks them up
    $self->{perfdata}->threshold_validate(
        label => 'warning-time-offset',
        value => $self->{option_results}->{warning_time_offset}
    );
    $self->{perfdata}->threshold_validate(
        label => 'critical-time-offset',
        value => $self->{option_results}->{critical_time_offset}
    );
    $self->{perfdata}->threshold_validate(
        label => 'warning-ntp-server-offset',
        value => $self->{option_results}->{warning_ntp_server_offset}
    );
    $self->{perfdata}->threshold_validate(
        label => 'critical-ntp-server-offset',
        value => $self->{option_results}->{critical_ntp_server_offset}
    );
    $self->{perfdata}->threshold_validate(
        label => 'warning-ntp-server-jitter',
        value => $self->{option_results}->{warning_ntp_server_jitter}
    );
    $self->{perfdata}->threshold_validate(
        label => 'critical-ntp-server-jitter',
        value => $self->{option_results}->{critical_ntp_server_jitter}
    );
}

# -------------------------------------------------------------------------
# Utility: parse ISO 8601 date string into epoch
# -------------------------------------------------------------------------

sub _parse_iso8601 {
    my ($date_str) = @_;
    return undef unless (defined($date_str) && $date_str =~ /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2}):(\d{2})/);
    eval { require Time::Local; };
    return undef if $@;
    return eval { Time::Local::timegm($6, $5, $4, $3, $2 - 1, $1 - 1900); };
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    # Try both known endpoint paths — name changed between OneView versions
    # Older: /rest/appliance/time-locale
    # Newer: /rest/appliance/configuration/time-locale
    my $result = $options{custom}->request_api(
        url_path      => '/rest/appliance/time-locale',
        ignore_errors => 1
    );
    if (!defined($result)) {
        $result = $options{custom}->request_api(
            url_path      => '/rest/appliance/configuration/time-locale',
            ignore_errors => 1
        );
    }

    if (!defined($result)) {
        $self->{output}->output_add(
            severity  => 'UNKNOWN',
            short_msg => 'The /rest/appliance/time-locale endpoint is not available on this OneView version'
        );
        $self->{output}->display();
        $self->{output}->exit();
    }

    my $now = time();

    # ---- Determine overall NTP sync status ----
    # Field names vary between OneView versions:
    #   ntpStatus (older): 'SYNCED' / 'UNSYNCED'
    #   syncStatus: 'true' / 'false' or boolean
    #   pollingInterval also present
    my $sync_status = 'unknown';
    if (defined($result->{ntpStatus})) {
        $sync_status = lc($result->{ntpStatus});
    } elsif (defined($result->{syncStatus})) {
        $sync_status = $result->{syncStatus} ? 'synced' : 'unsynchronized';
    } elsif (defined($result->{synchronized})) {
        $sync_status = $result->{synchronized} ? 'synced' : 'unsynchronized';
    }

    # ---- Determine appliance time and compute offset vs monitoring host ----
    my $appliance_time_str = $result->{dateTime} // $result->{currentDateTime} // 'n/a';
    my $time_offset_seconds = undef;
    if ($appliance_time_str ne 'n/a') {
        my $appliance_epoch = _parse_iso8601($appliance_time_str);
        $time_offset_seconds = abs($now - $appliance_epoch) if (defined($appliance_epoch));
    }

    my $timezone = $result->{timezone} // $result->{timeZone} // 'n/a';

    # ---- NTP servers ----
    my @ntp_server_list;
    if (defined($result->{ntpServers}) && ref($result->{ntpServers}) eq 'ARRAY') {
        # older format: plain array of hostnames/IPs
        @ntp_server_list = map { { address => $_, status => 'unknown' } } @{$result->{ntpServers}};
    } elsif (defined($result->{ntpConfiguration}) && defined($result->{ntpConfiguration}->{ntpServers})) {
        @ntp_server_list = @{$result->{ntpConfiguration}->{ntpServers}};
    }

    $self->{timesync} = {
        sync_status         => $sync_status,
        timezone            => $timezone,
        appliance_time      => $appliance_time_str,
        time_offset_seconds => $time_offset_seconds,
        ntp_servers_count   => scalar(@ntp_server_list),
    };

    $self->{ntpservers} = {};
    foreach my $srv (@ntp_server_list) {
        my $address = ref($srv) eq 'HASH'
            ? ($srv->{address} // $srv->{hostname} // $srv->{server} // 'unknown')
            : $srv;

        if (defined($self->{option_results}->{filter_ntp_server}) && $self->{option_results}->{filter_ntp_server} ne '' &&
            $address !~ /$self->{option_results}->{filter_ntp_server}/) {
            $self->{output}->output_add(
                long_msg => "skipping NTP server '$address': no matching filter.", debug => 1
            );
            next;
        }

        # Per-server fields present in some OneView versions
        my $server_status = 'unknown';
        if (ref($srv) eq 'HASH') {
            $server_status = lc($srv->{status} // $srv->{reachable} // 'unknown');
            # Normalize: 'true'/'reachable' -> 'reachable', 'false'/'unreachable' -> 'unreachable'
            $server_status = 'reachable'   if ($server_status =~ /^(true|reachable|ok)$/);
            $server_status = 'unreachable' if ($server_status =~ /^(false|unreachable|error|fail)/);
        }

        $self->{ntpservers}->{$address} = {
            display       => $address,
            server_status => $server_status,
            stratum       => ref($srv) eq 'HASH' ? ($srv->{stratum}      // undef) : undef,
            poll_interval => ref($srv) eq 'HASH' ? ($srv->{pollInterval} // undef) : undef,
            ntp_offset_ms => ref($srv) eq 'HASH' ? ($srv->{offset}       // undef) : undef,
            ntp_jitter_ms => ref($srv) eq 'HASH' ? ($srv->{jitter}       // undef) : undef,
        };

        $self->{output}->output_add(
            long_msg => sprintf(
                "NTP server '%s' status: %s%s%s%s%s",
                $address, $server_status,
                defined($self->{ntpservers}->{$address}->{stratum})
                    ? " [stratum: $self->{ntpservers}->{$address}->{stratum}]" : '',
                defined($self->{ntpservers}->{$address}->{poll_interval})
                    ? " [poll: $self->{ntpservers}->{$address}->{poll_interval}s]" : '',
                defined($self->{ntpservers}->{$address}->{ntp_offset_ms})
                    ? " [offset: $self->{ntpservers}->{$address}->{ntp_offset_ms}ms]" : '',
                defined($self->{ntpservers}->{$address}->{ntp_jitter_ms})
                    ? " [jitter: $self->{ntpservers}->{$address}->{ntp_jitter_ms}ms]" : ''
            )
        );
    }
}

1;

__END__

=head1 MODE

Check HPE OneView appliance time synchronisation via B</rest/appliance/time-locale> (or B</rest/appliance/configuration/time-locale> on newer versions).

Reports the overall NTP synchronisation status, the clock offset between the
appliance and the monitoring host, and per-NTP-server details where available
(stratum, poll interval, offset, jitter).

Global perfdata: time offset vs monitoring host (s), NTP server count.
Per-server perfdata: poll interval (s), NTP offset (ms), jitter (ms).

=over 8

=item B<--filter-ntp-server>

Filter NTP servers by address (can be a regexp).

=item B<--unknown-ntp-sync-status>

Conditions for UNKNOWN NTP sync status (default: '').
Variables: %{sync_status}, %{timezone}, %{appliance_time}

=item B<--warning-ntp-sync-status>

Conditions for WARNING NTP sync status (default: '').

=item B<--critical-ntp-sync-status>

Conditions for CRITICAL NTP sync status
(default: '%{sync_status} =~ /unsynchronized|notsynced|false/i').

=item B<--unknown-ntp-server-status>

Conditions for UNKNOWN per-server status (default: '').
Variables: %{server_status}, %{stratum}, %{display}

=item B<--warning-ntp-server-status>

Conditions for WARNING per-server status (default: '').

=item B<--critical-ntp-server-status>

Conditions for CRITICAL per-server status
(default: '%{server_status} =~ /unreachable|error/i').

=item B<--warning-*> B<--critical-*>

Thresholds:
'time-offset' (s), 'ntp-servers-count'.
Per-server: 'ntp-server-poll-interval' (s), 'ntp-server-offset' (ms),
'ntp-server-jitter' (ms).

Default thresholds: warning at 30s, critical at 60s (time-offset); warning at 500ms, critical at 1000ms (ntp-server-offset); warning at 200ms, critical at 500ms (ntp-server-jitter).
than 60 seconds off compared to the monitoring host.

=back

=cut
