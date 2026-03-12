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

package storage::hp::alletra::ssh::mode::stat;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;

# =============================================================================
# OUTPUT EXAMPLES FOR EACH COMPONENT
# =============================================================================
#
# statcpu -iter 1 -d 1 (component: cpu):
# 17:34:58 01/27/2022
# node,cpu user sys idle intr/s ctxt/s
#      0,0    1   0   99
#      0,1    1   1   98
#      0,2    0   1   99
#      0,3    1   1   98
#      0,4    0   1   99
#      0,5    0   1   99
#      0,6    4   1   95
#      0,7    0   0  100
#  0,total    1   1   98   7276   9026
#      1,0    0   0  100
#      1,1    0   0  100
#      1,2    0   0  100
#      1,3    0   1   99
#      1,4    0   0  100
#      1,5    0   1   99
#      1,6    0   2   98
#      1,7    0   0  100
#  1,total    0   1   99   5312   4799
#
# =============================================================================

sub custom_cpu_output {
    my ($self, %options) = @_;
    return sprintf(
        "User: %s%%, Sys: %s%%, Idle: %s%%, Usage: %s%%",
        $self->{result_values}->{user},
        $self->{result_values}->{sys},
        $self->{result_values}->{idle},
        $self->{result_values}->{usage}
    );
}

sub custom_cagetemp_output {
    my ($self, %options) = @_;
    return sprintf(
        "Temp: %s°C [Warning: %s°C, Critical: %s°C] State: %s",
        $self->{result_values}->{temp},
        $self->{result_values}->{hi_warning},
        $self->{result_values}->{critical},
        $self->{result_values}->{state}
    );
}

sub custom_cagetemp_perfdata {
    my ($self, %options) = @_;
    
    my $label = $self->{result_values}->{perfdata_label};
    my $state = $self->{result_values}->{state};
    
    # Determine status value based on state
    my $status_value = 0; # OK
    if ($state =~ /^Warning$/i) {
        $status_value = 1;
    } elsif ($state !~ /^OK$/i) {
        $status_value = 2; # Critical
    }
    
    $self->{output}->perfdata_add(
        label => $label . '.temperature.celsius',
        unit => 'C',
        value => $self->{result_values}->{temp},
        warning => $self->{result_values}->{hi_warning},
        critical => $self->{result_values}->{critical},
        min => 0
    );
    
    # Overall status for this sensor
    $self->{output}->perfdata_add(
        label => $label . '.status',
        value => $status_value,
        min => 0,
        max => 2
    );
}

sub custom_cagetemp_threshold {
    my ($self, %options) = @_;
    
    my $state = $self->{result_values}->{state};
    
    return 'ok' if ($state =~ /^OK$/i);
    return 'warning' if ($state =~ /^Warning$/i);
    return 'critical';
}

sub custom_space_output {
    my ($self, %options) = @_;
    return sprintf(
        "Raw Free: %s MiB, Usable Free: %s MiB",
        $self->{result_values}->{raw_free},
        $self->{result_values}->{usable_free}
    );
}

sub custom_space_perfdata {
    my ($self, %options) = @_;
    
    $self->{output}->perfdata_add(
        label => 'space.raw.free.mebibytes',
        unit => 'MiB',
        value => $self->{result_values}->{raw_free},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'space.usable.free.mebibytes',
        unit => 'MiB',
        value => $self->{result_values}->{usable_free},
        min => 0
    );
}

sub prefix_space_output {
    my ($self, %options) = @_;
    return "Space usage ";
}

sub custom_pdspace_output {
    my ($self, %options) = @_;
    return sprintf(
        "Size: %s MB, Volume: %s MB, Free: %s MB, Spare: %s MB",
        $self->{result_values}->{size_mb},
        $self->{result_values}->{volume_mb},
        $self->{result_values}->{free_mb},
        $self->{result_values}->{spare_mb}
    );
}

sub custom_pdspace_perfdata {
    my ($self, %options) = @_;
    
    my $id = $self->{result_values}->{id};
    
    $self->{output}->perfdata_add(
        label => 'pd.' . $id . '.size.megabytes',
        unit => 'MB',
        value => $self->{result_values}->{size_mb},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'pd.' . $id . '.volume.megabytes',
        unit => 'MB',
        value => $self->{result_values}->{volume_mb},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'pd.' . $id . '.spare.megabytes',
        unit => 'MB',
        value => $self->{result_values}->{spare_mb},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'pd.' . $id . '.free.megabytes',
        unit => 'MB',
        value => $self->{result_values}->{free_mb},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'pd.' . $id . '.unavailable.megabytes',
        unit => 'MB',
        value => $self->{result_values}->{unavail_mb},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'pd.' . $id . '.failed.megabytes',
        unit => 'MB',
        value => $self->{result_values}->{failed_mb},
        min => 0
    );
}

sub prefix_pdspace_output {
    my ($self, %options) = @_;
    return "PD " . $options{instance_value}->{id} . " [" . $options{instance_value}->{cagepos} . "] ";
}

