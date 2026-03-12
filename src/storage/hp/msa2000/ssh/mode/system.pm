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

package storage::hp::msa2000::ssh::mode::system;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    my $msg = sprintf('health: %s', $self->{result_values}->{health});

    # Append unhealthy component summary to the short output
    if (defined($self->{instance_mode}->{unhealthy_summary}) && $self->{instance_mode}->{unhealthy_summary} ne '') {
        $msg .= ' - ' . $self->{instance_mode}->{unhealthy_summary};
    }

    return $msg;
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'system', type => 0 }
    ];

    $self->{maps_counters}->{system} = [
        {
            label => 'health-status',
            type => 2,
            unknown_default => '%{health} =~ /unknown/i',
            warning_default => '',
            critical_default => '%{health} =~ /degraded|fault|failed/i',
            set => {
                key_values => [ { name => 'health' }, { name => 'health_reason' }, { name => 'name' } ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {});

    return $self;
}

my $map_health = {
    0 => 'ok', 1 => 'degraded',
    2 => 'fault', 3 => 'unknown',
    4 => 'not available',
};

sub manage_selection {
    my ($self, %options) = @_;

    # Get the system info (basetype=system)
    my ($sys_result) = $options{custom}->get_infos(
        cmd => 'show system',
        base_type => 'system',
        properties_name => '^(?:system-name|health|health-numeric|health-reason|health-recommendation|midplane-serial-number|vendor-name|product-id|platform-type)$'
    );

    my $system_info;
    if (ref($sys_result) eq 'ARRAY') {
        $system_info = $sys_result->[0] if (scalar(@$sys_result) > 0);
    } elsif (ref($sys_result) eq 'HASH' && scalar(keys %$sys_result) > 0) {
        my @keys = keys %$sys_result;
        $system_info = $sys_result->{$keys[0]};
    }

    if (!defined($system_info)) {
        $self->{output}->add_option_msg(short_msg => 'No system information found.');
        $self->{output}->option_exit();
    }

    my $health = defined($system_info->{'health-numeric'}) ?
        ($map_health->{ $system_info->{'health-numeric'} } // 'unknown') :
        (defined($system_info->{'health'}) ? lc($system_info->{'health'}) : 'unknown');

    $self->{system} = {
        name => defined($system_info->{'system-name'}) ? $system_info->{'system-name'} : 'msa2000',
        health => $health,
        health_reason => defined($system_info->{'health-reason'}) ? $system_info->{'health-reason'} : '',
    };

    $self->{output}->output_add(long_msg => sprintf(
        "system '%s' [product: %s] [serial: %s]",
        $self->{system}->{name},
        defined($system_info->{'product-id'}) ? $system_info->{'product-id'} : '-',
        defined($system_info->{'midplane-serial-number'}) ? $system_info->{'midplane-serial-number'} : '-'
    ));

    # Get unhealthy components (basetype=unhealthy-component)
    my ($uc_result) = $options{custom}->get_infos(
        cmd => 'show system',
        base_type => 'unhealthy-component',
        properties_name => '^(?:component-type|component-id|health|health-numeric|health-reason|health-recommendation)$',
        no_quit => 1
    );

    # Build short summary + verbose details
    # Track worst health across all unhealthy components
    my @summary_parts;
    my $worst_health = $health;
    my %health_severity = ( 'ok' => 0, 'not available' => 0, 'unknown' => 1, 'degraded' => 2, 'fault' => 3 );
    $self->{unhealthy_summary} = '';

    if (defined($uc_result)) {
        my @items = ref($uc_result) eq 'ARRAY' ? @$uc_result : values %$uc_result;
        foreach my $comp (@items) {
            my $name = defined($comp->{'component-id'}) ? $comp->{'component-id'} : 'unknown';
            my $comp_health = defined($comp->{'health-numeric'}) ?
                ($map_health->{ $comp->{'health-numeric'} } // 'unknown') :
                (defined($comp->{'health'}) ? lc($comp->{'health'}) : 'unknown');
            my $comp_type = defined($comp->{'component-type'}) ? $comp->{'component-type'} : '-';
            my $reason = defined($comp->{'health-reason'}) ? $comp->{'health-reason'} : '';
            my $recommendation = defined($comp->{'health-recommendation'}) ? $comp->{'health-recommendation'} : '';

            # Short: just name and health
            push @summary_parts, $name . ': ' . $comp_health;

            # Track worst health
            if (($health_severity{$comp_health} // 0) > ($health_severity{$worst_health} // 0)) {
                $worst_health = $comp_health;
            }

            # Verbose: full details with reason + recommendation
            my $long = sprintf("  [%s] '%s' health: %s", $comp_type, $name, $comp_health);
            $long .= ' - reason: ' . $reason if ($reason ne '');
            $long .= ' - recommendation: ' . $recommendation if ($recommendation ne '');
            $self->{output}->output_add(long_msg => $long);
        }
    }

    $self->{unhealthy_summary} = join(', ', @summary_parts) if (scalar(@summary_parts) > 0);

    # Use the worst health (system or any component) for threshold evaluation
    $self->{system}->{health} = $worst_health;
}

1;

__END__

=head1 MODE

Check overall system health of the HPE MSA 2060.
Unhealthy components are listed in the short output.
Use --verbose to see detailed reasons and recommendations.

=over 8

=item B<--unknown-health-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{health} =~ /unknown/i').
You can use the following variables: %{health}, %{health_reason}, %{name}

=item B<--warning-health-status>

Define the conditions to match for the status to be WARNING (default: '%{health} =~ /degraded/i').
You can use the following variables: %{health}, %{health_reason}, %{name}

=item B<--critical-health-status>

Define the conditions to match for the status to be CRITICAL (default: '%{health} =~ /fault|failed/i').
You can use the following variables: %{health}, %{health_reason}, %{name}

=back

=cut
