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

package network::brocade::restapi::mode::license;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use POSIX;

sub custom_license_status_output {
    my ($self, %options) = @_;

    my $msg = sprintf("status: %s", $self->{result_values}->{status});
    if (defined($self->{result_values}->{expiration}) && $self->{result_values}->{expiration} ne '') {
        $msg .= sprintf(" [expires: %s]", $self->{result_values}->{expiration});
    }
    return $msg;
}

sub custom_license_days_output {
    my ($self, %options) = @_;

    return sprintf("expires in %d days", $self->{result_values}->{days_remaining});
}

sub prefix_license_output {
    my ($self, %options) = @_;

    return "License '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ' },
        { name => 'licenses', type => 1, cb_prefix_output => 'prefix_license_output', message_multiple => 'All licenses are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'licenses-total', nlabel => 'licenses.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total licenses: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'licenses-valid', nlabel => 'licenses.valid.count', set => {
                key_values => [ { name => 'valid' } ],
                output_template => 'valid: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'licenses-expired', nlabel => 'licenses.expired.count', set => {
                key_values => [ { name => 'expired' } ],
                output_template => 'expired: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'licenses-expiring-soon', nlabel => 'licenses.expiring.soon.count', set => {
                key_values => [ { name => 'expiring_soon' } ],
                output_template => 'expiring soon: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{licenses} = [
        {
            label => 'license-status',
            type => 2,
            critical_default => '%{status} =~ /expired/i',
            warning_default => '%{status} =~ /expiring/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'expiration' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_license_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'license-days-remaining', nlabel => 'license.expiration.days.remaining', set => {
                key_values => [ { name => 'days_remaining' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_license_days_output'),
                perfdatas => [
                    { template => '%d', unit => 'd', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-feature:s'      => { name => 'filter_feature' },
        'exclude-feature:s'     => { name => 'exclude_feature' },
        'warning-expiration:s'  => { name => 'warning_expiration', default => 30 },
        'critical-expiration:s' => { name => 'critical_expiration', default => 7 }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $license_data = $options{custom}->get_license_info();

    $self->{global} = { total => 0, valid => 0, expired => 0, expiring_soon => 0 };
    $self->{licenses} = {};

    my $licenses = $license_data->{'Response'}->{'license'} // $license_data->{'brocade-license'}->{'license'} // [];
    $licenses = [$licenses] if (ref($licenses) ne 'ARRAY');

    my $warning_days = $self->{option_results}->{warning_expiration};
    my $critical_days = $self->{option_results}->{critical_expiration};

    foreach my $lic (@{$licenses}) {
        my $feature = $lic->{'feature'} // $lic->{'name'} // next;

        if (defined($self->{option_results}->{filter_feature}) && $self->{option_results}->{filter_feature} ne '' &&
            $feature !~ /$self->{option_results}->{filter_feature}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_feature}) && $self->{option_results}->{exclude_feature} ne '' &&
            $feature =~ /$self->{option_results}->{exclude_feature}/) {
            next;
        }

        $self->{global}->{total}++;

        my $status = 'valid';
        my $expiration = $lic->{'expiration-date'} // $lic->{'expiration'} // '';
        my $days_remaining = undef;

        # Check if license has expiration
        if ($expiration ne '' && $expiration !~ /never|permanent/i) {
            # Try to parse expiration date and calculate remaining days
            # Format could be: "Mon DD YYYY" or "YYYY-MM-DD" or epoch
            my $exp_epoch;
            
            if ($expiration =~ /^(\d+)$/) {
                $exp_epoch = $1;
            } elsif ($expiration =~ /(\d{4})-(\d{2})-(\d{2})/) {
                $exp_epoch = POSIX::mktime(0, 0, 0, $3, $2 - 1, $1 - 1900);
            }

            if (defined($exp_epoch)) {
                $days_remaining = int(($exp_epoch - time()) / 86400);
                
                if ($days_remaining < 0) {
                    $status = 'expired';
                    $self->{global}->{expired}++;
                } elsif ($days_remaining <= $critical_days) {
                    $status = 'expiring-critical';
                    $self->{global}->{expiring_soon}++;
                } elsif ($days_remaining <= $warning_days) {
                    $status = 'expiring-warning';
                    $self->{global}->{expiring_soon}++;
                } else {
                    $self->{global}->{valid}++;
                }
            } else {
                $self->{global}->{valid}++;
            }
        } else {
            # Permanent license
            $self->{global}->{valid}++;
            $expiration = 'permanent';
        }

        $self->{licenses}->{$feature} = {
            display => $feature,
            status => $status,
            expiration => $expiration,
            days_remaining => $days_remaining
        };
    }

    if (scalar(keys %{$self->{licenses}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No licenses found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check license status.

=over 8

=item B<--filter-feature>

Filter licenses by feature name (can be a regexp).

=item B<--exclude-feature>

Exclude licenses by feature name (can be a regexp).

=item B<--warning-expiration>

Number of days before expiration to trigger a warning (default: 30).

=item B<--critical-expiration>

Number of days before expiration to trigger a critical (default: 7).

=item B<--unknown-license-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{expiration}, %{display}

=item B<--warning-license-status>

Define the conditions to match for the status to be WARNING (default: '%{status} =~ /expiring/i').
You can use the following variables: %{status}, %{expiration}, %{display}

=item B<--critical-license-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} =~ /expired/i').
You can use the following variables: %{status}, %{expiration}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'licenses-total', 'licenses-valid', 'licenses-expired', 'licenses-expiring-soon',
'license-days-remaining'.

=back

=cut
