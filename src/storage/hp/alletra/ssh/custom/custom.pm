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

package storage::hp::alletra::ssh::custom::custom;

use strict;
use warnings;
use centreon::plugins::ssh;
use centreon::plugins::misc;

sub new {
    my ($class, %options) = @_;
    my $self  = {};
    bless $self, $class;

    if (!defined($options{output})) {
        print "Class Custom: Need to specify 'output' argument.\n";
        exit 3;
    }
    if (!defined($options{options})) {
        $options{output}->add_option_msg(short_msg => "Class Custom: Need to specify 'options' argument.");
        $options{output}->option_exit();
    }

    if (!defined($options{noptions})) {
        $options{options}->add_options(arguments => {
            'hostname:s'        => { name => 'hostname' },
            'timeout:s'         => { name => 'timeout', default => 45 },
            'command:s'         => { name => 'command' },
            'command-path:s'    => { name => 'command_path' },
            'command-options:s' => { name => 'command_options' }
        });
    }
    $options{options}->add_help(package => __PACKAGE__, sections => 'SSH OPTIONS', once => 1);

    $self->{output} = $options{output};
    $self->{ssh} = centreon::plugins::ssh->new(%options);

    return $self;
}

sub set_options {
    my ($self, %options) = @_;

    $self->{option_results} = $options{option_results};
}

sub set_defaults {}

sub check_options {
    my ($self, %options) = @_;

    if (defined($self->{option_results}->{hostname}) && $self->{option_results}->{hostname} ne '') {
        $self->{ssh}->check_options(option_results => $self->{option_results});
    }

    centreon::plugins::misc::check_security_command(
        output => $self->{output},
        command => $self->{option_results}->{command},
        command_options => $self->{option_results}->{command_options},
        command_path => $self->{option_results}->{command_path}
    );

    return 0;
}

sub execute_command {
    my ($self, %options) = @_;

    $self->{ssh_commands} = '';
    my $append = '';
    foreach (@{$options{commands}}) {
        $self->{ssh_commands} .= $append . " $_";
        $append = ';';
    }

    $self->{output}->output_add(long_msg => "Executing SSH command: " . $self->{ssh_commands}, debug => 1);

    my $content;
    if (defined($self->{option_results}->{hostname}) && $self->{option_results}->{hostname} ne '') {
        ($content) = $self->{ssh}->execute(
            ssh_pipe => 1,
            hostname => $self->{option_results}->{hostname},
            command => defined($self->{option_results}->{command}) && $self->{option_results}->{command} ne '' ? $self->{option_results}->{command} : $self->{ssh_commands},
            command_path => $self->{option_results}->{command_path},
            command_options => defined($self->{option_results}->{command_options}) && $self->{option_results}->{command_options} ne '' ? $self->{option_results}->{command_options} : undef,
            timeout => $self->{option_results}->{timeout}
        );
    } else {
        if (!defined($self->{option_results}->{command}) || $self->{option_results}->{command} eq '') {
            $self->{output}->add_option_msg(short_msg => 'please set --hostname option for ssh connection (or --command for local)');
            $self->{output}->option_exit();
        }
        ($content) = centreon::plugins::misc::execute(
            ssh_pipe => 1,
            output => $self->{output},
            options => { timeout => $self->{option_results}->{timeout} },
            command => $self->{option_results}->{command},
            command_path => $self->{option_results}->{command_path},
            command_options => defined($self->{option_results}->{command_options}) && $self->{option_results}->{command_options} ne '' ? $self->{option_results}->{command_options} : undef
        );
    }

    $self->{output}->output_add(long_msg => "Command response:\n" . $content, debug => 1);

    return $content;
}

