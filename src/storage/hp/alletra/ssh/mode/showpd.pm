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

package storage::hp::alletra::ssh::mode::showpd;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "state: '%s', detailed state: '%s', sed state: '%s'",
        $self->{result_values}->{state},
        $self->{result_values}->{detailed_state},
        $self->{result_values}->{sed_state}
    );
}

sub custom_status_calc {
    my ($self, %options) = @_;

    $self->{result_values}->{pd_id} = $options{new_datas}->{$self->{instance} . '_pd_id'};
    $self->{result_values}->{state} = $options{new_datas}->{$self->{instance} . '_state'};
    $self->{result_values}->{detailed_state} = $options{new_datas}->{$self->{instance} . '_detailed_state'};
    $self->{result_values}->{sed_state} = $options{new_datas}->{$self->{instance} . '_sed_state'};

    return 0;
}

sub pd_long_output {
    my ($self, %options) = @_;

    return sprintf(
        "checking physical disk '%s'",
        $options{instance_value}->{pd_id}
    );
}

sub prefix_pd_output {
    my ($self, %options) = @_;

    return sprintf(
        "physical disk '%s' [%s] ",
        $options{instance_value}->{pd_id},
        $options{instance_value}->{cagepos}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'pds', type => 1, cb_prefix_output => 'prefix_pd_output', cb_long_output => 'pd_long_output', message_multiple => 'All physical disks are ok' }
    ];

    $self->{maps_counters}->{pds} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{state} !~ /normal/i || %{detailed_state} !~ /normal/i',
            warning_default => '%{sed_state} !~ /capable/i',
            set => {
                key_values => [
                    { name => 'pd_id' }, { name => 'cagepos' }, { name => 'state' },
                    { name => 'detailed_state' }, { name => 'sed_state' }
                ],
                closure_custom_calc => $self->can('custom_status_calc'),
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
        'filter-pd-id:s'     => { name => 'filter_pd_id' },
        'filter-pd-type:s'   => { name => 'filter_pd_type' },
        'exclude-pd-id:s'    => { name => 'exclude_pd_id' },
        'exclude-pd-type:s'  => { name => 'exclude_pd_type' },
        'exclude-pd-state:s' => { name => 'exclude_pd_state' }
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($content) = $options{custom}->execute_command(commands => ['showpd -state']);

    # Parse columns dynamically - we need: Id, CagePos, Type, State, Detailed_State, SedState
    my $rows = $options{custom}->parse_columns(
        content  => $content,
        required => ['Id', 'CagePos', 'Type', 'State', 'Detailed_State', 'SedState']
    );

    $self->{pds} = {};
    foreach my $row (@{$rows}) {
        my $pd_id = $row->{id};
        next if (!defined($pd_id));
        
        my $cagepos = $row->{cagepos} // '-';
        my $type = $row->{type} // '-';
        my $state = $row->{state} // 'unknown';
        my $detailed_state = $row->{detailed_state} // $row->{state} // 'unknown';
        my $sed_state = $row->{sedstate} // $row->{sed_state} // 'unknown';

        next if (defined($self->{option_results}->{filter_pd_id}) && $self->{option_results}->{filter_pd_id} ne '' &&
            $pd_id !~ /$self->{option_results}->{filter_pd_id}/);
        next if (defined($self->{option_results}->{filter_pd_type}) && $self->{option_results}->{filter_pd_type} ne '' &&
            $type !~ /$self->{option_results}->{filter_pd_type}/);
        next if (defined($self->{option_results}->{exclude_pd_id}) && $self->{option_results}->{exclude_pd_id} ne '' &&
            $pd_id =~ /$self->{option_results}->{exclude_pd_id}/);
        next if (defined($self->{option_results}->{exclude_pd_type}) && $self->{option_results}->{exclude_pd_type} ne '' &&
            $type =~ /$self->{option_results}->{exclude_pd_type}/i);
        next if (defined($self->{option_results}->{exclude_pd_state}) && $self->{option_results}->{exclude_pd_state} ne '' &&
            $state =~ /$self->{option_results}->{exclude_pd_state}/i);

        $self->{pds}->{'pd' . $pd_id} = {
            pd_id          => $pd_id,
            cagepos        => $cagepos,
            type           => $type,
            state          => $state,
            detailed_state => $detailed_state,
            sed_state      => $sed_state
        };
    }

    if (scalar(keys %{$self->{pds}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No physical disks found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check physical disks status.

=over 8

=item B<--filter-pd-id>

Filter physical disks by ID (can be a regexp).

=item B<--filter-pd-type>

Filter physical disks by type (can be a regexp).

=item B<--exclude-pd-id>

Exclude physical disks by ID (can be a regexp). Example: --exclude-pd-id='0|1' to exclude disks 0 and 1.

=item B<--exclude-pd-type>

Exclude physical disks by type (can be a regexp). Example: --exclude-pd-type='FC' to exclude FC type disks.

=item B<--exclude-pd-state>

Exclude physical disks with specific state (can be a regexp). Example: --exclude-pd-state='failed' to exclude failed disks.

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{state}, %{detailed_state}, %{sed_state}, %{pd_id}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{sed_state} !~ /capable/i').
You can use the following variables: %{state}, %{detailed_state}, %{sed_state}, %{pd_id}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{state} !~ /normal/i || %{detailed_state} !~ /normal/i').
You can use the following variables: %{state}, %{detailed_state}, %{sed_state}, %{pd_id}

=back

=cut
