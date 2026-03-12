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

package storage::hp::alletra::ssh::mode::showswitch;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("state: '%s'", $self->{result_values}->{state});
}

sub switch_long_output {
    my ($self, %options) = @_;
    return sprintf("checking switch '%s'", $options{instance_value}->{display});
}

sub prefix_switch_output {
    my ($self, %options) = @_;
    return sprintf("switch '%s' ", $options{instance_value}->{display});
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'switches', type => 1, cb_prefix_output => 'prefix_switch_output', cb_long_output => 'switch_long_output', message_multiple => 'All switches are ok' }
    ];

    $self->{maps_counters}->{switches} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{state} !~ /^(ok|normal|online|up)$/i',
            set => {
                key_values => [ { name => 'display' }, { name => 'state' }, { name => 'perfdata_label' } ],
                closure_custom_output => $self->can('custom_status_output'),
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
        'component:s@'          => { name => 'component' },
        'exclude-component:s@'  => { name => 'exclude_component' },
        'filter-switch-name:s'  => { name => 'filter_switch_name' },
        'filter-switch-id:s'    => { name => 'filter_switch_id' },
        'exclude-state:s'       => { name => 'exclude_state' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my @available = qw(base detail fan port ps);
    my @check_components;

    if (defined($self->{option_results}->{component}) && scalar(@{$self->{option_results}->{component}}) > 0) {
        @check_components = @{$self->{option_results}->{component}};
    } else {
        @check_components = ('base');
    }

    if (defined($self->{option_results}->{exclude_component})) {
        my %excluded = map { $_ => 1 } @{$self->{option_results}->{exclude_component}};
        @check_components = grep { !$excluded{$_} } @check_components;
    }

    $self->{switches} = {};
    $self->{global_status} = 0;
    foreach my $comp (@check_components) {
        my $method = 'check_' . $comp;
        $self->$method(custom => $options{custom}) if ($self->can($method));
    }

    if (scalar(keys %{$self->{switches}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No switches found. Switch mode may not be available on this platform (e.g., Alletra 9000).");
        $self->{output}->option_exit();
    }
}

sub check_base {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showswitch']);
    
    # Parse columns dynamically - we need: Name, State
    my $rows = $options{custom}->parse_columns(
        content  => $content,
        required => ['Name', 'State']
    );
    
    foreach my $row (@{$rows}) {
        my $name = $row->{name};
        my $state = $row->{state} // 'unknown';
        next if (!defined($name));
        next if (defined($self->{option_results}->{filter_switch_name}) && $self->{option_results}->{filter_switch_name} ne '' && $name !~ /$self->{option_results}->{filter_switch_name}/);
        $self->{switches}->{'base_' . $name} = { display => $name, state => $state, perfdata_label => 'switch.' . $name . '.base' };
    }
}

sub check_detail {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showswitch -d']);
    
    # Parse columns dynamically - we need: ID, Name, State
    my $rows = $options{custom}->parse_columns(
        content  => $content,
        required => ['ID', 'Name', 'State']
    );
    
    foreach my $row (@{$rows}) {
        my $id = $row->{id};
        my $name = $row->{name} // 'unknown';
        my $state = $row->{state} // 'unknown';
        next if (!defined($id));
        next if (defined($self->{option_results}->{filter_switch_id}) && $self->{option_results}->{filter_switch_id} ne '' && $id !~ /$self->{option_results}->{filter_switch_id}/);
        $self->{switches}->{'detail_' . $id} = { display => "$name (ID: $id)", state => $state, perfdata_label => 'switch.' . $id . '.detail' };
    }
}

sub check_fan {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showswitch -fan']);
    
    # Remove CLI prompts
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        # Detect header
        if ($line =~ /^\s*Name\s+/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                $col_index{lc($cols[$i])} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [switch-fan]: Header found, columns: $col_list", debug => 1);
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $name = $parts[$col_index{name}] if defined($col_index{name});
        # Fan name can be in various columns
        my $fan_name;
        for my $col_name (qw(fan_name fanname fan)) {
            if (defined($col_index{$col_name})) {
                $fan_name = $parts[$col_index{$col_name}];
                last;
            }
        }
        # Find state column
        my $state;
        for my $col_name (qw(state status)) {
            if (defined($col_index{$col_name})) {
                $state = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        next if (!defined($name) || !defined($fan_name));
        next if (defined($self->{option_results}->{filter_switch_name}) && $self->{option_results}->{filter_switch_name} ne '' && $name !~ /$self->{option_results}->{filter_switch_name}/);
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/);
        $self->{switches}->{'fan_' . $name . '_' . $fan_name} = { display => "$name $fan_name", state => $state // 'unknown', perfdata_label => 'switch.' . $name . '.' . lc($fan_name) };
    }
}

sub check_port {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showswitch -port']);
    
    # Remove CLI prompts
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        # Detect header
        if ($line =~ /^\s*Name\s+/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                $col_index{lc($cols[$i])} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [switch-port]: Header found, columns: $col_list", debug => 1);
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $name = $parts[$col_index{name}] if defined($col_index{name});
        my $port_id = $parts[$col_index{port}] if defined($col_index{port});
        # Find state column
        my $state;
        for my $col_name (qw(state status)) {
            if (defined($col_index{$col_name})) {
                $state = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        next if (!defined($name) || !defined($port_id));
        next if (defined($self->{option_results}->{filter_switch_name}) && $self->{option_results}->{filter_switch_name} ne '' && $name !~ /$self->{option_results}->{filter_switch_name}/);
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/);
        $self->{switches}->{'port_' . $name . '_' . $port_id} = { display => "$name port $port_id", state => $state // 'unknown', perfdata_label => 'switch.' . $name . '.port' . $port_id };
    }
}

sub check_ps {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showswitch -ps']);
    
    # Remove CLI prompts
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        # Detect header
        if ($line =~ /^\s*Name\s+/i) {
            my @cols = split(/\s+/, $line);
            shift @cols if ($cols[0] eq '');
            for my $i (0..$#cols) {
                $col_index{lc($cols[$i])} = $i;
            }
            $header_found = 1;
            
            # Debug: show detected columns
            my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
            $self->{output}->output_add(long_msg => "DEBUG [switch-ps]: Header found, columns: $col_list", debug => 1);
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $name = $parts[$col_index{name}] if defined($col_index{name});
        # PS name can be in various columns
        my $ps_name;
        for my $col_name (qw(ps_name psname ps)) {
            if (defined($col_index{$col_name})) {
                $ps_name = $parts[$col_index{$col_name}];
                last;
            }
        }
        # Find state column
        my $state;
        for my $col_name (qw(state status)) {
            if (defined($col_index{$col_name})) {
                $state = $parts[$col_index{$col_name}];
                last;
            }
        }
        
        next if (!defined($name) || !defined($ps_name));
        next if (defined($self->{option_results}->{filter_switch_name}) && $self->{option_results}->{filter_switch_name} ne '' && $name !~ /$self->{option_results}->{filter_switch_name}/);
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/);
        $self->{switches}->{'ps_' . $name . '_' . $ps_name} = { display => "$name $ps_name", state => $state // 'unknown', perfdata_label => 'switch.' . $name . '.' . lc($ps_name) };
    }
}


1;

__END__

=head1 MODE

Check switches status. Note: This mode may not be available on all platforms (e.g., Alletra 9000).
If no switches are found, the command may not be supported on your storage system.

=over 8

=item B<--component>

Which component to check. Can be specified multiple times.
Available: base, detail, fan, port, ps.
Default: base.

=item B<--exclude-component>

Exclude specific component(s). Can be specified multiple times.

=item B<--filter-switch-name>

Filter switches by name (can be a regexp).

=item B<--filter-switch-id>

Filter switches by ID (can be a regexp). Used for detail component.

=item B<--exclude-state>

Exclude items with specific state (can be a regexp). Example: --exclude-state='-' to exclude items with state '-'. Works for all components (fan, port, ps).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{display}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{state}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{state} !~ /^(ok|normal|online)$/i').
You can use the following variables: %{state}, %{display}

=back

=cut