# Parse column-based output dynamically
# Arguments:
#   content     => raw SSH output
#   required    => arrayref of required column names (case-insensitive, strips -dashes-)
# Returns:
#   arrayref of hashrefs with column_name => value
sub parse_columns {
    my ($self, %options) = @_;
    
    my $content = $options{content};
    my @required = @{$options{required}};
    
    # Remove CLI prompts
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/\n[^\n]*total[^\n]*$//si;  # Remove last line if it contains total
    
    my @lines = split /\n/, $content;
    my @results;
    my %col_index;
    my $header_found = 0;
    
    foreach my $line (@lines) {
        # Skip empty lines and totals
        next if ($line =~ /^\s*$/);
        next if ($line =~ /^\s*-+\s*$/);
        next if ($line =~ /\d+\s+total\s*$/i);
        
        # Detect header line (contains at least 2 required columns)
        if (!$header_found) {
            my $matches = 0;
            foreach my $req (@required) {
                my $pattern = $req;
                $pattern =~ s/_/[_\\s]/g;  # Allow _ or space
                if ($line =~ /\b-?$pattern-?\b/i) {
                    $matches++;
                }
            }
            
            if ($matches >= 2 || ($matches >= 1 && scalar(@required) == 1)) {
                # This is the header line - parse column positions
                my @header_parts = split(/\s+/, $line);
                for my $i (0..$#header_parts) {
                    my $col_name = lc($header_parts[$i]);
                    $col_name =~ s/^-+|-+$//g;  # Remove surrounding dashes
                    $col_name =~ s/[\(\)]//g;   # Remove parentheses
                    $col_index{$col_name} = $i;
                }
                $header_found = 1;
                
                # Debug: show detected columns
                my $col_list = join(', ', map { "$_=$col_index{$_}" } sort keys %col_index);
                $self->{output}->output_add(long_msg => "DEBUG [parse_columns]: Header found, columns: $col_list", debug => 1);
                
                next;
            }
        }
        
        # Parse data line
        if ($header_found) {
            my @parts = split(/\s+/, $line);
            # Remove leading empty element if line starts with spaces
            shift @parts if (defined($parts[0]) && $parts[0] eq '');
            
            next if (scalar(@parts) < 2);  # Skip invalid lines
            
            my %row;
            my $valid = 1;
            
            foreach my $req (@required) {
                my $req_lower = lc($req);
                $req_lower =~ s/_//g;  # Remove underscores for matching
                
                # Find matching column
                my $found = 0;
                foreach my $col_name (keys %col_index) {
                    my $col_clean = $col_name;
                    $col_clean =~ s/_//g;
                    
                    if ($col_clean eq $req_lower || $col_name eq lc($req)) {
                        my $idx = $col_index{$col_name};
                        if (defined($parts[$idx])) {
                            $row{lc($req)} = $parts[$idx];
                            $found = 1;
                            last;
                        }
                    }
                }
                
                # Try alternate names
                if (!$found) {
                    # Handle common variations
                    my %alternates = (
                        'state' => ['state', 'status', 'detailed_state', 'detailedstate'],
                        'detailed_state' => ['detailed_state', 'detailedstate', 'detailed'],
                        'sed_state' => ['sedstate', 'sed_state', 'sed'],
                        'vsize' => ['vsize', 'vsize_mb', 'vsizemib', 'vsizemb'],
                        'connstatus' => ['connstatus', 'status', 'state'],
                    );
                    
                    if (defined($alternates{lc($req)})) {
                        foreach my $alt (@{$alternates{lc($req)}}) {
                            foreach my $col_name (keys %col_index) {
                                my $col_clean = $col_name;
                                $col_clean =~ s/_//g;
                                if ($col_clean eq $alt || $col_name eq $alt) {
                                    my $idx = $col_index{$col_name};
                                    if (defined($parts[$idx])) {
                                        $row{lc($req)} = $parts[$idx];
                                        $found = 1;
                                        last;
                                    }
                                }
                            }
                            last if $found;
                        }
                    }
                }
            }
            
            # Only add if we have at least some data
            if (scalar(keys %row) > 0) {
                push @results, \%row;
            }
        }
    }
    
    return \@results;
}

1;

__END__

=head1 NAME

ssh

=head1 SYNOPSIS

HPE Alletra SSH custom mode

=head1 SSH OPTIONS

=over 8

=item B<--hostname>

Hostname to query.

=item B<--timeout>

Timeout in seconds for the command (default: 45).

=item B<--command>

Command to get information. Used it you have output in a file.

=item B<--command-path>

Command path.

=item B<--command-options>

Command options.

=back

=head1 DESCRIPTION

Custom SSH mode for HPE Alletra MP / Alletra 9000 (3PAR) storage systems.
Handles SSH connection and CLI command execution.

=cut
