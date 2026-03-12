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

package network::paloalto::restapi::mode::certificates;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use DateTime;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    if ($self->{result_values}->{expiry_days} < 0) {
        return sprintf(
            "EXPIRED %d days ago [%s], subject: %s, issuer: %s",
            abs($self->{result_values}->{expiry_days}),
            $self->{result_values}->{not_valid_after},
            $self->{result_values}->{subject},
            $self->{result_values}->{issuer}
        );
    }

    return sprintf(
        "expires in %d days [%s], subject: %s, issuer: %s",
        $self->{result_values}->{expiry_days},
        $self->{result_values}->{not_valid_after},
        $self->{result_values}->{subject},
        $self->{result_values}->{issuer}
    );
}

sub custom_status_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{display} = $options{new_datas}->{$self->{instance} . '_display'};
    $self->{result_values}->{subject} = $options{new_datas}->{$self->{instance} . '_subject'};
    $self->{result_values}->{issuer} = $options{new_datas}->{$self->{instance} . '_issuer'};
    $self->{result_values}->{not_valid_after} = $options{new_datas}->{$self->{instance} . '_not_valid_after'};
    $self->{result_values}->{expiry_seconds} = $options{new_datas}->{$self->{instance} . '_expiry_seconds'};
    $self->{result_values}->{expiry_days} = defined($self->{result_values}->{expiry_seconds}) ?
        int($self->{result_values}->{expiry_seconds} / 86400) : 0;
    return 0;
}

sub custom_expires_perfdata {
    my ($self, %options) = @_;

    $self->{output}->perfdata_add(
        nlabel => 'certificate.expires.days',
        instances => $self->{result_values}->{display},
        value => $self->{result_values}->{expiry_days},
        warning => $self->{perfdata}->get_perfdata_for_output(label => 'warning-' . $self->{thlabel}),
        critical => $self->{perfdata}->get_perfdata_for_output(label => 'critical-' . $self->{thlabel})
    );
}

sub custom_expires_threshold {
    my ($self, %options) = @_;

    return $self->{perfdata}->threshold_check(
        value => $self->{result_values}->{expiry_days},
        threshold => [
            { label => 'critical-' . $self->{thlabel}, exit_litteral => 'critical' },
            { label => 'warning-' . $self->{thlabel}, exit_litteral => 'warning' }
        ]
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 },
        { name => 'certificates', type => 1, cb_prefix_output => 'prefix_cert_output', message_multiple => 'All certificates are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'total', nlabel => 'certificates.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total certificates: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'expired', nlabel => 'certificates.expired.count', set => {
                key_values => [ { name => 'expired' } ],
                output_template => 'expired: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{certificates} = [
        { label => 'status', type => 2, warning_default => '%{expiry_days} < 30', critical_default => '%{expiry_days} < 7', set => {
                key_values => [
                    { name => 'display' }, { name => 'subject' }, { name => 'issuer' },
                    { name => 'not_valid_after' }, { name => 'expiry_seconds' }
                ],
                closure_custom_calc => $self->can('custom_status_calc'),
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => $self->can('custom_expires_perfdata'),
                closure_custom_threshold_check => $self->can('custom_expires_threshold')
            }
        }
    ];
}

sub prefix_cert_output {
    my ($self, %options) = @_;

    return "Certificate '" . $options{instance_value}->{display} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s' => { name => 'filter_name' }
    });

    return $self;
}

