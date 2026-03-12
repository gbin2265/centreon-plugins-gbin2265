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

package storage::hp::alletra::ssh::mode::showvv;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf("state: '%s'", $self->{result_values}->{state});
}

sub custom_status_perfdata {
    my ($self, %options) = @_;

    my $name = $self->{result_values}->{name};
    $name =~ s/[^a-zA-Z0-9]/_/g;

    # VSize in MB - only real data perfdata
    if (defined($self->{result_values}->{vsize}) && $self->{result_values}->{vsize} =~ /^\d+$/) {
        $self->{output}->perfdata_add(
            label => 'vv.' . $name . '.vsize.megabytes',
            unit => 'MB',
            value => $self->{result_values}->{vsize},
            min => 0
        );
    }
}

sub vv_long_output {
    my ($self, %options) = @_;

    return sprintf(
        "checking virtual volume '%s'",
        $options{instance_value}->{name}
    );
}

sub prefix_vv_output {
    my ($self, %options) = @_;

    return sprintf(
        "virtual volume '%s' ",
        $options{instance_value}->{name}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'vvs', type => 1, cb_prefix_output => 'prefix_vv_output', cb_long_output => 'vv_long_output', message_multiple => 'All virtual volumes are ok' }
    ];

    $self->{maps_counters}->{vvs} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{state} !~ /normal/i',
            set => {
                key_values => [ { name => 'name' }, { name => 'state' }, { name => 'vsize' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => $self->can('custom_status_perfdata'),
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-vv-name:s'   => { name => 'filter_vv_name' },
        'filter-vv-type:s'   => { name => 'filter_vv_type' },
        'exclude-vv-name:s'  => { name => 'exclude_vv_name' },
        'exclude-vv-type:s'  => { name => 'exclude_vv_type' },
        'exclude-vv-state:s' => { name => 'exclude_vv_state' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($content) = $options{custom}->execute_command(commands => ['showvv']);

    # Remove CLI prompts
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total

    $self->{vvs} = {};
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/);
        next if ($line =~ /^\s*-+\s*$/);
        next if ($line =~ /\d+\s+total\s*$/i);
        
        # Detect header line
        if ($line =~ /^\s*Id\s+Name/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                my $col_name = lc($cols[$i]);
                $col_name =~ s/^-+|-+$//g;
                $col_name =~ s/[\(\)]//g;
                $col_index{$col_name} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [showvv]: Header found, columns: $col_list", debug => 1);
            
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        next if (scalar(@parts) < 5);
        
        # Get required columns dynamically
        my $id = $parts[$col_index{id}] if defined($col_index{id});
        my $name = $parts[$col_index{name}] if defined($col_index{name});
        my $type = $parts[$col_index{type}] if defined($col_index{type});
        
        # Find state column (may be called state, detailed_state, etc.)
        my $state;
        for my $col_name (qw(state detailed_state detailedstate)) {
            if (defined($col_index{$col_name})) {
                $state = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        # Find vsize column (may be vsize, vsize_mb, vsizemib, etc.)
        my $vsize;
        for my $col_name (qw(vsize vsize_mb vsizemib vsizemb)) {
            if (defined($col_index{$col_name})) {
                $vsize = $parts[$col_index{$col_name}];
                last;
            }
        }
        # If not found by name, take the last numeric column
        if (!defined($vsize)) {
            for (my $i = $#parts; $i >= 0; $i--) {
                if ($parts[$i] =~ /^\d+$/) {
                    $vsize = $parts[$i];
                    last;
                }
            }
        }

        next if (!defined($name));

        next if (defined($self->{option_results}->{filter_vv_name}) && $self->{option_results}->{filter_vv_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_vv_name}/);
        next if (defined($self->{option_results}->{filter_vv_type}) && $self->{option_results}->{filter_vv_type} ne '' &&
            defined($type) && $type !~ /$self->{option_results}->{filter_vv_type}/);
        next if (defined($self->{option_results}->{exclude_vv_name}) && $self->{option_results}->{exclude_vv_name} ne '' &&
            $name =~ /$self->{option_results}->{exclude_vv_name}/);
        next if (defined($self->{option_results}->{exclude_vv_type}) && $self->{option_results}->{exclude_vv_type} ne '' &&
            defined($type) && $type =~ /$self->{option_results}->{exclude_vv_type}/i);
        next if (defined($self->{option_results}->{exclude_vv_state}) && $self->{option_results}->{exclude_vv_state} ne '' &&
            defined($state) && $state =~ /$self->{option_results}->{exclude_vv_state}/i);

        $self->{vvs}->{$name} = {
            name  => $name,
            type  => $type // 'unknown',
            state => $state // 'unknown',
            vsize => $vsize
        };
    }

    if (scalar(keys %{$self->{vvs}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No virtual volumes found.");
        $self->{output}->option_exit();
    }
}


1;

__END__

=head1 MODE

Check virtual volumes status.

=over 8

=item B<--filter-vv-name>

Filter virtual volumes by name (can be a regexp).

=item B<--filter-vv-type>

Filter virtual volumes by type (can be a regexp).

=item B<--exclude-vv-name>

Exclude virtual volumes by name (can be a regexp). Example: --exclude-vv-name='test_.*' to exclude volumes starting with test_.

=item B<--exclude-vv-type>

Exclude virtual volumes by type (can be a regexp). Example: --exclude-vv-type='cpvv' to exclude cpvv type volumes.

=item B<--exclude-vv-state>

Exclude virtual volumes with specific state (can be a regexp). Example: --exclude-vv-state='offline' to exclude offline volumes.

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{name}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{state}, %{name}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{state} !~ /normal/i').
You can use the following variables: %{state}, %{name}

=back

=cut