sub long_pdspace_output {
    my ($self, %options) = @_;
    return sprintf(
        "PD %s [%s] - Size: %s MB, Volume: %s MB, Free: %s MB",
        $options{instance_value}->{id},
        $options{instance_value}->{cagepos},
        $options{instance_value}->{size_mb},
        $options{instance_value}->{volume_mb},
        $options{instance_value}->{free_mb}
    );
}

sub custom_vvspace_output {
    my ($self, %options) = @_;
    return sprintf(
        "Data Used: %s MB, VSize: %s MB, Used: %s%%",
        $self->{result_values}->{data_used_mb},
        $self->{result_values}->{vsize_mb},
        $self->{result_values}->{used_perc}
    );
}

sub custom_vvspace_perfdata {
    my ($self, %options) = @_;
    
    my $name = $self->{result_values}->{name};
    $name =~ s/[^a-zA-Z0-9]/_/g;
    
    $self->{output}->perfdata_add(
        label => 'vv.' . $name . '.data.used.mebibytes',
        unit => 'MB',
        value => $self->{result_values}->{data_used_mb},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'vv.' . $name . '.vsize.mebibytes',
        unit => 'MB',
        value => $self->{result_values}->{vsize_mb},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'vv.' . $name . '.used.percentage',
        unit => '%',
        value => $self->{result_values}->{used_perc},
        min => 0,
        max => 100
    );
}

sub prefix_vvspace_output {
    my ($self, %options) = @_;
    return "VV " . $options{instance_value}->{name} . " ";
}

sub long_vvspace_output {
    my ($self, %options) = @_;
    return sprintf(
        "VV %s - Data Used: %s MB, VSize: %s MB, Used: %s%%",
        $options{instance_value}->{name},
        $options{instance_value}->{data_used_mb},
        $options{instance_value}->{vsize_mb},
        $options{instance_value}->{used_perc}
    );
}

sub custom_cpgspace_output {
    my ($self, %options) = @_;
    return sprintf(
        "Used: %s MB, Free: %s MB, Total: %s MB",
        $self->{result_values}->{used},
        $self->{result_values}->{free},
        $self->{result_values}->{total}
    );
}

sub custom_cpgspace_perfdata {
    my ($self, %options) = @_;
    
    my $name = $self->{result_values}->{name};
    $name =~ s/[^a-zA-Z0-9]/_/g;
    
    $self->{output}->perfdata_add(
        label => 'cpg.' . $name . '.used.mebibytes',
        unit => 'MB',
        value => $self->{result_values}->{used},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'cpg.' . $name . '.free.mebibytes',
        unit => 'MB',
        value => $self->{result_values}->{free},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'cpg.' . $name . '.total.mebibytes',
        unit => 'MB',
        value => $self->{result_values}->{total},
        min => 0
    );
}

sub prefix_cpgspace_output {
    my ($self, %options) = @_;
    return "CPG " . $options{instance_value}->{name} . " ";
}

sub long_cpgspace_output {
    my ($self, %options) = @_;
    return sprintf(
        "CPG %s - Used: %s MB, Free: %s MB, Total: %s MB",
        $options{instance_value}->{name},
        $options{instance_value}->{used},
        $options{instance_value}->{free},
        $options{instance_value}->{total}
    );
}

sub custom_cap_output {
    my ($self, %options) = @_;
    return sprintf(
        "Total: %s MiB, Alloc: %s MiB, Free: %s MiB, Failed: %s MiB",
        $self->{result_values}->{total_cap},
        $self->{result_values}->{alloc_cap},
        $self->{result_values}->{free_cap},
        $self->{result_values}->{failed_cap}
    );
}

sub custom_cap_perfdata {
    my ($self, %options) = @_;
    
    $self->{output}->perfdata_add(
        label => 'capacity.total.mebibytes',
        unit => 'MiB',
        value => $self->{result_values}->{total_cap},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'capacity.allocated.mebibytes',
        unit => 'MiB',
        value => $self->{result_values}->{alloc_cap},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'capacity.free.mebibytes',
        unit => 'MiB',
        value => $self->{result_values}->{free_cap},
        min => 0
    );
    $self->{output}->perfdata_add(
        label => 'capacity.failed.mebibytes',
        unit => 'MiB',
        value => $self->{result_values}->{failed_cap},
        min => 0
    );
}

sub prefix_cap_output {
    my ($self, %options) = @_;
    return "System Capacity ";
}

sub prefix_cagetemp_output {
    my ($self, %options) = @_;
    return $options{instance_value}->{display} . " ";
}

sub long_cagetemp_output {
    my ($self, %options) = @_;
    return sprintf(
        "%s - Temp: %s°C, State: %s",
        $options{instance_value}->{display},
        $options{instance_value}->{temp},
        $options{instance_value}->{state}
    );
}

sub custom_cpu_perfdata {
    my ($self, %options) = @_;
    
    my $node = $self->{result_values}->{node};
    my $cpu = $self->{result_values}->{cpu};
    my $label_prefix = 'node' . $node . '.cpu' . $cpu;
    
    $self->{output}->perfdata_add(
        label => $label_prefix . '.user.percentage',
        unit => '%',
        value => $self->{result_values}->{user},
        min => 0,
        max => 100
    );
    $self->{output}->perfdata_add(
        label => $label_prefix . '.sys.percentage',
        unit => '%',
        value => $self->{result_values}->{sys},
        min => 0,
        max => 100
    );
    $self->{output}->perfdata_add(
        label => $label_prefix . '.idle.percentage',
        unit => '%',
        value => $self->{result_values}->{idle},
        min => 0,
        max => 100
    );
    $self->{output}->perfdata_add(
        label => $label_prefix . '.usage.percentage',
        unit => '%',
        value => $self->{result_values}->{usage},
        min => 0,
        max => 100
    );
}

