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

package network::brocade::restapi::mode::fabric;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s [principal: %s]",
        $self->{result_values}->{status},
        $self->{result_values}->{principal}
    );
}

sub prefix_fabric_output {
    my ($self, %options) = @_;

    return "Fabric ";
}

sub prefix_member_output {
    my ($self, %options) = @_;

    return "Switch '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_fabric_output' },
        { name => 'members', type => 1, cb_prefix_output => 'prefix_member_output', message_multiple => 'All fabric members are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'members-total', nlabel => 'fabric.members.total.count', set => {
                key_values => [ { name => 'members_total' } ],
                output_template => 'total members: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'members-online', nlabel => 'fabric.members.online.count', set => {
                key_values => [ { name => 'members_online' } ],
                output_template => 'members online: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'members-offline', nlabel => 'fabric.members.offline.count', set => {
                key_values => [ { name => 'members_offline' } ],
                output_template => 'members offline: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{members} = [
        {
            label => 'member-status',
            type => 2,
            critical_default => '%{status} ne "online"',
            set => {
                key_values => [ { name => 'status' }, { name => 'principal' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'member-domain-id', nlabel => 'fabric.member.domain.id', display_ok => 0, set => {
                key_values => [ { name => 'domain_id' }, { name => 'display' } ],
                output_template => 'domain ID: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
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
        'filter-switch-name:s' => { name => 'filter_switch_name' },
        'filter-switch-wwn:s'  => { name => 'filter_switch_wwn' },
        'exclude-switch-name:s' => { name => 'exclude_switch_name' },
        'exclude-switch-wwn:s'  => { name => 'exclude_switch_wwn' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $fabric = $options{custom}->get_fabric_info();

    $self->{global} = {
        members_total => 0,
        members_online => 0,
        members_offline => 0
    };
    $self->{members} = {};

    my $fabric_data = $fabric->{'Response'}->{'fabric-switch'} // $fabric->{'brocade-fabric'}->{'fabric-switch'} // [];
    $fabric_data = [$fabric_data] if (ref($fabric_data) ne 'ARRAY');

    foreach my $member (@{$fabric_data}) {
        my $switch_name = $member->{'name'} // $member->{'switch-name'} // $member->{'switch-user-friendly-name'} // 'unknown';
        my $switch_wwn = $member->{'wwn'} // $member->{'switch-wwn'} // '';
        my $domain_id = $member->{'domain-id'} // 0;

        if (defined($self->{option_results}->{filter_switch_name}) && $self->{option_results}->{filter_switch_name} ne '' &&
            $switch_name !~ /$self->{option_results}->{filter_switch_name}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_switch_wwn}) && $self->{option_results}->{filter_switch_wwn} ne '' &&
            $switch_wwn !~ /$self->{option_results}->{filter_switch_wwn}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_switch_name}) && $self->{option_results}->{exclude_switch_name} ne '' &&
            $switch_name =~ /$self->{option_results}->{exclude_switch_name}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_switch_wwn}) && $self->{option_results}->{exclude_switch_wwn} ne '' &&
            $switch_wwn =~ /$self->{option_results}->{exclude_switch_wwn}/) {
            next;
        }

        $self->{global}->{members_total}++;

        # Determine status - if switch appears in fabric response, it's reachable/online
        # The fabric-switch endpoint doesn't return operational-status, 
        # but if a switch is visible in the fabric, it's online
        my $status = 'online';
        
        # path-count indicates number of paths to reach this switch
        # For the local/principal switch, path-count is typically 0
        my $path_count = $member->{'path-count'} // 0;
        
        $self->{global}->{members_online}++;

        # Determine if principal switch
        my $principal = 'no';
        if (defined($member->{'is-principal'}) && $member->{'is-principal'}) {
            $principal = 'yes';
        } elsif (defined($member->{'principal'}) && $member->{'principal'}) {
            $principal = 'yes';
        }

        # Use friendly name if available
        my $display_name = $member->{'switch-user-friendly-name'} // $switch_name;
        if ($display_name eq 'unknown' && $switch_wwn ne '') {
            $display_name = $switch_wwn;
        }

        $self->{members}->{$display_name} = {
            display => $display_name,
            status => $status,
            principal => $principal,
            domain_id => $domain_id
        };
    }

    if ($self->{global}->{members_total} == 0) {
        $self->{output}->add_option_msg(short_msg => "No fabric members found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check fabric topology and member switches.

=over 8

=item B<--filter-switch-name>

Filter switches by name (can be a regexp).

=item B<--filter-switch-wwn>

Filter switches by WWN (can be a regexp).

=item B<--exclude-switch-name>

Exclude switches by name (can be a regexp).

=item B<--exclude-switch-wwn>

Exclude switches by WWN (can be a regexp).

=item B<--unknown-member-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{principal}, %{display}

=item B<--warning-member-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{principal}, %{display}

=item B<--critical-member-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} ne "online"').
You can use the following variables: %{status}, %{principal}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'members-total', 'members-online', 'members-offline', 'member-domain-id'.

=back

=cut
