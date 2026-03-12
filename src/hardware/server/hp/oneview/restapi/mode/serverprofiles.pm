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

package hardware::server::hp::oneview::restapi::mode::serverprofiles;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [compliance: %s] [template: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{compliance_state},
        $self->{result_values}->{template_name}
    );
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'profiles', type => 1, cb_prefix_output => 'prefix_profile_output',
          message_multiple => 'All server profiles are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'profiles-total', nlabel => 'server.profiles.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total: %d',
                perfdatas       => [ { value => 'total', template => '%d', min => 0 } ],
            }
        },
        { label => 'profiles-status-ok', nlabel => 'server.profiles.status.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_ok' } ],
                output_template => 'health ok: %d',
                perfdatas       => [ { value => 'status_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'profiles-status-warning', nlabel => 'server.profiles.status.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_warning' } ],
                output_template => 'health warning: %d',
                perfdatas       => [ { value => 'status_warning', template => '%d', min => 0 } ],
            }
        },
        { label => 'profiles-status-critical', nlabel => 'server.profiles.status.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_critical' } ],
                output_template => 'health critical: %d',
                perfdatas       => [ { value => 'status_critical', template => '%d', min => 0 } ],
            }
        },
        { label => 'profiles-compliant', nlabel => 'server.profiles.compliant.count', display_ok => 0, set => {
                key_values      => [ { name => 'compliant' } ],
                output_template => 'compliant: %d',
                perfdatas       => [ { value => 'compliant', template => '%d', min => 0 } ],
            }
        },
        { label => 'profiles-noncompliant', nlabel => 'server.profiles.noncompliant.count', display_ok => 0, set => {
                key_values      => [ { name => 'noncompliant' } ],
                output_template => 'non-compliant: %d',
                perfdatas       => [ { value => 'noncompliant', template => '%d', min => 0 } ],
            }
        },
        { label => 'profiles-unassigned', nlabel => 'server.profiles.unassigned.count', display_ok => 0, set => {
                key_values      => [ { name => 'unassigned' } ],
                output_template => 'unassigned: %d',
                perfdatas       => [ { value => 'unassigned', template => '%d', min => 0 } ],
            }
        },
    ];

    # ---- Per server profile ----
    $self->{maps_counters}->{profiles} = [
        { label => 'profile-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'compliance_state' },
                    { name => 'template_name' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        # Number of connections defined in the profile
        { label => 'profile-connections', nlabel => 'server.profile.connections.count', display_ok => 0, set => {
                key_values      => [ { name => 'connection_count' }, { name => 'display' } ],
                output_template => 'connections: %d',
                perfdatas       => [
                    { value => 'connection_count', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Number of volumes attached
        { label => 'profile-volumes', nlabel => 'server.profile.volumes.count', display_ok => 0, set => {
                key_values      => [ { name => 'volume_count' }, { name => 'display' } ],
                output_template => 'volumes: %d',
                perfdatas       => [
                    { value => 'volume_count', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

sub prefix_profile_output {
    my ($self, %options) = @_;
    return "Server profile '" . $options{instance_value}->{display} . "' ";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'                 => { name => 'filter_name' },
        'filter-template-name:s'        => { name => 'filter_template_name' },
        'filter-compliance-state:s'     => { name => 'filter_compliance_state' },
        'filter-server-hardware-type:s' => { name => 'filter_server_hardware_type' },
        'unknown-profile-status:s'  => { name => 'unknown_profile_status',
            default => '%{status} =~ /unknown/i' },
        'warning-profile-status:s'  => { name => 'warning_profile_status',
            default => '%{status} =~ /warning/i' },
        'critical-profile-status:s' => { name => 'critical_profile_status',
            default => '%{status} =~ /critical/i' },
        'unknown-compliance:s'      => { name => 'unknown_compliance',  default => '' },
        'warning-compliance:s'      => { name => 'warning_compliance',  default => '' },
        'critical-compliance:s'     => { name => 'critical_compliance',
            default => '%{compliance_state} =~ /inconsistent/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_profile_status', 'critical_profile_status', 'unknown_profile_status',
        'warning_compliance',     'critical_compliance',     'unknown_compliance',
    ]);
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api_all(url_path => '/rest/server-profiles');

    $self->{global} = {
        total           => 0,
        status_ok       => 0,
        status_warning  => 0,
        status_critical => 0,
        compliant       => 0,
        noncompliant    => 0,
        unassigned      => 0,
    };
    $self->{profiles} = {};

    foreach my $profile (@{$results->{members}}) {
        my $name = defined($profile->{name}) ? $profile->{name} : $profile->{uri};

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(
                long_msg => "skipping profile '$name': no matching filter.", debug => 1
            );
            next;
        }

        # Template name (may be unset for unassigned profiles)
        my $template_name = 'none';
        if (defined($profile->{serverProfileTemplateUri}) && $profile->{serverProfileTemplateUri} ne '') {
            # Extract last segment of URI as a readable name
            ($template_name) = $profile->{serverProfileTemplateUri} =~ m{/([^/]+)$};
            $template_name //= $profile->{serverProfileTemplateUri};
        }

        if (defined($self->{option_results}->{filter_template_name}) && $self->{option_results}->{filter_template_name} ne '' &&
            $template_name !~ /$self->{option_results}->{filter_template_name}/) {
            $self->{output}->output_add(
                long_msg => "skipping profile '$name': template '$template_name' no matching filter.", debug => 1
            );
            next;
        }

        my $status           = defined($profile->{status})          ? lc($profile->{status})          : 'unknown';
        my $compliance_state = defined($profile->{templateCompliance}) ? lc($profile->{templateCompliance}) : 'unknown';

        if (defined($self->{option_results}->{filter_compliance_state}) && $self->{option_results}->{filter_compliance_state} ne '' &&
            $compliance_state !~ /$self->{option_results}->{filter_compliance_state}/i) {
            $self->{output}->output_add(long_msg => "skipping profile '$name': compliance '$compliance_state' no matching filter.", debug => 1);
            next;
        }

        my $sht_name = '';
        if (defined($profile->{serverHardwareTypeUri}) && $profile->{serverHardwareTypeUri} ne '') {
            ($sht_name) = $profile->{serverHardwareTypeUri} =~ m{/([^/]+)$};
            $sht_name //= '';
        }
        if (defined($self->{option_results}->{filter_server_hardware_type}) && $self->{option_results}->{filter_server_hardware_type} ne '' &&
            $sht_name !~ /$self->{option_results}->{filter_server_hardware_type}/i) {
            $self->{output}->output_add(long_msg => "skipping profile '$name': hardware type '$sht_name' no matching filter.", debug => 1);
            next;
        }
        my $server_uri       = $profile->{serverHardwareUri} // '';
        my $connection_count = defined($profile->{connectionSettings}->{connections})
            ? scalar(@{$profile->{connectionSettings}->{connections}}) : 0;
        my $volume_count     = defined($profile->{sanStorage}->{volumeAttachments})
            ? scalar(@{$profile->{sanStorage}->{volumeAttachments}}) : 0;

        # Global counters
        $self->{global}->{total}++;
        $self->{global}->{'status_' . $status}++
            if (exists $self->{global}->{'status_' . $status});
        $self->{global}->{unassigned}++  if ($server_uri eq '');

        if ($compliance_state =~ /^compliant$/i) {
            $self->{global}->{compliant}++;
        } elsif ($compliance_state =~ /inconsistent/i) {
            $self->{global}->{noncompliant}++;
        }

        $self->{profiles}->{$name} = {
            display          => $name,
            status           => $status,
            compliance_state => $compliance_state,
            template_name    => $template_name,
            connection_count => $connection_count,
            volume_count     => $volume_count,
        };
    }

    if (scalar(keys %{$self->{profiles}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No server profiles found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView server profiles: health status and template compliance.

Global perfdata: total count, health status counts, compliant/non-compliant/unassigned counts.
Per-profile perfdata: connection count, volume attachment count.

=over 8

=item B<--filter-name>

Filter server profile by name (can be a regexp).

=item B<--filter-template-name>

Filter server profiles by their assigned template name (can be a regexp).

=item B<--filter-compliance-state>

Filter server profiles by compliance state before reporting (can be a regexp).
Example: --filter-compliance-state='inconsistent' to focus only on non-compliant profiles.

=item B<--filter-server-hardware-type>

Filter server profiles by their assigned server hardware type (can be a regexp).
Example: --filter-server-hardware-type='BL460c Gen10'.

=item B<--unknown-profile-status>

Conditions for UNKNOWN health status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{compliance_state}, %{template_name}, %{display}

=item B<--warning-profile-status>

Conditions for WARNING health status (default: '%{status} =~ /warning/i').

=item B<--critical-profile-status>

Conditions for CRITICAL health status (default: '%{status} =~ /critical/i').

=item B<--unknown-compliance>

Conditions for UNKNOWN compliance (default: '').
Variables: %{compliance_state}, %{template_name}, %{display}

=item B<--warning-compliance>

Conditions for WARNING compliance (default: '').

=item B<--critical-compliance>

Conditions for CRITICAL compliance
(default: '%{compliance_state} =~ /inconsistent/i').

=item B<--warning-*> B<--critical-*>

Global thresholds:
'profiles-total', 'profiles-status-ok/warning/critical',
'profiles-compliant', 'profiles-noncompliant', 'profiles-unassigned'.

Per-profile thresholds:
'profile-connections', 'profile-volumes'.

=back

=cut
