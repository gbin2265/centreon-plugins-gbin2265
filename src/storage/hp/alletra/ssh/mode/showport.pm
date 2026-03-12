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

package storage::hp::alletra::ssh::mode::showport;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf("state: '%s'", $self->{result_values}->{state});
}

sub port_long_output {
    my ($self, %options) = @_;

    return sprintf(
        "checking port '%s'",
        $options{instance_value}->{port_id}
    );
}

sub prefix_port_output {
    my ($self, %options) = @_;

    return sprintf(
        "port '%s' ",
        $options{instance_value}->{port_id}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'ports', type => 1, cb_prefix_output => 'prefix_port_output', cb_long_output => 'port_long_output', message_multiple => 'All ports are ok' }
    ];

    $self->{maps_counters}->{ports} = [
        {
            label => 'status',
            type => 2,
            warning_default => '%{state} =~ /loss_sync/i',
            critical_default => '%{state} !~ /ready|loss_sync/i',
            set => {
                key_values => [ { name => 'port_id' }, { name => 'state' } ],
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
        'filter-port-id:s'     => { name => 'filter_port_id' },
        'filter-node-id:s'     => { name => 'filter_node_id' },
        'filter-slot-id:s'     => { name => 'filter_slot_id' },
        'filter-port-mode:s'   => { name => 'filter_port_mode' },
        'filter-port-type:s'   => { name => 'filter_port_type' },
        'exclude-port-id:s'    => { name => 'exclude_port_id' },
        'exclude-slot-id:s'    => { name => 'exclude_slot_id' },
        'exclude-port-mode:s'  => { name => 'exclude_port_mode' },
        'exclude-port-type:s'  => { name => 'exclude_port_type' },
        'exclude-port-state:s' => { name => 'exclude_port_state' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($content) = $options{custom}->execute_command(commands => ['showport']);

    # Parse columns dynamically - we need: N:S:P (special), Mode, State
    # N:S:P is special format so we handle it separately
    
    # Remove CLI prompts
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total

    $self->{ports} = {};
    my $header_found = 0;
    my $state_col = 2;  # Default position for State column
    my $mode_col = 1;   # Default position for Mode column
    my $type_col = -1;  # Position for Type column (-1 = not found)
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/);
        next if ($line =~ /^\s*-+\s*$/);
        next if ($line =~ /\d+\s+total\s*$/i);
        
        # Detect header and find State, Mode, Type column positions
        if ($line =~ /^\s*N:S:P/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                if ($cols[$i] =~ /^-?State-?$/i) {
                    $state_col = $i;
                }
                if ($cols[$i] =~ /^-?Mode-?$/i) {
                    $mode_col = $i;
                }
                if ($cols[$i] =~ /^-?Type-?$/i) {
                    $type_col = $i;
                }
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', @cols);
            $self->{output}->output_add(long_msg => "DEBUG [showport]: Header found, columns: $col_list (State=$state_col, Mode=$mode_col, Type=$type_col)", debug => 1);
            
            next;
        }
        
        next if (!$header_found);

        # Parse: N:S:P Mode State ...
        if ($line =~ /^\s*(\d+):(\d+):(\d+)\s+(.*)/) {
            my ($node, $slot, $port, $rest) = ($1, $2, $3, $4);
            my $port_id = "$node:$slot:$port";
            
            my @parts = split(/\s+/, $rest);
            # State is at position (state_col - 1) because we already extracted N:S:P
            my $state = $parts[$state_col - 1] // 'unknown';
            # Mode is at position (mode_col - 1) because we already extracted N:S:P
            my $mode = $parts[$mode_col - 1] // 'unknown';
            # Type is at position (type_col - 1) if found
            my $type = ($type_col >= 0) ? ($parts[$type_col - 1] // 'unknown') : 'unknown';

            next if (defined($self->{option_results}->{filter_port_id}) && $self->{option_results}->{filter_port_id} ne '' &&
                $port_id !~ /$self->{option_results}->{filter_port_id}/);
            next if (defined($self->{option_results}->{filter_node_id}) && $self->{option_results}->{filter_node_id} ne '' &&
                $node !~ /$self->{option_results}->{filter_node_id}/);
            next if (defined($self->{option_results}->{filter_slot_id}) && $self->{option_results}->{filter_slot_id} ne '' &&
                $slot !~ /$self->{option_results}->{filter_slot_id}/);
            next if (defined($self->{option_results}->{filter_port_mode}) && $self->{option_results}->{filter_port_mode} ne '' &&
                $mode !~ /$self->{option_results}->{filter_port_mode}/i);
            next if (defined($self->{option_results}->{filter_port_type}) && $self->{option_results}->{filter_port_type} ne '' &&
                $type !~ /$self->{option_results}->{filter_port_type}/i);
            next if (defined($self->{option_results}->{exclude_port_id}) && $self->{option_results}->{exclude_port_id} ne '' &&
                $port_id =~ /$self->{option_results}->{exclude_port_id}/);
            next if (defined($self->{option_results}->{exclude_slot_id}) && $self->{option_results}->{exclude_slot_id} ne '' &&
                $slot =~ /$self->{option_results}->{exclude_slot_id}/);
            next if (defined($self->{option_results}->{exclude_port_mode}) && $self->{option_results}->{exclude_port_mode} ne '' &&
                $mode =~ /$self->{option_results}->{exclude_port_mode}/i);
            next if (defined($self->{option_results}->{exclude_port_type}) && $self->{option_results}->{exclude_port_type} ne '' &&
                $type =~ /$self->{option_results}->{exclude_port_type}/i);
            next if (defined($self->{option_results}->{exclude_port_state}) && $self->{option_results}->{exclude_port_state} ne '' &&
                $state =~ /$self->{option_results}->{exclude_port_state}/i);

            $self->{ports}->{$port_id} = {
                port_id => $port_id,
                node    => $node,
                slot    => $slot,
                port    => $port,
                state   => $state
            };
        }
    }

    if (scalar(keys %{$self->{ports}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No ports found.");
        $self->{output}->option_exit();
    }
}


1;

__END__

=head1 MODE

Check ports status.

=over 8

=item B<--filter-port-id>

Filter ports by ID (N:S:P format, can be a regexp).

=item B<--filter-node-id>

Filter ports by node ID (can be a regexp).

=item B<--filter-slot-id>

Filter ports by slot ID (can be a regexp).

=item B<--filter-port-mode>

Filter ports by Mode column (can be a regexp). Example: --filter-port-mode='target' to show only target ports.

=item B<--filter-port-type>

Filter ports by Type column (can be a regexp). Example: --filter-port-type='host' to show only host ports.

=item B<--exclude-port-id>

Exclude ports by ID (can be a regexp). Example: --exclude-port-id='0:1:.*' to exclude all ports on node 0 slot 1.

=item B<--exclude-slot-id>

Exclude ports by slot ID (can be a regexp). Example: --exclude-slot-id='2' to exclude all ports on slot 2.

=item B<--exclude-port-mode>

Exclude ports by Mode (can be a regexp). Example: --exclude-port-mode='initiator' to exclude initiator ports.

=item B<--exclude-port-type>

Exclude ports by Type (can be a regexp). Example: --exclude-port-type='rcfc' to exclude rcfc type ports.

=item B<--exclude-port-state>

Exclude ports with specific state (can be a regexp). Example: --exclude-port-state='offline|loss_sync' to exclude offline and loss_sync ports.

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{port_id}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{state} =~ /loss_sync/i').
You can use the following variables: %{state}, %{port_id}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{state} !~ /ready|loss_sync/i').
You can use the following variables: %{state}, %{port_id}

=back

=cut
