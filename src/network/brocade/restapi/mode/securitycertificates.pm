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

package network::brocade::restapi::mode::securitycertificates;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use POSIX;

sub custom_cert_status_output {
    my ($self, %options) = @_;

    my $msg = sprintf("status: %s", $self->{result_values}->{status});
    if (defined($self->{result_values}->{issuer}) && $self->{result_values}->{issuer} ne '') {
        $msg .= sprintf(" [issuer: %s]", $self->{result_values}->{issuer});
    }
    if (defined($self->{result_values}->{valid_to}) && $self->{result_values}->{valid_to} ne '') {
        $msg .= sprintf(" [expires: %s]", $self->{result_values}->{valid_to});
    }
    return $msg;
}

sub custom_cert_days_output {
    my ($self, %options) = @_;

    if ($self->{result_values}->{days_remaining} < 0) {
        return sprintf("expired %d days ago", abs($self->{result_values}->{days_remaining}));
    }
    return sprintf("expires in %d days", $self->{result_values}->{days_remaining});
}

sub prefix_global_output {
    my ($self, %options) = @_;

    return 'Certificates: ';
}

sub prefix_cert_output {
    my ($self, %options) = @_;

    return "Certificate '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, cb_prefix_output => 'prefix_global_output' },
        { name => 'certificates', type => 1, cb_prefix_output => 'prefix_cert_output', message_multiple => 'All certificates are ok' }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'certificates-total', nlabel => 'certificates.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'certificates-valid', nlabel => 'certificates.valid.count', set => {
                key_values => [ { name => 'valid' } ],
                output_template => 'valid: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'certificates-expired', nlabel => 'certificates.expired.count', set => {
                key_values => [ { name => 'expired' } ],
                output_template => 'expired: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'certificates-expiring-soon', nlabel => 'certificates.expiring.soon.count', set => {
                key_values => [ { name => 'expiring_soon' } ],
                output_template => 'expiring soon: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{certificates} = [
        {
            label => 'certificate-status',
            type => 2,
            critical_default => '%{status} =~ /expired/i',
            warning_default => '%{status} =~ /expiring/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'issuer' }, { name => 'subject' },
                                { name => 'valid_to' }, { name => 'cert_type' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_cert_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'certificate-days-remaining', nlabel => 'certificate.expiration.days.remaining', set => {
                key_values => [ { name => 'days_remaining' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_cert_days_output'),
                perfdatas => [
                    { template => '%d', unit => 'd', label_extra_instance => 1 }
                ]
            }
        },
        { label => 'certificate-key-size', nlabel => 'certificate.key.size.bits', display_ok => 0, set => {
                key_values => [ { name => 'key_size' }, { name => 'display' } ],
                output_template => 'key size: %s bits',
                perfdatas => [
                    { template => '%s', unit => 'bits', min => 0, label_extra_instance => 1 }
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
        'filter-cert-type:s'    => { name => 'filter_cert_type' },
        'filter-cert-entity:s'  => { name => 'filter_cert_entity' },
        'exclude-cert-type:s'   => { name => 'exclude_cert_type' },
        'exclude-cert-entity:s' => { name => 'exclude_cert_entity' },
        'warning-expiration:s'  => { name => 'warning_expiration', default => 30 },
        'critical-expiration:s' => { name => 'critical_expiration', default => 7 }
    });

    return $self;
}

# Parse date strings commonly returned by Brocade FOS REST API
# Supports: "YYYY-MM-DD", "YYYY-MM-DDTHH:MM:SS", "Mon DD HH:MM:SS YYYY GMT",
#           "Mon DD HH:MM:SS YYYY", epoch seconds
sub _parse_date {
    my ($self, %options) = @_;

    my $date_str = $options{date};
    return undef if (!defined($date_str) || $date_str eq '');

    my %month_map = (
        'jan' => 0, 'feb' => 1, 'mar' => 2, 'apr' => 3,
        'may' => 4, 'jun' => 5, 'jul' => 6, 'aug' => 7,
        'sep' => 8, 'oct' => 9, 'nov' => 10, 'dec' => 11
    );

    # Epoch
    if ($date_str =~ /^(\d{10,})$/) {
        return $1;
    }

    # ISO format: 2024-12-31 or 2024-12-31T23:59:59
    if ($date_str =~ /(\d{4})-(\d{2})-(\d{2})(?:T(\d{2}):(\d{2}):(\d{2}))?/) {
        return POSIX::mktime($6 // 0, $5 // 0, $4 // 0, $3, $2 - 1, $1 - 1900);
    }

    # OpenSSL-style: "Dec 31 23:59:59 2024 GMT" or "Dec 31 23:59:59 2024"
    if ($date_str =~ /(\w{3})\s+(\d{1,2})\s+(\d{2}):(\d{2}):(\d{2})\s+(\d{4})/) {
        my $mon = $month_map{lc($1)};
        return undef if (!defined($mon));
        return POSIX::mktime($5, $4, $3, $2, $mon, $6 - 1900);
    }

    return undef;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $cert_data = $options{custom}->get_security_certificate();

    if (!defined($cert_data)) {
        $self->{output}->add_option_msg(short_msg => "No security certificate information available (API returned 403/404). Check REST API permissions or FOS version.");
        $self->{output}->option_exit();
    }

    $self->{global} = { total => 0, valid => 0, expired => 0, expiring_soon => 0 };
    $self->{certificates} = {};

    my $certs = $cert_data->{'Response'}->{'security-certificate'} //
                $cert_data->{'brocade-security'}->{'security-certificate'} // [];
    $certs = [$certs] if (ref($certs) ne 'ARRAY');

    my $warning_days = $self->{option_results}->{warning_expiration};
    my $critical_days = $self->{option_results}->{critical_expiration};

    foreach my $cert (@{$certs}) {
        my $cert_entity = $cert->{'certificate-entity'} // $cert->{'entity'} // 'unknown';
        my $cert_type = $cert->{'certificate-type'} // $cert->{'type'} // 'unknown';

        # Apply filters
        if (defined($self->{option_results}->{filter_cert_type}) && $self->{option_results}->{filter_cert_type} ne '' &&
            $cert_type !~ /$self->{option_results}->{filter_cert_type}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_cert_entity}) && $self->{option_results}->{filter_cert_entity} ne '' &&
            $cert_entity !~ /$self->{option_results}->{filter_cert_entity}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_cert_type}) && $self->{option_results}->{exclude_cert_type} ne '' &&
            $cert_type =~ /$self->{option_results}->{exclude_cert_type}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_cert_entity}) && $self->{option_results}->{exclude_cert_entity} ne '' &&
            $cert_entity =~ /$self->{option_results}->{exclude_cert_entity}/) {
            next;
        }

        # Skip CSRs — they are not installed certificates
        next if ($cert_entity =~ /^csr$/i);

        $self->{global}->{total}++;

        my $subject = $cert->{'subject'} // $cert->{'principal'} // '';
        my $issuer = $cert->{'issuer'} // '';
        my $valid_from = $cert->{'valid-from'} // $cert->{'not-before'} // '';
        my $valid_to = $cert->{'valid-to'} // $cert->{'not-after'} // '';
        my $key_size = $cert->{'key-size'} // $cert->{'key-length'} // undef;
        my $hash_algo = $cert->{'hash-algorithm'} // $cert->{'signature-algorithm'} // '';

        # Build display name: type/entity (e.g., "https/cert", "syslog/ca-cert")
        my $display_name = $cert_type . '/' . $cert_entity;

        # Parse expiry date and calculate remaining days
        my $status = 'valid';
        my $days_remaining = undef;

        my $exp_epoch = $self->_parse_date(date => $valid_to);

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
            # Cannot parse expiry — treat as valid but without days_remaining
            $self->{global}->{valid}++;
        }

        $self->{certificates}->{$display_name} = {
            display => $display_name,
            status => $status,
            cert_type => $cert_type,
            cert_entity => $cert_entity,
            subject => $subject,
            issuer => $issuer,
            valid_to => $valid_to,
            key_size => $key_size,
            days_remaining => $days_remaining
        };
    }

    if (scalar(keys %{$self->{certificates}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No security certificates found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check security certificates installed on the switch (HTTPS, syslog, LDAP, RADIUS, FCAP).
Monitors certificate validity and expiration.

Requires Fabric OS 8.2.1 or later with REST API access.

=over 8

=item B<--filter-cert-type>

Filter certificates by type (can be a regexp, e.g. 'https', 'syslog', 'ldap', 'radius', 'fcap', 'commoncert').

=item B<--filter-cert-entity>

Filter certificates by entity (can be a regexp, e.g. 'cert', 'ca-cert', 'ca-client-cert').

=item B<--exclude-cert-type>

Exclude certificates by type (can be a regexp).

=item B<--exclude-cert-entity>

Exclude certificates by entity (can be a regexp).

=item B<--warning-expiration>

Number of days before expiration to trigger a warning (default: 30).

=item B<--critical-expiration>

Number of days before expiration to trigger a critical (default: 7).

=item B<--unknown-certificate-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{issuer}, %{subject}, %{valid_to}, %{cert_type}, %{display}

=item B<--warning-certificate-status>

Define the conditions to match for the status to be WARNING (default: '%{status} =~ /expiring/i').
You can use the following variables: %{status}, %{issuer}, %{subject}, %{valid_to}, %{cert_type}, %{display}

=item B<--critical-certificate-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} =~ /expired/i').
You can use the following variables: %{status}, %{issuer}, %{subject}, %{valid_to}, %{cert_type}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'certificates-total', 'certificates-valid', 'certificates-expired', 'certificates-expiring-soon',
'certificate-days-remaining', 'certificate-key-size'.

=back

=cut
