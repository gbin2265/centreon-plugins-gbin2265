#
# Copyright 2026-Present Centreon (http://www.centreon.com/)
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

package network::paloalto::restapi::mode::globalprotect;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'GlobalProtect ';
}

sub prefix_gateway_output {
    my ($self, %options) = @_;

    return "Gateway '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'gateways', type => 1, cb_prefix_output => 'prefix_gateway_output', message_multiple => 'All gateways are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'users-total', nlabel => 'globalprotect.users.total.count', set => {
                key_values => [ { name => 'total_users' } ],
                output_template => 'total connected users: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{gateways} = [
        { label => 'gateway-users', nlabel => 'globalprotect.gateway.users.count', set => {
                key_values => [ { name => 'users' }, { name => 'display' } ],
                output_template => 'users: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
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
        'filter-gateway:s' => { name => 'filter_gateway' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    # Get current users from all gateways
    my $result = $options{custom}->request_api(
        cmd => '<show><global-protect-gateway><current-user></current-user></global-protect-gateway></show>',
        ForceArray => ['entry']
    );

    $self->{global} = { total_users => 0 };
    $self->{gateways} = {};

    # Parse gateway user entries
    # XML structure varies: may have gateway sub-keys or flat entry list
    my $entries = [];
    if (defined($result->{entry})) {
        $entries = $result->{entry};
    } elsif (ref($result) eq 'HASH') {
        foreach my $key (keys %$result) {
            next if (ref($result->{$key}) ne 'HASH');
            if (defined($result->{$key}->{entry})) {
                push @$entries, @{$result->{$key}->{entry}};
            }
        }
    }

    # Count users per gateway
    my $gw_count = {};
    foreach my $entry (@$entries) {
        my $gw_name = defined($entry->{gateway}) ? $entry->{gateway} :
                      defined($entry->{'virtual-sys'}) ? $entry->{'virtual-sys'} : 'default';

        if (defined($self->{option_results}->{filter_gateway}) && $self->{option_results}->{filter_gateway} ne '' &&
            $gw_name !~ /$self->{option_results}->{filter_gateway}/) {
            next;
        }

        $gw_count->{$gw_name} = 0 if (!defined($gw_count->{$gw_name}));
        $gw_count->{$gw_name}++;
        $self->{global}->{total_users}++;
    }

    foreach my $gw_name (keys %$gw_count) {
        $self->{gateways}->{$gw_name} = {
            display => $gw_name,
            users   => $gw_count->{$gw_name}
        };
    }

    # If no gateways found but no error, create a default entry
    if (scalar(keys %{$self->{gateways}}) == 0) {
        $self->{gateways}->{default} = {
            display => 'default',
            users   => 0
        };
    }
}

1;

__END__

=head1 MODE

Check GlobalProtect VPN connected users.

=over 8

=item B<--filter-gateway>

Filter gateway by name (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'users-total', 'gateway-users'.

=back

=cut
