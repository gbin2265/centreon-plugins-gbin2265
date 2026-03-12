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

package network::paloalto::restapi::mode::listipsec;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my @labels = (
    'tunnel_name',
    'gateway_name',
    'peer_address',
    'ike_phase1_state',
    'state',
    'monitor_status'
);

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

sub is_exact_filter {
    my ($self, %options) = @_;

    my $filter = $options{filter};
    return 0 if (!defined($filter) || $filter eq '');

    # Strip common exact-match anchors: ^name$
    # If filter contains regex special chars (unescaped), it's a regex
    return 0 if ($filter =~ /(?<!\\)[.+*?{}()\[\]|\\]/ && $filter !~ /^\^[A-Za-z0-9_\-]+\$$/);

    # Simple anchored name like ^tunnel-name$ -> extract exact name
    if ($filter =~ /^\^([A-Za-z0-9_\-]+)\$$/) {
        return $1;
    }

    # Plain name without any regex chars
    if ($filter =~ /^[A-Za-z0-9_\-]+$/) {
        return $filter;
    }

    return 0;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $filter = $self->{option_results}->{filter_name};
    my $exact_name = $self->is_exact_filter(filter => $filter);

    # Get IKE SA (phase 1)
    my $ike_cmd = $exact_name
        ? '<show><vpn><ike-sa><gateway>' . $exact_name . '</gateway></ike-sa></vpn></show>'
        : '<show><vpn><ike-sa></ike-sa></vpn></show>';

    my $ike_result = $options{custom}->request_api(
        cmd => $ike_cmd,
        ForceArray => ['entry']
    );

    my $tunnels = {};
    if (defined($ike_result->{entry})) {
        foreach my $entry (@{$ike_result->{entry}}) {
            my $name = $entry->{name};

            # Only apply regex filter when not using exact match
            if (!$exact_name && defined($filter) && $filter ne '' &&
                $name !~ /$filter/) {
                $self->{output}->output_add(long_msg => "skipping '" . $name . "': no matching filter.", debug => 1);
                next;
            }

            $tunnels->{ $entry->{gwid} } = {
                tunnel_name => $name,
                gateway_name => defined($entry->{'gateway-name'}) ? $entry->{'gateway-name'} : $name,
                peer_address => defined($entry->{peerip}) ? $entry->{peerip} : 'unknown',
                ike_phase1_state => (defined($entry->{created}) && $entry->{created} ne '') ? 'up' : 'down',
                state => 'unknown',
                monitor_status => 'unknown',
                gwid => $entry->{gwid}
            };
        }
    }

    return $tunnels if (scalar(keys %$tunnels) == 0);

    # Get IPSec SA (phase 2) to map gwid -> tid
    my $ipsec_cmd = $exact_name
        ? '<show><vpn><ipsec-sa><tunnel>' . $exact_name . '</tunnel></ipsec-sa></vpn></show>'
        : '<show><vpn><ipsec-sa></ipsec-sa></vpn></show>';

    my $ipsec_result = $options{custom}->request_api(
        cmd => $ipsec_cmd,
        ForceArray => ['entry']
    );
    if (defined($ipsec_result->{entries}->{entry})) {
        foreach my $entry (@{$ipsec_result->{entries}->{entry}}) {
            if (defined($tunnels->{ $entry->{gwid} })) {
                $tunnels->{ $entry->{gwid} }->{tid} = $entry->{tid};
            }
        }
    }

    # Get VPN flow for state and monitor
    my $flow_cmd = $exact_name
        ? '<show><vpn><flow><name>' . $exact_name . '</name></flow></vpn></show>'
        : '<show><vpn><flow></flow></vpn></show>';

    my $flow_result = $options{custom}->request_api(
        cmd => $flow_cmd,
        ForceArray => ['entry']
    );
    if (defined($flow_result->{IPSec}->{entry})) {
        foreach my $gwid (keys %$tunnels) {
            next if (!defined($tunnels->{$gwid}->{tid}));
            foreach my $entry (@{$flow_result->{IPSec}->{entry}}) {
                next if ($tunnels->{$gwid}->{tid} ne $entry->{id});
                $tunnels->{$gwid}->{state} = $entry->{state};
                $tunnels->{$gwid}->{monitor_status} = $entry->{mon};
            }
        }
    }

    return $tunnels;
}

sub run {
    my ($self, %options) = @_;

    my $tunnels = $self->manage_selection(custom => $options{custom});
    foreach my $tunnel (values %$tunnels) {
        $self->{output}->output_add(
            long_msg => join('', map("[" . $_ . ": " . $tunnel->{$_} . "]", @labels))
        );
    }

    $self->{output}->output_add(
        severity => 'OK',
        short_msg => 'List IPSec tunnels:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => [@labels]);
}

sub disco_show {
    my ($self, %options) = @_;

    my $tunnels = $self->manage_selection(custom => $options{custom});
    foreach my $tunnel (values %$tunnels) {
        $self->{output}->add_disco_entry(
            map { $_ => $tunnel->{$_} } @labels
        );
    }
}

1;

__END__

=head1 MODE

List IPSec tunnels.

=over 8

=item B<--filter-name>

Filter tunnels by name (can be a regexp).
If the filter is an exact name (no regex characters), targeted API calls
are used for better performance.

=back

=head1 DISCOVERY

This mode is used for Centreon host/service auto-discovery.
Discovery labels available:

=over 4

=item * tunnel_name

=item * gateway_name

=item * peer_address

=item * ike_phase1_state

=item * state

=item * monitor_status

=back

=cut