sub parse_date {
    my ($self, %options) = @_;

    # PAN-OS formats: 'Nov 30 23:59:59 2025 GMT' or 'Dec  5 12:00:00 2024 GMT'
    # or 'November 30, 2025' or '2025/11/30 23:59:59'
    my $date_str = $options{date};
    return undef if (!defined($date_str) || $date_str eq '' || $date_str eq 'N/A');

    my $months_short = {
        jan => 1, feb => 2, mar => 3, apr => 4, may => 5, jun => 6,
        jul => 7, aug => 8, sep => 9, oct => 10, nov => 11, dec => 12
    };
    my $months_long = {
        january => 1, february => 2, march => 3, april => 4, may => 5, june => 6,
        july => 7, august => 8, september => 9, october => 10, november => 11, december => 12
    };

    my $dt;
    # 'Nov 30 23:59:59 2025 GMT' or 'Nov  5 12:00:00 2024 GMT'
    if ($date_str =~ /^(\w{3})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/) {
        my $mon = $months_short->{lc($1)};
        return undef if (!defined($mon));
        $dt = DateTime->new(year => $6, month => $mon, day => $2, hour => $3, minute => $4, second => $5);
    }
    # 'November 30, 2025'
    elsif ($date_str =~ /^(\w+)\s+(\d{1,2}).*?(\d{4})/) {
        my $mon = $months_long->{lc($1)};
        return undef if (!defined($mon));
        $dt = DateTime->new(year => $3, month => $mon, day => $2);
    }
    # '2025/11/30 23:59:59'
    elsif ($date_str =~ /^(\d{4})\/(\d{2})\/(\d{2})\s+(\d{2}):(\d{2}):(\d{2})/) {
        $dt = DateTime->new(year => $1, month => $2, day => $3, hour => $4, minute => $5, second => $6);
    }

    return $dt;
}

sub manage_selection {
    my ($self, %options) = @_;

    # Get device certificates
    my $result = $options{custom}->request_api(
        cmd => '<show><sslmgr-store><config-certificate-info></config-certificate-info></sslmgr-store></show>',
        ForceArray => ['entry']
    );

    $self->{global} = { total => 0, expired => 0 };
    $self->{certificates} = {};

    # Navigate the XML structure - may vary by PAN-OS version
    my $entries = [];
    if (defined($result->{certificates}->{entry})) {
        $entries = $result->{certificates}->{entry};
    } elsif (defined($result->{entry})) {
        $entries = $result->{entry};
    } elsif (ref($result) eq 'HASH') {
        # Single level entries
        foreach my $key (keys %$result) {
            next if (ref($result->{$key}) ne 'HASH');
            push @$entries, { %{$result->{$key}}, 'certificate-name' => $key };
        }
    }

    foreach my $entry (@$entries) {
        my $name = defined($entry->{'certificate-name'}) ? $entry->{'certificate-name'} :
                   defined($entry->{name}) ? $entry->{name} :
                   defined($entry->{'common-name'}) ? $entry->{'common-name'} : 'unknown';

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping certificate '" . $name . "': no matching filter.", debug => 1);
            next;
        }

        my $not_after_str = defined($entry->{'not-valid-after'}) ? $entry->{'not-valid-after'} :
                            defined($entry->{'expiry-date'}) ? $entry->{'expiry-date'} :
                            defined($entry->{expiry}) ? $entry->{expiry} : undef;

        my $dt = $self->parse_date(date => $not_after_str);
        my $expiry_seconds = defined($dt) ? ($dt->epoch - time()) : 0;

        my $subject = defined($entry->{subject}) ? $entry->{subject} :
                      defined($entry->{'common-name'}) ? $entry->{'common-name'} : '-';
        my $issuer = defined($entry->{issuer}) ? $entry->{issuer} :
                     defined($entry->{'issuer-name'}) ? $entry->{'issuer-name'} :
                     defined($entry->{'ca'}) ? $entry->{'ca'} : '-';

        $self->{certificates}->{$name} = {
            display         => $name,
            subject         => $subject,
            issuer          => $issuer,
            not_valid_after => defined($not_after_str) ? $not_after_str : 'unknown',
            expiry_seconds  => $expiry_seconds
        };

        $self->{global}->{total}++;
        $self->{global}->{expired}++ if ($expiry_seconds < 0);
    }

    if ($self->{global}->{total} == 0) {
        $self->{output}->add_option_msg(short_msg => 'No certificates found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check device certificates expiration.

=over 8

=item B<--filter-name>

Filter certificate by name (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{display}, %{subject}, %{issuer}, %{expiry_days}.

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{expiry_days} < 30').
You can use the following variables: %{display}, %{subject}, %{issuer}, %{expiry_days}.

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{expiry_days} < 7').
You can use the following variables: %{display}, %{subject}, %{issuer}, %{expiry_days}.

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'total', 'expired'.

=back

=cut
