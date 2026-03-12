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

package network::paloalto::restapi::mode::threats;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_threat_output {
    my ($self, %options) = @_;

    return 'Threats ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'threats', type => 0, cb_prefix_output => 'prefix_threat_output', message_separator => ' - ', skipped_code => { -10 => 1 } }
    ];

    $self->{maps_counters}->{threats} = [
        { label => 'virus-detected', nlabel => 'threats.virus.detected.count', set => {
                key_values => [ { name => 'virus', diff => 1 } ],
                output_template => 'virus: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'spyware-detected', nlabel => 'threats.spyware.detected.count', set => {
                key_values => [ { name => 'spyware', diff => 1 } ],
                output_template => 'spyware: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'vulnerability-detected', nlabel => 'threats.vulnerability.detected.count', set => {
                key_values => [ { name => 'vulnerability', diff => 1 } ],
                output_template => 'vulnerability: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'url-blocked', nlabel => 'threats.url.blocked.count', set => {
                key_values => [ { name => 'url', diff => 1 } ],
                output_template => 'url filtering: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'wildfire-detected', nlabel => 'threats.wildfire.detected.count', set => {
                key_values => [ { name => 'wildfire', diff => 1 } ],
                output_template => 'wildfire: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'file-blocked', nlabel => 'threats.file.blocked.count', display_ok => 0, set => {
                key_values => [ { name => 'file_blocking', diff => 1 } ],
                output_template => 'file blocking: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'data-filtered', nlabel => 'threats.data.filtered.count', display_ok => 0, set => {
                key_values => [ { name => 'data_filtering', diff => 1 } ],
                output_template => 'data filtering: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, statefile => 1, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(
        cmd => '<show><threat><summary></summary></threat></show>'
    );

    $self->{threats} = {
        virus          => 0,
        spyware        => 0,
        vulnerability  => 0,
        url            => 0,
        wildfire       => 0,
        file_blocking  => 0,
        data_filtering => 0
    };

    if (defined($result) && ref($result) eq 'HASH') {
        # Structured XML - field names vary by PAN-OS version
        $self->{threats}->{virus} =
            defined($result->{virus}) ? $result->{virus} :
            defined($result->{'antivirus'}) ? $result->{'antivirus'} : 0;
        $self->{threats}->{spyware} =
            defined($result->{spyware}) ? $result->{spyware} :
            defined($result->{'anti-spyware'}) ? $result->{'anti-spyware'} : 0;
        $self->{threats}->{vulnerability} =
            defined($result->{vulnerability}) ? $result->{vulnerability} :
            defined($result->{'vulnerability-protection'}) ? $result->{'vulnerability-protection'} : 0;
        $self->{threats}->{url} =
            defined($result->{url}) ? $result->{url} :
            defined($result->{'url-filtering'}) ? $result->{'url-filtering'} : 0;
        $self->{threats}->{wildfire} =
            defined($result->{wildfire}) ? $result->{wildfire} :
            defined($result->{'wildfire-virus'}) ? $result->{'wildfire-virus'} : 0;
        $self->{threats}->{file_blocking} =
            defined($result->{'file-blocking'}) ? $result->{'file-blocking'} :
            defined($result->{fileblocking}) ? $result->{fileblocking} : 0;
        $self->{threats}->{data_filtering} =
            defined($result->{'data-filtering'}) ? $result->{'data-filtering'} :
            defined($result->{datafiltering}) ? $result->{datafiltering} : 0;
    } elsif (defined($result) && !ref($result)) {
        # Text output fallback
        if ($result =~ /virus.*?(\d+)/si) { $self->{threats}->{virus} = $1; }
        if ($result =~ /spyware.*?(\d+)/si) { $self->{threats}->{spyware} = $1; }
        if ($result =~ /vulnerability.*?(\d+)/si) { $self->{threats}->{vulnerability} = $1; }
        if ($result =~ /url.*?(\d+)/si) { $self->{threats}->{url} = $1; }
        if ($result =~ /wildfire.*?(\d+)/si) { $self->{threats}->{wildfire} = $1; }
        if ($result =~ /file.?block.*?(\d+)/si) { $self->{threats}->{file_blocking} = $1; }
        if ($result =~ /data.?filter.*?(\d+)/si) { $self->{threats}->{data_filtering} = $1; }
    }

    $self->{cache_name} = 'paloalto_' . $self->{mode} . '_' . $options{custom}->get_hostname() . '_' . $options{custom}->get_port() . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check threat prevention statistics (virus, spyware, vulnerability, URL filtering).

All counters are delta-based (difference between checks).

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='^(virus|spyware)'

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'virus-detected', 'spyware-detected', 'vulnerability-detected',
'url-blocked', 'wildfire-detected', 'file-blocked', 'data-filtered'.

=back

=cut
