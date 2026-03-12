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

package network::paloalto::restapi::mode::panorama;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        'connection status: %s [server: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{server}
    );
}

sub prefix_panorama_output {
    my ($self, %options) = @_;

    return "Panorama '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'panorama', type => 1, cb_prefix_output => 'prefix_panorama_output', message_multiple => 'All Panorama connections are ok' }
    ];

    $self->{maps_counters}->{panorama} = [
        { label => 'status', type => 2, critical_default => '%{status} ne "connected"', set => {
                key_values => [
                    { name => 'status' }, { name => 'server' }, { name => 'display' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(
        cmd => '<show><panorama-status></panorama-status></show>'
    );

    $self->{panorama} = {};

    # The output can be text-based or structured XML depending on PAN-OS version
    if (defined($result) && !ref($result)) {
        # Text output: parse lines like "Panorama Server 1 : 10.0.0.100" and "    Connected     : yes"
        my $current_server = '';
        my $current_ip = '';
        my $idx = 0;

        foreach my $line (split /\n/, $result) {
            if ($line =~ /Panorama\s+Server\s+(\d+)\s*:\s*(\S+)/i) {
                $current_server = "server-$1";
                $current_ip = $2;
                $idx++;
            } elsif ($line =~ /Connected\s*:\s*(\S+)/i && $current_server ne '') {
                my $connected = lc($1);
                $self->{panorama}->{$current_server} = {
                    display => $current_server,
                    server  => $current_ip,
                    status  => ($connected eq 'yes') ? 'connected' : 'not-connected'
                };
                $current_server = '';
            }
        }
    } elsif (ref($result) eq 'HASH') {
        # Structured XML
        my $idx = 0;
        foreach my $key (sort keys %$result) {
            next if (ref($result->{$key}) ne '' && ref($result->{$key}) ne 'HASH');
            $idx++;
            if (ref($result->{$key}) eq 'HASH') {
                $self->{panorama}->{"server-$idx"} = {
                    display => "server-$idx",
                    server  => defined($result->{$key}->{addr}) ? $result->{$key}->{addr} :
                               defined($result->{$key}->{ip}) ? $result->{$key}->{ip} : '-',
                    status  => defined($result->{$key}->{connected}) ?
                        ($result->{$key}->{connected} eq 'yes' ? 'connected' : 'not-connected') : 'unknown'
                };
            }
        }
    }

    if (scalar(keys %{$self->{panorama}}) == 0) {
        $self->{output}->add_option_msg(short_msg => 'No Panorama configuration found (not managed by Panorama?)');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check Panorama management server connectivity status.

=over 8

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{server}, %{display}.

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{server}, %{display}.

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} ne "connected"').
You can use the following variables: %{status}, %{server}, %{display}.

=back

=cut
