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

package storage::hp::alletra::ssh::mode::showcage;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf("state: '%s'", $self->{result_values}->{state});
}

sub cage_long_output {
    my ($self, %options) = @_;
    return sprintf("checking cage item '%s'", $options{instance_value}->{display});
}

sub prefix_cage_output {
    my ($self, %options) = @_;
    return sprintf("cage '%s' ", $options{instance_value}->{display});
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'items', type => 1, cb_prefix_output => 'prefix_cage_output', cb_long_output => 'cage_long_output', message_multiple => 'All cage components are ok' }
    ];

    $self->{maps_counters}->{items} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{state} !~ /^(OK|YES)$/i',
            set => {
                key_values => [ { name => 'state' }, { name => 'display' }, { name => 'perfdata_label' } ],
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
        'component:s@'         => { name => 'component' },
        'exclude-component:s@' => { name => 'exclude_component' },
        'filter-cage-id:s'     => { name => 'filter_cage_id' },
        'filter-iom:s'         => { name => 'filter_iom' },
        'filter-mag:s'         => { name => 'filter_mag' },
        'filter-fan:s'         => { name => 'filter_fan' },
        'exclude-cage-id:s'    => { name => 'exclude_cage_id' },
        'exclude-iom:s'        => { name => 'exclude_iom' },
        'exclude-mag:s'        => { name => 'exclude_mag' },
        'exclude-fan:s'        => { name => 'exclude_fan' },
        'exclude-state:s'      => { name => 'exclude_state' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my @available = qw(fan cooling power iom enclosure mag sep ilo cdm cpld ubm connector sfp temperature);
    my @check_components;

    if (defined($self->{option_results}->{component}) && scalar(@{$self->{option_results}->{component}}) > 0) {
        @check_components = @{$self->{option_results}->{component}};
    } else {
        @check_components = qw(fan cooling power iom enclosure mag sep);
    }

    if (defined($self->{option_results}->{exclude_component})) {
        my %excluded = map { $_ => 1 } @{$self->{option_results}->{exclude_component}};
        @check_components = grep { !$excluded{$_} } @check_components;
    }

    $self->{items} = {};

    foreach my $comp (@check_components) {
        my $method = 'check_' . $comp;
        $self->$method(custom => $options{custom}) if ($self->can($method));
    }

    if (scalar(keys %{$self->{items}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No cage items found. Some components may not be available on your platform.");
        $self->{output}->option_exit();
    }
}

# Helper: parse header and build column index
sub _parse_header {
    my ($self, %options) = @_;
    
    my $line = $options{line};
    my $component = $options{component} // 'unknown';
    
    my @cols = split(/\s+/, $line);
    shift @cols if ($cols[0] eq '');
    
    my %col_index;
    for my $i (0..$#cols) {
        my $col_name = lc($cols[$i]);
        $col_name =~ s/^-+|-+$//g;
        $col_index{$col_name} = $i;
    }
    
    # Debug: show detected columns
    my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
    $self->{output}->output_add(long_msg => "DEBUG [$component]: Header found, columns: $col_list", debug => 1);
    
    return %col_index;
}

# Helper: get state from parts using col_index
sub _get_state {
    my ($self, %options) = @_;
    
    my $col_index = $options{col_index};
    my $parts = $options{parts};
    
    if (defined($col_index->{state})) {
        return $parts->[$col_index->{state}];
    } elsif (defined($col_index->{status})) {
        return $parts->[$col_index->{status}];
    }
    # Fallback: last column
    return $parts->[$#{$parts}];
}

# Helper: check cage filter - returns 1 if cage should be SKIPPED
sub _filter_cage {
    my ($self, %options) = @_;
    
    my $cage = $options{cage};
    return 1 if (!defined($cage));  # Skip if cage undefined
    
    # Check exclude first - skip if cage MATCHES exclude pattern
    if (defined($self->{option_results}->{exclude_cage_id}) && $self->{option_results}->{exclude_cage_id} ne '') {
        return 1 if ($cage =~ /$self->{option_results}->{exclude_cage_id}/);
    }
    
    # No filter defined = don't skip anything
    return 0 if (!defined($self->{option_results}->{filter_cage_id}) || $self->{option_results}->{filter_cage_id} eq '');
    
    # Filter defined: skip if cage does NOT match
    return ($cage =~ /$self->{option_results}->{filter_cage_id}/) ? 0 : 1;
}

# Helper: filter IOM - returns 1 if should be SKIPPED
sub _filter_iom {
    my ($self, %options) = @_;
    
    my $iom = $options{iom};
    return 0 if (!defined($iom));  # Don't skip if iom undefined (optional field)
    
    # Check exclude first - skip if iom MATCHES exclude pattern
    if (defined($self->{option_results}->{exclude_iom}) && $self->{option_results}->{exclude_iom} ne '') {
        return 1 if ($iom =~ /$self->{option_results}->{exclude_iom}/);
    }
    
    # No filter defined = don't skip anything
    return 0 if (!defined($self->{option_results}->{filter_iom}) || $self->{option_results}->{filter_iom} eq '');
    
    # Filter defined: skip if iom does NOT match
    return ($iom =~ /$self->{option_results}->{filter_iom}/) ? 0 : 1;
}

# Helper: filter Mag - returns 1 if should be SKIPPED
sub _filter_mag {
    my ($self, %options) = @_;
    
    my $mag = $options{mag};
    return 0 if (!defined($mag));  # Don't skip if mag undefined (optional field)
    
    # Check exclude first - skip if mag MATCHES exclude pattern
    if (defined($self->{option_results}->{exclude_mag}) && $self->{option_results}->{exclude_mag} ne '') {
        return 1 if ($mag =~ /$self->{option_results}->{exclude_mag}/);
    }
    
    # No filter defined = don't skip anything
    return 0 if (!defined($self->{option_results}->{filter_mag}) || $self->{option_results}->{filter_mag} eq '');
    
    # Filter defined: skip if mag does NOT match
    return ($mag =~ /$self->{option_results}->{filter_mag}/) ? 0 : 1;
}

# Helper: filter Fan - returns 1 if should be SKIPPED
sub _filter_fan {
    my ($self, %options) = @_;
    
    my $fan = $options{fan};
    return 0 if (!defined($fan));  # Don't skip if fan undefined (optional field)
    
    # Check exclude first - skip if fan MATCHES exclude pattern
    if (defined($self->{option_results}->{exclude_fan}) && $self->{option_results}->{exclude_fan} ne '') {
        return 1 if ($fan =~ /$self->{option_results}->{exclude_fan}/);
    }
    
    # No filter defined = don't skip anything
    return 0 if (!defined($self->{option_results}->{filter_fan}) || $self->{option_results}->{filter_fan} eq '');
    
    # Filter defined: skip if fan does NOT match
    return ($fan =~ /$self->{option_results}->{filter_fan}/) ? 0 : 1;
}

sub check_fan {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -fan']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*(Cage|IOM|PCM)\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'fan');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $iom = defined($col_index{iom}) ? $parts[$col_index{iom}] : undef;
        my $fan = defined($col_index{fan}) ? $parts[$col_index{fan}] : 
                  defined($col_index{pcm}) ? $parts[$col_index{pcm}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($iom) || !defined($fan));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_iom(iom => $iom));
        next if ($self->_filter_fan(fan => $fan));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_iom${iom}_fan${fan}";
        $self->{items}->{$key} = { display => "cage $cage iom $iom fan $fan", state => $state, perfdata_label => "cage${cage}.iom${iom}.fan${fan}" };
    }
}

sub check_cooling {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -cooling']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*(Cage|IOM|PCM)\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'cooling');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $iom = defined($col_index{iom}) ? $parts[$col_index{iom}] : undef;
        my $fan = defined($col_index{fan}) ? $parts[$col_index{fan}] : 
                  defined($col_index{pcm}) ? $parts[$col_index{pcm}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($iom) || !defined($fan));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_iom(iom => $iom));
        next if ($self->_filter_fan(fan => $fan));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_iom${iom}_cooling${fan}";
        $self->{items}->{$key} = { display => "cage $cage iom $iom cooling $fan", state => $state, perfdata_label => "cage${cage}.iom${iom}.cooling${fan}" };
    }
}

