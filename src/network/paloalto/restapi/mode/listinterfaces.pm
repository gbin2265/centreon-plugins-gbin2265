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

package network::paloalto::restapi::mode::listinterfaces;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s' => { name => 'filter_name' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(
        cmd => '<show><interface>all</interface></show>',
        ForceArray => ['entry']
    );

    # Build lookup from ifnet (logical interfaces)
    my $ifnet = {};
    if (defined($result->{ifnet}->{entry})) {
        foreach my $entry (@{$result->{ifnet}->{entry}}) {
            $ifnet->{ $entry->{name} } = $entry;
        }
    }

    my $interfaces = {};
    if (defined($result->{hw}->{entry})) {
        foreach my $entry (@{$result->{hw}->{entry}}) {
            my $name = $entry->{name};

            if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
                $name !~ /$self->{option_results}->{filter_name}/) {
                $self->{output}->output_add(long_msg => "skipping '" . $name . "': no matching filter.", debug => 1);
                next;
            }

            my $if = defined($ifnet->{$name}) ? $ifnet->{$name} : {};

            $interfaces->{$name} = {
                name  => $name,
                state => defined($entry->{state}) ? $entry->{state} : 'unknown',
                type  => defined($entry->{type}) ? $entry->{type} : '-',
                speed => defined($entry->{speed}) ? $entry->{speed} : '-',
                mac   => defined($entry->{mac}) ? $entry->{mac} : '-',
                ip    => defined($if->{ip}) ? $if->{ip} : '-',
                zone  => defined($if->{zone}) ? $if->{zone} : '-',
                vsys  => defined($if->{vsys}) ? $if->{vsys} : '-'
            };
        }
    }

    return $interfaces;
}

sub run {
    my ($self, %options) = @_;

    my $interfaces = $self->manage_selection(%options);
    foreach my $name (sort keys %$interfaces) {
        $self->{output}->output_add(
            long_msg => sprintf(
                "[name: %s][state: %s][type: %s][speed: %s][zone: %s][ip: %s][mac: %s]",
                $interfaces->{$name}->{name},
                $interfaces->{$name}->{state},
                $interfaces->{$name}->{type},
                $interfaces->{$name}->{speed},
                $interfaces->{$name}->{zone},
                $interfaces->{$name}->{ip},
                $interfaces->{$name}->{mac}
            )
        );
    }

    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List interfaces:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => [
        'name', 'state', 'type', 'speed', 'mac', 'ip', 'zone', 'vsys'
    ]);
}

sub disco_show {
    my ($self, %options) = @_;

    my $interfaces = $self->manage_selection(%options);
    foreach my $name (sort keys %$interfaces) {
        $self->{output}->add_disco_entry(%{$interfaces->{$name}});
    }
}

1;

__END__

=head1 MODE

List interfaces.

=over 8

=item B<--filter-name>

Filter interface name (can be a regexp).

=back

=head1 DISCOVERY

This mode is used for Centreon host/service auto-discovery.
Discovery labels available:

=over 4

=item * name

=item * state

=item * type

=item * speed

=item * mac

=item * ip

=item * zone

=item * vsys

=back

=cut
