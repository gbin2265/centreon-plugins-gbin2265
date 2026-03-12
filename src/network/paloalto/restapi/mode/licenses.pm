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

package network::paloalto::restapi::mode::licenses;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use DateTime;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    if ($self->{result_values}->{expiry_date} eq 'never') {
        return sprintf("expired status is '%s', never expires", $self->{result_values}->{expired});
    }

    return sprintf(
        "expired status is '%s', expires in %d days [%s]",
        $self->{result_values}->{expired},
        $self->{result_values}->{expiry_days},
        $self->{result_values}->{expiry_date}
    );
}

sub custom_status_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{feature} = $options{new_datas}->{$self->{instance} . '_feature'};
    $self->{result_values}->{expired} = $options{new_datas}->{$self->{instance} . '_expired'};
    $self->{result_values}->{expiry_date} = $options{new_datas}->{$self->{instance} . '_expiry_date'};
    $self->{result_values}->{expiry_seconds} = $options{new_datas}->{$self->{instance} . '_expiry_seconds'};
    $self->{result_values}->{expiry_days} = ($self->{result_values}->{expiry_seconds} ne '') ? int($self->{result_values}->{expiry_seconds} / 86400) : -1;
    return 0;
}

sub custom_expires_perfdata {
    my ($self, %options) = @_;

    return if ($self->{result_values}->{expiry_seconds} eq '' || $self->{result_values}->{expiry_date} eq 'never');
    $self->{output}->perfdata_add(
        nlabel => 'license.expires.days',
        instances => $self->{result_values}->{feature},
        value => $self->{result_values}->{expiry_days},
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel}),
        min => 0
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'features', type => 1, cb_prefix_output => 'prefix_feature_output', message_multiple => 'All features licensing are ok' }
    ];

    $self->{maps_counters}->{features} = [
        { label => 'status', type => 2, critical_default => '%{expired} eq "yes"', set => {
                key_values => [ { name => 'feature' }, { name => 'expired' }, { name => 'expiry_date' }, { name => 'expiry_seconds' } ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => $self->can('custom_expires_perfdata'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub prefix_feature_output {
    my ($self, %options) = @_;

    return "Feature '" . $options{instance_value}->{feature} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-feature:s' => { name => 'filter_feature' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $result = $options{custom}->request_api(
        cmd => '<request><license><info></info></license></request>',
        ForceArray => ['entry']
    );

    my $months = {
        january => 1, february => 2, march => 3, april => 4, may => 5, june => 6,
        july => 7, august => 8, september => 9, october => 10, november => 11, december => 12
    };

    $self->{features} = {};
    my $entries = defined($result->{licenses}->{entry}) ? $result->{licenses}->{entry} : [];
    foreach my $feature (@$entries) {
        my $feat_name = $feature->{feature};
        my $expires = lc(defined($feature->{expires}) ? $feature->{expires} : 'never');

        if (defined($self->{option_results}->{filter_feature}) && $self->{option_results}->{filter_feature} ne '' &&
            $feat_name !~ /$self->{option_results}->{filter_feature}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $feat_name . "': no matching filter.", debug => 1);
            next;
        }

        my $expiry_seconds = '';
        # 'January 30, 2022' or 'never'
        if ($expires =~ /^(\w+)\s+(\d+).*?(\d{4})$/) {
            if (defined($months->{$1})) {
                my $dt = DateTime->new(year => $3, month => $months->{$1}, day => $2);
                $expiry_seconds = $dt->epoch - time();
            }
        }

        $self->{features}->{$feat_name} = {
            feature        => $feat_name,
            expired        => defined($feature->{expired}) ? $feature->{expired} : 'unknown',
            expiry_date    => $expires,
            expiry_seconds => $expiry_seconds
        };
    }

    if (scalar(keys %{$self->{features}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No features found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check features licensing.

=over 8

=item B<--filter-feature>

Filter license by feature name (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{expired}, %{expiry_days}, %{feature}, %{expiry_date}.

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (example: '%{expiry_days} < 60').
You can use the following variables: %{expired}, %{expiry_days}, %{feature}, %{expiry_date}.

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{expired} eq "yes"').
You can use the following variables: %{expired}, %{expiry_days}, %{feature}, %{expiry_date}.

=back

=cut
