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

package network::paloalto::restapi::mode::ha;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_sync_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'sync status: %s [enabled: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{enabled}
    );
}

sub custom_member_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'state: %s',
        $self->{result_values}->{state}
    );
}

sub custom_member_status_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{stateLast} = $options{old_datas}->{$self->{instance} . '_state'};
    $self->{result_values}->{state} = $options{new_datas}->{$self->{instance} . '_state'};
    if (!defined($options{old_datas}->{$self->{instance} . '_state'})) {
        $self->{error_msg} = "buffer creation";
        return -2;
    }

    return 0;
}

sub custom_link_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'status: %s',
        $self->{result_values}->{status}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'sync', type => 0 },
        {
            name => 'member', type => 3, cb_prefix_output => 'prefix_member_output',
            cb_long_output => 'member_long_output', indent_long_output => '    ',
            message_multiple => 'All members are ok',
            group => [
                { name => 'global', type => 0, skipped_code => { -10 => 1 } },
                { name => 'link', display_long => 1, cb_prefix_output => 'prefix_link_output', message_multiple => 'All links are ok', type => 1, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{sync} = [
        { label => 'sync-status', type => 2, critical_default => '%{enabled} eq "yes" and %{status} ne "synchronized"', set => {
                key_values => [ { name => 'enabled' }, { name => 'status' } ],
                closure_custom_output => $self->can('custom_sync_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'member-status', type => 2, critical_default => '%{state} ne %{stateLast}', set => {
                key_values => [ { name => 'state' }, { name => 'display' } ],
                closure_custom_calc => $self->can('custom_member_status_calc'),
                closure_custom_output => $self->can('custom_member_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{link} = [
        { label => 'link-status', type => 2, critical_default => '%{status} ne "up"', set => {
                key_values => [ { name => 'status' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_link_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub member_long_output {
    my ($self, %options) = @_;

    my $iv = $options{instance_value};
    my $msg = "checking member '" . $iv->{display} . "'";
    $msg .= "\n        * priority: " . $iv->{priority} if (defined($iv->{priority}));
    $msg .= ", preemptive: " . $iv->{preemptive} if (defined($iv->{preemptive}));
    $msg .= ", version: " . $iv->{version} if (defined($iv->{version}));
    return $msg;
}

sub prefix_member_output {
    my ($self, %options) = @_;

    return "Member '" . $options{instance_value}->{display} . "' ";
}

sub prefix_link_output {
    my ($self, %options) = @_;

    return "link '" . $options{instance_value}->{display} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(
        cmd => '<show><high-availability><state></state></high-availability></show>'
    );

    if (!defined($result->{enabled}) || $result->{enabled} ne 'yes') {
        $self->{output}->add_option_msg(short_msg => 'high-availability is disabled');
        $self->{output}->option_exit();
    }

    my $local_info = defined($result->{group}->{'local-info'}) ? $result->{group}->{'local-info'} : {};
    my $peer_info  = defined($result->{group}->{'peer-info'}) ? $result->{group}->{'peer-info'} : {};

    $self->{member} = {
        local => {
            display    => 'local',
            priority   => defined($local_info->{priority}) ? $local_info->{priority} : '-',
            preemptive => defined($local_info->{preemptive}) ? $local_info->{preemptive} : '-',
            version    => defined($local_info->{'build-rel'}) ? $local_info->{'build-rel'} : '-',
            global     => {
                display => 'local',
                state   => defined($local_info->{state}) ? $local_info->{state} : 'unknown'
            },
            link => {}
        },
        peer => {
            display    => 'peer',
            priority   => defined($peer_info->{priority}) ? $peer_info->{priority} : '-',
            preemptive => defined($peer_info->{preemptive}) ? $peer_info->{preemptive} : '-',
            version    => defined($peer_info->{'build-rel'}) ? $peer_info->{'build-rel'} : '-',
            global     => {
                display => 'peer',
                state   => defined($peer_info->{state}) ? $peer_info->{state} : 'unknown'
            },
            link => {}
        }
    };

    # Peer connection links
    foreach my $key (keys %$peer_info) {
        next if ($key !~ /^conn-(.*)$/ || ref($peer_info->{$key}) ne 'HASH');
        my $name = $1 . '-' . $peer_info->{$key}->{'conn-desc'};
        $self->{member}->{peer}->{link}->{$name} = {
            display => $name,
            status  => $peer_info->{$key}->{'conn-status'}
        };
    }

    # Local connection links
    foreach my $key (keys %$local_info) {
        next if ($key !~ /^conn-(.*)$/ || ref($local_info->{$key}) ne 'HASH');
        my $name = $1 . '-' . $local_info->{$key}->{'conn-desc'};
        $self->{member}->{local}->{link}->{$name} = {
            display => $name,
            status  => $local_info->{$key}->{'conn-status'}
        };
    }

    $self->{sync} = {
        enabled => defined($result->{group}->{'running-sync-enabled'}) ? $result->{group}->{'running-sync-enabled'} : 'unknown',
        status  => defined($result->{group}->{'running-sync'}) ? $result->{group}->{'running-sync'} : 'unknown'
    };

    $self->{cache_name} = 'paloalto_' . $self->{mode} . '_' . $options{custom}->get_hostname() . '_' . $options{custom}->get_port() . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check high availability status.

=over 8

=item B<--unknown-sync-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{enabled}, %{status}.

=item B<--warning-sync-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{enabled}, %{status}.

=item B<--critical-sync-status>

Define the conditions to match for the status to be CRITICAL (default: '%{enabled} eq "yes" and %{status} ne "synchronized"').
You can use the following variables: %{enabled}, %{status}.

=item B<--unknown-member-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{stateLast}, %{display}.

=item B<--warning-member-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{state}, %{stateLast}, %{display}.

=item B<--critical-member-status>

Define the conditions to match for the status to be CRITICAL (default: '%{state} ne %{stateLast}').
You can use the following variables: %{state}, %{stateLast}, %{display}.

=item B<--unknown-link-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{display}.

=item B<--warning-link-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{display}.

=item B<--critical-link-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} ne "up"').
You can use the following variables: %{status}, %{display}.

=back

=cut
