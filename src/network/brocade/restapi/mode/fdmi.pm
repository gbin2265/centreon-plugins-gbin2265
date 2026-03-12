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

package network::brocade::restapi::mode::fdmi;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

sub custom_hba_output {
    my ($self, %options) = @_;

    return sprintf(
        "[vendor: %s] [model: %s] [driver: %s] [firmware: %s]",
        $self->{result_values}->{vendor},
        $self->{result_values}->{model},
        $self->{result_values}->{driver_version},
        $self->{result_values}->{firmware_version}
    );
}

sub prefix_hba_output {
    my ($self, %options) = @_;

    return "HBA '" . $options{instance_value}->{display} . "' ";
}

sub hba_long_output {
    my ($self, %options) = @_;

    return "checking HBA '" . $options{instance_value}->{display} . "'";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ' },
        { name => 'hbas', type => 3, cb_prefix_output => 'prefix_hba_output', cb_long_output => 'hba_long_output',
          indent_long_output => '    ', message_multiple => 'All HBAs are ok',
            group => [
                { name => 'info', type => 0, skipped_code => { -10 => 1 } },
                { name => 'ports', type => 0, skipped_code => { -10 => 1 } }
            ]
        }
    ];

    $self->{maps_counters}->{global} = [
        { label => 'hbas-total', nlabel => 'fdmi.hba.total.count', set => {
                key_values => [ { name => 'total' } ],
                output_template => 'total HBAs: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'ports-total', nlabel => 'fdmi.ports.total.count', set => {
                key_values => [ { name => 'total_ports' } ],
                output_template => 'total ports: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        }
    ];

    $self->{maps_counters}->{info} = [
        {
            label => 'hba-info',
            type => 0,
            set => {
                key_values => [ { name => 'vendor' }, { name => 'model' }, 
                               { name => 'driver_version' }, { name => 'firmware_version' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_hba_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];

    $self->{maps_counters}->{ports} = [
        { label => 'hba-ports', nlabel => 'hba.ports.count', set => {
                key_values => [ { name => 'port_count' }, { name => 'display' } ],
                output_template => 'ports: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
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
        'filter-hba:s'    => { name => 'filter_hba' },
        'filter-vendor:s' => { name => 'filter_vendor' },
        'exclude-hba:s'    => { name => 'exclude_hba' },
        'exclude-vendor:s' => { name => 'exclude_vendor' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $fdmi_data = $options{custom}->get_fdmi_info();

    $self->{global} = { total => 0, total_ports => 0 };
    $self->{hbas} = {};

    my $hba_list = $fdmi_data->{'Response'}->{'hba'} // $fdmi_data->{'brocade-fdmi'}->{'hba'} // [];
    $hba_list = [$hba_list] if (ref($hba_list) ne 'ARRAY');

    foreach my $hba (@{$hba_list}) {
        my $hba_id = $hba->{'hba-id'} // next;

        if (defined($self->{option_results}->{filter_hba}) && $self->{option_results}->{filter_hba} ne '' &&
            $hba_id !~ /$self->{option_results}->{filter_hba}/) {
            next;
        }

        my $vendor = $hba->{'vendor-identifier'} // $hba->{'manufacturer'} // 'unknown';
        
        if (defined($self->{option_results}->{filter_vendor}) && $self->{option_results}->{filter_vendor} ne '' &&
            $vendor !~ /$self->{option_results}->{filter_vendor}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_hba}) && $self->{option_results}->{exclude_hba} ne '' &&
            $hba_id =~ /$self->{option_results}->{exclude_hba}/) {
            next;
        }

        if (defined($self->{option_results}->{exclude_vendor}) && $self->{option_results}->{exclude_vendor} ne '' &&
            $vendor =~ /$self->{option_results}->{exclude_vendor}/) {
            next;
        }

        $self->{global}->{total}++;

        my $model = $hba->{'model'} // $hba->{'model-description'} // 'unknown';
        my $driver_version = $hba->{'driver-version'} // 'unknown';
        my $firmware_version = $hba->{'firmware-version'} // 'unknown';
        my $hardware_version = $hba->{'hardware-version'} // '';
        my $serial = $hba->{'serial-number'} // '';
        my $os_name = $hba->{'os-name-and-version'} // '';
        my $node_name = $hba->{'node-name'} // '';
        my $num_ports = $hba->{'number-of-ports'} // 1;
        
        $self->{global}->{total_ports} += $num_ports;

        # Truncate HBA ID for display (WWN format)
        my $display_name = $hba_id;
        if (length($display_name) > 23) {
            $display_name = substr($display_name, 0, 23);
        }

        $self->{hbas}->{$hba_id} = {
            display => $display_name,
            info => {
                display => $display_name,
                vendor => $vendor,
                model => $model,
                driver_version => $driver_version,
                firmware_version => $firmware_version
            },
            ports => {
                display => $display_name,
                port_count => $num_ports
            }
        };
    }

    if (scalar(keys %{$self->{hbas}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No HBAs found via FDMI.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check FDMI (Fabric Device Management Interface) registered HBA information.

=over 8

=item B<--filter-hba>

Filter HBAs by ID/WWN (can be a regexp).

=item B<--filter-vendor>

Filter HBAs by vendor (can be a regexp).

=item B<--exclude-hba>

Exclude HBAs by ID/WWN (can be a regexp).

=item B<--exclude-vendor>

Exclude HBAs by vendor (can be a regexp).

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'hbas-total', 'ports-total', 'hba-ports'.

=back

=cut
