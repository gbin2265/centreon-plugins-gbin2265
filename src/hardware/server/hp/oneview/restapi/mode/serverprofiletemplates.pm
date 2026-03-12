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

package hardware::server::hp::oneview::restapi::mode::serverprofiletemplates;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s', $self->{result_values}->{status});
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'templates', type => 1, cb_prefix_output => 'prefix_template_output',
          message_multiple => 'All server profile templates are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'templates-total', nlabel => 'server.profile.templates.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total: %d',
                perfdatas       => [ { value => 'total', template => '%d', min => 0 } ],
            }
        },
        { label => 'templates-status-ok', nlabel => 'server.profile.templates.status.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_ok' } ],
                output_template => 'health ok: %d',
                perfdatas       => [ { value => 'status_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'templates-status-warning', nlabel => 'server.profile.templates.status.warning.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_warning' } ],
                output_template => 'health warning: %d',
                perfdatas       => [ { value => 'status_warning', template => '%d', min => 0 } ],
            }
        },
        { label => 'templates-status-critical', nlabel => 'server.profile.templates.status.critical.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_critical' } ],
                output_template => 'health critical: %d',
                perfdatas       => [ { value => 'status_critical', template => '%d', min => 0 } ],
            }
        },
        # How many templates have at least one non-compliant profile assigned
        { label => 'templates-with-noncompliant', nlabel => 'server.profile.templates.noncompliant.profiles.count', display_ok => 0, set => {
                key_values      => [ { name => 'templates_with_noncompliant' } ],
                output_template => 'templates with non-compliant profiles: %d',
                perfdatas       => [ { value => 'templates_with_noncompliant', template => '%d', min => 0 } ],
            }
        },
    ];

    # ---- Per template ----
    $self->{maps_counters}->{templates} = [
        { label => 'template-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        # Total profiles assigned to this template
        { label => 'template-profiles-total', nlabel => 'server.profile.template.profiles.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'profiles_total' }, { name => 'display' } ],
                output_template => 'assigned profiles: %d',
                perfdatas       => [
                    { value => 'profiles_total', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Compliant profiles
        { label => 'template-profiles-compliant', nlabel => 'server.profile.template.profiles.compliant.count', display_ok => 0, set => {
                key_values      => [ { name => 'profiles_compliant' }, { name => 'display' } ],
                output_template => 'compliant profiles: %d',
                perfdatas       => [
                    { value => 'profiles_compliant', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Non-compliant profiles assigned to this template
        { label => 'template-profiles-noncompliant', nlabel => 'server.profile.template.profiles.noncompliant.count', display_ok => 0, set => {
                key_values      => [ { name => 'profiles_noncompliant' }, { name => 'display' } ],
                output_template => 'non-compliant profiles: %d',
                perfdatas       => [
                    { value => 'profiles_noncompliant', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Number of connections defined in the template
        { label => 'template-connections', nlabel => 'server.profile.template.connections.count', display_ok => 0, set => {
                key_values      => [ { name => 'connection_count' }, { name => 'display' } ],
                output_template => 'connections defined: %d',
                perfdatas       => [
                    { value => 'connection_count', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];
}

sub prefix_template_output {
    my ($self, %options) = @_;
    return "Server profile template '" . $options{instance_value}->{display} . "' ";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s'                    => { name => 'filter_name' },
        'filter-server-hardware-type:s'    => { name => 'filter_server_hardware_type' },
        'unknown-template-status:s'  => { name => 'unknown_template_status',
            default => '%{status} =~ /unknown/i' },
        'warning-template-status:s'  => { name => 'warning_template_status',
            default => '%{status} =~ /warning/i' },
        'critical-template-status:s' => { name => 'critical_template_status',
            default => '%{status} =~ /critical/i' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_template_status', 'critical_template_status', 'unknown_template_status',
    ]);
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $templates = $options{custom}->request_api_all(url_path => '/rest/server-profile-templates');

    # Build a map: templateUri -> { compliant, noncompliant, total }
    # by fetching all server profiles once
    my %template_profile_counts;
    my $profiles = $options{custom}->request_api_all(url_path => '/rest/server-profiles');
    foreach my $profile (@{$profiles->{members}}) {
        my $t_uri = $profile->{serverProfileTemplateUri} // '';
        next if ($t_uri eq '');
        $template_profile_counts{$t_uri} //= { total => 0, compliant => 0, noncompliant => 0 };
        $template_profile_counts{$t_uri}->{total}++;
        my $compliance = lc($profile->{templateCompliance} // '');
        if ($compliance =~ /^compliant$/) {
            $template_profile_counts{$t_uri}->{compliant}++;
        } elsif ($compliance =~ /inconsistent/) {
            $template_profile_counts{$t_uri}->{noncompliant}++;
        }
    }

    $self->{global} = {
        total                      => 0,
        status_ok                  => 0,
        status_warning             => 0,
        status_critical            => 0,
        templates_with_noncompliant => 0,
    };
    $self->{templates} = {};

    foreach my $tmpl (@{$templates->{members}}) {
        my $name = defined($tmpl->{name}) ? $tmpl->{name} : $tmpl->{uri};

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(
                long_msg => "skipping template '$name': no matching filter.", debug => 1
            );
            next;
        }

        my $sht_name = '';
        if (defined($tmpl->{serverHardwareTypeUri}) && $tmpl->{serverHardwareTypeUri} ne '') {
            ($sht_name) = $tmpl->{serverHardwareTypeUri} =~ m{/([^/]+)$};
            $sht_name //= $tmpl->{serverHardwareTypeUri};
        }
        if (defined($self->{option_results}->{filter_server_hardware_type}) && $self->{option_results}->{filter_server_hardware_type} ne '' &&
            $sht_name !~ /$self->{option_results}->{filter_server_hardware_type}/i) {
            $self->{output}->output_add(
                long_msg => "skipping template '$name': server hardware type '$sht_name' no matching filter.", debug => 1
            );
            next;
        }

        my $status           = defined($tmpl->{status}) ? lc($tmpl->{status}) : 'unknown';
        my $connection_count = defined($tmpl->{connectionSettings}->{connections})
            ? scalar(@{$tmpl->{connectionSettings}->{connections}}) : 0;

        my $pc = $template_profile_counts{$tmpl->{uri}} // { total => 0, compliant => 0, noncompliant => 0 };

        # Global counters
        $self->{global}->{total}++;
        $self->{global}->{'status_' . $status}++
            if (exists $self->{global}->{'status_' . $status});
        $self->{global}->{templates_with_noncompliant}++
            if ($pc->{noncompliant} > 0);

        $self->{templates}->{$name} = {
            display              => $name,
            status               => $status,
            profiles_total       => $pc->{total},
            profiles_compliant   => $pc->{compliant},
            profiles_noncompliant => $pc->{noncompliant},
            connection_count     => $connection_count,
        };
    }

    if (scalar(keys %{$self->{templates}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No server profile templates found');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check HPE OneView server profile templates and their assigned profile compliance.

Fetches both the template list and all server profiles in two API calls to compute
per-template compliance statistics.

Global perfdata: total templates, health status counts, templates with non-compliant profiles.
Per-template perfdata: assigned profiles total/compliant/non-compliant, connection count.

=over 8

=item B<--filter-name>

Filter template by name (can be a regexp).

=item B<--filter-server-hardware-type>

Filter templates by their assigned server hardware type (can be a regexp).
Example: --filter-server-hardware-type='BL460c Gen10'

=item B<--unknown-template-status>

Conditions for UNKNOWN status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{display}

=item B<--warning-template-status>

Conditions for WARNING status (default: '%{status} =~ /warning/i').

=item B<--critical-template-status>

Conditions for CRITICAL status (default: '%{status} =~ /critical/i').

=item B<--warning-*> B<--critical-*>

Global thresholds:
'templates-total', 'templates-status-ok/warning/critical',
'templates-with-noncompliant'.

Per-template thresholds:
'template-profiles-total', 'template-profiles-compliant',
'template-profiles-noncompliant', 'template-connections'.

=back

=cut
