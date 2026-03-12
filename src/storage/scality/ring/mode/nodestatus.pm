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

package storage::scality::ring::mode::nodestatus;
use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("state is '%s' [ring: %s, server: %s, reachable: %s]",
        $self->{result_values}->{state},
        $self->{result_values}->{ring},
        $self->{result_values}->{server},
        $self->{result_values}->{reachable});
}

sub set_counters {
    my ($self, %options) = @_;
    $self->{maps_counters_type} = [
        { name => 'nodes', type => 1, cb_prefix_output => 'prefix_node_output',
          message_multiple => 'All storenodes are OK', skipped_code => { -10 => 1 } },
    ];
    $self->{maps_counters}->{nodes} = [
        { label => 'status', type => 2,
          critical_default => '%{state} !~ /^RUN$/i || %{reachable} ne "true"',
          set => {
            key_values => [ { name => 'state' }, { name => 'reachable' },
                            { name => 'ring' }, { name => 'server' }, { name => 'name' } ],
            closure_custom_output => $self->can('custom_status_output'),
            closure_custom_perfdata => sub { return 0; },
            closure_custom_threshold_check => \&catalog_status_threshold_ng,
          }
        },
        { label => 'chunks', nlabel => 'storenode.chunks.count', set => {
            key_values => [ { name => 'nb_chunks' }, { name => 'name' } ],
            output_template => '%d chunk(s)',
            perfdatas => [ { template => '%d', min => 0,
                label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
    ];
}

sub prefix_node_output {
    my ($self, %options) = @_;
    return "Storenode '" . $options{instance_value}->{name} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        'filter-name:s'      => { name => 'filter_name' },
        'filter-ring:s'      => { name => 'filter_ring' },
        'filter-server:s'    => { name => 'filter_server' },
        'filter-state:s'      => { name => 'filter_state'     },
        'filter-reachable:s'  => { name => 'filter_reachable'  },
        'exclude-name:s'      => { name => 'exclude_name'      },
        'exclude-ring:s'      => { name => 'exclude_ring'      },
        'exclude-server:s'    => { name => 'exclude_server'    },
        'exclude-state:s'     => { name => 'exclude_state'     },
        'exclude-reachable:s' => { name => 'exclude_reachable' },
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;
    my $data  = $options{custom}->get_storenodes();
    my $items = ref($data) eq 'ARRAY' ? $data : [];

    $self->{nodes} = {};
    foreach my $node (@{$items}) {
        my $name   = $node->{name}   // $node->{id} // 'unknown';
        my $ring   = $node->{ring}   // 'n/a';
        my $server = $node->{server} // 'n/a';
        my $state  = $node->{state}  // 'unknown';

        # Filters
        next if (defined($self->{option_results}->{filter_name})   && $self->{option_results}->{filter_name}   ne '' && $name   !~ /$self->{option_results}->{filter_name}/);
        next if (defined($self->{option_results}->{filter_ring})   && $self->{option_results}->{filter_ring}   ne '' && $ring   !~ /$self->{option_results}->{filter_ring}/);
        next if (defined($self->{option_results}->{filter_server}) && $self->{option_results}->{filter_server} ne '' && $server !~ /$self->{option_results}->{filter_server}/);
        next if (defined($self->{option_results}->{filter_state})     && $self->{option_results}->{filter_state}     ne '' && $state     !~ /$self->{option_results}->{filter_state}/i);
        my $reachable = $node->{reachable} ? 'true' : 'false';
        next if (defined($self->{option_results}->{filter_reachable})  && $self->{option_results}->{filter_reachable}  ne '' && $reachable !~ /$self->{option_results}->{filter_reachable}/i);
        # Excludes
        next if (defined($self->{option_results}->{exclude_name})      && $self->{option_results}->{exclude_name}      ne '' && $name      =~ /$self->{option_results}->{exclude_name}/);
        next if (defined($self->{option_results}->{exclude_ring})      && $self->{option_results}->{exclude_ring}      ne '' && $ring      =~ /$self->{option_results}->{exclude_ring}/);
        next if (defined($self->{option_results}->{exclude_server})    && $self->{option_results}->{exclude_server}    ne '' && $server    =~ /$self->{option_results}->{exclude_server}/);
        next if (defined($self->{option_results}->{exclude_state})     && $self->{option_results}->{exclude_state}     ne '' && $state     =~ /$self->{option_results}->{exclude_state}/i);
        next if (defined($self->{option_results}->{exclude_reachable}) && $self->{option_results}->{exclude_reachable} ne '' && $reachable =~ /$self->{option_results}->{exclude_reachable}/i);

        $self->{nodes}->{$name} = {
            name      => $name,
            state     => $state,
            reachable => $reachable,
            ring      => $ring,
            server    => $server,
            nb_chunks => ($node->{nb_chunks} // 0) || 0,
        };
    }
    if (scalar(keys %{$self->{nodes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No storenodes found.");
        $self->{output}->option_exit();
    }
}
1;

__END__

=head1 MODE

Check Scality RING storenode status and metrics.

=over 8

=item B<--filter-name>

Filter storenodes by name (regexp).

=item B<--filter-ring>

Filter storenodes by ring name (regexp).

=item B<--filter-server>

Filter storenodes by server (regexp).

=item B<--filter-state>

Filter storenodes by state (regexp).

=item B<--filter-reachable>

Filter storenodes by reachable status (regexp, e.g. true, false).

=item B<--exclude-name>

Exclude storenodes by name (regexp).

=item B<--exclude-ring>

Exclude storenodes by ring (regexp).

=item B<--exclude-server>

Exclude storenodes by server (regexp).

=item B<--exclude-state>

Exclude storenodes by state (regexp).

=item B<--exclude-reachable>

Exclude storenodes by reachable status (regexp, e.g. false).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{reachable}, %{ring}, %{server}, %{name}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{state}, %{reachable}, %{ring}, %{server}, %{name}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{state} !~ /^RUN$/i || %{reachable} ne "true"').
You can use the following variables: %{state}, %{reachable}, %{ring}, %{server}, %{name}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'chunks'.

=back

=cut
