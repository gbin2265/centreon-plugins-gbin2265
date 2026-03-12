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

package hardware::server::dell::idrac::restapi::mode::firmware;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'components-total', nlabel => 'firmware.components.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total components: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
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

    my $result = $options{custom}->request_api(endpoint => '/redfish/v1/UpdateService/FirmwareInventory');

    $self->{global} = { total => 0 };

    return if (!defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        
        my $fw = $options{custom}->request_api(endpoint => $member->{'@odata.id'}, ignore_error => 1);
        next if (!defined($fw));

        my $name = $fw->{Name} // $fw->{Id} // 'unknown';
        
        next if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' && $name !~ /$self->{option_results}->{filter_name}/i);

        my $version = $fw->{Version} // 'N/A';
        
        $self->{output}->output_add(long_msg => sprintf("'%s' version: %s", $name, $version));
        $self->{global}->{total}++;
    }

    if ($self->{global}->{total} == 0) {
        $self->{output}->add_option_msg(short_msg => "No firmware components found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check firmware inventory.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='components'

=item B<--filter-name>

Filter firmware by name (regexp).

=item B<--warning-components-total> B<--critical-components-total>

Thresholds on total firmware components count.

=back

=cut