sub check_power {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -power']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'power');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $ps = defined($col_index{ps}) ? $parts[$col_index{ps}] : 
                 defined($col_index{psu}) ? $parts[$col_index{psu}] : 
                 defined($col_index{power}) ? $parts[$col_index{power}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($ps));
        next if ($self->_filter_cage(cage => $cage));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_ps${ps}";
        $self->{items}->{$key} = { display => "cage $cage ps $ps", state => $state, perfdata_label => "cage${cage}.ps${ps}.power" };
    }
}

sub check_iom {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -iom']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'iom');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $iom = defined($col_index{iom}) ? $parts[$col_index{iom}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($iom));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_iom(iom => $iom));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_iom${iom}";
        $self->{items}->{$key} = { display => "cage $cage iom $iom", state => $state, perfdata_label => "cage${cage}.iom${iom}.iom" };
    }
}

sub check_enclosure {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -enclosure']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'enclosure');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage));
        next if ($self->_filter_cage(cage => $cage));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_enclosure";
        $self->{items}->{$key} = { display => "cage $cage enclosure", state => $state, perfdata_label => "cage${cage}.enclosure" };
    }
}

sub check_mag {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -mag']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'mag');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $mag = defined($col_index{mag}) ? $parts[$col_index{mag}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($mag));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_mag(mag => $mag));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_mag${mag}";
        $self->{items}->{$key} = { display => "cage $cage mag $mag", state => $state, perfdata_label => "cage${cage}.mag${mag}.mag" };
    }
}

