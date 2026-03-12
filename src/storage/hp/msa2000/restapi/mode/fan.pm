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

package storage::hp::msa2000::restapi::mode::fan;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [state: %s]",
        $self->{result_values}->{health},
        $self->{result_values}->{state}
    );
}

sub prefix_fan_output {
    my ($self, %options) = @_;

    return sprintf(
        "Fan '%s' [Enclosure: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{enclosure}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'fans', type => 1, cb_prefix_output => 'prefix_fan_output', message_multiple => 'All fans are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'fans-total', nlabel => 'fans.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total fans: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{fans} = [
        {
            label => 'fan-status',
            type => 2,
            warning_default => '%{health} =~ /degraded/i',
            critical_default => '%{health} =~ /fault|failed/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' },
                    { name => 'enclosure' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'fan-speed', nlabel => 'fan.speed.rpm', set => {
                key_values => [ { name => 'speed' }, { name => 'name' } ],
                output_template => 'speed: %s RPM',
                perfdatas => [
                    { template => '%s', unit => 'rpm', min => 0, label_extra_instance => 1, instance_use => 'name' }
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
        'filter-fan-id:s'     => { name => 'filter_fan_id' },
        'filter-enclosure:s'  => { name => 'filter_enclosure' },
        'filter-fan-name:s' => { name => 'filter_fan_name' },
        'exclude-enclosure:s' => { name => 'exclude_enclosure' },
        'exclude-fan-id:s' => { name => 'exclude_fan_id' },
        'exclude-fan-name:s' => { name => 'exclude_fan_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0 };
    $self->{fans} = {};

    my $chassis_result = $options{custom}->request_api(url_path => '/redfish/v1/Chassis');
    return if (!defined($chassis_result) || !defined($chassis_result->{Members}));

    foreach my $chassis (@{$chassis_result->{Members}}) {
        next if (!defined($chassis->{'@odata.id'}));
        
        my $chassis_data = $options{custom}->request_api(
            url_path => $chassis->{'@odata.id'},
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($chassis_data));

        my $enclosure_id = defined($chassis_data->{Id}) ? $chassis_data->{Id} : 'unknown';
        
        if (defined($self->{option_results}->{filter_enclosure}) && $self->{option_results}->{filter_enclosure} ne '' &&
            $enclosure_id !~ /$self->{option_results}->{filter_enclosure}/) {
            next;
        }

        
        if (defined($self->{option_results}->{exclude_enclosure}) && $self->{option_results}->{exclude_enclosure} ne '' &&
            $enclosure_id =~ /$self->{option_results}->{exclude_enclosure}/) {
            next;
        }

        next if (!defined($chassis_data->{ThermalSubsystem}) && !defined($chassis_data->{Thermal}));

        my $thermal_url = defined($chassis_data->{ThermalSubsystem}) 
            ? $chassis_data->{ThermalSubsystem}->{'@odata.id'} 
            : $chassis_data->{Thermal}->{'@odata.id'};
        next if (!defined($thermal_url));

        # MSA may return invalid URLs like "UNKNOWN/enclosure_1/Thermal"
        # Build correct path from chassis ID if URL doesn't start with /redfish
        if ($thermal_url !~ /^\/redfish/) {
            my $chassis_id = defined($chassis_data->{Id}) ? $chassis_data->{Id} : '';
            if ($chassis_id ne '') {
                $thermal_url = '/redfish/v1/Chassis/' . $chassis_id . '/Thermal';
            } else {
                next;
            }
        }

        my $thermal_data = $options{custom}->request_api(
            url_path => $thermal_url,
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($thermal_data));

        my @fans;
        if (defined($thermal_data->{Fans}) && ref($thermal_data->{Fans}) eq 'ARRAY') {
            @fans = @{$thermal_data->{Fans}};
        } elsif (defined($thermal_data->{Fans}) && defined($thermal_data->{Fans}->{'@odata.id'})) {
            my $fans_collection = $options{custom}->request_api(
                url_path => $thermal_data->{Fans}->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            if (defined($fans_collection) && defined($fans_collection->{Members})) {
                foreach my $fan_ref (@{$fans_collection->{Members}}) {
                    next if (!defined($fan_ref->{'@odata.id'}));
                    my $fan_data = $options{custom}->request_api(
                        url_path => $fan_ref->{'@odata.id'},
                        ignore_codes => { 404 => 1 }
                    );
                    push @fans, $fan_data if (defined($fan_data));
                }
            }
        }

        foreach my $fan (@fans) {
            my $fan_id = defined($fan->{MemberId}) ? $fan->{MemberId} : 
                (defined($fan->{Id}) ? $fan->{Id} : 'unknown');

            if (defined($self->{option_results}->{filter_fan_id}) && $self->{option_results}->{filter_fan_id} ne '' &&
                $fan_id !~ /$self->{option_results}->{filter_fan_id}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_fan_id}) && $self->{option_results}->{exclude_fan_id} ne '' &&
                $fan_id =~ /$self->{option_results}->{exclude_fan_id}/) {
                next;
            }

            my $fan_name = defined($fan->{Name}) ? $fan->{Name} : $fan_id;

            if (defined($self->{option_results}->{filter_fan_name}) && $self->{option_results}->{filter_fan_name} ne '' &&
                $fan_name !~ /$self->{option_results}->{filter_fan_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_fan_name}) && $self->{option_results}->{exclude_fan_name} ne '' &&
                $fan_name =~ /$self->{option_results}->{exclude_fan_name}/) {
                next;
            }

            my $health = defined($fan->{Status}) && defined($fan->{Status}->{Health})
                ? $fan->{Status}->{Health} : 'n/a';
            my $state = defined($fan->{Status}) && defined($fan->{Status}->{State})
                ? $fan->{Status}->{State} : 'n/a';
            next if ($state =~ /^Absent$/i);


            my $speed = defined($fan->{Reading}) ? $fan->{Reading} : 
                (defined($fan->{SpeedRPM}) ? $fan->{SpeedRPM} : undef);

            my $fan_full_id = $enclosure_id . '_' . $fan_id;

            $self->{fans}->{$fan_full_id} = {
                name      => $fan_name,
                enclosure => $enclosure_id,
                health    => $health,
                state     => $state,
                speed     => $speed,
            };
            
            $self->{global}->{total}++;
        }
    }

    if (scalar(keys %{$self->{fans}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No fans found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA fans status via Redfish API.

=over 8

=item B<--filter-enclosure>

Filter by enclosure (can be a regexp).

=item B<--filter-fan-id>

Filter by fan id (can be a regexp).

=item B<--filter-fan-name>

Filter by fan name (can be a regexp).

=item B<--exclude-enclosure>

Exclude by enclosure (can be a regexp).

=item B<--exclude-fan-id>

Exclude by fan id (can be a regexp).

=item B<--exclude-fan-name>

Exclude by fan name (can be a regexp).

=item B<--warning-fan-status> B<--critical-fan-status>

Set warning/critical threshold for fan status.
Default warning: '%{health} =~ /degraded/i'
Default critical: '%{health} =~ /fault|failed/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'fan-speed', 'fans-total'.

=back

=cut
