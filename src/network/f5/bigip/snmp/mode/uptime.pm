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

package network::f5::bigip::snmp::mode::uptime;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use POSIX;
use centreon::plugins::misc;

my $unitdiv = { s => 1, w => 604800, d => 86400, h => 3600, m => 60 };
my $unitdiv_long = { s => 'seconds', w => 'weeks', d => 'days', h => 'hours', m => 'minutes' };

sub custom_uptime_output {
    my ($self, %options) = @_;

    return sprintf(
        'system uptime is: %s',
        centreon::plugins::misc::change_seconds(value => $self->{result_values}->{uptime}, start => 'd')
    );
}

sub custom_uptime_perfdata {
    my ($self, %options) = @_;

    $self->{output}->perfdata_add(
        nlabel   => 'system.uptime.' . $unitdiv_long->{ $self->{instance_mode}->{option_results}->{unit} },
        unit     => $self->{instance_mode}->{option_results}->{unit},
        value    => sprintf('%.2f', $self->{result_values}->{uptime} / $unitdiv->{ $self->{instance_mode}->{option_results}->{unit} }),
        warning  => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel}),
        min      => 0
    );
}

sub custom_uptime_threshold {
    my ($self, %options) = @_;

    return $self->{perfdata}->threshold_check(
        value     => $self->{result_values}->{uptime} / $unitdiv->{ $self->{instance_mode}->{option_results}->{unit} },
        threshold => [
            { label => 'critical-' . $self->{thlabel}, exit_litteral => 'critical' },
            { label => 'warning-'  . $self->{thlabel}, exit_litteral => 'warning' }
        ]
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'uptime', nlabel => 'system.uptime.seconds', set => {
                key_values => [ { name => 'uptime' } ],
                closure_custom_output         => $self->can('custom_uptime_output'),
                closure_custom_perfdata       => $self->can('custom_uptime_perfdata'),
                closure_custom_threshold_check => $self->can('custom_uptime_threshold')
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'unit:s' => { name => 'unit', default => 's' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    if ($self->{option_results}->{unit} eq '' || !defined($unitdiv->{$self->{option_results}->{unit}})) {
        $self->{option_results}->{unit} = 's';
    }
}

sub manage_selection {
    my ($self, %options) = @_;

    # F5-BIGIP-SYSTEM-MIB: sysSystemUptimeInSec (seconds, no 32-bit wrap issue)
    my $oid_sysSystemUptimeInSec = '.1.3.6.1.4.1.3375.2.1.6.7.0';
    # Standard SNMP fallbacks
    my $oid_hrSystemUptime = '.1.3.6.1.2.1.25.1.1.0';  # centiseconds
    my $oid_sysUpTime      = '.1.3.6.1.2.1.1.3.0';      # timeticks (centiseconds)

    my $result = $options{snmp}->get_leef(
        oids         => [ $oid_sysSystemUptimeInSec, $oid_hrSystemUptime, $oid_sysUpTime ],
        nothing_quit => 1
    );

    my $uptime;

    # Prefer F5-native (already in seconds, no 32-bit timetick wrap at 497 days)
    if (defined($result->{$oid_sysSystemUptimeInSec}) && $result->{$oid_sysSystemUptimeInSec} > 0) {
        $uptime = $result->{$oid_sysSystemUptimeInSec};
    }
    # Fallback: hrSystemUptime (centiseconds, 32-bit but wraps later)
    elsif (defined($result->{$oid_hrSystemUptime}) && $result->{$oid_hrSystemUptime} > 0) {
        $uptime = floor($result->{$oid_hrSystemUptime} / 100);
    }
    # Last resort: sysUpTime (timeticks centiseconds)
    elsif (defined($result->{$oid_sysUpTime})) {
        $uptime = floor($result->{$oid_sysUpTime} / 100);
    }
    else {
        $self->{output}->add_option_msg(short_msg => 'No uptime information found.');
        $self->{output}->option_exit();
    }

    $self->{global} = {
        uptime => $uptime
    };
}

1;

__END__

=head1 MODE

Check system uptime on F5 BIG-IP devices.

Uses F5-native sysSystemUptimeInSec (F5-BIGIP-SYSTEM-MIB) which reports uptime in
seconds and does not suffer from the 32-bit timetick rollover at ~497 days that
affects standard SNMP sysUpTime. Falls back to hrSystemUptime or sysUpTime if the
F5-native OID is unavailable.

=over 8

=item B<--unit>

Select the time unit for thresholds and perfdata. Can be: 's' (seconds),
'm' (minutes), 'h' (hours), 'd' (days), 'w' (weeks). Default: 's'.

=item B<--warning-uptime>

Warning threshold for uptime.

=item B<--critical-uptime>

Critical threshold for uptime.

=back

=cut
