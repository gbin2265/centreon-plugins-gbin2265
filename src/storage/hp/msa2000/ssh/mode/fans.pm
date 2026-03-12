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

package storage::hp::msa2000::ssh::mode::fans;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf('status: %s [location: %s]', $self->{result_values}->{health}, $self->{result_values}->{location});
}

sub prefix_fan_output {
    my ($self, %options) = @_;

    return "Fan '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'fan', type => 1, cb_prefix_output => 'prefix_fan_output', message_multiple => 'All fans are ok' }
    ];

    $self->{maps_counters}->{fan} = [
        {
            label => 'status',
            type => 2,
            unknown_default => '%{health} =~ /unknown/i',
            warning_default => '',
            critical_default => '%{health} =~ /degraded|fault|failed|off|error/i',
            set => {
                key_values => [ { name => 'health' }, { name => 'display' }, { name => 'location' }, { name => 'reason' }, { name => 'recommendation' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'speed', nlabel => 'fan.speed.rpm', set => {
                key_values => [ { name => 'speed' }, { name => 'display' } ],
                output_template => 'speed: %s rpm',
                perfdatas => [
                    { template => '%s', unit => 'rpm', min => 0, label_extra_instance => 1, instance_use => 'display' }
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
        'filter-fan-name:s' => { name => 'filter_fan_name' },
        'exclude-fan-name:s' => { name => 'exclude_fan_name' }
    });

    return $self;
}

my $map_health = {
    0 => 'ok', 1 => 'degraded',
    2 => 'fault', 3 => 'unknown',
    4 => 'not available',
};

sub manage_selection {
    my ($self, %options) = @_;

    my ($result) = $options{custom}->get_infos(
        cmd => 'show fans',
        base_type => 'fan',
        properties_name => '^(?:durable-id|name|location|status|status-numeric|health|health-numeric|health-reason|health-recommendation|speed|extended-status|fw-revision|position)$'
    );

    $self->{fan} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $fan (@items) {
        my $name = defined($fan->{'durable-id'}) ? $fan->{'durable-id'} :
                   (defined($fan->{'name'}) ? $fan->{'name'} :
                   (defined($fan->{'location'}) ? $fan->{'location'} : 'unknown'));

        if (defined($self->{option_results}->{filter_fan_name}) && $self->{option_results}->{filter_fan_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_fan_name}/) {
            $self->{output}->output_add(long_msg => "skipping fan '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_fan_name}) && $self->{option_results}->{exclude_fan_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_fan_name}/) {
            $self->{output}->output_add(long_msg => "skipping fan '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $health = defined($fan->{'health-numeric'}) ?
            ($map_health->{ $fan->{'health-numeric'} } // 'unknown') :
            (defined($fan->{'health'}) ? lc($fan->{'health'}) :
            (defined($fan->{'status'}) ? lc($fan->{'status'}) : 'unknown'));

        my $speed = defined($fan->{'speed'}) ? $fan->{'speed'} : undef;
        if (defined($speed)) {
            $speed =~ s/[^\d]//g;
            $speed = undef if ($speed eq '');
        }

        $self->{fan}->{$name} = {
            display => $name,
            health => $health,
            location => defined($fan->{'location'}) ? $fan->{'location'} : '-',
            reason => defined($fan->{'health-reason'}) ? $fan->{'health-reason'} : '',
            recommendation => defined($fan->{'health-recommendation'}) ? $fan->{'health-recommendation'} : '',
            speed => $speed,
        };
    }

    if (scalar(keys %{$self->{fan}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No fan found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check fans health and speed.

=over 8

=item B<--filter-fan-name>

Filter fans by name (can be a regexp).

=item B<--exclude-fan-name>

Exclude fans by name (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{health} =~ /unknown/i').
You can use the following variables: %{health}, %{display}, %{location}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{health} =~ /degraded/i').
You can use the following variables: %{health}, %{display}, %{location}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{health} =~ /fault|failed|off|error/i').
You can use the following variables: %{health}, %{display}, %{location}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'speed' (rpm).

=back

=cut
