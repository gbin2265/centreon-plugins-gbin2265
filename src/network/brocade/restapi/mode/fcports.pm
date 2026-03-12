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

package network::brocade::restapi::mode::fcports;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);
use Digest::MD5 qw(md5_hex);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "operational status: %s [admin: %s]",
        $self->{result_values}->{oper_status},
        $self->{result_values}->{admin_status}
    );
}

sub prefix_port_output {
    my ($self, %options) = @_;

    return "Port '" . $options{instance_value}->{display} . "' ";
}

sub port_long_output {
    my ($self, %options) = @_;

    return "checking port '" . $options{instance_value}->{display} . "'";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'ports', type => 3, cb_prefix_output => 'prefix_port_output', cb_long_output => 'port_long_output', 
          indent_long_output => '    ', message_multiple => 'All FC ports are ok',
            group => [
                { name => 'status', type => 0, skipped_code => { -10 => 1 } },
                { name => 'traffic', type => 0, skipped_code => { -10 => 1 } },
                { name => 'errors', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{status} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{admin_status} eq "enabled" and %{oper_status} ne "online"',
            set => {
                key_values => [ { name => 'oper_status' }, { name => 'admin_status' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];

    $self->{maps_counters}->{traffic} = [
        { label => 'traffic-in', nlabel => 'port.traffic.in.bitspersecond', set => {
                key_values => [ { name => 'traffic_in', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic in: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'traffic-out', nlabel => 'port.traffic.out.bitspersecond', set => {
                key_values => [ { name => 'traffic_out', per_second => 1 }, { name => 'display' } ],
                output_template => 'traffic out: %s %s/s',
                output_change_bytes => 2,
                perfdatas => [
                    { template => '%s', unit => 'b/s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'frames-in', nlabel => 'port.frames.in.persecond', set => {
                key_values => [ { name => 'frames_in', per_second => 1 }, { name => 'display' } ],
                output_template => 'frames in: %.2f/s',
                perfdatas => [
                    { template => '%.2f', unit => '/s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'frames-out', nlabel => 'port.frames.out.persecond', set => {
                key_values => [ { name => 'frames_out', per_second => 1 }, { name => 'display' } ],
                output_template => 'frames out: %.2f/s',
                perfdatas => [
                    { template => '%.2f', unit => '/s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'speed', nlabel => 'port.speed.gbps', display_ok => 0, set => {
                key_values => [ { name => 'speed_gbps' }, { name => 'display' } ],
                output_template => 'speed: %s Gbps',
                perfdatas => [
                    { template => '%s', unit => 'Gbps', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'bytes-in-total', nlabel => 'port.bytes.in.total.count', display_ok => 0, set => {
                key_values => [ { name => 'bytes_in', diff => 1 }, { name => 'display' } ],
                output_template => 'bytes in: %s',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'bytes-out-total', nlabel => 'port.bytes.out.total.count', display_ok => 0, set => {
                key_values => [ { name => 'bytes_out', diff => 1 }, { name => 'display' } ],
                output_template => 'bytes out: %s',
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{errors} = [
        { label => 'errors-crc', nlabel => 'port.errors.crc.count', set => {
                key_values => [ { name => 'crc_errors', diff => 1 }, { name => 'display' } ],
                output_template => 'CRC errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-enc-out', nlabel => 'port.errors.encoding.out.count', set => {
                key_values => [ { name => 'enc_out', diff => 1 }, { name => 'display' } ],
                output_template => 'encoding errors out: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-link-failures', nlabel => 'port.errors.link.failures.count', set => {
                key_values => [ { name => 'link_failures', diff => 1 }, { name => 'display' } ],
                output_template => 'link failures: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-loss-signal', nlabel => 'port.errors.loss.signal.count', set => {
                key_values => [ { name => 'loss_signal', diff => 1 }, { name => 'display' } ],
                output_template => 'loss of signal: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-loss-sync', nlabel => 'port.errors.loss.sync.count', set => {
                key_values => [ { name => 'loss_sync', diff => 1 }, { name => 'display' } ],
                output_template => 'loss of sync: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-class3-discards', nlabel => 'port.errors.class3.discards.count', set => {
                key_values => [ { name => 'class3_discards', diff => 1 }, { name => 'display' } ],
                output_template => 'class3 discards: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-invalid-words', nlabel => 'port.errors.invalid.words.count', set => {
                key_values => [ { name => 'invalid_words', diff => 1 }, { name => 'display' } ],
                output_template => 'invalid words: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-invalid-crcs', nlabel => 'port.errors.invalid.crcs.count', set => {
                key_values => [ { name => 'invalid_crcs', diff => 1 }, { name => 'display' } ],
                output_template => 'invalid CRCs: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-disparity', nlabel => 'port.errors.disparity.count', set => {
                key_values => [ { name => 'encoding_disparity', diff => 1 }, { name => 'display' } ],
                output_template => 'disparity errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-too-many-rdys', nlabel => 'port.errors.toomanyrdys.count', set => {
                key_values => [ { name => 'too_many_rdys', diff => 1 }, { name => 'display' } ],
                output_template => 'too many RDYs: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-frames-too-long', nlabel => 'port.errors.frames.toolong.count', set => {
                key_values => [ { name => 'frames_too_long', diff => 1 }, { name => 'display' } ],
                output_template => 'frames too long: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-truncated-frames', nlabel => 'port.errors.frames.truncated.count', set => {
                key_values => [ { name => 'truncated_frames', diff => 1 }, { name => 'display' } ],
                output_template => 'truncated frames: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-bad-eof', nlabel => 'port.errors.badeof.count', set => {
                key_values => [ { name => 'bad_eofs', diff => 1 }, { name => 'display' } ],
                output_template => 'bad EOFs: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-address', nlabel => 'port.errors.address.count', set => {
                key_values => [ { name => 'address_errors', diff => 1 }, { name => 'display' } ],
                output_template => 'address errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-delimiter', nlabel => 'port.errors.delimiter.count', set => {
                key_values => [ { name => 'delimiter_errors', diff => 1 }, { name => 'display' } ],
                output_template => 'delimiter errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-enc-disp-frame', nlabel => 'port.errors.encodingdisparityframe.count', set => {
                key_values => [ { name => 'enc_disp_frame', diff => 1 }, { name => 'display' } ],
                output_template => 'enc disp in frame: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-multicast-timeouts', nlabel => 'port.errors.multicast.timeouts.count', set => {
                key_values => [ { name => 'multicast_timeouts', diff => 1 }, { name => 'display' } ],
                output_template => 'multicast timeouts: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-primitive-seq', nlabel => 'port.errors.primitiveseq.count', set => {
                key_values => [ { name => 'primitive_seq_errors', diff => 1 }, { name => 'display' } ],
                output_template => 'primitive seq errors: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-fec-corrected', nlabel => 'port.errors.fec.corrected.count', display_ok => 0, set => {
                key_values => [ { name => 'fec_corrected', diff => 1 }, { name => 'display' } ],
                output_template => 'FEC corrected: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'errors-fec-uncorrected', nlabel => 'port.errors.fec.uncorrected.count', set => {
                key_values => [ { name => 'fec_uncorrected', diff => 1 }, { name => 'display' } ],
                output_template => 'FEC uncorrected: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'bb-credit-zero', nlabel => 'port.bbcreditzero.count', display_ok => 0, set => {
                key_values => [ { name => 'bb_credit_zero', diff => 1 }, { name => 'display' } ],
                output_template => 'BB credit zero: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'frames-tx-total', nlabel => 'port.frames.tx.total.count', display_ok => 0, set => {
                key_values => [ { name => 'frames_tx', diff => 1 }, { name => 'display' } ],
                output_template => 'frames TX total: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'frames-rx-total', nlabel => 'port.frames.rx.total.count', display_ok => 0, set => {
                key_values => [ { name => 'frames_rx', diff => 1 }, { name => 'display' } ],
                output_template => 'frames RX total: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
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
        'filter-port-name:s'   => { name => 'filter_port_name' },
        'filter-port-wwn:s'    => { name => 'filter_port_wwn' },
        'filter-slot-number:s' => { name => 'filter_slot_number' },
        'exclude-port-name:s'   => { name => 'exclude_port_name' },
        'exclude-port-wwn:s'    => { name => 'exclude_port_wwn' },
        'exclude-slot-number:s' => { name => 'exclude_slot_number' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $ports = $options{custom}->get_fcport_info();
    my $stats = $options{custom}->get_fcport_statistics();

    $self->{ports} = {};
    $self->{cache_name} = 'brocade_restapi_' . $options{custom}->get_hostname() . '_' . $options{custom}->get_port() . '_' . 
        $self->{mode} . '_' . md5_hex(
            (defined($self->{option_results}->{filter_port_name}) ? $self->{option_results}->{filter_port_name} : '') . '_' .
            (defined($self->{option_results}->{filter_port_wwn}) ? $self->{option_results}->{filter_port_wwn} : '') . '_' .
            (defined($self->{option_results}->{filter_slot_number}) ? $self->{option_results}->{filter_slot_number} : '')
        );

    # Build port info hash
    my $port_data = $ports->{'Response'}->{'fibrechannel'} // $ports->{'brocade-interface'}->{'fibrechannel'} // [];
    $port_data = [$port_data] if (ref($port_data) ne 'ARRAY');
    
    my %port_info;
    foreach my $port (@{$port_data}) {
        my $port_name = $port->{'name'} // next;
        $port_info{$port_name} = $port;
    }

    # Build statistics hash
    my $stats_data = $stats->{'Response'}->{'fibrechannel-statistics'} // $stats->{'brocade-interface'}->{'fibrechannel-statistics'} // [];
    $stats_data = [$stats_data] if (ref($stats_data) ne 'ARRAY');
    
    my %port_stats;
    foreach my $stat (@{$stats_data}) {
        my $port_name = $stat->{'name'} // next;
        $port_stats{$port_name} = $stat;
    }

    # Process ports
    foreach my $port_name (keys %port_info) {
        my $port = $port_info{$port_name};
        my $stat = $port_stats{$port_name} // {};

        # Extract slot and port from name (format: slot/port)
        my ($slot_number, $port_number) = split(/\//, $port_name);

        # Apply filters
        if (defined($self->{option_results}->{filter_port_name}) && $self->{option_results}->{filter_port_name} ne '' &&
            $port_name !~ /$self->{option_results}->{filter_port_name}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_port_wwn}) && $self->{option_results}->{filter_port_wwn} ne '' &&
            defined($port->{'wwn'}) && $port->{'wwn'} !~ /$self->{option_results}->{filter_port_wwn}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_slot_number}) && $self->{option_results}->{filter_slot_number} ne '' &&
            defined($slot_number) && $slot_number !~ /$self->{option_results}->{filter_slot_number}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_port_name}) && $self->{option_results}->{exclude_port_name} ne '' &&
            $port_name =~ /$self->{option_results}->{exclude_port_name}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_port_wwn}) && $self->{option_results}->{exclude_port_wwn} ne '' &&
            defined($port->{'wwn'}) && $port->{'wwn'} =~ /$self->{option_results}->{exclude_port_wwn}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_slot_number}) && $self->{option_results}->{exclude_slot_number} ne '' &&
            defined($slot_number) && $slot_number =~ /$self->{option_results}->{exclude_slot_number}/) {
            next;
        }

        # Map operational status
        my $oper_status = 'unknown';
        my $oper_status_code = $port->{'operational-status'};
        if (defined($oper_status_code)) {
            my %oper_status_map = (
                0 => 'undefined',
                2 => 'online',
                3 => 'offline',
                5 => 'faulty',
                6 => 'testing'
            );
            $oper_status = $oper_status_map{$oper_status_code} // lc($oper_status_code);
        }

        # Map admin status
        my $admin_status = 'unknown';
        my $is_enabled = $port->{'is-enabled-state'};
        if (defined($is_enabled)) {
            $admin_status = $is_enabled ? 'enabled' : 'disabled';
        }

        # Get statistics - convert words to bytes (1 word = 4 bytes) to bits
        my $in_words = $stat->{'in-octets'} // $stat->{'in-words'} // 0;
        my $out_words = $stat->{'out-octets'} // $stat->{'out-words'} // 0;
        
        # If in-octets exists, it's already in bytes; if in-words, multiply by 4
        my $in_bytes = defined($stat->{'in-octets'}) ? $in_words : ($in_words * 4);
        my $out_bytes = defined($stat->{'out-octets'}) ? $out_words : ($out_words * 4);

        # Get speed in Gbps
        my $speed_gbps = 0;
        if (defined($port->{'speed'})) {
            # Speed is often in bps or Gbps, normalize
            my $speed = $port->{'speed'};
            if ($speed > 1000000000) {
                $speed_gbps = $speed / 1000000000;
            } else {
                $speed_gbps = $speed;
            }
        }

        $self->{ports}->{$port_name} = {
            display => $port_name,
            status => {
                display => $port_name,
                oper_status => $oper_status,
                admin_status => $admin_status
            },
            traffic => {
                display => $port_name,
                traffic_in => $in_bytes * 8,  # Convert to bits
                traffic_out => $out_bytes * 8,
                frames_in => $stat->{'in-frames'} // 0,
                frames_out => $stat->{'out-frames'} // 0,
                speed_gbps => $speed_gbps,
                bytes_in => $in_bytes,
                bytes_out => $out_bytes
            },
            errors => {
                display => $port_name,
                crc_errors => $stat->{'crc-errors'} // 0,
                enc_out => $stat->{'encoding-errors-outside-frame'} // $stat->{'enc-out'} // 0,
                link_failures => $stat->{'link-failures'} // 0,
                loss_signal => $stat->{'loss-of-signal'} // 0,
                loss_sync => $stat->{'loss-of-sync'} // 0,
                class3_discards => $stat->{'class3-discards'} // $stat->{'class-3-discards'} // 0,
                invalid_words => $stat->{'invalid-transmission-words'} // 0,
                invalid_crcs => $stat->{'invalid-crcs'} // 0,
                encoding_disparity => $stat->{'encoding-disparity-errors'} // 0,
                too_many_rdys => $stat->{'too-many-rdys'} // 0,
                frames_too_long => $stat->{'frames-too-long'} // 0,
                truncated_frames => $stat->{'truncated-frames'} // 0,
                bad_eofs => $stat->{'bad-eofs-received'} // $stat->{'bad-eof'} // 0,
                address_errors => $stat->{'address-errors'} // 0,
                delimiter_errors => $stat->{'delimiter-errors'} // 0,
                enc_disp_frame => $stat->{'encoding-disparity-frame'} // 0,
                multicast_timeouts => $stat->{'multicast-timeouts'} // 0,
                primitive_seq_errors => $stat->{'primitive-sequence-protocol-error'} // 0,
                fec_corrected => $stat->{'fec-corrected'} // 0,
                fec_uncorrected => $stat->{'fec-uncorrected'} // 0,
                bb_credit_zero => $stat->{'bb-credit-zero'} // 0,
                frames_tx => $stat->{'out-frames'} // 0,
                frames_rx => $stat->{'in-frames'} // 0
            }
        };
    }

    if (scalar(keys %{$self->{ports}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No FC ports found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check FC ports status and statistics.

=over 8

=item B<--filter-port-name>

Filter ports by name (can be a regexp).

=item B<--filter-port-wwn>

Filter ports by WWN (can be a regexp).

=item B<--filter-slot-number>

Filter ports by slot number (can be a regexp).

=item B<--exclude-port-name>

Exclude ports by name (can be a regexp).

=item B<--exclude-port-wwn>

Exclude ports by WWN (can be a regexp).

=item B<--exclude-slot-number>

Exclude ports by slot number (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{oper_status}, %{admin_status}, %{display}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{oper_status}, %{admin_status}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{admin_status} eq "enabled" and %{oper_status} ne "online"').
You can use the following variables: %{oper_status}, %{admin_status}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'traffic-in', 'traffic-out', 'frames-in', 'frames-out', 'speed',
'bytes-in-total', 'bytes-out-total',
'errors-crc', 'errors-enc-out', 'errors-link-failures', 
'errors-loss-signal', 'errors-loss-sync', 'errors-class3-discards',
'errors-invalid-words', 'errors-invalid-crcs', 'errors-disparity',
'errors-too-many-rdys', 'errors-frames-too-long', 'errors-truncated-frames',
'errors-bad-eof', 'errors-address', 'errors-delimiter', 'errors-enc-disp-frame',
'errors-multicast-timeouts', 'errors-primitive-seq',
'errors-fec-corrected', 'errors-fec-uncorrected',
'bb-credit-zero', 'frames-tx-total', 'frames-rx-total'.

=back

=cut
