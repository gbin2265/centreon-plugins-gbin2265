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

package hardware::server::hp::oneview::restapi::mode::appliancenodes;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold catalog_status_calc);

# -------------------------------------------------------------------------
# Custom output helpers
# -------------------------------------------------------------------------

sub custom_node_status_output {
    my ($self, %options) = @_;
    return sprintf(
        'status: %s [version: %s]',
        $self->{result_values}->{status},
        $self->{result_values}->{firmware_version}
    );
}

# -------------------------------------------------------------------------
# Counters definition
# -------------------------------------------------------------------------

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ', skipped_code => { -10 => 1 } },
        { name => 'nodes', type => 1, cb_prefix_output => 'prefix_node_output',
          message_multiple => 'All appliance nodes are ok', skipped_code => { -10 => 1 } },
        { name => 'disks', type => 2, cb_prefix_output => 'prefix_disk_output',
          cb_long_output => 'disk_long_output',
          message_multiple => 'All node disks are ok', skipped_code => { -10 => 1 } },
        { name => 'services', type => 2, cb_prefix_output => 'prefix_service_output',
          cb_long_output => 'service_long_output',
          message_multiple => 'All node services are ok', skipped_code => { -10 => 1 } },
        { name => 'interfaces', type => 2, cb_prefix_output => 'prefix_iface_output',
          cb_long_output => 'iface_long_output',
          message_multiple => 'All node interfaces are ok', skipped_code => { -10 => 1 } },
    ];

    # ---- Global summary ----
    $self->{maps_counters}->{global} = [
        { label => 'nodes-total', nlabel => 'appliance.nodes.total.count', display_ok => 0, set => {
                key_values      => [ { name => 'total' } ],
                output_template => 'total nodes: %d',
                perfdatas       => [ { value => 'total', template => '%d', min => 0 } ],
            }
        },
        { label => 'nodes-status-ok', nlabel => 'appliance.nodes.status.ok.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_ok' } ],
                output_template => 'nodes ok: %d',
                perfdatas       => [ { value => 'status_ok', template => '%d', min => 0 } ],
            }
        },
        { label => 'nodes-status-failed', nlabel => 'appliance.nodes.status.failed.count', display_ok => 0, set => {
                key_values      => [ { name => 'status_failed' } ],
                output_template => 'nodes failed: %d',
                perfdatas       => [ { value => 'status_failed', template => '%d', min => 0 } ],
            }
        },
        # Number of nodes acting as active/primary
        { label => 'nodes-role-active', nlabel => 'appliance.nodes.role.active.count', display_ok => 0, set => {
                key_values      => [ { name => 'role_active' } ],
                output_template => 'active nodes: %d',
                perfdatas       => [ { value => 'role_active', template => '%d', min => 0 } ],
            }
        },
        # Number of nodes acting as standby
        { label => 'nodes-role-standby', nlabel => 'appliance.nodes.role.standby.count', display_ok => 0, set => {
                key_values      => [ { name => 'role_standby' } ],
                output_template => 'standby nodes: %d',
                perfdatas       => [ { value => 'role_standby', template => '%d', min => 0 } ],
            }
        },
    ];

    # ---- Per node ----
    $self->{maps_counters}->{nodes} = [
        # Status + role + version (drives OK/WARN/CRIT)
        { label => 'node-status', threshold => 0, set => {
                key_values => [
                    { name => 'status' },
                    { name => 'role' },
                    { name => 'firmware_version' },
                    { name => 'hostname' },
                    { name => 'display' },
                ],
                closure_custom_calc            => \&catalog_status_calc,
                closure_custom_output          => $self->can('custom_node_status_output'),
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
        # CPU usage %
        { label => 'node-cpu-utilization', nlabel => 'appliance.node.cpu.utilization.percentage', display_ok => 0, set => {
                key_values      => [ { name => 'cpu_utilization' }, { name => 'display' } ],
                output_template => 'cpu: %.1f %%',
                perfdatas       => [
                    { value => 'cpu_utilization', template => '%.1f', unit => '%',
                      min => 0, max => 100,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Memory usage %
        { label => 'node-memory-utilization', nlabel => 'appliance.node.memory.utilization.percentage', display_ok => 0, set => {
                key_values      => [ { name => 'memory_utilization' }, { name => 'display' } ],
                output_template => 'memory: %.1f %%',
                perfdatas       => [
                    { value => 'memory_utilization', template => '%.1f', unit => '%',
                      min => 0, max => 100,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Uptime seconds
        { label => 'node-uptime', nlabel => 'appliance.node.uptime.seconds', display_ok => 0, set => {
                key_values      => [ { name => 'uptime_seconds' }, { name => 'display' } ],
                output_template => 'uptime: %d s',
                perfdatas       => [
                    { value => 'uptime_seconds', template => '%d', unit => 's', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        # Total managed resources on this node
        { label => 'node-managed-resources', nlabel => 'appliance.node.managed.resources.count', display_ok => 0, set => {
                key_values      => [ { name => 'managed_resources' }, { name => 'display' } ],
                output_template => 'managed resources: %d',
                perfdatas       => [
                    { value => 'managed_resources', template => '%d', min => 0,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];

    # ---- Per disk volume ----
    $self->{maps_counters}->{disks} = [
        { label => 'disk-usage', nlabel => 'appliance.node.disk.usage.bytes', set => {
                key_values      => [ { name => 'used_bytes' }, { name => 'total_bytes' }, { name => 'display' } ],
                output_template => 'used: %s',
                output_change_bytes => 1,
                perfdatas       => [
                    { value => 'used_bytes', template => '%d', unit => 'B', min => 0,
                      max => 'total_bytes',
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'disk-free', nlabel => 'appliance.node.disk.free.bytes', display_ok => 0, set => {
                key_values      => [ { name => 'free_bytes' }, { name => 'total_bytes' }, { name => 'display' } ],
                output_template => 'free: %s',
                output_change_bytes => 1,
                perfdatas       => [
                    { value => 'free_bytes', template => '%d', unit => 'B', min => 0,
                      max => 'total_bytes',
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
        { label => 'disk-usage-prct', nlabel => 'appliance.node.disk.usage.percentage', display_ok => 0, set => {
                key_values      => [ { name => 'used_prct' }, { name => 'display' } ],
                output_template => 'used: %.1f %%',
                perfdatas       => [
                    { value => 'used_prct', template => '%.1f', unit => '%', min => 0, max => 100,
                      label_extra_instance => 1, instance_use => 'display' },
                ],
            }
        },
    ];

    # ---- Per service ----
    $self->{maps_counters}->{services} = [
        { label => 'service-status', threshold => 0, set => {
                key_values => [
                    { name => 'service_status' },
                    { name => 'display' },
                ],
                closure_custom_calc   => \&catalog_status_calc,
                closure_custom_output => sub {
                    my ($self, %options) = @_;
                    return sprintf('status: %s', $self->{result_values}->{service_status});
                },
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];

    # ---- Per network interface ----
    $self->{maps_counters}->{interfaces} = [
        { label => 'interface-status', threshold => 0, set => {
                key_values => [
                    { name => 'link_status' },
                    { name => 'ip_address' },
                    { name => 'display' },
                ],
                closure_custom_calc   => \&catalog_status_calc,
                closure_custom_output => sub {
                    my ($self, %options) = @_;
                    return sprintf('link: %s [ip: %s]',
                        $self->{result_values}->{link_status},
                        $self->{result_values}->{ip_address} // 'n/a');
                },
                closure_custom_perfdata        => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold,
            }
        },
    ];
}

sub prefix_node_output {
    my ($self, %options) = @_;
    my $role = $options{instance_value}->{role} // 'unknown';
    return "Node '" . $options{instance_value}->{display} . "' [" . $role . "] ";
}

sub prefix_disk_output {
    my ($self, %options) = @_;
    return "Disk '" . $options{instance_value}->{display} . "' ";
}

sub disk_long_output {
    my ($self, %options) = @_;
    return "checking disk '" . $options{instance_value}->{display} . "'";
}

sub prefix_service_output {
    my ($self, %options) = @_;
    return "Service '" . $options{instance_value}->{display} . "' ";
}

sub service_long_output {
    my ($self, %options) = @_;
    return "checking service '" . $options{instance_value}->{display} . "'";
}

sub prefix_iface_output {
    my ($self, %options) = @_;
    return "Interface '" . $options{instance_value}->{display} . "' ";
}

sub iface_long_output {
    my ($self, %options) = @_;
    return "checking interface '" . $options{instance_value}->{display} . "'";
}

# -------------------------------------------------------------------------
# Constructor & options
# -------------------------------------------------------------------------

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-hostname:s'      => { name => 'filter_hostname' },
        'filter-role:s'          => { name => 'filter_role' },
        'filter-service:s'       => { name => 'filter_service' },
        'filter-disk:s'          => { name => 'filter_disk' },
        'filter-interface:s'     => { name => 'filter_interface' },
        'unknown-node-status:s'  => { name => 'unknown_node_status',
            default => '%{status} =~ /unknown/i' },
        'warning-node-status:s'  => { name => 'warning_node_status',
            default => '%{status} =~ /warning/i' },
        'critical-node-status:s' => { name => 'critical_node_status',
            default => '%{status} =~ /critical|failed/i' },
        'unknown-service-status:s'  => { name => 'unknown_service_status',  default => '' },
        'warning-service-status:s'  => { name => 'warning_service_status',  default => '' },
        'critical-service-status:s' => { name => 'critical_service_status',
            default => '%{service_status} =~ /stopped|error|failed/i' },
        'unknown-interface-status:s'  => { name => 'unknown_interface_status',  default => '' },
        'warning-interface-status:s'  => { name => 'warning_interface_status',  default => '' },
        'critical-interface-status:s' => { name => 'critical_interface_status',
            default => '%{link_status} =~ /down/i' },
        # Warn if the number of active nodes is not exactly 1
        'warning-nodes-role-active:s'  => { name => 'warning_nodes_role_active',  default => '' },
        'critical-nodes-role-active:s' => { name => 'critical_nodes_role_active', default => '' },
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);
    $self->change_macros(macros => [
        'warning_node_status', 'critical_node_status', 'unknown_node_status',
        'warning_service_status', 'critical_service_status', 'unknown_service_status',
        'warning_interface_status', 'critical_interface_status', 'unknown_interface_status',
    ]);
}

# -------------------------------------------------------------------------
# Data collection
# -------------------------------------------------------------------------

sub manage_selection {
    my ($self, %options) = @_;

    my $results = $options{custom}->request_api(url_path => '/rest/appliance/ha-nodes');

    $self->{global} = {
        total          => 0,
        status_ok      => 0,
        status_failed  => 0,
        role_active    => 0,
        role_standby   => 0,
    };
    $self->{nodes}      = {};
    $self->{disks}      = {};
    $self->{services}   = {};
    $self->{interfaces} = {};

    foreach my $node (@{$results->{members} // []}) {
        # Identify node by hostname, fall back to applianceUri or role+index
        # Build display name matching OneView console: "ENCL11-FRAME1, appliance bay 1"
        my $hostname;
        if (defined($node->{enclosureName}) && defined($node->{applianceBayNumber})) {
            $hostname = $node->{enclosureName} . ', appliance bay ' . $node->{applianceBayNumber};
        } elsif (defined($node->{enclosureName})) {
            $hostname = $node->{enclosureName};
        } else {
            $hostname = $node->{hostname} // $node->{name} // $node->{applianceUri} // 'node';
        }

        if (defined($self->{option_results}->{filter_hostname}) && $self->{option_results}->{filter_hostname} ne '' &&
            $hostname !~ /$self->{option_results}->{filter_hostname}/) {
            $self->{output}->output_add(
                long_msg => "skipping node '$hostname': no matching filter.", debug => 1
            );
            next;
        }

        my $role   = defined($node->{role})   ? lc($node->{role})   : 'unknown';
        my $status = defined($node->{status}) ? lc($node->{status}) : 'unknown';

        if (defined($self->{option_results}->{filter_role}) && $self->{option_results}->{filter_role} ne '' &&
            $role !~ /$self->{option_results}->{filter_role}/i) {
            $self->{output}->output_add(
                long_msg => "skipping node '$hostname': role '$role' no matching filter.", debug => 1
            );
            next;
        }

        # Global counters
        $self->{global}->{total}++;
        if ($status eq 'ok') {
            $self->{global}->{status_ok}++;
        } elsif ($status =~ /critical|fail/i) {
            $self->{global}->{status_failed}++;
        }
        $self->{global}->{role_active}++  if ($role =~ /^active$/i);
        $self->{global}->{role_standby}++ if ($role =~ /^standby$/i);

        # Make display key unique if multiple nodes with same hostname
        my $key = $hostname;
        my $idx = 1;
        while (exists $self->{nodes}->{$key}) {
            $key = $hostname . '_' . $idx++;
        }

        $self->{nodes}->{$key} = {
            display           => $key,
            hostname          => $hostname,
            role              => $role,
            status            => $status,
            firmware_version  => $node->{softwareVersion}  // 'n/a',
            cpu_utilization   => $node->{cpuPercentUsed}   // undef,
            memory_utilization => $node->{memoryPercentUsed} // undef,
            uptime_seconds    => $node->{uptimeSeconds}    // undef,
            managed_resources => $node->{managedResourceCount} // undef,
        };

        # ---- Disk volumes ----
        foreach my $vol (@{$node->{storageVolumeInfo} // []}) {
            my $vol_name = $vol->{name} // $vol->{volumeName} // 'vol';
            my $disk_key = $key . ':' . $vol_name;

            if (defined($self->{option_results}->{filter_disk}) && $self->{option_results}->{filter_disk} ne '' &&
                $disk_key !~ /$self->{option_results}->{filter_disk}/) {
                $self->{output}->output_add(long_msg => "skipping disk '$disk_key': no matching filter.", debug => 1);
                next;
            }

            my $total_bytes = defined($vol->{totalCapacityMib})     ? $vol->{totalCapacityMib} * 1024 * 1024     : undef;
            my $used_bytes  = defined($vol->{usedCapacityMib})      ? $vol->{usedCapacityMib}  * 1024 * 1024     : undef;
            my $free_bytes  = (defined($total_bytes) && defined($used_bytes)) ? $total_bytes - $used_bytes : undef;
            my $used_prct   = (defined($total_bytes) && $total_bytes > 0 && defined($used_bytes))
                ? ($used_bytes / $total_bytes) * 100 : undef;

            $self->{disks}->{$disk_key} = {
                display     => $disk_key,
                used_bytes  => $used_bytes,
                free_bytes  => $free_bytes,
                total_bytes => $total_bytes,
                used_prct   => $used_prct,
            };
        }

        # ---- Services ----
        foreach my $svc (@{$node->{services} // []}) {
            my $svc_name   = $svc->{name}   // $svc->{serviceName} // 'unknown';
            my $svc_status = lc($svc->{status} // 'unknown');
            my $svc_key    = $key . ':' . $svc_name;

            if (defined($self->{option_results}->{filter_service}) && $self->{option_results}->{filter_service} ne '' &&
                $svc_key !~ /$self->{option_results}->{filter_service}/) {
                $self->{output}->output_add(long_msg => "skipping service '$svc_key': no matching filter.", debug => 1);
                next;
            }

            $self->{services}->{$svc_key} = {
                display        => $svc_key,
                service_status => $svc_status,
            };
        }

        # ---- Network interfaces ----
        foreach my $iface (@{$node->{networkInterfaces} // []}) {
            my $if_name   = $iface->{name}       // $iface->{interfaceName} // 'eth0';
            my $link_stat = lc($iface->{linkStatus} // $iface->{status} // 'unknown');
            my $ip_addr   = $iface->{ipAddress}   // $iface->{ipv4Address} // undef;
            my $iface_key = $key . ':' . $if_name;

            if (defined($self->{option_results}->{filter_interface}) && $self->{option_results}->{filter_interface} ne '' &&
                $iface_key !~ /$self->{option_results}->{filter_interface}/) {
                $self->{output}->output_add(long_msg => "skipping interface '$iface_key': no matching filter.", debug => 1);
                next;
            }

            $self->{interfaces}->{$iface_key} = {
                display     => $iface_key,
                link_status => $link_stat,
                ip_address  => $ip_addr,
            };
        }
    }

    if (scalar(keys %{$self->{nodes}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No appliance nodes (Composers) found');
        $self->{output}->option_exit();
    }

    # Build dynamic message_multiple: "ENCL11-FRAME1 active, ENCL11-FRAME2 standby"
    my $node_summary = join(', ', map {
        $self->{nodes}->{$_}->{display} . ' ' . ($self->{nodes}->{$_}->{role} // 'unknown')
    } sort keys %{$self->{nodes}});

    # Update message_multiple in maps_counters_type for nodes group
    for my $group (@{$self->{maps_counters_type}}) {
        if ($group->{name} eq 'nodes') {
            $group->{message_multiple} = 'All appliance nodes are ok - ' . $node_summary;
            last;
        }
    }
}

1;

__END__

=head1 MODE

Check HPE OneView appliance HA nodes (Synergy Composers).

Each Composer node reports its role (Active/Standby), status, firmware version,
CPU/memory utilization, uptime and managed resource count.

Global perfdata: total nodes, status ok/failed counts, active/standby role counts.
Per-node perfdata: cpu utilization (%), memory utilization (%),
uptime (s), managed resources count.

=over 8

=item B<--filter-hostname>

Filter node by hostname (can be a regexp).

=item B<--filter-role>

Filter nodes by role, e.g. Active or Standby (can be a regexp).

=item B<--filter-disk>

Filter disk volumes by name (can be a regexp).
Example: --filter-disk='data' to only check the data volume.

=item B<--filter-service>

Filter services by name (can be a regexp).
Example: --filter-service='oneview-webservice'.

=item B<--filter-interface>

Filter network interfaces by name (can be a regexp).
Example: --filter-interface='eth0'.

=item B<--unknown-node-status>

Conditions for UNKNOWN node status (default: '%{status} =~ /unknown/i').
Variables: %{status}, %{role}, %{firmware_version}, %{hostname}, %{display}

=item B<--warning-node-status>

Conditions for WARNING node status (default: '%{status} =~ /warning/i').

=item B<--critical-node-status>

Conditions for CRITICAL node status
(default: '%{status} =~ /critical|failed/i').

=item B<--warning-*> B<--critical-*>

Global thresholds:
'nodes-total', 'nodes-status-ok', 'nodes-status-failed',
'nodes-role-active', 'nodes-role-standby'.

Per-node thresholds:
'node-cpu-utilization' (%), 'node-memory-utilization' (%),
'node-uptime' (s), 'node-managed-resources'.

=back

=cut