sub prefix_cpu_output {
    my ($self, %options) = @_;
    return "Node " . $options{instance_value}->{node} . " CPU " . $options{instance_value}->{cpu} . " ";
}

sub long_cpu_output {
    my ($self, %options) = @_;
    return sprintf(
        "Node %s CPU %s - User: %s%%, Sys: %s%%, Idle: %s%%, Usage: %s%%",
        $options{instance_value}->{node},
        $options{instance_value}->{cpu},
        $options{instance_value}->{user},
        $options{instance_value}->{sys},
        $options{instance_value}->{idle},
        $options{instance_value}->{usage}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'cpu', type => 1, cb_prefix_output => 'prefix_cpu_output', cb_long_output => 'long_cpu_output', message_multiple => 'All CPU stats collected' },
        { name => 'cagetemp', type => 1, cb_prefix_output => 'prefix_cagetemp_output', cb_long_output => 'long_cagetemp_output', message_multiple => 'All cage temperatures are ok' },
        { name => 'space', type => 0, cb_prefix_output => 'prefix_space_output' },
        { name => 'pdspace', type => 1, cb_prefix_output => 'prefix_pdspace_output', cb_long_output => 'long_pdspace_output', message_multiple => 'All PD space stats collected' },
        { name => 'vvspace', type => 1, cb_prefix_output => 'prefix_vvspace_output', cb_long_output => 'long_vvspace_output', message_multiple => 'All VV space stats collected' },
        { name => 'cpgspace', type => 1, cb_prefix_output => 'prefix_cpgspace_output', cb_long_output => 'long_cpgspace_output', message_multiple => 'All CPG space stats collected' },
        { name => 'capacity', type => 0, cb_prefix_output => 'prefix_cap_output' }
    ];

    $self->{maps_counters}->{cpu} = [
        {
            label => 'cpu-usage',
            type => 2,
            set => {
                key_values => [
                    { name => 'node' }, { name => 'cpu' }, { name => 'user' }, { name => 'sys' },
                    { name => 'idle' }, { name => 'usage' }
                ],
                closure_custom_output => $self->can('custom_cpu_output'),
                closure_custom_perfdata => $self->can('custom_cpu_perfdata'),
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];

    $self->{maps_counters}->{cagetemp} = [
        {
            label => 'temperature',
            type => 2,
            set => {
                key_values => [
                    { name => 'cage' }, { name => 'sensor' }, { name => 'temp' }, { name => 'hi_warning' },
                    { name => 'hi_caution' }, { name => 'hi_critical' }, { name => 'critical' },
                    { name => 'state' }, { name => 'name' }, { name => 'display' }, { name => 'perfdata_label' }
                ],
                closure_custom_output => $self->can('custom_cagetemp_output'),
                closure_custom_perfdata => $self->can('custom_cagetemp_perfdata'),
                closure_custom_threshold_check => $self->can('custom_cagetemp_threshold')
            }
        }
    ];

    $self->{maps_counters}->{space} = [
        {
            label => 'space',
            type => 2,
            set => {
                key_values => [
                    { name => 'raw_free' }, { name => 'usable_free' }
                ],
                closure_custom_output => $self->can('custom_space_output'),
                closure_custom_perfdata => $self->can('custom_space_perfdata'),
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];

    $self->{maps_counters}->{pdspace} = [
        {
            label => 'pdspace',
            type => 2,
            set => {
                key_values => [
                    { name => 'id' }, { name => 'cagepos' }, { name => 'size_mb' }, { name => 'volume_mb' },
                    { name => 'spare_mb' }, { name => 'free_mb' }, { name => 'unavail_mb' }, { name => 'failed_mb' }
                ],
                closure_custom_output => $self->can('custom_pdspace_output'),
                closure_custom_perfdata => $self->can('custom_pdspace_perfdata'),
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];

    $self->{maps_counters}->{vvspace} = [
        {
            label => 'vvspace',
            type => 2,
            set => {
                key_values => [
                    { name => 'name' }, { name => 'data_used_mb' }, { name => 'vsize_mb' }, { name => 'used_perc' }
                ],
                closure_custom_output => $self->can('custom_vvspace_output'),
                closure_custom_perfdata => $self->can('custom_vvspace_perfdata'),
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];

    $self->{maps_counters}->{cpgspace} = [
        {
            label => 'cpgspace',
            type => 2,
            set => {
                key_values => [
                    { name => 'name' }, { name => 'used' }, { name => 'free' }, { name => 'total' }
                ],
                closure_custom_output => $self->can('custom_cpgspace_output'),
                closure_custom_perfdata => $self->can('custom_cpgspace_perfdata'),
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];

    $self->{maps_counters}->{capacity} = [
        {
            label => 'capacity',
            type => 2,
            set => {
                key_values => [
                    { name => 'total_cap' }, { name => 'alloc_cap' }, { name => 'free_cap' }, { name => 'failed_cap' }
                ],
                closure_custom_output => $self->can('custom_cap_output'),
                closure_custom_perfdata => $self->can('custom_cap_perfdata'),
                closure_custom_threshold_check => sub { return 'ok'; }
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'component:s@'         => { name => 'component' },
        'exclude-component:s@' => { name => 'exclude_component' },
        'filter-node:s'        => { name => 'filter_node_id' },
        'filter-cage:s'        => { name => 'filter_cage_id' },
        'filter-pd:s'          => { name => 'filter_pd_id' },
        'filter-vv:s'          => { name => 'filter_vv_id' },
        'filter-cpg:s'         => { name => 'filter_cpg_name' },
        'debug-raw'            => { name => 'debug_raw' }
    });

    return $self;
}

sub clean_output {
    my ($self, %options) = @_;
    my $content = $options{content};
    my $cmd = $options{cmd} // '';
    
    # Show raw output if --debug-raw is set
    if (defined($self->{option_results}->{debug_raw})) {
        $self->{output}->output_add(long_msg => "DEBUG RAW EXECUTE COMMAND:\n" . $cmd, debug => 1) if ($cmd);
        $self->{output}->output_add(long_msg => "DEBUG RAW output:\n" . $content, debug => 1);
    }
    
    if ($content =~ /^([^\n]*cli%\s*)/) {
        my $prompt = $1;
        $prompt =~ s/^\s+//;
        my $prompt_pattern = quotemeta($prompt);
        $content =~ s/$prompt_pattern//g;
    }
    
    # Remove blank lines
    $content =~ s/^\s*\n//mg;
    
    # Replace multiple spaces with single space
    $content =~ s/  +/ /g;
    
    return $content;
}

sub check_cpu {
    my ($self, %options) = @_;
    
    # Expected output format:
    # 17:34:58 01/27/2022
    # node,cpu user sys idle intr/s ctxt/s
    #      0,0    1   0   99
    #      0,1    1   1   98
    #  0,total    1   1   98   7276   9026
    #      1,0    0   0  100
    #  1,total    0   1   99   5312   4799
    
    my $cmd = 'statcpu -iter 1 -d 1';
    my ($content) = $options{custom}->execute_command(commands => [$cmd]);
    $content = $self->clean_output(content => $content, cmd => $cmd);
    $self->{output}->output_add(long_msg => "DEBUG: CPU cleaned output:\n" . $content, debug => 1);
    
    foreach my $line (split /\n/, $content) {
        # Skip header lines
        next if ($line =~ /^\s*node,cpu/i);
        next if ($line =~ /^\s*\d+:\d+:\d+/);  # timestamp
        next if ($line =~ /^\s*$/);
        
        # Parse CPU lines - first 5 columns: node,cpu user sys idle
        # Example:      0,0    1   0   99
        # Example:  0,total    1   1   98   7276   9026
        if ($line =~ /(\d+),(\S+)\s+(\d+)\s+(\d+)\s+(\d+)/) {
            my ($node, $cpu, $user, $sys, $idle) = ($1, $2, $3, $4, $5);
            
            next if (defined($self->{option_results}->{filter_node_id}) && $self->{option_results}->{filter_node_id} ne '' &&
                $node !~ /$self->{option_results}->{filter_node_id}/);
            
            my $usage = 100 - $idle;
            my $key = 'node' . $node . '_cpu' . $cpu;
            
            $self->{cpu}->{$key} = {
                node  => $node,
                cpu   => $cpu,
                user  => $user,
                sys   => $sys,
                idle  => $idle,
                usage => $usage
            };
        }
    }
}

sub check_cagetemperature {
    my ($self, %options) = @_;
    
    # Expected output format:
    # Cage Sensor Temp HiCritical HiCaution HiWarning -State- ---------------Name----------------
    #    1      1   32         --       105        95 OK      Iom[1]Connector[0]Temp
    #   41      2   78         --        85        75 Warning Iom[1]NVMeCtrl[1]Temp
    
    my $cmd = 'showcage -temperature -showcols Cage,Sensor,Temp,HiCaution,HiWarning,State,Name';
    my ($content) = $options{custom}->execute_command(commands => [$cmd]);
    
    # Remove CLI prompts if present
    $content =~ s/^.*?cli%\s*//s if ($content =~ /cli%/);
    $content =~ s/\s*\S*\s*cli%\s*$//s if ($content =~ /cli%/);
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/);
        next if ($line =~ /^\s*-+\s*$/);
        next if ($line =~ /\d+\s+total\s*$/i);
        
        # Detect header line
        if ($line =~ /^\s*Cage\s+Sensor/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                my $col_name = lc($cols[$i]);
                $col_name =~ s/^-+|-+$//g;
                $col_index{$col_name} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [cagetemperature]: Header found, columns: $col_list", debug => 1);
            
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        # Get values dynamically
        my $cage = $parts[$col_index{cage}] if defined($col_index{cage});
        my $sensor = $parts[$col_index{sensor}] if defined($col_index{sensor});
        my $temp = $parts[$col_index{temp}] if defined($col_index{temp});
        my $hi_critical = $parts[$col_index{hicritical}] if defined($col_index{hicritical});
        my $hi_caution = $parts[$col_index{hicaution}] if defined($col_index{hicaution});
        my $hi_warning = $parts[$col_index{hiwarning}] if defined($col_index{hiwarning});
        my $state = $parts[$col_index{state}] if defined($col_index{state});
        my $name = $parts[$col_index{name}] if defined($col_index{name});
        
        # If name not found by column, it's the last element
        if (!defined($name) && scalar(@parts) > 0) {
            $name = $parts[$#parts];
        }
        
        next if (!defined($cage) || !defined($sensor));
        
        next if (defined($self->{option_results}->{filter_cage_id}) && $self->{option_results}->{filter_cage_id} ne '' &&
            $cage !~ /$self->{option_results}->{filter_cage_id}/);
        
        # Determine critical threshold: use HiCaution if available, otherwise HiCritical
        my $critical = '--';
        if (defined($hi_caution) && $hi_caution =~ /^\d+$/) {
            $critical = $hi_caution;
        } elsif (defined($hi_critical) && $hi_critical =~ /^\d+$/) {
            $critical = $hi_critical;
        }
        
        # Clean name for perfdata: replace non-alphanumeric (except -) with -, then -- with -
        my $clean_name = $name // 'unknown';
        $clean_name =~ s/[^a-zA-Z0-9\-]/-/g;
        $clean_name =~ s/--+/-/g;
        $clean_name =~ s/^-|-$//g;
        
        my $perfdata_label = 'cage' . $cage . '.sensor' . $sensor . '.' . $clean_name;
        my $key = 'cage' . $cage . '_sensor' . $sensor;
        
        $self->{cagetemp}->{$key} = {
            cage          => $cage,
            sensor        => $sensor,
            temp          => $temp // 0,
            hi_critical   => $hi_critical // '--',
            hi_caution    => $hi_caution // '--',
            hi_warning    => $hi_warning // '--',
            critical      => $critical,
            state         => $state // 'unknown',
            name          => $name // 'unknown',
            display       => "Cage $cage Sensor $sensor ($name)",
            perfdata_label => $perfdata_label
        };
    }
}

sub check_space {
    my ($self, %options) = @_;
    
    # Expected output format:
    # ---Estimated(MiB)---
    #   RawFree UsableFree
    # 307726644  239342950
    
    my $cmd = 'showspace';
    my ($content) = $options{custom}->execute_command(commands => [$cmd]);
    
    # Remove cli% prompt
    if ($content =~ /^([^\n]*cli%\s*)/) {
        my $prompt = $1;
        $prompt =~ s/^\s+//;
        my $prompt_pattern = quotemeta($prompt);
        $content =~ s/$prompt_pattern//g;
    }
    
    # Remove everything before the first line starting with ---
    $content =~ s/^.*?(?=\n\s*---)//s;
    $content =~ s/^\n+//;
    
    # Remove trailing dashes line and everything after it
    $content =~ s/\n-+\s*\n.*$//s;
    
    # Remove blank lines
    $content =~ s/^\s*\n//mg;
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /---Estimated/);
        next if ($line =~ /^\s*$/);
        
        # Detect header line
        if (!$header_found && $line =~ /^\s*RawFree/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                my $col_name = lc($cols[$i]);
                $col_name =~ s/^-+|-+$//g;
                $col_index{$col_name} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [space]: Header found, columns: $col_list", debug => 1);
            
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        next if (scalar(@parts) < 2);
        
        # Get values dynamically
        my $raw_free;
        for my $col_name (qw(rawfree raw_free rawfreemib)) {
            if (defined($col_index{$col_name})) {
                $raw_free = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        my $usable_free;
        for my $col_name (qw(usablefree usable_free usablefreemib)) {
            if (defined($col_index{$col_name})) {
                $usable_free = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Fallback: first two numeric columns
        if (!defined($raw_free) && $parts[0] =~ /^\d+$/) {
            $raw_free = $parts[0];
        }
        if (!defined($usable_free) && defined($parts[1]) && $parts[1] =~ /^\d+$/) {
            $usable_free = $parts[1];
        }
        
        if (defined($raw_free) && defined($usable_free)) {
            $self->{space} = {
                raw_free => $raw_free,
                usable_free => $usable_free
            };
            last;
        }
    }
}

sub check_vvspace {
    my ($self, %options) = @_;
    
    # Expected output format:
    # Id Name     Prov Compr Dedup Type Data_Used_MB Data_Rsvd_MB Host_Wrt_MB VSize_MB Used_% Warn_% Limit_% ...
    # 1  vol_db01 tp   on    on    rw   51200        102400       76800       102400   50     80     90      ...
    # Note: We need Name, Data_Used_MB (or Usr_Used_MB), VSize_MB, Used_%
    
    my $cmd = 'showvv -space';
    my ($content) = $options{custom}->execute_command(commands => [$cmd]);
    
    # Remove cli% prompt
    if ($content =~ /^([^\n]*cli%\s*)/) {
        my $prompt = $1;
        $prompt =~ s/^\s+//;
        my $prompt_pattern = quotemeta($prompt);
        $content =~ s/$prompt_pattern//g;
    }
    
    # Remove trailing dashes line and everything after it
    $content =~ s/\n-+\s*\n.*//s;
    
    # Remove blank lines
    $content =~ s/^\s*\n//mg;
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/);
        next if ($line =~ /^-+\s*$/);
        next if ($line =~ /----.*----/);  # Skip decorative headers
        next if ($line =~ /^\s*\d+\s+total\s*$/i);
        
        # Detect header line (contains Id and Name)
        if (!$header_found && $line =~ /^\s*Id\s+Name/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                my $col_name = lc($cols[$i]);
                $col_name =~ s/^-+|-+$//g;
                $col_name =~ s/%//g;  # Remove % from Used_%, Warn_%, etc.
                $col_name =~ s/_//g;  # Remove underscores for easier matching
                $col_index{$col_name} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [vvspace]: Header found, columns: $col_list", debug => 1);
            
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        next if (scalar(@parts) < 4);
        
        # Get Id and Name from known positions
        my $id = $parts[$col_index{id}] if defined($col_index{id});
        my $name = $parts[$col_index{name}] if defined($col_index{name});
        
        next if (!defined($id) || !defined($name));
        
        # Skip total line
        next if ($name eq 'total');
        
        # Get Data_Used_MB - try different column names
        my $data_used_mb;
        for my $col_name (qw(datausedmb usrusedmb usedmb)) {
            if (defined($col_index{$col_name})) {
                $data_used_mb = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Get VSize_MB - try different column names
        my $vsize_mb;
        for my $col_name (qw(vsizemb vsizemib vsize)) {
            if (defined($col_index{$col_name})) {
                $vsize_mb = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Get Used_% - try different column names
        my $used_perc;
        for my $col_name (qw(used usedperc usedpct)) {
            if (defined($col_index{$col_name})) {
                $used_perc = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        next if (defined($self->{option_results}->{filter_vv_id}) && $self->{option_results}->{filter_vv_id} ne '' &&
            $name !~ /$self->{option_results}->{filter_vv_id}/);
        
        $self->{vvspace}->{$name} = {
            name         => $name,
            data_used_mb => $data_used_mb // 0,
            vsize_mb     => $vsize_mb // 0,
            used_perc    => $used_perc // 0
        };
    }
}

sub check_cpgspace {
    my ($self, %options) = @_;
    
    # Expected output format (without showcols):
    # Id Name      Domain Warn% VVs TPVVs TDVVs ... Used    Free   Total
    #  0 SSD_r6         -     -  53     0    37 ... 1635900 1292025 2927925
    # Note: Used, Free, Total are always the last 3 numeric columns
    
    my $cmd = 'showcpg';
    my ($content) = $options{custom}->execute_command(commands => [$cmd]);
    
    # Remove cli% prompt
    if ($content =~ /^([^\n]*cli%\s*)/) {
        my $prompt = $1;
        $prompt =~ s/^\s+//;
        my $prompt_pattern = quotemeta($prompt);
        $content =~ s/$prompt_pattern//g;
    }
    
    # Remove trailing dashes line and everything after it
    $content =~ s/\n-+\s*\n.*//s;
    
    # Remove blank lines
    $content =~ s/^\s*\n//mg;
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/);
        next if ($line =~ /^-+\s*$/);
        next if ($line =~ /----.*----/);  # Skip decorative headers like ----Volumes----
        
        # Detect header line (contains Id and Name)
        if (!$header_found && $line =~ /^\s*Id\s+Name/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                my $col_name = lc($cols[$i]);
                $col_name =~ s/^-+|-+$//g;
                $col_name =~ s/%//g;  # Remove % from Warn%
                $col_index{$col_name} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [cpgspace]: Header found, columns: $col_list", debug => 1);
            
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        next if (scalar(@parts) < 4);
        
        # Get Id and Name from known positions
        my $id = $parts[$col_index{id}] if defined($col_index{id});
        my $name = $parts[$col_index{name}] if defined($col_index{name});
        
        next if (!defined($id) || !defined($name));
        
        # Skip total line
        next if ($name eq 'total');
        
        # Get Used, Free, Total - try column index first, otherwise use last 3 numeric columns
        my ($used, $free, $total);
        
        if (defined($col_index{free}) && defined($col_index{total})) {
            # Check for Used column, fallback to Base
            if (defined($col_index{used})) {
                $used = $parts[$col_index{used}];
            } elsif (defined($col_index{base})) {
                $used = $parts[$col_index{base}];
            }
            $free = $parts[$col_index{free}];
            $total = $parts[$col_index{total}];
        }
        
        # Fallback: Used/Base, Free, Total are always the last 3 columns
        if (!defined($used) || !defined($free) || !defined($total)) {
            $total = $parts[$#parts];
            $free = $parts[$#parts - 1];
            $used = $parts[$#parts - 2];
        }
        
        next if (defined($self->{option_results}->{filter_cpg_name}) && $self->{option_results}->{filter_cpg_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_cpg_name}/);
        
        $self->{cpgspace}->{$name} = {
            name  => $name,
            used  => $used,
            free  => $free,
            total => $total
        };
    }
}

sub check_capacity {
    my ($self, %options) = @_;
    
    # Expected output format for Alletra 9000:
    #      ID ---Name--- -----Model------ --Serial-- Nodes Master ClusterLED  TotalCap AllocCap   FreeCap FailedCap
    # 0x2BDFA BBBBBBST31 HPE Alletra 9080 AAAAAAAAAA     4      1 Green      175767552 20649984 155117568         0
    #
    # Expected output format for Alletra MP:
    #      ID ---Name--- --------Model--------- --Serial-- Nodes Master TotalCap  AllocCap   FreeCap FailedCap
    # 0x2CE54 BBBBBBST11 HPE Alletra Storage MP AAAAAAAAAA     4      1 322240512 14555136 307685376         0
    
    my $cmd = 'showsys';
    my ($content) = $options{custom}->execute_command(commands => [$cmd]);
    
    # Remove cli% prompt
    if ($content =~ /^([^\n]*cli%\s*)/) {
        my $prompt = $1;
        $prompt =~ s/^\s+//;
        my $prompt_pattern = quotemeta($prompt);
        $content =~ s/$prompt_pattern//g;
    }
    
    # Remove blank lines
    $content =~ s/^\s*\n//mg;
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/);
        
        # Detect header line (contains ID and TotalCap or Total)
        if (!$header_found && $line =~ /^\s*ID\s+/i && $line =~ /Total/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                my $col_name = lc($cols[$i]);
                $col_name =~ s/^-+|-+$//g;
                $col_index{$col_name} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [capacity]: Header found, columns: $col_list", debug => 1);
            
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        next if (scalar(@parts) < 4);
        
        # Get values dynamically
        my $total_cap;
        for my $col_name (qw(totalcap total totalmib totalcapmib)) {
            if (defined($col_index{$col_name})) {
                $total_cap = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        my $alloc_cap;
        for my $col_name (qw(alloccap alloc allocmib alloccapmib)) {
            if (defined($col_index{$col_name})) {
                $alloc_cap = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        my $free_cap;
        for my $col_name (qw(freecap free freemib freecapmib)) {
            if (defined($col_index{$col_name})) {
                $free_cap = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        my $failed_cap;
        for my $col_name (qw(failedcap failed failedmib failedcapmib)) {
            if (defined($col_index{$col_name})) {
                $failed_cap = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Fallback: last 4 numeric columns
        if (!defined($total_cap) || !defined($free_cap)) {
            my @numeric_cols;
            for my $i (0..$#parts) {
                push @numeric_cols, $i if ($parts[$i] =~ /^\d+$/);
            }
            if (scalar(@numeric_cols) >= 4) {
                my @last4 = @numeric_cols[-4..-1];
                $total_cap //= $parts[$last4[0]];
                $alloc_cap //= $parts[$last4[1]];
                $free_cap //= $parts[$last4[2]];
                $failed_cap //= $parts[$last4[3]];
            }
        }
        
        if (defined($total_cap) && defined($free_cap)) {
            $self->{capacity} = {
                total_cap  => $total_cap // 0,
                alloc_cap  => $alloc_cap // 0,
                free_cap   => $free_cap // 0,
                failed_cap => $failed_cap // 0
            };
            last;
        }
    }
}

sub check_pdspace {
    my ($self, %options) = @_;
    
    # Expected output format:
    # Id CagePos Type State   Size_MB  Volume_MB  Spare_MB  Free_MB  Unavail_MB  Failed_MB
    # 0  0:0:0   SSD  normal  1920384  1280000    128000    512384   0           0
    # 1  0:0:1   SSD  normal  1920384  1300000    128000    494384   0           0
    
    my $cmd = 'showpd -space';
    my ($content) = $options{custom}->execute_command(commands => [$cmd]);
    
    # Remove cli% prompt
    if ($content =~ /^([^\n]*cli%\s*)/) {
        my $prompt = $1;
        $prompt =~ s/^\s+//;
        my $prompt_pattern = quotemeta($prompt);
        $content =~ s/$prompt_pattern//g;
    }
    
    # Remove trailing summary line
    $content =~ s/\n-+\s*\n.*//s;
    
    # Remove blank lines
    $content =~ s/^\s*\n//mg;
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/);
        next if ($line =~ /^-+\s*$/);
        next if ($line =~ /^\s*\d+\s+total\s*$/i);
        
        # Detect header line (contains Id and CagePos or Size)
        if (!$header_found && $line =~ /^\s*Id\s+/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                my $col_name = lc($cols[$i]);
                $col_name =~ s/^-+|-+$//g;
                $col_name =~ s/_//g;  # Remove underscores
                $col_index{$col_name} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [pdspace]: Header found, columns: $col_list", debug => 1);
            
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        next if (scalar(@parts) < 6);
        
        # Get Id
        my $id = defined($col_index{id}) ? $parts[$col_index{id}] : undef;
        next if (!defined($id) || $id !~ /^\d+$/);
        
        # Get CagePos
        my $cagepos;
        for my $col_name (qw(cagepos cage_pos cage pos position)) {
            if (defined($col_index{$col_name})) {
                $cagepos = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Get Size_MB
        my $size_mb;
        for my $col_name (qw(sizemb size sizemib totalmb total)) {
            if (defined($col_index{$col_name})) {
                $size_mb = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Get Volume_MB
        my $volume_mb;
        for my $col_name (qw(volumemb volume volmb vol usedmb used)) {
            if (defined($col_index{$col_name})) {
                $volume_mb = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Get Spare_MB
        my $spare_mb;
        for my $col_name (qw(sparemb spare sparemib)) {
            if (defined($col_index{$col_name})) {
                $spare_mb = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Get Free_MB
        my $free_mb;
        for my $col_name (qw(freemb free freemib)) {
            if (defined($col_index{$col_name})) {
                $free_mb = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Get Unavail_MB
        my $unavail_mb;
        for my $col_name (qw(unavailmb unavail unavailablemb unavailable)) {
            if (defined($col_index{$col_name})) {
                $unavail_mb = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Get Failed_MB
        my $failed_mb;
        for my $col_name (qw(failedmb failed failmb fail)) {
            if (defined($col_index{$col_name})) {
                $failed_mb = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        next if (defined($self->{option_results}->{filter_pd_id}) && $self->{option_results}->{filter_pd_id} ne '' &&
            $id !~ /$self->{option_results}->{filter_pd_id}/);
        
        $self->{pdspace}->{$id} = {
            id         => $id,
            cagepos    => $cagepos // 'unknown',
            size_mb    => $size_mb // 0,
            volume_mb  => $volume_mb // 0,
            spare_mb   => $spare_mb // 0,
            free_mb    => $free_mb // 0,
            unavail_mb => $unavail_mb // 0,
            failed_mb  => $failed_mb // 0
        };
    }
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{cpu} = {};
    $self->{cagetemp} = {};
    $self->{space} = {};
    $self->{pdspace} = {};
    $self->{vvspace} = {};
    $self->{cpgspace} = {};
    $self->{capacity} = {};
    
    my @available = qw(cpu cagetemperature space pdspace vvspace cpgspace capacity);
    my @check_components;
    
    if (defined($self->{option_results}->{component}) && scalar(@{$self->{option_results}->{component}}) > 0) {
        @check_components = @{$self->{option_results}->{component}};
    } else {
        @check_components = @available;
    }
    
    if (defined($self->{option_results}->{exclude_component})) {
        my %excluded = map { $_ => 1 } @{$self->{option_results}->{exclude_component}};
        @check_components = grep { !$excluded{$_} } @check_components;
    }
    
    foreach my $comp (@check_components) {
        my $method = 'check_' . $comp;
        if ($self->can($method)) {
            $self->$method(custom => $options{custom});
        }
    }

    if (scalar(keys %{$self->{cpu}}) <= 0 && scalar(keys %{$self->{cagetemp}}) <= 0 && 
        scalar(keys %{$self->{space}}) <= 0 && scalar(keys %{$self->{pdspace}}) <= 0 &&
        scalar(keys %{$self->{vvspace}}) <= 0 && scalar(keys %{$self->{cpgspace}}) <= 0 &&
        scalar(keys %{$self->{capacity}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No stats found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check statistics for HPE Alletra MP / Alletra 9000 storage systems.

=over 8

=item B<--component>

Which component to check. Can be specified multiple times.
Available: cpu, cagetemperature, space, pdspace, vvspace, cpgspace, capacity
Default: all components

=item B<--exclude-component>

Exclude specific component(s). Can be specified multiple times.

=item B<--filter-node>

Filter by node ID (regexp allowed). Used for cpu component.

=item B<--filter-cage>

Filter by cage ID (regexp allowed). Used for cagetemperature component.

=item B<--filter-pd>

Filter by PD ID (regexp allowed). Used for pdspace component.

=item B<--filter-vv>

Filter by VV name (regexp allowed). Used for vvspace component.

=item B<--filter-cpg>

Filter by CPG name (regexp allowed). Used for cpgspace component.

=item B<--debug-raw>

Show raw command output in debug mode.

=back

=head1 PERFDATA

CPU component (--component=cpu):
  - node<n>.cpu<c>.user.percentage
  - node<n>.cpu<c>.sys.percentage
  - node<n>.cpu<c>.idle.percentage
  - node<n>.cpu<c>.usage.percentage

Cage Temperature component (--component=cagetemperature):
  - cage<n>.sensor<s>.<n>.temperature.celsius (with warning/critical thresholds)

Space component (--component=space):
  - space.raw.free.mebibytes
  - space.usable.free.mebibytes

PD Space component (--component=pdspace):
  - pd.<n>.size.megabytes
  - pd.<n>.volume.megabytes
  - pd.<n>.spare.megabytes
  - pd.<n>.free.megabytes
  - pd.<n>.unavailable.megabytes
  - pd.<n>.failed.megabytes

VV Space component (--component=vvspace):
  - vv.<n>.data.used.mebibytes
  - vv.<n>.vsize.mebibytes
  - vv.<n>.used.percentage

CPG Space component (--component=cpgspace):
  - cpg.<n>.used.mebibytes
  - cpg.<n>.free.mebibytes
  - cpg.<n>.total.mebibytes

Capacity component (--component=capacity):
  - capacity.total.mebibytes
  - capacity.allocated.mebibytes
  - capacity.free.mebibytes
  - capacity.failed.mebibytes

=cut
