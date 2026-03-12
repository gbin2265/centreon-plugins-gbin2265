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

package network::brocade::restapi::mode::switchstatus;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "operational status: %s [enabled: %s]",
        $self->{result_values}->{oper_status},
        $self->{result_values}->{enabled}
    );
}

sub prefix_switch_output {
    my ($self, %options) = @_;

    return "Switch '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'switches', type => 1, cb_prefix_output => 'prefix_switch_output', message_multiple => 'All switches are ok' }
    ];

    $self->{maps_counters}->{switches} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{enabled} eq "true" and %{oper_status} !~ /online|healthy/i',
            set => {
                key_values => [ { name => 'oper_status' }, { name => 'enabled' }, { name => 'display' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'uptime', nlabel => 'switch.uptime.seconds', set => {
                key_values => [ { name => 'uptime' }, { name => 'display' } ],
                output_template => 'uptime: %s s',
                perfdatas => [
                    { template => '%s', unit => 's', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'cpu-utilization', nlabel => 'switch.cpu.utilization.percentage', set => {
                key_values => [ { name => 'cpu_usage' }, { name => 'display' } ],
                output_template => 'CPU usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-usage', nlabel => 'switch.memory.usage.bytes', set => {
                key_values => [ { name => 'memory_used' }, { name => 'display' } ],
                output_template => 'memory used: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-usage-prct', nlabel => 'switch.memory.usage.percentage', set => {
                key_values => [ { name => 'memory_prct' }, { name => 'display' } ],
                output_template => 'memory usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'memory-free', nlabel => 'switch.memory.free.bytes', display_ok => 0, set => {
                key_values => [ { name => 'memory_free' }, { name => 'display' } ],
                output_template => 'memory free: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'flash-usage-prct', nlabel => 'switch.flash.usage.percentage', set => {
                key_values => [ { name => 'flash_prct' }, { name => 'display' } ],
                output_template => 'flash usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'ports-enabled', nlabel => 'switch.ports.enabled.count', set => {
                key_values => [ { name => 'ports_enabled' }, { name => 'display' } ],
                output_template => 'ports enabled: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'ports-online', nlabel => 'switch.ports.online.count', set => {
                key_values => [ { name => 'ports_online' }, { name => 'display' } ],
                output_template => 'ports online: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'ports-offline', nlabel => 'switch.ports.offline.count', set => {
                key_values => [ { name => 'ports_offline' }, { name => 'display' } ],
                output_template => 'ports offline: %s',
                perfdatas => [
                    { template => '%s', min => 0, label_extra_instance => 1 }
                ]
            }
        },
        { label => 'ports-faulty', nlabel => 'switch.ports.faulty.count', set => {
                key_values => [ { name => 'ports_faulty' }, { name => 'display' } ],
                output_template => 'ports faulty: %s',
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
        'filter-switch-name:s' => { name => 'filter_switch_name' },
        'filter-switch-wwn:s'  => { name => 'filter_switch_wwn' },
        'exclude-switch-name:s' => { name => 'exclude_switch_name' },
        'exclude-switch-wwn:s'  => { name => 'exclude_switch_wwn' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $switches = $options{custom}->get_switch_info();
    my $ports_data = $options{custom}->get_fcport_info();
    my $chassis_data = $options{custom}->get_chassis_info();

    $self->{switches} = {};

    my $switch_data = $switches->{'Response'}->{'fibrechannel-switch'} // $switches->{'brocade-fibrechannel-switch'}->{'fibrechannel-switch'} // [];
    $switch_data = [$switch_data] if (ref($switch_data) ne 'ARRAY');

    # Parse port data for counting
    my $port_list = $ports_data->{'Response'}->{'fibrechannel'} // $ports_data->{'brocade-interface'}->{'fibrechannel'} // [];
    $port_list = [$port_list] if (ref($port_list) ne 'ARRAY');

    my ($ports_online, $ports_offline, $ports_faulty, $ports_enabled) = (0, 0, 0, 0);
    foreach my $port (@{$port_list}) {
        my $oper_status = $port->{'operational-status'} // 0;
        my $is_enabled = $port->{'is-enabled-state'};
        
        $ports_enabled++ if ($is_enabled);
        
        if ($oper_status == 2) {
            $ports_online++;
        } elsif ($oper_status == 3) {
            $ports_offline++;
        } elsif ($oper_status == 5) {
            $ports_faulty++;
        }
    }

    # Parse chassis for CPU/memory
    my $chassis_info = $chassis_data->{'Response'}->{'chassis'} // $chassis_data->{'brocade-chassis'}->{'chassis'} // {};
    $chassis_info = $chassis_info->[0] if (ref($chassis_info) eq 'ARRAY');

    # Try to get CPU from MAPS system-resources first (available since v8.2.1)
    my $cpu_usage = 0;
    my $maps_resources;
    eval {
        $maps_resources = $options{custom}->get_maps_system_resources();
    };
    if (!$@ && defined($maps_resources)) {
        my $resources = $maps_resources->{'Response'}->{'system-resources'} // 
                        $maps_resources->{'brocade-maps'}->{'system-resources'} // {};
        $resources = $resources->[0] if (ref($resources) eq 'ARRAY');
        $cpu_usage = $resources->{'cpu-usage'} // 0;
    }
    
    # Fallback to chassis cpu-usage if MAPS didn't work
    if ($cpu_usage == 0) {
        $cpu_usage = $chassis_info->{'cpu-usage'} // 0;
    }

    # Memory: API returns total-memory, used-memory, free-memory (in KB)
    my $memory_total = $chassis_info->{'total-memory'} // 
                       $chassis_info->{'memory-capacity'} // 0;
    my $memory_used = $chassis_info->{'used-memory'} // 
                      $chassis_info->{'memory-used'} // 0;
    my $memory_free = $chassis_info->{'free-memory'} //
                      $chassis_info->{'available-memory'} // 0;
    
    # Brocade FOS REST API returns memory values in KB — always convert to bytes
    $memory_total = $memory_total * 1024 if ($memory_total > 0);
    $memory_used = $memory_used * 1024 if ($memory_used > 0);
    $memory_free = $memory_free * 1024 if ($memory_free > 0);
    
    # Calculate free if not provided
    if ($memory_free == 0 && $memory_used > 0 && $memory_total > 0) {
        $memory_free = $memory_total - $memory_used;
    }
    
    my $memory_prct = ($memory_total > 0) ? ($memory_used / $memory_total * 100) : 0;
    
    my $flash_prct = $chassis_info->{'flash-usage'} // 0;

    # Fetch MAPS status once (outside loop) — data is switch-independent
    my $maps_status;
    eval {
        $maps_status = $options{custom}->get_maps_status();
    };
    my $maps_health;
    if (!$@ && defined($maps_status)) {
        my $maps_data = $maps_status->{'Response'}->{'switch-status-policy-report'} // 
                       $maps_status->{'brocade-maps'}->{'switch-status-policy-report'} // [];
        $maps_data = [$maps_data] if (ref($maps_data) ne 'ARRAY');
        
        foreach my $report (@{$maps_data}) {
            if (defined($report->{'switch-health'})) {
                $maps_health = lc($report->{'switch-health'});
                last;
            }
        }
    }

    foreach my $switch (@{$switch_data}) {
        my $switch_name = $switch->{'name'} // $switch->{'switch-name'} // $switch->{'user-friendly-name'} // 'unknown';
        my $switch_wwn = $switch->{'wwn'} // '';

        if (defined($self->{option_results}->{filter_switch_name}) && $self->{option_results}->{filter_switch_name} ne '' &&
            $switch_name !~ /$self->{option_results}->{filter_switch_name}/) {
            next;
        }
        if (defined($self->{option_results}->{filter_switch_wwn}) && $self->{option_results}->{filter_switch_wwn} ne '' &&
            $switch_wwn !~ /$self->{option_results}->{filter_switch_wwn}/) {
            next;
        }

        # Apply excludes
        if (defined($self->{option_results}->{exclude_switch_name}) && $self->{option_results}->{exclude_switch_name} ne '' &&
            $switch_name =~ /$self->{option_results}->{exclude_switch_name}/) {
            next;
        }
        if (defined($self->{option_results}->{exclude_switch_wwn}) && $self->{option_results}->{exclude_switch_wwn} ne '' &&
            $switch_wwn =~ /$self->{option_results}->{exclude_switch_wwn}/) {
            next;
        }

        # Map operational status
        my $oper_status = 'unknown';
        my $oper_status_code = $switch->{'operational-status'};
        if (defined($oper_status_code)) {
            my %oper_status_map = (
                0 => 'undefined',
                2 => 'online',
                3 => 'offline',
                4 => 'testing',
                5 => 'faulty'
            );
            $oper_status = $oper_status_map{$oper_status_code} // lc($oper_status_code);
        }

        # Get enabled state
        my $enabled = 'unknown';
        if (defined($switch->{'is-enabled-state'})) {
            $enabled = $switch->{'is-enabled-state'} ? 'true' : 'false';
        }

        # Calculate uptime in seconds
        my $uptime = $switch->{'up-time'} // 0;

        # Use pre-fetched MAPS health status if oper_status is still unknown
        if ($oper_status eq 'unknown' && defined($maps_health)) {
            $oper_status = $maps_health;
        }

        $self->{switches}->{$switch_name} = {
            display => $switch_name,
            oper_status => $oper_status,
            enabled => $enabled,
            uptime => $uptime,
            cpu_usage => $cpu_usage,
            memory_used => $memory_used,
            memory_free => $memory_free,
            memory_prct => $memory_prct,
            flash_prct => $flash_prct,
            ports_enabled => $ports_enabled,
            ports_online => $ports_online,
            ports_offline => $ports_offline,
            ports_faulty => $ports_faulty
        };
    }

    if (scalar(keys %{$self->{switches}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No switch found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check switch status.

=over 8

=item B<--filter-switch-name>

Filter switches by name (can be a regexp).

=item B<--filter-switch-wwn>

Filter switches by WWN (can be a regexp).

=item B<--exclude-switch-name>

Exclude switches by name (can be a regexp).

=item B<--exclude-switch-wwn>

Exclude switches by WWN (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{oper_status}, %{enabled}, %{display}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{oper_status}, %{enabled}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{enabled} eq "true" and %{oper_status} !~ /online|healthy/i').
You can use the following variables: %{oper_status}, %{enabled}, %{display}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'uptime', 'cpu-utilization', 'memory-usage', 'memory-usage-prct', 'memory-free',
'flash-usage-prct', 'ports-enabled', 'ports-online', 'ports-offline', 'ports-faulty'.

=back

=cut
