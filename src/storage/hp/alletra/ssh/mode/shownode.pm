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

package storage::hp::alletra::ssh::mode::shownode;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "online: '%s', in cluster: '%s'",
        $self->{result_values}->{online},
        $self->{result_values}->{in_cluster}
    );
}

sub node_long_output {
    my ($self, %options) = @_;

    return sprintf(
        "checking node '%s'",
        $options{instance_value}->{node_id}
    );
}

sub prefix_node_output {
    my ($self, %options) = @_;

    return sprintf(
        "node '%s' ",
        $options{instance_value}->{node_id}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'nodes', type => 1, cb_prefix_output => 'prefix_node_output', cb_long_output => 'node_long_output', message_multiple => 'All nodes are ok' }
    ];

    $self->{maps_counters}->{nodes} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{online} !~ /Yes/i || %{in_cluster} !~ /Yes/i',
            set => {
                key_values => [ { name => 'node_id' }, { name => 'online' }, { name => 'in_cluster' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-node-id:s' => { name => 'filter_node_id' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($content) = $options{custom}->execute_command(commands => ['shownode -verbose']);

    $self->{nodes} = {};
    $self->{global_status} = 0;

    # Remove CLI prompts
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;

    # Parse verbose output - look for Node ID, Online, and InCluster
    my @lines = split /\n/, $content;
    my ($current_node, $online, $in_cluster);

    foreach my $line (@lines) {
        # Skip empty lines and headers
        next if ($line =~ /^\s*$/);
        next if ($line =~ /^\*+/);
        next if ($line =~ /^-+/);
        
        if ($line =~ /Node\s+ID\s*:\s*(\d+)/i) {
            # Save previous node if exists
            if (defined($current_node) && defined($online) && defined($in_cluster)) {
                if (!defined($self->{option_results}->{filter_node_id}) || $self->{option_results}->{filter_node_id} eq '' ||
                    $current_node =~ /$self->{option_results}->{filter_node_id}/) {
                    $self->{nodes}->{'node' . $current_node} = {
                        node_id    => $current_node,
                        online     => $online,
                        in_cluster => $in_cluster
                    };
                }
            }
            $current_node = $1;
            $online = undef;
            $in_cluster = undef;
        }
        elsif ($line =~ /^\s*Online\s*:\s*(\S+)/i) {
            $online = $1;
        }
        elsif ($line =~ /^\s*In\s*Cluster\s*:\s*(\S+)/i) {
            $in_cluster = $1;
        }
    }

    # Save last node
    if (defined($current_node) && defined($online) && defined($in_cluster)) {
        if (!defined($self->{option_results}->{filter_node_id}) || $self->{option_results}->{filter_node_id} eq '' ||
            $current_node =~ /$self->{option_results}->{filter_node_id}/) {
            $self->{nodes}->{'node' . $current_node} = {
                node_id    => $current_node,
                online     => $online,
                in_cluster => $in_cluster
            };
        }
    }

    if (scalar(keys %{$self->{nodes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No nodes found.");
        $self->{output}->option_exit();
    }
}


1;

__END__

=head1 MODE

Check nodes status.

=over 8

=item B<--filter-node-id>

Filter nodes by ID (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{online}, %{in_cluster}, %{node_id}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{online}, %{in_cluster}, %{node_id}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{online} !~ /Yes/i || %{in_cluster} !~ /Yes/i').
You can use the following variables: %{online}, %{in_cluster}, %{node_id}

=back

=cut
