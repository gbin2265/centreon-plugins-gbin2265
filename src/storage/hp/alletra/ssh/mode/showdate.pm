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

package storage::hp::alletra::ssh::mode::showdate;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use POSIX qw(mktime);

sub custom_drift_output {
    my ($self, %options) = @_;

    return sprintf(
        "date: '%s', drift: %ds from reference",
        $self->{result_values}->{date},
        $self->{result_values}->{drift}
    );
}

sub node_long_output {
    my ($self, %options) = @_;

    return sprintf(
        "checking node '%s' date",
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
        { name => 'global', type => 0 },
        { name => 'nodes', type => 1, cb_prefix_output => 'prefix_node_output', cb_long_output => 'node_long_output', message_multiple => 'All node dates are synchronized' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'drift-count', nlabel => 'nodes.date.drift.detected.count', set => {
                key_values => [ { name => 'drift_count' } ],
                output_template => 'date drift detected on %d node(s)',
                perfdatas => [
                    { template => '%d', min => 0 }
                ]
            }
        },
        { label => 'max-drift', nlabel => 'nodes.date.drift.max.seconds', set => {
                key_values => [ { name => 'max_drift' } ],
                output_template => 'max drift: %ds',
                perfdatas => [
                    { template => '%d', unit => 's', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{nodes} = [
        {
            label => 'node-drift',
            nlabel => 'node.date.drift.seconds',
            set => {
                key_values => [ { name => 'node_id' }, { name => 'date' }, { name => 'drift' } ],
                closure_custom_output => $self->can('custom_drift_output'),
                perfdatas => [
                    { template => '%d', unit => 's', min => 0, label_extra_instance => 1, instance_use => 'node_id' }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-node-id:s'      => { name => 'filter_node_id' },
        'warning-node-drift:s'  => { name => 'warning_node_drift', default => '10' },
        'critical-node-drift:s' => { name => 'critical_node_drift', default => '60' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    # Parse drift thresholds
    $self->{warning_drift} = $self->{option_results}->{warning_node_drift};
    $self->{critical_drift} = $self->{option_results}->{critical_node_drift};

    # Validate thresholds are numeric
    if ($self->{warning_drift} !~ /^\d+$/) {
        $self->{output}->add_option_msg(short_msg => "Invalid --warning-node-drift value: must be a number (seconds).");
        $self->{output}->option_exit();
    }
    if ($self->{critical_drift} !~ /^\d+$/) {
        $self->{output}->add_option_msg(short_msg => "Invalid --critical-node-drift value: must be a number (seconds).");
        $self->{output}->option_exit();
    }
}

# Parse datetime string to epoch seconds
# Supports formats: "2025-02-06 14:30:05" and "02/06/2025 14:30:05"
sub _parse_datetime {
    my ($self, %options) = @_;

    my $datetime = $options{datetime};
    my ($year, $mon, $day, $hour, $min, $sec);

    # Format: YYYY-MM-DD HH:MM:SS
    if ($datetime =~ /(\d{4})-(\d{2})-(\d{2})\s+(\d{2}):(\d{2}):(\d{2})/) {
        ($year, $mon, $day, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
    }
    # Format: MM/DD/YYYY HH:MM:SS
    elsif ($datetime =~ /(\d{2})\/(\d{2})\/(\d{4})\s+(\d{2}):(\d{2}):(\d{2})/) {
        ($mon, $day, $year, $hour, $min, $sec) = ($1, $2, $3, $4, $5, $6);
    }
    else {
        $self->{output}->output_add(long_msg => "DEBUG [showdate]: Could not parse datetime: '$datetime'", debug => 1);
        return undef;
    }

    my $epoch = mktime($sec, $min, $hour, $day, $mon - 1, $year - 1900);
    return $epoch;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($content) = $options{custom}->execute_command(commands => ['showdate']);

    # Remove CLI prompts
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;

    $self->{nodes} = {};
    $self->{global} = { drift_count => 0, max_drift => 0 };

    my @node_data;
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*Node\s+Date/i);
        next if ($line =~ /^\s*-+/);
        next if ($line =~ /^\s*$/);

        # Parse: Node Date Time [Zone]
        if ($line =~ /^\s*(\d+)\s+(\S+)\s+(\S+)/) {
            my ($node_id, $date, $time) = ($1, $2, $3);

            next if (defined($self->{option_results}->{filter_node_id}) && $self->{option_results}->{filter_node_id} ne '' &&
                $node_id !~ /$self->{option_results}->{filter_node_id}/);

            my $datetime = "$date $time";
            my $epoch = $self->_parse_datetime(datetime => $datetime);

            push @node_data, {
                node_id  => $node_id,
                datetime => $datetime,
                epoch    => $epoch
            };
        }
    }

    if (scalar(@node_data) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No node dates found.");
        $self->{output}->option_exit();
    }

    # Find the reference time: the most common epoch across all nodes
    my %epoch_count;
    foreach my $nd (@node_data) {
        next if (!defined($nd->{epoch}));
        $epoch_count{$nd->{epoch}}++;
    }

    # Reference = most common epoch (if tied, use the earliest)
    my $ref_epoch;
    if (scalar(keys %epoch_count) > 0) {
        $ref_epoch = (sort { $epoch_count{$b} <=> $epoch_count{$a} || $a <=> $b } keys %epoch_count)[0];
    }

    $self->{output}->output_add(
        long_msg => sprintf("DEBUG [showdate]: Reference epoch: %s (%d nodes found)", 
            defined($ref_epoch) ? $ref_epoch : 'undef', scalar(@node_data)),
        debug => 1
    );

    # Calculate drift per node
    foreach my $nd (@node_data) {
        my $drift = 0;

        if (defined($nd->{epoch}) && defined($ref_epoch)) {
            $drift = abs($nd->{epoch} - $ref_epoch);
        }

        # Track max drift
        if ($drift > $self->{global}->{max_drift}) {
            $self->{global}->{max_drift} = $drift;
        }

        # Count drifted nodes (using warning threshold as minimum)
        if ($drift >= $self->{warning_drift}) {
            $self->{global}->{drift_count}++;
        }

        $self->{nodes}->{'node' . $nd->{node_id}} = {
            node_id => $nd->{node_id},
            date    => $nd->{datetime},
            drift   => $drift
        };
    }

    # Apply severity based on max drift across all nodes
    if ($self->{global}->{max_drift} >= $self->{critical_drift}) {
        $self->{output}->output_add(
            severity => 'critical',
            short_msg => sprintf("Max date drift is %ds (critical threshold: %ds)",
                $self->{global}->{max_drift}, $self->{critical_drift})
        );
    } elsif ($self->{global}->{max_drift} >= $self->{warning_drift}) {
        $self->{output}->output_add(
            severity => 'warning',
            short_msg => sprintf("Max date drift is %ds (warning threshold: %ds)",
                $self->{global}->{max_drift}, $self->{warning_drift})
        );
    }
}


1;

__END__

=head1 MODE

Check node date synchronization.

Compares the date/time of all nodes and detects clock drift.
The reference time is the most common time across all nodes.
Drift is calculated in seconds per node.

=over 8

=item B<--filter-node-id>

Filter nodes by ID (can be a regexp).

=item B<--warning-node-drift>

Warning threshold in seconds for date drift between nodes (default: 10).
If any node differs more than this many seconds from the reference, a WARNING is raised.

=item B<--critical-node-drift>

Critical threshold in seconds for date drift between nodes (default: 60).
If any node differs more than this many seconds from the reference, a CRITICAL is raised.

=item B<--warning-drift-count>

Warning threshold for number of drifted nodes.

=item B<--critical-drift-count>

Critical threshold for number of drifted nodes.

=item B<--warning-max-drift>

Warning threshold for max drift in seconds (overrides --warning-node-drift for perfdata).

=item B<--critical-max-drift>

Critical threshold for max drift in seconds (overrides --critical-node-drift for perfdata).

=back

=cut
