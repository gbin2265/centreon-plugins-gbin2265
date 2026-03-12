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

package storage::scality::ring::mode::connectorstatus;
use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("state is '%s', status is '%s' [ring: %s, protocol: %s, detached: %s]",
        $self->{result_values}->{state},
        $self->{result_values}->{status},
        $self->{result_values}->{ring},
        $self->{result_values}->{protocol},
        $self->{result_values}->{detached});
}

sub set_counters {
    my ($self, %options) = @_;
    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ', ' },
        { name => 'connectors', type => 1, cb_prefix_output => 'prefix_conn_output',
          message_multiple => 'All connectors are OK', skipped_code => { -10 => 1 } },
    ];
    $self->{maps_counters}->{global} = [
        { label => 'connectors-ok', nlabel => 'connectors.status.ok.count', set => {
            key_values => [ { name => 'ok' } ],
            output_template => '%d connector(s) OK',
            perfdatas => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'connectors-warning', nlabel => 'connectors.status.warning.count', set => {
            key_values => [ { name => 'warning' } ],
            output_template => '%d connector(s) WARNING',
            perfdatas => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'connectors-critical', nlabel => 'connectors.status.critical.count', set => {
            key_values => [ { name => 'critical' } ],
            output_template => '%d connector(s) CRITICAL',
            perfdatas => [ { template => '%d', min => 0 } ],
          }
        },
    ];
    $self->{maps_counters}->{connectors} = [
        { label => 'status', type => 2,
          critical_default => '%{status} !~ /^ok$/i || %{state} !~ /^ok$/i',
          set => {
            key_values => [ { name => 'status' }, { name => 'state' }, { name => 'ring' },
                            { name => 'protocol' }, { name => 'detached' }, { name => 'name' } ],
            closure_custom_output => $self->can('custom_status_output'),
            closure_custom_perfdata => sub { return 0; },
            closure_custom_threshold_check => \&catalog_status_threshold_ng,
          }
        },
    ];
}

sub prefix_conn_output {
    my ($self, %options) = @_;
    return "Connector '" . $options{instance_value}->{name} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        'filter-name:s'      => { name => 'filter_name' },
        'filter-ring:s'      => { name => 'filter_ring' },
        'filter-protocol:s'  => { name => 'filter_protocol' },
        'filter-detached:s'  => { name => 'filter_detached'  },
        'filter-state:s'     => { name => 'filter_state'    },
        'filter-status:s'    => { name => 'filter_status'   },
        'exclude-name:s'     => { name => 'exclude_name'    },
        'exclude-ring:s'     => { name => 'exclude_ring'    },
        'exclude-protocol:s' => { name => 'exclude_protocol'},
        'exclude-detached:s' => { name => 'exclude_detached'},
        'exclude-state:s'    => { name => 'exclude_state'   },
        'exclude-status:s'   => { name => 'exclude_status'  },
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;
    my $items = $options{custom}->get_connectors();

    $self->{global}     = { ok => 0, warning => 0, critical => 0 };
    $self->{connectors} = {};

    foreach my $conn (@{$items}) {
        my $name     = $conn->{name}     // $conn->{id} // 'unknown';
        my $ring     = $conn->{ring}     // 'n/a';
        my $protocol = $conn->{protocol} // 'none';
        my $detached = $conn->{detached} ? 'true' : 'false';
        my $state    = ref($conn->{state}) eq 'ARRAY'
                     ? join(',', @{$conn->{state}}) : ($conn->{state} // 'unknown');
        my $status   = $conn->{status} // 'unknown';

        # Filters
        next if (defined($self->{option_results}->{filter_name})     && $self->{option_results}->{filter_name}     ne '' && $name     !~ /$self->{option_results}->{filter_name}/);
        next if (defined($self->{option_results}->{filter_ring})     && $self->{option_results}->{filter_ring}     ne '' && $ring     !~ /$self->{option_results}->{filter_ring}/);
        next if (defined($self->{option_results}->{filter_protocol}) && $self->{option_results}->{filter_protocol} ne '' && $protocol !~ /$self->{option_results}->{filter_protocol}/i);
        next if (defined($self->{option_results}->{filter_detached}) && $self->{option_results}->{filter_detached} ne '' && $detached !~ /$self->{option_results}->{filter_detached}/i);
        next if (defined($self->{option_results}->{filter_state})    && $self->{option_results}->{filter_state}    ne '' && $state    !~ /$self->{option_results}->{filter_state}/i);
        next if (defined($self->{option_results}->{filter_status})   && $self->{option_results}->{filter_status}   ne '' && $status   !~ /$self->{option_results}->{filter_status}/i);
        # Excludes
        next if (defined($self->{option_results}->{exclude_name})     && $self->{option_results}->{exclude_name}     ne '' && $name     =~ /$self->{option_results}->{exclude_name}/);
        next if (defined($self->{option_results}->{exclude_ring})     && $self->{option_results}->{exclude_ring}     ne '' && $ring     =~ /$self->{option_results}->{exclude_ring}/);
        next if (defined($self->{option_results}->{exclude_protocol}) && $self->{option_results}->{exclude_protocol} ne '' && $protocol =~ /$self->{option_results}->{exclude_protocol}/i);
        next if (defined($self->{option_results}->{exclude_detached}) && $self->{option_results}->{exclude_detached} ne '' && $detached =~ /$self->{option_results}->{exclude_detached}/i);
        next if (defined($self->{option_results}->{exclude_state})    && $self->{option_results}->{exclude_state}    ne '' && $state    =~ /$self->{option_results}->{exclude_state}/i);
        next if (defined($self->{option_results}->{exclude_status})   && $self->{option_results}->{exclude_status}   ne '' && $status   =~ /$self->{option_results}->{exclude_status}/i);

        my $status_lc = lc($status);
        if    ($status_lc eq 'ok')       { $self->{global}->{ok}++;       }
        elsif ($status_lc eq 'warning')  { $self->{global}->{warning}++;  }
        elsif ($status_lc eq 'critical') { $self->{global}->{critical}++; }

        $self->{connectors}->{$name} = {
            name     => $name,
            state    => $state,
            status   => $status,
            ring     => $ring,
            protocol => $protocol,
            detached => $detached,
        };
    }
    if (scalar(keys %{$self->{connectors}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No connectors found.");
        $self->{output}->option_exit();
    }
}
1;

__END__

=head1 MODE

Check Scality RING volume connector status.

=over 8

=item B<--filter-name>

Filter connectors by name (regexp).

=item B<--filter-ring>

Filter connectors by ring (regexp).

=item B<--filter-protocol>

Filter connectors by protocol (regexp, e.g. S3, NFS, SMB).

=item B<--filter-detached>

Filter connectors by detached state (regexp, e.g. true, false).

=item B<--filter-state>

Filter connectors by state (regexp).

=item B<--filter-status>

Filter connectors by status (regexp).

=item B<--exclude-name>

Exclude connectors by name (regexp).

=item B<--exclude-ring>

Exclude connectors by ring (regexp).

=item B<--exclude-protocol>

Exclude connectors by protocol (regexp).

=item B<--exclude-detached>

Exclude connectors by detached state (regexp, e.g. true).

=item B<--exclude-state>

Exclude connectors by state (regexp).

=item B<--exclude-status>

Exclude connectors by status (regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{state}, %{ring}, %{protocol}, %{detached}, %{name}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{state}, %{ring}, %{protocol}, %{detached}, %{name}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{status} !~ /^ok$/i || %{state} !~ /^ok$/i').
You can use the following variables: %{status}, %{state}, %{ring}, %{protocol}, %{detached}, %{name}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'connectors-ok', 'connectors-warning', 'connectors-critical'.

=back

=cut
