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

package storage::hp::msa2000::ssh::mode::ntpstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf('NTP status: %s [server: %s, last contact: %s]',
        $self->{result_values}->{ntp_status},
        $self->{result_values}->{ntp_server},
        $self->{result_values}->{ntp_contact}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'ntp', type => 0 }
    ];

    $self->{maps_counters}->{ntp} = [
        {
            label => 'ntp-status',
            type => 2,
            warning_default => '%{ntp_status} =~ /deactivated/i',
            critical_default => '%{ntp_status} =~ /failed/i',
            set => {
                key_values => [ { name => 'ntp_status' }, { name => 'ntp_server' }, { name => 'ntp_contact' } ],
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

    my ($result) = $options{custom}->get_infos(
        cmd => 'show ntp-status',
        base_type => 'ntp-status',
        properties_name => '^(?:ntp-status|ntp-server-address|ntp-contact-time)$'
    );

    my $info;
    if (ref($result) eq 'ARRAY') {
        $info = $result->[0] if (scalar(@$result) > 0);
    } elsif (ref($result) eq 'HASH' && scalar(keys %$result) > 0) {
        my @keys = keys %$result;
        $info = $result->{$keys[0]};
    }

    if (!defined($info)) {
        $self->{output}->add_option_msg(short_msg => 'No NTP status information found.');
        $self->{output}->option_exit();
    }

    $self->{ntp} = {
        ntp_status => defined($info->{'ntp-status'}) ? $info->{'ntp-status'} : 'unknown',
        ntp_server => defined($info->{'ntp-server-address'}) ? $info->{'ntp-server-address'} : '-',
        ntp_contact => defined($info->{'ntp-contact-time'}) ? $info->{'ntp-contact-time'} : '-',
    };
}

1;

__END__

=head1 MODE

Check NTP synchronization status.

=over 8

=item B<--warning-ntp-status>

Define the conditions to match for the status to be WARNING
(default: '%{ntp_status} =~ /deactivated/i').
You can use the following variables: %{ntp_status}, %{ntp_server}, %{ntp_contact}

=item B<--critical-ntp-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{ntp_status} =~ /failed/i').
You can use the following variables: %{ntp_status}, %{ntp_server}, %{ntp_contact}

=back

=cut
