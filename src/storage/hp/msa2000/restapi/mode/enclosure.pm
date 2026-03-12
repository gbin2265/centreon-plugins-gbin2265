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

package storage::hp::msa2000::restapi::mode::enclosure;

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

sub prefix_enclosure_output {
    my ($self, %options) = @_;

    return "Enclosure '" . $options{instance_value}->{name} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'enclosures', type => 1, cb_prefix_output => 'prefix_enclosure_output', message_multiple => 'All enclosures are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'enclosures-total', nlabel => 'enclosures.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total enclosures: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{enclosures} = [
        {
            label => 'enclosure-status',
            type => 2,
            warning_default => '%{health} =~ /degraded/i',
            critical_default => '%{health} =~ /fault|failed/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'state' }, { name => 'name' }
                ],
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
        'filter-enclosure-id:s' => { name => 'filter_enclosure_id' },
        'filter-enclosure-name:s' => { name => 'filter_enclosure_name' },
        'exclude-enclosure-id:s' => { name => 'exclude_enclosure_id' },
        'exclude-enclosure-name:s' => { name => 'exclude_enclosure_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{global} = { total => 0 };
    $self->{enclosures} = {};

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

        if (defined($self->{option_results}->{filter_enclosure_id}) && $self->{option_results}->{filter_enclosure_id} ne '' &&
            $enclosure_id !~ /$self->{option_results}->{filter_enclosure_id}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_enclosure_id}) && $self->{option_results}->{exclude_enclosure_id} ne '' &&
            $enclosure_id =~ /$self->{option_results}->{exclude_enclosure_id}/) {
            next;
        }

        my $enclosure_name = defined($chassis_data->{Name}) ? $chassis_data->{Name} : $enclosure_id;

        if (defined($self->{option_results}->{filter_enclosure_name}) && $self->{option_results}->{filter_enclosure_name} ne '' &&
            $enclosure_name !~ /$self->{option_results}->{filter_enclosure_name}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_enclosure_name}) && $self->{option_results}->{exclude_enclosure_name} ne '' &&
            $enclosure_name =~ /$self->{option_results}->{exclude_enclosure_name}/) {
            next;
        }

        my $health = defined($chassis_data->{Status}) && defined($chassis_data->{Status}->{Health})
            ? $chassis_data->{Status}->{Health} : 'n/a';
        my $state = defined($chassis_data->{Status}) && defined($chassis_data->{Status}->{State})
            ? $chassis_data->{Status}->{State} : 'n/a';
        next if ($state =~ /^Absent$/i);


        $self->{enclosures}->{$enclosure_id} = {
            name   => $enclosure_name,
            health => $health,
            state  => $state,
        };
        
        $self->{global}->{total}++;
    }

    if (scalar(keys %{$self->{enclosures}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No enclosures found.");
        $self->{output}->option_exit();
    }

    $options{custom}->logout();
}


1;

__END__

=head1 MODE

Check HPE MSA enclosures status via Redfish API.

=over 8

=item B<--filter-enclosure-id>

Filter by enclosure id (can be a regexp).

=item B<--filter-enclosure-name>

Filter by enclosure name (can be a regexp).

=item B<--exclude-enclosure-id>

Exclude by enclosure id (can be a regexp).

=item B<--exclude-enclosure-name>

Exclude by enclosure name (can be a regexp).

=item B<--warning-enclosure-status> B<--critical-enclosure-status>

Set warning/critical threshold for enclosure status.
Default warning: '%{health} =~ /degraded/i'
Default critical: '%{health} =~ /fault|failed/i'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'enclosures-total'.

=back

=cut
