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

package storage::scality::ring::mode::serverstatus;
use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("state is '%s', status is '%s' [roles: %s, zone: %s]",
        $self->{result_values}->{state},
        $self->{result_values}->{status},
        $self->{result_values}->{roles},
        $self->{result_values}->{zone});
}

sub set_counters {
    my ($self, %options) = @_;
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ', ' },
        { name => 'servers', type => 1, cb_prefix_output => 'prefix_server_output',
          message_multiple => 'All servers are OK', skipped_code => { -10 => 1 } },
    ];
    $self->{maps_counters}->{global} = [
        { label => 'servers-ok', nlabel => 'servers.status.ok.count', set => {
            key_values => [ { name => 'ok' } ],
            output_template => '%d server(s) OK',
            perfdatas => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'servers-warning', nlabel => 'servers.status.warning.count', set => {
            key_values => [ { name => 'warning' } ],
            output_template => '%d server(s) WARNING',
            perfdatas => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'servers-critical', nlabel => 'servers.status.critical.count', set => {
            key_values => [ { name => 'critical' } ],
            output_template => '%d server(s) CRITICAL',
            perfdatas => [ { template => '%d', min => 0 } ],
          }
        },
    ];
    $self->{maps_counters}->{servers} = [
        { label => 'status', type => 2,
          critical_default => '%{status} !~ /^ok$/i || %{state} !~ /^online$/i',
          set => {
            key_values => [ { name => 'status' }, { name => 'state' },
                            { name => 'roles' }, { name => 'zone' }, { name => 'name' } ],
            closure_custom_output => $self->can('custom_status_output'),
            closure_custom_perfdata => sub { return 0; },
            closure_custom_threshold_check => \&catalog_status_threshold_ng,
          }
        },
        { label => 'disks-ok', nlabel => 'server.disks.ok.count', set => {
            key_values => [ { name => 'disks_ok' }, { name => 'name' } ],
            output_template => '%d disk(s) OK',
            perfdatas => [ { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
        { label => 'disks-warning', nlabel => 'server.disks.warning.count', set => {
            key_values => [ { name => 'disks_warning' }, { name => 'name' } ],
            output_template => '%d disk(s) WARNING',
            perfdatas => [ { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
        { label => 'disks-critical', nlabel => 'server.disks.critical.count', set => {
            key_values => [ { name => 'disks_critical' }, { name => 'name' } ],
            output_template => '%d disk(s) CRITICAL',
            perfdatas => [ { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
    ];
}

sub prefix_server_output {
    my ($self, %options) = @_;
    return "Server '" . $options{instance_value}->{name} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        'filter-name:s'    => { name => 'filter_name'   },
        'filter-zone:s'    => { name => 'filter_zone'   },
        'filter-role:s'    => { name => 'filter_role'   },
        'filter-state:s'   => { name => 'filter_state'  },
        'filter-status:s'  => { name => 'filter_status' },
        'exclude-name:s'   => { name => 'exclude_name'   },
        'exclude-zone:s'   => { name => 'exclude_zone'  },
        'exclude-role:s'   => { name => 'exclude_role'   },
        'exclude-state:s'  => { name => 'exclude_state'  },
        'exclude-status:s' => { name => 'exclude_status' },
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;
    my $items = $options{custom}->get_nodes();

    $self->{global} = { ok => 0, warning => 0, critical => 0 };
    $self->{servers} = {};

    foreach my $server (@{$items}) {
        my $name  = $server->{name} // $server->{id} // 'unknown';
        my $state = ref($server->{state}) eq 'ARRAY'
                  ? join(',', @{$server->{state}}) : ($server->{state} // 'unknown');
        my $roles = ref($server->{roles}) eq 'ARRAY'
                  ? join(',', @{$server->{roles}}) : ($server->{roles} // 'n/a');
        my $zone  = $server->{zone} // 'n/a';

        # Filters
        next if (defined($self->{option_results}->{filter_name})   && $self->{option_results}->{filter_name}   ne '' && $name   !~ /$self->{option_results}->{filter_name}/);
        next if (defined($self->{option_results}->{filter_zone})   && $self->{option_results}->{filter_zone}   ne '' && $zone   !~ /$self->{option_results}->{filter_zone}/);
        next if (defined($self->{option_results}->{filter_role})   && $self->{option_results}->{filter_role}   ne '' && $roles  !~ /$self->{option_results}->{filter_role}/);
        next if (defined($self->{option_results}->{filter_state})  && $self->{option_results}->{filter_state}  ne '' && $state  !~ /$self->{option_results}->{filter_state}/i);
        next if (defined($self->{option_results}->{filter_status}) && $self->{option_results}->{filter_status} ne '' && ($server->{status} // '') !~ /$self->{option_results}->{filter_status}/i);
        # Excludes
        next if (defined($self->{option_results}->{exclude_name})   && $self->{option_results}->{exclude_name}   ne '' && $name   =~ /$self->{option_results}->{exclude_name}/);
        next if (defined($self->{option_results}->{exclude_zone})   && $self->{option_results}->{exclude_zone}   ne '' && $zone   =~ /$self->{option_results}->{exclude_zone}/);
        next if (defined($self->{option_results}->{exclude_role})   && $self->{option_results}->{exclude_role}   ne '' && $roles  =~ /$self->{option_results}->{exclude_role}/);
        next if (defined($self->{option_results}->{exclude_state})  && $self->{option_results}->{exclude_state}  ne '' && $state  =~ /$self->{option_results}->{exclude_state}/i);
        next if (defined($self->{option_results}->{exclude_status}) && $self->{option_results}->{exclude_status} ne '' && ($server->{status} // '') =~ /$self->{option_results}->{exclude_status}/i);
        my $status = lc($server->{status} // 'unknown');
        if    ($status eq 'ok')       { $self->{global}->{ok}++;       }
        elsif ($status eq 'warning')  { $self->{global}->{warning}++;  }
        elsif ($status eq 'critical') { $self->{global}->{critical}++; }

        $self->{servers}->{$name} = {
            name           => $name,
            state          => $state,
            status         => $server->{status}                  // 'unknown',
            roles          => $roles,
            zone           => $zone,
            disks_ok       => ($server->{diskcount_status_ok}       // 0) || 0,
            disks_warning  => ($server->{diskcount_status_warning}  // 0) || 0,
            disks_critical => ($server->{diskcount_status_critical} // 0) || 0,
        };
    }
    if (scalar(keys %{$self->{servers}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No servers found.");
        $self->{output}->option_exit();
    }
}
1;

__END__

=head1 MODE

Check Scality RING server status and disk counts.

=over 8

=item B<--filter-name>

Filter servers by name (regexp).

=item B<--filter-zone>

Filter servers by zone (regexp).

=item B<--filter-role>

Filter servers by role (regexp).

=item B<--filter-state>

Filter servers by state (regexp).

=item B<--filter-status>

Filter servers by status (regexp).

=item B<--exclude-name>

Exclude servers by name (regexp).

=item B<--exclude-zone>

Exclude servers by zone (regexp).

=item B<--exclude-role>

Exclude servers by role (regexp).

=item B<--exclude-state>

Exclude servers by state (regexp).

=item B<--exclude-status>

Exclude servers by status (regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{state}, %{roles}, %{zone}, %{name}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{state}, %{roles}, %{zone}, %{name}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{status} !~ /^ok$/i || %{state} !~ /^online$/i').
You can use the following variables: %{status}, %{state}, %{roles}, %{zone}, %{name}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'servers-ok', 'servers-warning', 'servers-critical',
'disks-ok', 'disks-warning', 'disks-critical'.

=back

=cut
