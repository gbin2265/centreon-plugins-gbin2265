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

package network::paloalto::restapi::mode::interfaces;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'state: %s [type: %s][speed: %s][zone: %s]',
        $self->{result_values}->{state},
        $self->{result_values}->{type},
        $self->{result_values}->{speed},
        $self->{result_values}->{zone}
    );
}

sub interface_long_output {
    my ($self, %options) = @_;

    my $iv = $options{instance_value};
    my $msg = "checking interface '" . $iv->{display} . "'";
    $msg .= "\n        * mac: " . $iv->{mac} . ", ip: " . $iv->{ip} . ", zone: " . $iv->{zone};
    $msg .= ", vsys: " . $iv->{vsys} if (defined($iv->{vsys}) && $iv->{vsys} ne '');
    return $msg;
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Total ';
}

sub prefix_interface_output {
    my ($self, %options) = @_;

    return "Interface '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        {
            name => 'interfaces', type => 3, cb_prefix_output => 'prefix_interface_output',
            cb_long_output => 'interface_long_output', indent_long_output => '    ',
            message_multiple => 'All interfaces are ok',
            group => [
                { name => 'status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'traffic', type => 0, skipped_code => { -10 => 1 } },
                { name => 'errors', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'total', nlabel => 'interfaces.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'interfaces: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{status} = [
        { label => 'status', type => 2, critical_default => '%{state} ne "up"', set => {
                key_values => [
                    { name => 'state' }, { name => 'type' },
                    { name => 'speed' }, { name => 'zone' },
                    { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{traffic} = [
        { label => 'in-traffic', nlabel => 'interface.traffic.in.bytes', set => {
                key_values => [ { name => 'ibytes', diff => 1 }, { name => 'display' } ],
                output_template => 'in: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'out-traffic', nlabel => 'interface.traffic.out.bytes', set => {
                key_values => [ { name => 'obytes', diff => 1 }, { name => 'display' } ],
                output_template => 'out: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', min => 0, unit => 'B', label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'in-packets', nlabel => 'interface.packets.in.count', set => {
                key_values => [ { name => 'ipackets', diff => 1 }, { name => 'display' } ],
                output_template => 'in packets: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'out-packets', nlabel => 'interface.packets.out.count', set => {
                key_values => [ { name => 'opackets', diff => 1 }, { name => 'display' } ],
                output_template => 'out packets: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];

    $self->{maps_counters}->{errors} = [
        { label => 'in-errors', nlabel => 'interface.errors.in.count', set => {
                key_values => [ { name => 'ierrors', diff => 1 }, { name => 'display' } ],
                output_template => 'in errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'in-drops', nlabel => 'interface.drops.in.count', set => {
                key_values => [ { name => 'idrops', diff => 1 }, { name => 'display' } ],
                output_template => 'in drops: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'out-drops', nlabel => 'interface.drops.out.count', set => {
                key_values => [ { name => 'odrops', diff => 1 }, { name => 'display' } ],
                output_template => 'out drops: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s' => { name => 'filter_name' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(
        cmd => '<show><interface>all</interface></show>',
        ForceArray => ['entry']
    );

    # Build lookup from ifnet (logical interfaces with counters)
    my $ifnet = {};
    if (defined($result->{ifnet}->{entry})) {
        foreach my $entry (@{$result->{ifnet}->{entry}}) {
            $ifnet->{ $entry->{name} } = $entry;
        }
    }

    $self->{global} = { total => 0 };
    $self->{interfaces} = {};

    if (defined($result->{hw}->{entry})) {
        foreach my $entry (@{$result->{hw}->{entry}}) {
            my $name = $entry->{name};

            if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
                $name !~ /$self->{option_results}->{filter_name}/) {
                $self->{output}->output_add(long_msg => "skipping '" . $name . "': no matching filter.", debug => 1);
                next;
            }

            my $if = defined($ifnet->{$name}) ? $ifnet->{$name} : {};
            my $counters = defined($if->{counters}) ? $if->{counters} : {};

            $self->{interfaces}->{$name} = {
                display => $name,
                mac     => defined($entry->{mac}) ? $entry->{mac} : '-',
                ip      => defined($if->{ip}) ? $if->{ip} : '-',
                zone    => defined($if->{zone}) ? $if->{zone} : '-',
                vsys    => defined($if->{vsys}) ? $if->{vsys} : '',

                status => {
                    display => $name,
                    state   => defined($entry->{state}) ? $entry->{state} : 'unknown',
                    type    => defined($entry->{type}) ? $entry->{type} : '-',
                    speed   => defined($entry->{speed}) ? $entry->{speed} : '-',
                    zone    => defined($if->{zone}) ? $if->{zone} : '-'
                },
                traffic => {
                    display  => $name,
                    ibytes   => defined($counters->{ibytes}) ? $counters->{ibytes} : 0,
                    obytes   => defined($counters->{obytes}) ? $counters->{obytes} : 0,
                    ipackets => defined($counters->{ipackets}) ? $counters->{ipackets} : 0,
                    opackets => defined($counters->{opackets}) ? $counters->{opackets} : 0
                },
                errors => {
                    display => $name,
                    ierrors => defined($counters->{ierrors}) ? $counters->{ierrors} : 0,
                    idrops  => defined($counters->{idrops}) ? $counters->{idrops} : 0,
                    odrops  => defined($counters->{odrops}) ? $counters->{odrops} : 0
                }
            };

            $self->{global}->{total}++;
        }
    }

    $self->{cache_name} = 'paloalto_' . $self->{mode} . '_' . $options{custom}->get_hostname() . '_' . $options{custom}->get_port() . '_' .
        md5_hex(
            (defined($self->{option_results}->{filter_name}) ? $self->{option_results}->{filter_name} : '') . '_' .
            (defined($self->{option_results}->{filter_counters}) ? $self->{option_results}->{filter_counters} : '')
        );
}

1;

__END__

=head1 MODE

Check interfaces status and traffic.

=over 8

=item B<--filter-name>

Filter interface name (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{type}, %{speed}, %{zone}, %{display}.

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{state}, %{type}, %{speed}, %{zone}, %{display}.

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{state} ne "up"').
You can use the following variables: %{state}, %{type}, %{speed}, %{zone}, %{display}.

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'total', 'in-traffic' (B), 'out-traffic' (B),
'in-packets', 'out-packets', 'in-errors', 'in-drops', 'out-drops'.

=back

=cut
