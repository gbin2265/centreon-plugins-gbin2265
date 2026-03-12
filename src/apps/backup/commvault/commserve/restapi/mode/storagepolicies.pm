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

package apps::backup::commvault::commserve::restapi::mode::storagepolicies;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf('status: %s [copies: %s]', $self->{result_values}->{status}, $self->{result_values}->{copies});
}

sub prefix_policy_output {
    my ($self, %options) = @_;
    return "Storage policy '" . $options{instance_value}->{display} . "' [id: " . $options{instance_value}->{policy_id} . "] ";
}

sub prefix_global_output {
    my ($self, %options) = @_;
    return 'Storage policies ';
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output', skipped_code => { -10 => 1 } },
        { name => 'policies', type => 1, cb_prefix_output => 'prefix_policy_output', message_multiple => 'All storage policies are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'policies-total', nlabel => 'storagepolicies.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [ { template => '%s', min => 0 } ]
            }
        }
    ];

    $self->{maps_counters}->{policies} = [
        {
            label => 'status', type => 2,
            critical_default => '%{status} !~ /ok|good/i',
            set => {
                key_values => [
                    { name => 'display' }, { name => 'policy_id' },
                    { name => 'status' }, { name => 'copies' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'policy-copies', nlabel => 'storagepolicy.copies.count', display_ok => 0, set => {
                key_values => [ { name => 'copies_count' }, { name => 'display' } ],
                output_template => 'copies: %s',
                perfdatas => [ { template => '%s', min => 0, label_extra_instance => 1 } ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-policy-name:s' => { name => 'filter_policy_name' }
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request(
        type => 'storagepolicy',
        endpoint => '/StoragePolicy'
    );

    $self->{global} = { total => 0 };
    $self->{policies} = {};

    my $entries = $results->{policies} // [];
    foreach my $entry (@{$entries}) {
        my $policy = $entry->{storagePolicyName} // '';
        my $policy_id = $entry->{storagePolicyId} // '';
        next if ($policy eq '');

        if (defined($self->{option_results}->{filter_policy_name}) && $self->{option_results}->{filter_policy_name} ne '' &&
            $policy !~ /$self->{option_results}->{filter_policy_name}/) {
            $self->{output}->output_add(long_msg => "skipping policy '" . $policy . "': no matching filter.", debug => 1);
            next;
        }

        my $copies = $entry->{storagePolicyCopyInfo} // [];
        my $copies_count = ref($copies) eq 'ARRAY' ? scalar(@{$copies}) : 0;
        my $copy_names = join(', ', map { $_->{StoragePolicyCopy}->{copyName} // 'unknown' } @{$copies});

        my $status = 'ok';
        if (defined($entry->{status})) {
            $status = ref($entry->{status}) ? 'ok' : lc($entry->{status});
        }

        $self->{policies}->{$policy} = {
            display      => $policy,
            policy_id    => $policy_id,
            status       => $status,
            copies       => $copy_names ne '' ? $copy_names : '-',
            copies_count => $copies_count
        };
        $self->{global}->{total}++;
    }

    if (scalar(keys %{$self->{policies}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No storage policies found");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check storage policy status.

=over 8

=item B<--filter-policy-name>

Filter policies by name (can be a regexp).

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{display}, %{policy_id}, %{status}, %{copies}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /ok|good/i').

=item B<--warning-policies-total>

Thresholds.

=item B<--critical-policies-total>

Thresholds.

=item B<--warning-policy-copies>

Warning threshold for number of copies.

=item B<--critical-policy-copies>

Critical threshold for number of copies.

=back

=cut
