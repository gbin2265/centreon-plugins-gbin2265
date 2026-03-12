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

package storage::hp::msa2000::restapi::mode::psu;

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

sub prefix_psu_output {
    my ($self, %options) = @_;

    return sprintf(
        "PSU '%s' [Enclosure: %s] ",
        $options{instance_value}->{name},
        $options{instance_value}->{enclosure}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'psus', type => 1, cb_prefix_output => 'prefix_psu_output', message_multiple => 'All power supplies are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'psus-total', nlabel => 'power_supplies.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total power supplies: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{psus} = [
        {
            label => 'psu-status',
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
        { label => 'psu-power', nlabel => 'psu.power.watt', set => {
                key_values => [ { name => 'power' }, { name => 'name' } ],
                output_template => 'power: %s W',
                perfdatas => [
                    { template => '%s', unit => 'W', min => 0, label_extra_instance => 1, instance_use => 'name' }
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
        'filter-psu-id:s'    => { name => 'filter_psu_id' },
        'filter-enclosure:s' => { name => 'filter_enclosure' },
        'filter-psu-name:s' => { name => 'filter_psu_name' },
        'exclude-enclosure:s' => { name => 'exclude_enclosure' },
        'exclude-psu-id:s' => { name => 'exclude_psu_id' },
        'exclude-psu-name:s' => { name => 'exclude_psu_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0 };
    $self->{psus} = {};

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

        next if (!defined($chassis_data->{PowerSubsystem}) && !defined($chassis_data->{Power}));

        my $power_url = defined($chassis_data->{PowerSubsystem}) 
            ? $chassis_data->{PowerSubsystem}->{'@odata.id'} 
            : $chassis_data->{Power}->{'@odata.id'};
        next if (!defined($power_url));

        # MSA may return invalid URLs like "UNKNOWN/enclosure_1/Power"
        # Build correct path from chassis ID if URL doesn't start with /redfish
        if ($power_url !~ /^\/redfish/) {
            my $chassis_id = defined($chassis_data->{Id}) ? $chassis_data->{Id} : '';
            if ($chassis_id ne '') {
                $power_url = '/redfish/v1/Chassis/' . $chassis_id . '/Power';
            } else {
                next;
            }
        }

        my $power_data = $options{custom}->request_api(
            url_path => $power_url,
            ignore_codes => { 404 => 1 }
        );
        next if (!defined($power_data));

        my @psus;
        if (defined($power_data->{PowerSupplies}) && ref($power_data->{PowerSupplies}) eq 'ARRAY') {
            @psus = @{$power_data->{PowerSupplies}};
        } elsif (defined($power_data->{PowerSupplies}) && defined($power_data->{PowerSupplies}->{'@odata.id'})) {
            my $psus_collection = $options{custom}->request_api(
                url_path => $power_data->{PowerSupplies}->{'@odata.id'},
                ignore_codes => { 404 => 1 }
            );
            if (defined($psus_collection) && defined($psus_collection->{Members})) {
                foreach my $psu_ref (@{$psus_collection->{Members}}) {
                    next if (!defined($psu_ref->{'@odata.id'}));
                    my $psu_data = $options{custom}->request_api(
                        url_path => $psu_ref->{'@odata.id'},
                        ignore_codes => { 404 => 1 }
                    );
                    push @psus, $psu_data if (defined($psu_data));
                }
            }
        }

        foreach my $psu (@psus) {
            my $psu_id = defined($psu->{MemberId}) ? $psu->{MemberId} : 
                (defined($psu->{Id}) ? $psu->{Id} : 'unknown');

            if (defined($self->{option_results}->{filter_psu_id}) && $self->{option_results}->{filter_psu_id} ne '' &&
                $psu_id !~ /$self->{option_results}->{filter_psu_id}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_psu_id}) && $self->{option_results}->{exclude_psu_id} ne '' &&
                $psu_id =~ /$self->{option_results}->{exclude_psu_id}/) {
                next;
            }

            my $psu_name = defined($psu->{Name}) ? $psu->{Name} : $psu_id;

            if (defined($self->{option_results}->{filter_psu_name}) && $self->{option_results}->{filter_psu_name} ne '' &&
                $psu_name !~ /$self->{option_results}->{filter_psu_name}/) {
                next;
            }

            if (defined($self->{option_results}->{exclude_psu_name}) && $self->{option_results}->{exclude_psu_name} ne '' &&
                $psu_name =~ /$self->{option_results}->{exclude_psu_name}/) {
                next;
            }

            my $health = defined($psu->{Status}) && defined($psu->{Status}->{Health})
                ? $psu->{Status}->{Health} : 'n/a';
            my $state = defined($psu->{Status}) && defined($psu->{Status}->{State})
                ? $psu->{Status}->{State} : 'n/a';
            next if ($state =~ /^Absent$/i);


            my $power = defined($psu->{PowerOutputWatts}) ? $psu->{PowerOutputWatts} : 
                (defined($psu->{LastPowerOutputWatts}) ? $psu->{LastPowerOutputWatts} : undef);

            my $psu_full_id = $enclosure_id . '_' . $psu_id;

            $self->{psus}->{$psu_full_id} = {
                name      => $psu_name,
                enclosure => $enclosure_id,
                health    => $health,
                state     => $state,
                power     => $power,
            };
            
            $self->{global}->{total}++;
        }
    }

    if (scalar(keys %{$self->{psus}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No power supplies found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA power supplies status via Redfish API.

=over 8

=item B<--filter-enclosure>

Filter by enclosure (can be a regexp).

=item B<--filter-psu-id>

Filter by psu id (can be a regexp).

=item B<--filter-psu-name>

Filter by psu name (can be a regexp).

=item B<--exclude-enclosure>

Exclude by enclosure (can be a regexp).

=item B<--exclude-psu-id>

Exclude by psu id (can be a regexp).

=item B<--exclude-psu-name>

Exclude by psu name (can be a regexp).

=item B<--warning-psu-status> B<--critical-psu-status>

Set warning/critical threshold for psu status.
Default warning: '%{health} =~ /degraded/i'
Default critical: '%{health} =~ /fault|failed/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'psu-power', 'psus-total'.

=back

=cut
