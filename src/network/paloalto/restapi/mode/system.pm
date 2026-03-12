#
# Copyright 2026-Present Centreon (http://www.centreon.com/)
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

package network::paloalto::restapi::mode::system;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use centreon::plugins::misc;
use DateTime;
use Digest::MD5 qw(md5_hex);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'operational mode: %s [model: %s][PAN-OS: %s][serial: %s]',
        $self->{result_values}->{oper_mode},
        $self->{result_values}->{model},
        $self->{result_values}->{sw_version},
        $self->{result_values}->{serial}
    );
}

sub custom_uptime_output {
    my ($self, %options) = @_;

    return sprintf(
        'uptime: %s',
        centreon::plugins::misc::change_seconds(value => $self->{result_values}->{uptime_seconds})
    );
}

sub custom_update_output {
    my ($self, %options) = @_;

    my $update = $self->{result_values}->{lastupdate_time};
    my $msg;
    if ($update eq 'unknown') {
        $msg = sprintf("%s version '%s', last update unknown", $self->{result_values}->{update_type}, $self->{result_values}->{version});
    } else {
        $msg = sprintf(
            "%s version '%s', last update %s",
            $self->{result_values}->{update_type},
            $self->{result_values}->{version},
            centreon::plugins::misc::change_seconds(value => $update)
        );
    }
    return $msg;
}

sub custom_update_perfdata {
    my ($self, %options) = @_;

    return if ($self->{result_values}->{lastupdate_time} eq 'unknown');
    $self->{output}->perfdata_add(
        nlabel => $self->{nlabel},
        unit => 's',
        value => $self->{result_values}->{lastupdate_time},
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel}),
        min => 0
    );
}

sub custom_update_threshold {
    my ($self, %options) = @_;

    return 'ok' if ($self->{result_values}->{lastupdate_time} eq 'unknown');
    return $self->{perfdata}->threshold_check(
        value => $self->{result_values}->{lastupdate_time},
        threshold => [
            { label => 'critical-' . $self->{thlabel}, exit_litteral => 'critical' },
            { label => 'warning-' . $self->{thlabel}, exit_litteral => 'warning' }
        ]
    );
}

