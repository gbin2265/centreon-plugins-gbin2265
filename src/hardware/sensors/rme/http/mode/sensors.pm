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

package hardware::sensors::rme::http::mode::sensors;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'warning-temp:s'      => { name => 'warning_temp' },
        'critical-temp:s'     => { name => 'critical_temp' },
        'warning-humidity:s'  => { name => 'warning_humidity' },
        'critical-humidity:s' => { name => 'critical_humidity' },
        'filter-channel:s'    => { name => 'filter_channel' },
        'exclude-channel:s'   => { name => 'exclude_channel' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);

    if (($self->{perfdata}->threshold_validate(label => 'warning-temp', value => $self->{option_results}->{warning_temp})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning-temp threshold '" . $self->{option_results}->{warning_temp} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical-temp', value => $self->{option_results}->{critical_temp})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical-temp threshold '" . $self->{option_results}->{critical_temp} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'warning-humidity', value => $self->{option_results}->{warning_humidity})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong warning-humidity threshold '" . $self->{option_results}->{warning_humidity} . "'.");
        $self->{output}->option_exit();
    }
    if (($self->{perfdata}->threshold_validate(label => 'critical-humidity', value => $self->{option_results}->{critical_humidity})) == 0) {
        $self->{output}->add_option_msg(short_msg => "Wrong critical-humidity threshold '" . $self->{option_results}->{critical_humidity} . "'.");
        $self->{output}->option_exit();
    }
}

sub run {
    my ($self, %options) = @_;

    my $data = $options{custom}->request_api(endpoint => '/prtg');

    if (!defined($data->{prtg}->{result})) {
        $self->{output}->add_option_msg(short_msg => "Cannot find 'prtg.result' in API response.");
        $self->{output}->option_exit();
    }

    my $temp             = undef;
    my $temp_channel     = 'Temperature';
    my $humidity         = undef;
    my $humidity_channel = 'Humidity';

    foreach my $channel (@{$data->{prtg}->{result}}) {
        my $channel_name = $channel->{channel};

        # Apply --filter-channel: skip if name does not match the filter
        if (defined($self->{option_results}->{filter_channel}) && $self->{option_results}->{filter_channel} ne '') {
            next if ($channel_name !~ /$self->{option_results}->{filter_channel}/i);
        }

        # Apply --exclude-channel: skip if name matches the exclude pattern
        if (defined($self->{option_results}->{exclude_channel}) && $self->{option_results}->{exclude_channel} ne '') {
            next if ($channel_name =~ /$self->{option_results}->{exclude_channel}/i);
        }

        my $value = $channel->{value};
        $value =~ s/^\s+|\s+$//g;  # trim whitespace

        if ($channel_name =~ /temp/i) {
            $temp         = $value;
            $temp_channel = $channel_name;
        } elsif ($channel_name =~ /humid/i) {
            $humidity         = $value;
            $humidity_channel = $channel_name;
        }
    }

    # --- Temperature ---
    if (defined($temp)) {
        my $exit_temp = $self->{perfdata}->threshold_check(
            value     => $temp,
            threshold => [
                { label => 'critical-temp', exit_litteral => 'critical' },
                { label => 'warning-temp',  exit_litteral => 'warning' }
            ]
        );
        $self->{output}->output_add(
            severity  => $exit_temp,
            short_msg => sprintf("%s: %.1f Celsius", $temp_channel, $temp)
        );
        $self->{output}->perfdata_add(
            label    => 'temperature',
            unit     => 'C',
            value    => $temp,
            warning  => $self->{perfdata}->get_perfdata_for_output(label => 'warning-temp'),
            critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-temp')
        );
    } else {
        $self->{output}->output_add(severity => 'UNKNOWN', short_msg => "Temperature channel not found in API response.");
    }

    # --- Humidity ---
    if (defined($humidity)) {
        my $exit_hum = $self->{perfdata}->threshold_check(
            value     => $humidity,
            threshold => [
                { label => 'critical-humidity', exit_litteral => 'critical' },
                { label => 'warning-humidity',  exit_litteral => 'warning' }
            ]
        );
        $self->{output}->output_add(
            severity  => $exit_hum,
            short_msg => sprintf("%s: %.1f %%RH", $humidity_channel, $humidity)
        );
        $self->{output}->perfdata_add(
            label    => 'humidity',
            unit     => '%',
            value    => $humidity,
            warning  => $self->{perfdata}->get_perfdata_for_output(label => 'warning-humidity'),
            critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-humidity'),
            min      => 0,
            max      => 100
        );
    } else {
        $self->{output}->output_add(severity => 'UNKNOWN', short_msg => "Humidity channel not found in API response.");
    }

    $self->{output}->display();
    $self->{output}->exit();
}

1;

__END__

=head1 MODE

Check temperature and humidity from RME sensor device via HTTP JSON API.

=over 8

=item B<--warning-temp>

Warning threshold for temperature (in Celsius).

=item B<--critical-temp>

Critical threshold for temperature (in Celsius).

=item B<--warning-humidity>

Warning threshold for humidity (in %RH).

=item B<--critical-humidity>

Critical threshold for humidity (in %RH).

=item B<--filter-channel>

Only check channels whose name matches this regex (case-insensitive).
Example: --filter-channel="sensor1"

=item B<--exclude-channel>

Skip channels whose name matches this regex (case-insensitive).
Example: --exclude-channel="sensor2"

=back

=cut
