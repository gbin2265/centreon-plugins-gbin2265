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

package hardware::server::dell::idrac::restapi::mode::license;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("type: %s, status: %s [health: %s]", $self->{result_values}->{license_type}, $self->{result_values}->{state}, $self->{result_values}->{health});
}

sub prefix_license_output {
    my ($self, %options) = @_;
    return sprintf("License '%s' ", $options{instance_value}->{name});
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'licenses', type => 1, cb_prefix_output => 'prefix_license_output', message_multiple => 'All licenses are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'licenses-total', nlabel => 'licenses.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total licenses: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'licenses-active', nlabel => 'licenses.active.count', set => {
                key_values => [ { name => 'active' } ],
                output_template => 'active: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        }
    ];

    $self->{maps_counters}->{licenses} = [
        {
            label => 'license-status',
            type => 2,
            warning_default => '%{health} =~ /warning/i',
            critical_default => '%{state} =~ /disabled|expired/i || %{health} =~ /critical/i',
            set => {
                key_values => [ { name => 'state' }, { name => 'health' }, { name => 'license_type' }, { name => 'name' } ],
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
    $options{options}->add_options(arguments => { 'filter-name:s' => { name => 'filter_name' } });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(endpoint => '/redfish/v1/LicenseService/Licenses');

    $self->{global} = { total => 0, active => 0 };
    $self->{licenses} = {};

    return if (!defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        
        my $license = $options{custom}->request_api(endpoint => $member->{'@odata.id'}, ignore_error => 1);
        next if (!defined($license));

        my $name = $license->{Description} // $license->{Name} // $license->{Id} // 'unknown';
        next if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' && $name !~ /$self->{option_results}->{filter_name}/i);

        my $state = $license->{Status}->{State} // 'N/A';
        my $health = $license->{Status}->{Health} // 'N/A';

        next if ($state =~ /absent/i);

        $self->{licenses}->{$name} = {
            name => $name,
            state => $state,
            health => $health,
            license_type => $license->{LicenseType} // 'N/A'
        };
        $self->{global}->{total}++;
        if ($state =~ /enabled/i && $health =~ /ok/i) { $self->{global}->{active}++; }
    }

    if ($self->{global}->{total} == 0) {
        $self->{output}->add_option_msg(short_msg => "No licenses found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check iDRAC licenses.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='status'

=item B<--filter-name>

Filter licenses by name (regexp).

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'licenses-total', 'licenses-active'.

=back

=cut