sub check_sep {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -sep -showcols Cage,IOM,SEP,FWVersion,FWStatus,State']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'sep');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $iom = defined($col_index{iom}) ? $parts[$col_index{iom}] : undef;
        my $sep = defined($col_index{sep}) ? $parts[$col_index{sep}] : 
                  defined($col_index{expander}) ? $parts[$col_index{expander}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($iom) || !defined($sep));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_iom(iom => $iom));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_iom${iom}_sep${sep}";
        $self->{items}->{$key} = { display => "cage $cage iom $iom sep $sep", state => $state, perfdata_label => "cage${cage}.iom${iom}.sep${sep}" };
    }
}

sub check_ilo {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -ilo']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'ilo');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $iom = defined($col_index{iom}) ? $parts[$col_index{iom}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($iom));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_iom(iom => $iom));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_iom${iom}_ilo";
        $self->{items}->{$key} = { display => "cage $cage iom $iom ilo", state => $state, perfdata_label => "cage${cage}.iom${iom}.ilo" };
    }
}

sub check_cdm {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -cdm']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'cdm');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage));
        next if ($self->_filter_cage(cage => $cage));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_cdm";
        $self->{items}->{$key} = { display => "cage $cage cdm", state => $state, perfdata_label => "cage${cage}.cdm" };
    }
}

sub check_cpld {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -cpld']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'cpld');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $iom = defined($col_index{iom}) ? $parts[$col_index{iom}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($iom));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_iom(iom => $iom));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_iom${iom}_cpld";
        $self->{items}->{$key} = { display => "cage $cage iom $iom cpld", state => $state, perfdata_label => "cage${cage}.iom${iom}.cpld" };
    }
}

sub check_ubm {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -ubm -showcols Cage,IOM,Location,State']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'ubm');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $iom = defined($col_index{iom}) ? $parts[$col_index{iom}] : undef;
        my $location = defined($col_index{location}) ? $parts[$col_index{location}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($iom));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_iom(iom => $iom));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $loc_str = defined($location) ? "_${location}" : "";
        my $loc_display = defined($location) ? " $location" : "";
        my $loc_perfdata = defined($location) ? ".${location}" : "";
        
        my $key = "cage${cage}_iom${iom}_ubm${loc_str}";
        $self->{items}->{$key} = { display => "cage $cage iom $iom ubm${loc_display}", state => $state, perfdata_label => "cage${cage}.iom${iom}.ubm${loc_perfdata}" };
    }
}

sub check_connector {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -connector']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'connector');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $iom = defined($col_index{iom}) ? $parts[$col_index{iom}] : undef;
        my $conn = defined($col_index{connector}) ? $parts[$col_index{connector}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($iom) || !defined($conn));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_iom(iom => $iom));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_iom${iom}_connector${conn}";
        $self->{items}->{$key} = { display => "cage $cage iom $iom connector $conn", state => $state, perfdata_label => "cage${cage}.iom${iom}.connector${conn}" };
    }
}

