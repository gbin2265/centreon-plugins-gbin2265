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

package network::f5::bigip::snmp::mode::httpprofilestats;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use Digest::MD5 qw(md5_hex);

sub prefix_profile_output {
    my ($self, %options) = @_;

    return "HTTP profile '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'profiles', type => 1, cb_prefix_output => 'prefix_profile_output',
          message_multiple => 'All HTTP profiles are ok' }
    ];

    $self->{maps_counters}->{profiles} = [
        { label => 'requests', nlabel => 'httpprofile.requests.persecond', set => {
                key_values => [ { name => 'number_reqs', diff => 1 }, { name => 'display' } ],
                output_template => 'requests: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'responses', nlabel => 'httpprofile.responses.persecond', set => {
                key_values => [ { name => 'number_resp', diff => 1 }, { name => 'display' } ],
                output_template => 'responses: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'get-requests', nlabel => 'httpprofile.requests.get.persecond', display_ok => 0, set => {
                key_values => [ { name => 'get_reqs', diff => 1 }, { name => 'display' } ],
                output_template => 'GET requests: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'post-requests', nlabel => 'httpprofile.requests.post.persecond', display_ok => 0, set => {
                key_values => [ { name => 'post_reqs', diff => 1 }, { name => 'display' } ],
                output_template => 'POST requests: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'responses-2xx', nlabel => 'httpprofile.responses.2xx.persecond', set => {
                key_values => [ { name => 'resp_2xx', diff => 1 }, { name => 'display' } ],
                output_template => '2xx responses: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'responses-3xx', nlabel => 'httpprofile.responses.3xx.persecond', display_ok => 0, set => {
                key_values => [ { name => 'resp_3xx', diff => 1 }, { name => 'display' } ],
                output_template => '3xx responses: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'responses-4xx', nlabel => 'httpprofile.responses.4xx.persecond', set => {
                key_values => [ { name => 'resp_4xx', diff => 1 }, { name => 'display' } ],
                output_template => '4xx responses: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        },
        { label => 'responses-5xx', nlabel => 'httpprofile.responses.5xx.persecond', set => {
                key_values => [ { name => 'resp_5xx', diff => 1 }, { name => 'display' } ],
                output_template => '5xx responses: %.2f/s',
                per_second => 1,
                perfdatas => [
                    { template => '%.2f', min => 0, label_extra_instance => 1, instance_use => 'display' }
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

# F5-BIGIP-LOCAL-MIB::ltmHttpStatProfileTable
my $mapping = {
    ltmHttpStatProfileNumberReqs => { oid => '.1.3.6.1.4.1.3375.2.2.6.5.2.1.3' },
    ltmHttpStatProfileGetReqs    => { oid => '.1.3.6.1.4.1.3375.2.2.6.5.2.1.4' },
    ltmHttpStatProfilePostReqs   => { oid => '.1.3.6.1.4.1.3375.2.2.6.5.2.1.5' },
    ltmHttpStatProfileNumberResp => { oid => '.1.3.6.1.4.1.3375.2.2.6.5.2.1.6' },
    ltmHttpStatProfileResp2xxCnt => { oid => '.1.3.6.1.4.1.3375.2.2.6.5.2.1.7' },
    ltmHttpStatProfileResp3xxCnt => { oid => '.1.3.6.1.4.1.3375.2.2.6.5.2.1.8' },
    ltmHttpStatProfileResp4xxCnt => { oid => '.1.3.6.1.4.1.3375.2.2.6.5.2.1.9' },
    ltmHttpStatProfileResp5xxCnt => { oid => '.1.3.6.1.4.1.3375.2.2.6.5.2.1.10' },
};
my $oid_ltmHttpStatProfileEntry = '.1.3.6.1.4.1.3375.2.2.6.5.2.1';

sub manage_selection {
    my ($self, %options) = @_;

    my $snmp_result = $options{snmp}->get_table(
        oid          => $oid_ltmHttpStatProfileEntry,
        nothing_quit => 1
    );

    $self->{profiles} = {};
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result})) {
        next if ($oid !~ /^$mapping->{ltmHttpStatProfileNumberReqs}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping,
            results  => $snmp_result,
            instance => $instance
        );

        my @indexes = split(/\./, $instance);
        my $name_length = shift(@indexes);
        my $name = join('', map(chr($_), splice(@indexes, 0, $name_length)));

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping HTTP profile '" . $name . "'.", debug => 1);
            next;
        }

        $self->{profiles}->{$name} = {
            display     => $name,
            number_reqs => $result->{ltmHttpStatProfileNumberReqs},
            number_resp => $result->{ltmHttpStatProfileNumberResp},
            get_reqs    => $result->{ltmHttpStatProfileGetReqs},
            post_reqs   => $result->{ltmHttpStatProfilePostReqs},
            resp_2xx    => $result->{ltmHttpStatProfileResp2xxCnt},
            resp_3xx    => $result->{ltmHttpStatProfileResp3xxCnt},
            resp_4xx    => $result->{ltmHttpStatProfileResp4xxCnt},
            resp_5xx    => $result->{ltmHttpStatProfileResp5xxCnt}
        };
    }

    if (scalar(keys %{$self->{profiles}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No HTTP profiles found.');
        $self->{output}->option_exit();
    }

    $self->{cache_name} = 'f5_bigip_' . $options{snmp}->get_hostname() . '_' . $options{snmp}->get_port() . '_' . $self->{mode} . '_' .
        (defined($self->{option_results}->{filter_counters}) ? md5_hex($self->{option_results}->{filter_counters}) : md5_hex('all')) . '_' .
        (defined($self->{option_results}->{filter_name}) ? md5_hex($self->{option_results}->{filter_name}) : md5_hex('all'));
}

1;

__END__

=head1 MODE

Check HTTP profile statistics on F5 BIG-IP devices.

Monitors request/response rates and HTTP status code distribution per HTTP profile.

=over 8

=item B<--filter-counters>

Only display some counters (regexp can be used).
Example: --filter-counters='responses-5xx'

=item B<--filter-name>

Filter HTTP profile name (can be a regexp).

=item B<--warning-requests>

Warning threshold for total requests per second.

=item B<--critical-requests>

Critical threshold for total requests per second.

=item B<--warning-responses-4xx>

Warning threshold for 4xx responses per second.

=item B<--critical-responses-4xx>

Critical threshold for 4xx responses per second.

=item B<--warning-responses-5xx>

Warning threshold for 5xx responses per second.

=item B<--critical-responses-5xx>

Critical threshold for 5xx responses per second.

=back

=cut
