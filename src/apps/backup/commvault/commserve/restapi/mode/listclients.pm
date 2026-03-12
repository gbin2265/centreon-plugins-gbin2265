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

package apps::backup::commvault::commserve::restapi::mode::listclients;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-client-name:s' => { name => 'filter_client_name' }
    });
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request(
        type => 'client',
        endpoint => '/Client'
    );

    my $clients = [];
    my $entries = $results->{clientProperties} // [];
    foreach my $entry (@{$entries}) {
        my $ce = ($entry->{client} // {})->{clientEntity} // {};
        my $client_name = $ce->{clientName} // '';
        my $client_id   = $ce->{clientId}   // '';
        my $hostname    = $ce->{hostName}   // '';

        next if ($client_name eq '');
        next if (defined($self->{option_results}->{filter_client_name}) && $self->{option_results}->{filter_client_name} ne '' &&
            $client_name !~ /$self->{option_results}->{filter_client_name}/);

        my $status = 'online';
        if (defined($entry->{status})) {
            $status = $entry->{status} =~ /^\d+$/ ? ($entry->{status} == 0 ? 'online' : 'offline') : lc($entry->{status});
        }

        push @{$clients}, {
            id       => $client_id,
            name     => $client_name,
            hostname => $hostname,
            status   => $status
        };
    }
    return $clients;
}

sub run {
    my ($self, %options) = @_;

    my $clients = $self->manage_selection(%options);
    foreach (@{$clients}) {
        $self->{output}->output_add(
            long_msg => sprintf(
                '[id: %s][name: %s][hostname: %s][status: %s]',
                $_->{id}, $_->{name}, $_->{hostname}, $_->{status}
            )
        );
    }

    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List clients:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;
    $self->{output}->add_disco_format(elements => ['id', 'name', 'hostname', 'status']);
}

sub disco_show {
    my ($self, %options) = @_;

    my $clients = $self->manage_selection(%options);
    foreach (@{$clients}) {
        $self->{output}->add_disco_entry(
            id       => $_->{id},
            name     => $_->{name},
            hostname => $_->{hostname},
            status   => $_->{status}
        );
    }
}

1;

__END__

=head1 MODE

List clients (for Centreon auto-discovery).

=over 8

=item B<--filter-client-name>

Filter clients by name (can be a regexp).

=back

=cut