sub check_sfp {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -sfp']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'sfp');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $iom = defined($col_index{iom}) ? $parts[$col_index{iom}] : undef;
        my $sfp = defined($col_index{sfp}) ? $parts[$col_index{sfp}] : 
                  defined($col_index{transceiver}) ? $parts[$col_index{transceiver}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($iom) || !defined($sfp));
        next if ($self->_filter_cage(cage => $cage));
        next if ($self->_filter_iom(iom => $iom));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_iom${iom}_sfp${sfp}";
        $self->{items}->{$key} = { display => "cage $cage iom $iom sfp $sfp", state => $state, perfdata_label => "cage${cage}.iom${iom}.sfp${sfp}" };
    }
}

sub check_temperature {
    my ($self, %options) = @_;
    my ($content) = $options{custom}->execute_command(commands => ['showcage -temperature -showcols Cage,Sensor,Temp,HiCaution,HiWarning,State,Name']);
    
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my $header_found = 0;
    my %col_index;
    
    foreach my $line (split /\n/, $content) {
        next if ($line =~ /^\s*$/ || $line =~ /^\s*-+\s*$/ || $line =~ /\d+\s+total\s*$/i);
        
        if (!$header_found && $line =~ /^\s*Cage\s+/i) {
            %col_index = $self->_parse_header(line => $line, component => 'temperature');
            $header_found = 1;
            next;
        }
        
        next if (!$header_found);
        
        my @parts = split(/\s+/, $line);
        shift @parts if (defined($parts[0]) && $parts[0] eq '');
        
        my $cage = defined($col_index{cage}) ? $parts[$col_index{cage}] : undef;
        my $sensor = defined($col_index{sensor}) ? $parts[$col_index{sensor}] : undef;
        my $state = $self->_get_state(col_index => \%col_index, parts => \@parts);
        
        next if (!defined($cage) || !defined($sensor));
        next if ($self->_filter_cage(cage => $cage));
        next if (defined($self->{option_results}->{exclude_state}) && $self->{option_results}->{exclude_state} ne '' && defined($state) && $state =~ /$self->{option_results}->{exclude_state}/i);
        
        my $key = "cage${cage}_sensor${sensor}_temperature";
        $self->{items}->{$key} = { display => "cage $cage sensor $sensor temperature", state => $state // 'unknown', perfdata_label => "cage${cage}.sensor${sensor}.temperature" };
    }
}

1;

__END__

=head1 MODE

Check cage components status. Note: Some components (ilo, cdm, cpld, ubm) may not be 
available on all platforms. If a component returns no data, it is not supported on 
your storage system.

=over 8

=item B<--component>

Which component to check. Can be specified multiple times.
Available: fan, cooling, power, iom, enclosure, mag, sep, ilo, cdm, cpld, ubm, connector, sfp, temperature.
Default: fan, cooling, power, iom, enclosure, mag, sep.

=item B<--exclude-component>

Exclude specific component(s). Can be specified multiple times.

=item B<--filter-cage-id>

Filter cages by ID (can be a regexp).

=item B<--filter-iom>

Filter by IOM (can be a regexp). Example: --filter-iom='0' to show only IOM 0.

=item B<--filter-mag>

Filter by Magazine (can be a regexp). Example: --filter-mag='1' to show only magazine 1.

=item B<--filter-fan>

Filter by Fan (can be a regexp). Example: --filter-fan='0' to show only fan 0.

=item B<--exclude-cage-id>

Exclude cages by ID (can be a regexp). Example: --exclude-cage-id='0' to exclude cage 0.

=item B<--exclude-iom>

Exclude by IOM (can be a regexp). Example: --exclude-iom='1' to exclude IOM 1.

=item B<--exclude-mag>

Exclude by Magazine (can be a regexp). Example: --exclude-mag='0' to exclude magazine 0.

=item B<--exclude-fan>

Exclude by Fan (can be a regexp). Example: --exclude-fan='2' to exclude fan 2.

=item B<--exclude-state>

Exclude items with specific state (can be a regexp). Example: --exclude-state='unknown' to exclude items with unknown state.

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{display}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{state}, %{display}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{state} !~ /^OK$/i').
You can use the following variables: %{state}, %{display}

=back

=cut
