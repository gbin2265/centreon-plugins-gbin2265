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

package hardware::server::dell::idrac::restapi::mode::interfaces;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("status: %s [state: %s, link: %s]", $self->{result_values}->{health}, $self->{result_values}->{state}, $self->{result_values}->{link_status});
}

sub prefix_iface_output {
    my ($self, %options) = @_;
    return sprintf("Interface '%s' ", $options{instance_value}->{name});
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, skipped_code => { -10 => 1 } },
        { name => 'interfaces', type => 1, cb_prefix_output => 'prefix_iface_output', message_multiple => 'All interfaces are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'interfaces-total', nlabel => 'interfaces.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total interfaces: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'interfaces-up', nlabel => 'interfaces.up.count', set => {
                key_values => [ { name => 'up' } ],
                output_template => 'up: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        },
        { label => 'interfaces-down', nlabel => 'interfaces.down.count', set => {
                key_values => [ { name => 'down' } ],
                output_template => 'down: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        }
    ];

    $self->{maps_counters}->{interfaces} = [
        {
            label => 'interface-status',
            type => 2,
            warning_default => '%{health} =~ /warning/i',
            critical_default => '%{health} =~ /critical/i',
            set => {
                key_values => [ { name => 'health' }, { name => 'state' }, { name => 'link_status' }, { name => 'name' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'interface-speed', nlabel => 'interface.speed.megabits_per_second', set => {
                key_values => [ { name => 'speed' }, { name => 'name' } ],
                output_template => 'speed: %s Mbps',
                perfdatas => [ { template => '%s', unit => 'Mbps', min => 0, label_extra_instance => 1, instance_use => 'name' } ]
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

    my $result = $options{custom}->request_api(endpoint => '/redfish/v1/Systems/System.Embedded.1/EthernetInterfaces');

    $self->{global} = { total => 0, up => 0, down => 0 };
    $self->{interfaces} = {};

    return if (!defined($result->{Members}));

    foreach my $member (@{$result->{Members}}) {
        next if (!defined($member->{'@odata.id'}));
        
        my $iface = $options{custom}->request_api(endpoint => $member->{'@odata.id'}, ignore_error => 1);
        next if (!defined($iface));

        my $name = $iface->{Id} // $iface->{Name} // 'unknown';
        my $state = $iface->{Status}->{State} // 'N/A';
        my $link_status = $iface->{LinkStatus} // 'N/A';

        next if ($state =~ /absent/i);
        next if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' && $name !~ /$self->{option_results}->{filter_name}/i);

        $self->{interfaces}->{$name} = {
            name => $name,
            health => $iface->{Status}->{Health} // 'N/A',
            state => $state,
            link_status => $link_status,
            speed => $iface->{SpeedMbps}
        };

        $self->{global}->{total}++;
        if ($link_status =~ /linkup/i) { $self->{global}->{up}++; }
        else { $self->{global}->{down}++; }
    }

    if ($self->{global}->{total} == 0) {
        $self->{output}->add_option_msg(short_msg => "No interfaces found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check network interfaces.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='status'

=item B<--filter-name>

Filter interfaces by name (regexp).

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'interfaces-total', 'interfaces-up', 'interfaces-down', 'interface-speed'.

=back

=cut
