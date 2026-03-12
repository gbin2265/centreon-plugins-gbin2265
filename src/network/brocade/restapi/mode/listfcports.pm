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

package network::brocade::restapi::mode::listfcports;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-port-name:s' => { name => 'filter_port_name' },
        'exclude-port-name:s' => { name => 'exclude_port_name' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $ports = $options{custom}->get_fcport_info();
    my $results = [];

    my $port_data = $ports->{'Response'}->{'fibrechannel'} // $ports->{'brocade-interface'}->{'fibrechannel'} // [];
    $port_data = [$port_data] if (ref($port_data) ne 'ARRAY');

    foreach my $port (@{$port_data}) {
        my $port_name = $port->{'name'} // next;
        my $port_index = $port->{'port-index'} // $port->{'index'} // '';

        if (defined($self->{option_results}->{filter_port_name}) && $self->{option_results}->{filter_port_name} ne '' &&
            $port_name !~ /$self->{option_results}->{filter_port_name}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_port_name}) && $self->{option_results}->{exclude_port_name} ne '' &&
            $port_name =~ /$self->{option_results}->{exclude_port_name}/) {
            next;
        }

        # Map operational status
        my $oper_status = 'unknown';
        my $oper_status_code = $port->{'operational-status'};
        if (defined($oper_status_code)) {
            my %oper_status_map = (
                0 => 'undefined',
                2 => 'online',
                3 => 'offline',
                5 => 'faulty',
                6 => 'testing'
            );
            $oper_status = $oper_status_map{$oper_status_code} // lc($oper_status_code);
        }

        # Map port type
        my $port_type = 'unknown';
        my $port_type_code = $port->{'port-type'};
        if (defined($port_type_code)) {
            my %port_type_map = (
                0  => 'unknown',
                7  => 'e-port',
                10 => 'g-port',
                11 => 'u-port',
                15 => 'f-port',
                16 => 'l-port',
                17 => 'fcoe-port',
                19 => 'ex-port',
                20 => 'd-port',
                21 => 'sim-port',
                22 => 'af-port',
                23 => 'ae-port',
                25 => 've-port',
                26 => 'n-port',
                29 => 'mirror-port',
                30 => 'icl-port',
                32768 => 'lb-port'
            );
            $port_type = $port_type_map{$port_type_code} // lc($port_type_code);
        }

        # Get enabled state
        my $admin_status = 'unknown';
        if (defined($port->{'is-enabled-state'})) {
            $admin_status = $port->{'is-enabled-state'} ? 'enabled' : 'disabled';
        }

        # Get speed
        my $speed = $port->{'speed'} // 'auto';
        my $max_speed = $port->{'max-speed'} // 0;

        push @{$results}, {
            name => $port_name,
            index => $port_index,
            wwn => $port->{'wwn'} // '',
            oper_status => $oper_status,
            admin_status => $admin_status,
            port_type => $port_type,
            speed => $speed,
            max_speed => $max_speed,
            slot => $port->{'slot-number'} // '',
            port => $port->{'port-number'} // ''
        };
    }

    return $results;
}

sub run {
    my ($self, %options) = @_;

    my $results = $self->manage_selection(%options);
    foreach my $port (@{$results}) {
        $self->{output}->output_add(
            long_msg => sprintf(
                "[name: %s] [index: %s] [wwn: %s] [oper_status: %s] [admin_status: %s] [port_type: %s] [speed: %s]",
                $port->{name},
                $port->{index},
                $port->{wwn},
                $port->{oper_status},
                $port->{admin_status},
                $port->{port_type},
                $port->{speed}
            )
        );
    }

    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List FC ports:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => [
        'name', 'index', 'wwn', 'oper_status', 'admin_status', 'port_type', 'speed', 'max_speed', 'slot', 'port'
    ]);
}

sub disco_show {
    my ($self, %options) = @_;

    my $results = $self->manage_selection(%options);
    foreach my $port (@{$results}) {
        $self->{output}->add_disco_entry(%{$port});
    }
}

1;

__END__

=head1 MODE

List FC ports.

=over 8

=item B<--filter-port-name>

Filter ports by name (can be a regexp).

=item B<--exclude-port-name>

Exclude ports by name (can be a regexp).

=back

=cut
