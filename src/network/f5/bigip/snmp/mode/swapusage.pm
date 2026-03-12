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

package network::f5::bigip::snmp::mode::swapusage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_usage_output {
    my ($self, %options) = @_;

    return sprintf(
        'swap usage: Total: %s Used: %s (%.2f%%) Free: %s (%.2f%%)',
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{total}),
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{used}),
        $self->{result_values}->{prct_used},
        $self->{perfdata}->change_bytes(value => $self->{result_values}->{free}),
        $self->{result_values}->{prct_free}
    );
}

sub custom_usage_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{total} = $options{new_datas}->{$self->{instance} . '_total'};
    $self->{result_values}->{used}  = $options{new_datas}->{$self->{instance} . '_used'};

    if ($self->{result_values}->{total} == 0) {
        $self->{error_msg} = 'no swap configured';
        return -10;
    }

    $self->{result_values}->{free}      = $self->{result_values}->{total} - $self->{result_values}->{used};
    $self->{result_values}->{prct_used} = $self->{result_values}->{used} * 100 / $self->{result_values}->{total};
    $self->{result_values}->{prct_free} = 100 - $self->{result_values}->{prct_used};

    return 0;
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'usage', nlabel => 'swap.usage.bytes', set => {
                key_values => [ { name => 'total' }, { name => 'used' } ],
                closure_custom_calc   => $self->can('custom_usage_calc'),
                closure_custom_output => $self->can('custom_usage_output'),
                threshold_use => 'prct_used',
                perfdatas => [
                    { value => 'used', template => '%s', min => 0, max => 'total',
                      unit => 'B', cast_int => 1 }
                ]
            }
        },
        { label => 'usage-percentage', display_ok => 0, nlabel => 'swap.usage.percentage', set => {
                key_values => [ { name => 'total' }, { name => 'used' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                output_template => 'used: %.2f%%',
                output_use => 'prct_used',
                threshold_use => 'prct_used',
                perfdatas => [
                    { value => 'prct_used', template => '%.2f', min => 0, max => 100, unit => '%' }
                ]
            }
        },
        { label => 'usage-free', display_ok => 0, nlabel => 'swap.free.bytes', set => {
                key_values => [ { name => 'total' }, { name => 'used' } ],
                closure_custom_calc => $self->can('custom_usage_calc'),
                output_template => 'free: %s %s',
                output_use => 'free',
                threshold_use => 'free',
                output_change_bytes => 1,
                perfdatas => [
                    { value => 'free', template => '%s', min => 0, max => 'total',
                      unit => 'B', cast_int => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # F5-BIGIP-SYSTEM-MIB: sysGlobalHostSwap (native, preferred)
    my $oid_sysGlobalHostSwapTotalKb = '.1.3.6.1.4.1.3375.2.1.1.2.20.50.0';
    my $oid_sysGlobalHostSwapUsedKb  = '.1.3.6.1.4.1.3375.2.1.1.2.20.51.0';

    # UCD-SNMP-MIB fallback
    my $oid_memTotalSwap = '.1.3.6.1.4.1.2021.4.3.0';
    my $oid_memAvailSwap = '.1.3.6.1.4.1.2021.4.4.0';

    my $result = $options{snmp}->get_leef(
        oids => [
            $oid_sysGlobalHostSwapTotalKb, $oid_sysGlobalHostSwapUsedKb,
            $oid_memTotalSwap, $oid_memAvailSwap
        ],
        nothing_quit => 1
    );

    my ($total, $used);

    # Prefer F5-native OIDs
    if (defined($result->{$oid_sysGlobalHostSwapTotalKb}) && $result->{$oid_sysGlobalHostSwapTotalKb} > 0) {
        $total = $result->{$oid_sysGlobalHostSwapTotalKb} * 1024;
        $used  = $result->{$oid_sysGlobalHostSwapUsedKb} * 1024;
    }
    # Fallback to UCD-SNMP
    elsif (defined($result->{$oid_memTotalSwap}) && $result->{$oid_memTotalSwap} > 0) {
        $total = $result->{$oid_memTotalSwap} * 1024;
        $used  = ($result->{$oid_memTotalSwap} - $result->{$oid_memAvailSwap}) * 1024;
    }
    else {
        $self->{output}->add_option_msg(short_msg => 'No swap information found.');
        $self->{output}->option_exit();
    }

    $self->{global} = {
        total => $total,
        used  => $used
    };
}

1;

__END__

=head1 MODE

Check swap usage on F5 BIG-IP devices.

Uses F5-native sysGlobalHostSwapTotal/Used OIDs (F5-BIGIP-SYSTEM-MIB) when available,
falls back to standard UCD-SNMP-MIB memTotalSwap/memAvailSwap.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).

=item B<--warning-usage>

Warning threshold for swap usage (in bytes).

=item B<--critical-usage>

Critical threshold for swap usage (in bytes).

=item B<--warning-usage-percentage>

Warning threshold for swap usage (in percent).

=item B<--critical-usage-percentage>

Critical threshold for swap usage (in percent).

=item B<--warning-usage-free>

Warning threshold for free swap (in bytes).

=item B<--critical-usage-free>

Critical threshold for free swap (in bytes).

=back

=cut