sub prefix_system_output {
    my ($self, %options) = @_;

    return 'System ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'system', type => 0, cb_prefix_output => 'prefix_system_output', message_separator => ' - ', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{system} = [
        { label => 'status', type => 2, critical_default => '%{oper_mode} !~ /normal/i', set => {
                key_values => [
                    { name => 'oper_mode' }, { name => 'model' },
                    { name => 'sw_version' }, { name => 'serial' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'uptime', nlabel => 'system.uptime.seconds', set => {
                key_values => [ { name => 'uptime_seconds' } ],
                closure_custom_output => $self->can('custom_uptime_output'),
                perfdatas => [
                    { template => '%s', unit => 's', min => 0 }
                ]
            }
        },
        { label => 'cpu-load', nlabel => 'system.cpu.utilization.percentage', set => {
                key_values => [ { name => 'cpu_load' } ],
                output_template => 'cpu usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100 }
                ]
            }
        },
        { label => 'memory-usage', nlabel => 'system.memory.usage.percentage', set => {
                key_values => [ { name => 'memory_used_pct' } ],
                output_template => 'memory used: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100 }
                ]
            }
        },
        { label => 'disk-usage', nlabel => 'system.disk.usage.percentage', set => {
                key_values => [ { name => 'disk_used_pct' } ],
                output_template => 'disk used: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100 }
                ]
            }
        },
        { label => 'swap-usage', nlabel => 'system.swap.usage.percentage', display_ok => 0, set => {
                key_values => [ { name => 'swap_used_pct' } ],
                output_template => 'swap used: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100 }
                ]
            }
        },
        { label => 'sessions-total-active', nlabel => 'system.sessions.total.active.count', set => {
                key_values => [ { name => 'active_sessions' } ],
                output_template => 'active sessions: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'sessions-tcp', nlabel => 'system.sessions.tcp.active.count', display_ok => 0, set => {
                key_values => [ { name => 'tcp_sessions' } ],
                output_template => 'tcp sessions: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'sessions-udp', nlabel => 'system.sessions.udp.active.count', display_ok => 0, set => {
                key_values => [ { name => 'udp_sessions' } ],
                output_template => 'udp sessions: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'sessions-icmp', nlabel => 'system.sessions.icmp.active.count', display_ok => 0, set => {
                key_values => [ { name => 'icmp_sessions' } ],
                output_template => 'icmp sessions: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'sessions-traffic', nlabel => 'system.sessions.traffic.count', display_ok => 0, set => {
                key_values => [ { name => 'throughput', diff => 1 } ],
                output_template => 'session traffic: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0 }
                ]
            }
        },
        { label => 'packet-rate', nlabel => 'system.packets.rate.persecond', display_ok => 0, set => {
                key_values => [ { name => 'packet_rate' } ],
                output_template => 'packet rate: %s/s',
                perfdatas => [
                    { template => '%s', unit => '/s', min => 0 }
                ]
            }
        },
        { label => 'av-update', nlabel => 'system.antivirus.lastupdate.time.seconds', display_ok => 0, set => {
                key_values => [ { name => 'av_lastupdate_time' }, { name => 'av_version' } ],
                closure_custom_output => sub {
                    my ($self, %options) = @_;
                    $self->{result_values}->{update_type} = 'antivirus';
                    $self->{result_values}->{version} = $self->{result_values}->{av_version};
                    $self->{result_values}->{lastupdate_time} = $self->{result_values}->{av_lastupdate_time};
                    return network::paloalto::restapi::mode::system::custom_update_output($self, %options);
                },
                closure_custom_perfdata => $self->can('custom_update_perfdata'),
                closure_custom_threshold_check => $self->can('custom_update_threshold')
            }
        },
        { label => 'threat-update', nlabel => 'system.threat.lastupdate.time.seconds', display_ok => 0, set => {
                key_values => [ { name => 'threat_lastupdate_time' }, { name => 'threat_version' } ],
                closure_custom_output => sub {
                    my ($self, %options) = @_;
                    $self->{result_values}->{update_type} = 'threat';
                    $self->{result_values}->{version} = $self->{result_values}->{threat_version};
                    $self->{result_values}->{lastupdate_time} = $self->{result_values}->{threat_lastupdate_time};
                    return network::paloalto::restapi::mode::system::custom_update_output($self, %options);
                },
                closure_custom_perfdata => $self->can('custom_update_perfdata'),
                closure_custom_threshold_check => $self->can('custom_update_threshold')
            }
        },
        { label => 'wildfire-update', nlabel => 'system.wildfire.lastupdate.time.seconds', display_ok => 0, set => {
                key_values => [ { name => 'wf_lastupdate_time' }, { name => 'wf_version' } ],
                closure_custom_output => sub {
                    my ($self, %options) = @_;
                    $self->{result_values}->{update_type} = 'wildfire';
                    $self->{result_values}->{version} = $self->{result_values}->{wf_version};
                    $self->{result_values}->{lastupdate_time} = $self->{result_values}->{wf_lastupdate_time};
                    return network::paloalto::restapi::mode::system::custom_update_output($self, %options);
                },
                closure_custom_perfdata => $self->can('custom_update_perfdata'),
                closure_custom_threshold_check => $self->can('custom_update_threshold')
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'timezone:s' => { name => 'timezone' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->{option_results}->{timezone} = 'GMT' if (!defined($self->{option_results}->{timezone}) || $self->{option_results}->{timezone} eq '');
}

sub get_diff_time {
    my ($self, %options) = @_;

    # '2019/10/15 12:03:58 BST'
    return 'unknown' if (!defined($options{time}) || $options{time} !~ /^\s*(\d{4})\/(\d{2})\/(\d{2})\s+(\d+):(\d+):(\d+)/);

    my $tz = centreon::plugins::misc::set_timezone(name => $self->{option_results}->{timezone});
    my $dt = DateTime->new(
        year => $1, month => $2, day => $3,
        hour => $4, minute => $5, second => $6,
        %$tz
    );
    return (time() - $dt->epoch);
}

sub parse_uptime {
    my ($self, %options) = @_;

    # '40 days, 5:53:12' or '0 days, 2:30:05'
    return 0 if (!defined($options{uptime}) || $options{uptime} eq '');

    if ($options{uptime} =~ /(\d+)\s+days?,?\s*(\d+):(\d+):(\d+)/) {
        return ($1 * 86400) + ($2 * 3600) + ($3 * 60) + $4;
    }
    return 0;
}

sub manage_selection {
    my ($self, %options) = @_;

    # Step 1: system info - structured XML
    my $sysinfo = $options{custom}->request_api(
        cmd => '<show><system><info></info></system></show>'
    );

    my $sys = $sysinfo->{system};
    $self->{system} = {
        oper_mode  => defined($sys->{'operational-mode'}) ? $sys->{'operational-mode'} : 'unknown',
        model      => defined($sys->{model}) ? $sys->{model} : '-',
        sw_version => defined($sys->{'sw-version'}) ? $sys->{'sw-version'} : '-',
        serial     => defined($sys->{serial}) ? $sys->{serial} : '-',
        uptime_seconds => $self->parse_uptime(uptime => $sys->{uptime}),
        # Content versions
        av_version     => defined($sys->{'av-version'}) ? $sys->{'av-version'} : '-',
        av_lastupdate_time     => $self->get_diff_time(time => $sys->{'av-release-date'}),
        threat_version => defined($sys->{'threat-version'}) ? $sys->{'threat-version'} : '-',
        threat_lastupdate_time => $self->get_diff_time(time => $sys->{'threat-release-date'}),
        wf_version     => defined($sys->{'wildfire-version'}) ? $sys->{'wildfire-version'} : '-',
        wf_lastupdate_time     => $self->get_diff_time(time => $sys->{'wildfire-release-date'})
    };

    # Step 2: system resources - text output (top-like)
    my $resources = $options{custom}->request_api(
        cmd => '<show><system><resources></resources></system></show>'
    );
    if (defined($resources) && !ref($resources)) {
        # %Cpu(s):  2.3 us,  0.5 sy,  0.0 ni, 97.0 id,  0.2 wa
        if ($resources =~ /Cpu.*?:\s+([\d.]+)\s+us.*?([\d.]+)\s+sy/si) {
            $self->{system}->{cpu_load} = $1 + $2;
        }
        # MiB Mem :  16384.0 total,   2048.0 free,   8192.0 used,   6144.0 buff/cache
        # or: Mem:  16384 total,  8192 used,  2048 free,  6144 buffers
        if ($resources =~ /Mem\s*:?\s+([\d.]+)\s+total.*?([\d.]+)\s+free/si) {
            my ($total, $free) = ($1, $2);
            $self->{system}->{memory_used_pct} = ($total > 0) ? (($total - $free) / $total) * 100 : 0;
        } elsif ($resources =~ /Mem\s*:?\s+([\d.]+)\s+total.*?([\d.]+)\s+used/si) {
            my ($total, $used) = ($1, $2);
            $self->{system}->{memory_used_pct} = ($total > 0) ? ($used / $total) * 100 : 0;
        }
        # Swap:   4096.0 total,   4096.0 free,      0.0 used
        if ($resources =~ /Swap\s*:?\s+([\d.]+)\s+total.*?([\d.]+)\s+free/si) {
            my ($total, $free) = ($1, $2);
            $self->{system}->{swap_used_pct} = ($total > 0) ? (($total - $free) / $total) * 100 : 0;
        }
    }

    # Step 3: disk space - text output (df-like)
    my $diskspace = $options{custom}->request_api(
        cmd => '<show><system><disk-space></disk-space></system></show>'
    );
    if (defined($diskspace) && !ref($diskspace)) {
        # /dev/sda2       7.6G  4.2G  3.0G  59% /
        # /dev/sda5       7.9G  657M  6.9G   9% /opt/panrepo
        my $max_pct = 0;
        while ($diskspace =~ /\s+(\d+)%\s+\//g) {
            $max_pct = $1 if ($1 > $max_pct);
        }
        $self->{system}->{disk_used_pct} = $max_pct;
    }

    # Step 4: session statistics - text output
    my $sessions = $options{custom}->request_api(
        cmd => '<show><system><statistics><session></session></statistics></system></show>'
    );
    if (defined($sessions) && !ref($sessions)) {
        # Throughput            : 111588 Kbps
        if ($sessions =~ /^Throughput\s*:\s*(\d+)\s+(..)/mi) {
            $self->{system}->{throughput} = centreon::plugins::misc::convert_bytes(value => $1, unit => $2);
        }
        # Packet rate           : 15872/s
        if ($sessions =~ /^Packet\s+rate\s*:\s*(\d+)/mi) {
            $self->{system}->{packet_rate} = $1;
        }
        # Total active sessions : 12769
        if ($sessions =~ /^Total\s+active\s+sessions\s*:\s*(\d+)/mi) {
            $self->{system}->{active_sessions} = $1;
        }
        # Active TCP sessions   : 5217
        if ($sessions =~ /^Active\s+TCP\s+sessions\s*:\s*(\d+)/mi) {
            $self->{system}->{tcp_sessions} = $1;
        }
        # Active UDP sessions   : 7531
        if ($sessions =~ /^Active\s+UDP\s+sessions\s*:\s*(\d+)/mi) {
            $self->{system}->{udp_sessions} = $1;
        }
        # Active ICMP sessions  : 19
        if ($sessions =~ /^Active\s+ICMP\s+sessions\s*:\s*(\d+)/mi) {
            $self->{system}->{icmp_sessions} = $1;
        }
    }

    $self->{cache_name} = 'paloalto_' . $self->{mode} . '_' . $options{custom}->get_hostname() . '_' . $options{custom}->get_port() . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check system health (CPU, memory, disk, sessions, content versions).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^(cpu|memory)'

=item B<--timezone>

Timezone options. Default is 'GMT'.

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{oper_mode}, %{model}, %{sw_version}, %{serial}.

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{oper_mode}, %{model}, %{sw_version}, %{serial}.

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{oper_mode} !~ /normal/i').
You can use the following variables: %{oper_mode}, %{model}, %{sw_version}, %{serial}.

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'uptime' (s), 'cpu-load' (%), 'memory-usage' (%), 'disk-usage' (%),
'swap-usage' (%), 'sessions-total-active', 'sessions-tcp', 'sessions-udp',
'sessions-icmp', 'sessions-traffic' (b/s), 'packet-rate',
'av-update' (s), 'threat-update' (s), 'wildfire-update' (s).

=back

=cut
