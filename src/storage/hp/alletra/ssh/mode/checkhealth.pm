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

package storage::hp::alletra::ssh::mode::checkhealth;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return $self->{result_values}->{message};
}

sub prefix_component_output {
    my ($self, %options) = @_;
    return "";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'components', type => 1, cb_prefix_output => 'prefix_component_output',
          message_multiple => 'All health checks are ok' }
    ];

    $self->{maps_counters}->{components} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{status} =~ /fail/i',
            set => {
                key_values => [ { name => 'component' }, { name => 'status' }, { name => 'message' } ],
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
        'filter-message:s'     => { name => 'filter_message' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::check_options(%options);

    $self->{check_components} = [];
    my @available_components = qw(
        alert cabling cage cdm cert dar date file fs host ld license 
        network node pd pdch port qos rc security signature snmp task ui vlun vv
    );

    if (defined($self->{option_results}->{component}) && scalar(@{$self->{option_results}->{component}}) > 0) {
        foreach my $comp (@{$self->{option_results}->{component}}) {
            if (grep(/^$comp$/i, @available_components)) {
                push @{$self->{check_components}}, lc($comp);
            } else {
                $self->{output}->add_option_msg(short_msg => "Unknown component: $comp");
                $self->{output}->option_exit();
            }
        }
    } else {
        @{$self->{check_components}} = @available_components;
    }

    $self->{exclude_components} = {};
    if (defined($self->{option_results}->{exclude_component})) {
        foreach my $comp (@{$self->{option_results}->{exclude_component}}) {
            $self->{exclude_components}->{lc($comp)} = 1;
        }
    }
}

sub manage_selection {
    my ($self, %options) = @_;

    $self->{components} = {};
    $self->{global_status} = 0;

    my @components_to_check = grep { !$self->{exclude_components}->{$_} } @{$self->{check_components}};
    
    if (scalar(@components_to_check) == 0) {
        $self->{output}->add_option_msg(short_msg => "No components to check after exclusions");
        $self->{output}->option_exit();
    }

    foreach my $component (@components_to_check) {
        my $cmd = 'checkhealth -quiet ' . $component;
        my ($stdout) = $options{custom}->execute_command(commands => [$cmd]);

        my ($status, $message);
        
        # Clean up stdout - remove prompts
        my $clean_output = $stdout;
        $clean_output =~ s/^.*?cli%\s*//s;
        $clean_output =~ s/\s*\S*\s*cli%\s*$//s;
        $clean_output =~ s/\r\n/\n/g;
        $clean_output =~ s/^\s+|\s+$//g;
        
        # Remove all whitespace for comparison
        my $check_output = $clean_output;
        $check_output =~ s/\s+//g;
        
        # Check if healthy: "Thefollowingcomponentsarehealthy:<component>"
        if ($check_output =~ /^Thefollowingcomponentsarehealthy:(\S+)$/i) {
            my $healthy_comp = lc($1);
            if ($healthy_comp eq lc($component)) {
                $status = 'pass';
                $message = "The following components are healthy: $component";
            } else {
                # Component mismatch - treat as fail
                $status = 'fail';
                $message = "Expected component '$component' but got '$healthy_comp'";
            }
        } else {
            # Not healthy - get detail output
            $status = 'fail';
            
            my $detail_cmd = 'checkhealth -detail ' . $component;
            my ($detail_stdout) = $options{custom}->execute_command(commands => [$detail_cmd]);
            
            $message = $detail_stdout;
            $message =~ s/^.*?cli%\s*//s;
            $message =~ s/\s*\S*\s*cli%\s*$//s;
            $message =~ s/\|/ /g;
            $message =~ s/^\s+|\s+$//g;
            $message = 'Health check failed' if ($message eq '');
        }

        # Apply message filter if defined
        if (defined($self->{option_results}->{filter_message}) && $self->{option_results}->{filter_message} ne '') {
            next if ($message !~ /$self->{option_results}->{filter_message}/i);
        }

        $self->{components}->{$component} = {
            component => $component,
            status => $status,
            message => $message
        };
    }

    if (scalar(keys %{$self->{components}}) == 0) {
        $self->{output}->add_option_msg(short_msg => "No health check results found");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check health status using checkhealth command.

=over 8

=item B<--component>

Components to check (default: all). Available: alert, cabling, cage, cdm, cert, dar, date, file, fs, host, ld, license, network, node, pd, pdch, port, qos, rc, security, signature, snmp, task, ui, vlun, vv.

=item B<--exclude-component>

Exclude component(s).

=item B<--filter-message>

Filter by message (regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{component}, %{message}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{component}, %{message}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} =~ /fail/i').
You can use the following variables: %{status}, %{component}, %{message}

=back

=cut
