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

package hardware::ups::powerware::snmp::mode::inputsource;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf("input source is '%s'", $self->{result_values}->{source});
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
    ];

    $self->{maps_counters}->{global} = [
        { label => 'status', threshold => 0, set => {
                key_values => [
                    { name => 'source' },
                ],
                closure_custom_calc => \&catalog_status_calc,
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        { label => 'line-bads', nlabel => 'input.line.bads.count', set => {
                key_values => [ { name => 'line_bads', no_value => 0 } ],
                output_template => 'line bads: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ],
            }
        },
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'unknown-status:s'  => { name => 'unknown_status',  default => '' },
        'warning-status:s'  => { name => 'warning_status',  default => '%{source} =~ /^(?:none|other)$/i' },
        'critical-status:s' => { name => 'critical_status', default => '' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->change_macros(macros => ['warning_status', 'critical_status', 'unknown_status']);
}

my $map_input_source = {
    1 => 'other',
    2 => 'none',
    3 => 'primaryUtility',
    4 => 'bypassFeed',
    5 => 'secondaryUtility',
    6 => 'generator',
    7 => 'flywheel',
    8 => 'fuelcell',
};

my $mapping = {
    xupsInputSource    => { oid => '.1.3.6.1.4.1.534.1.3.5', map => $map_input_source },
    xupsInputLineBads  => { oid => '.1.3.6.1.4.1.534.1.3.2' },
};

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_leef(
        oids => [
            $mapping->{xupsInputSource}->{oid}   . '.0',
            $mapping->{xupsInputLineBads}->{oid}  . '.0',
        ],
        nothing_quit => 1
    );

    my $result = $options{snmp}->map_instance(mapping => $mapping, results => $snmp_result, instance => '0');

    $self->{global} = {
        source    => $result->{xupsInputSource}   // 'other',
        line_bads => $result->{xupsInputLineBads} // 0,
    };
}

1;

__END__

=head1 MODE

Check the current UPS input power source and count of out-of-tolerance
input events (XUPS-MIB).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='status'

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (default: '').
You can use the following variables: %{source}.

=item B<--warning-status>

Define the conditions to match for the status to be WARNING
(default: '%{source} =~ /^(?:none|other)$/i').
You can use the following variables: %{source}.

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '').
You can use the following variables: %{source}.

Possible source values: primaryUtility, secondaryUtility, bypassFeed,
generator, flywheel, fuelcell, none, other.

=item B<--warning-line-bads> B<--critical-line-bads>

Thresholds on the cumulative number of times the input was out of tolerance
in voltage or frequency.
Example: --warning-line-bads=10 --critical-line-bads=50

=back

=cut
