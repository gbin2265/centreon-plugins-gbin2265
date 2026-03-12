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

package network::brocade::restapi::mode::diagnostics;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_test_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "state: %s, result: %s, mode: %s",
        $self->{result_values}->{state},
        $self->{result_values}->{result},
        $self->{result_values}->{mode}
    );
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Diagnostics: ';
}

sub prefix_port_output {
    my ($self, %options) = @_;

    return "Port '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'ports', type => 1, cb_prefix_output => 'prefix_port_output', message_multiple => 'All diagnostic tests are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'tests-total', nlabel => 'diagnostics.tests.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total tests: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'tests-passed', nlabel => 'diagnostics.tests.passed.count', set => {
                key_values => [ { name => 'passed' } ],
                output_template => 'passed: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'tests-failed', nlabel => 'diagnostics.tests.failed.count', set => {
                key_values => [ { name => 'failed' } ],
                output_template => 'failed: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'tests-in-progress', nlabel => 'diagnostics.tests.inprogress.count', set => {
                key_values => [ { name => 'in_progress' } ],
                output_template => 'in progress: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{ports} = [
        {
            label => 'test-status',
            type => 2,
            critical_default => '%{result} =~ /failed/i',
            set => {
                key_values => [
                    { name => 'state' }, { name => 'result' },
                    { name => 'mode' }, { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_test_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'estimated-distance', nlabel => 'port.distance.estimated.meters', set => {
                key_values => [ { name => 'distance' }, { name => 'display' } ],
                output_template => 'estimated distance: %s m',
                perfdatas => [
                    { template => '%s', unit => 'm', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'round-trip-time', nlabel => 'port.roundtrip.time.microseconds', set => {
                key_values => [ { name => 'round_trip' }, { name => 'display' } ],
                output_template => 'round-trip time: %s µs',
                perfdatas => [
                    { template => '%s', unit => 'us', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'buffers-required', nlabel => 'port.buffers.required.count', set => {
                key_values => [ { name => 'buffers_required' }, { name => 'display' } ],
                output_template => 'buffers required: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
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
        'filter-port-name:s' => { name => 'filter_port_name' },
        'filter-state:s'     => { name => 'filter_state' },
        'exclude-port-name:s' => { name => 'exclude_port_name' },
        'exclude-state:s'     => { name => 'exclude_state' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $diag_data = $options{custom}->get_diagnostics();

    $self->{global} = { total => 0, passed => 0, failed => 0, in_progress => 0 };
    $self->{ports} = {};

    my $diag_list = $diag_data->{'Response'}->{'fibrechannel-diagnostics'} // 
                    $diag_data->{'brocade-fibrechannel-diagnostics'}->{'fibrechannel-diagnostics'} // [];
    $diag_list = [$diag_list] if (ref($diag_list) ne 'ARRAY');

    foreach my $diag (@{$diag_list}) {
        my $port_name = $diag->{'name'} // next;
        my $state = $diag->{'state'} // $diag->{'diagnostic-state'} // 'unknown';
        my $result = $diag->{'result'} // $diag->{'test-result'} // 'unknown';
        my $mode = $diag->{'mode'} // $diag->{'diagnostic-mode'} // 'unknown';

        # Apply filters
        if (defined($self->{option_results}->{filter_port_name}) && $self->{option_results}->{filter_port_name} ne '' &&
            $port_name !~ /$self->{option_results}->{filter_port_name}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_state}) && $self->{option_results}->{filter_state} ne '' &&
            $state !~ /$self->{option_results}->{filter_state}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_port_name}) && $self->{option_results}->{exclude_port_name} ne '' &&
            $port_name =~ /$self->{option_results}->{exclude_port_name}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' &&
            $state =~ /$self->{option_results}->{exclude_state}/) {
            next;
        }

        $self->{global}->{total}++;
        
        if ($result =~ /passed|success/i) {
            $self->{global}->{passed}++;
        } elsif ($result =~ /failed|error/i) {
            $self->{global}->{failed}++;
        } elsif ($state =~ /progress|running/i) {
            $self->{global}->{in_progress}++;
        }

        # Get diagnostic metrics
        my $distance = $diag->{'estimated-distance'} // $diag->{'end-to-end-distance'} // undef;
        my $round_trip = $diag->{'round-trip-time'} // $diag->{'rtt'} // undef;
        my $buffers = $diag->{'buffers-required'} // undef;

        $self->{ports}->{$port_name} = {
            display => $port_name,
            state => lc($state),
            result => lc($result),
            mode => lc($mode),
            distance => $distance,
            round_trip => $round_trip,
            buffers_required => $buffers
        };
    }

    if (scalar(keys %{$self->{ports}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No diagnostic tests found (D-port tests not running or not supported).");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check D-port diagnostic test results.

=over 8

=item B<--filter-port-name>

Filter ports by name (can be a regexp).

=item B<--filter-state>

Filter tests by state (can be a regexp).

=item B<--exclude-port-name>

Exclude ports by name (can be a regexp).

=item B<--exclude-state>

Exclude tests by state (can be a regexp).

=item B<--unknown-test-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{result}, %{mode}, %{display}

=item B<--warning-test-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{state}, %{result}, %{mode}, %{display}

=item B<--critical-test-status>

Define the conditions to match for the status to be CRITICAL (default: '%{result} =~ /failed/i').
You can use the following variables: %{state}, %{result}, %{mode}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'tests-total', 'tests-passed', 'tests-failed', 'tests-in-progress',
'estimated-distance', 'round-trip-time', 'buffers-required'.

=back

=cut
