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

package storage::hp::alletra::ssh::mode::showmaint;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return $self->{result_values}->{maintenance};
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0 }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'status',
            type => 2,
            critical_default => '%{maintenance} !~ /Not in maintenance mode/i',
            set => {
                key_values => [ { name => 'maintenance' } ],
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

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my ($content) = $options{custom}->execute_command(commands => ['showmaint']);

    $self->{global} = { maintenance => 'Unknown' };

    # Remove CLI prompts
    $content =~ s/^.*?cli%\s*//s;
    $content =~ s/\s*\S*\s*cli%\s*$//s;
    $content =~ s/^\s+|\s+$//g;

    if ($content =~ /Not in maintenance mode/i) {
        $self->{global}->{maintenance} = 'Not in maintenance mode.';
    } else {
        # Store actual output for error message
        $self->{global}->{maintenance} = $content;
    }
}

1;

__END__

=head1 MODE

Check maintenance mode status.

=over 8

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variable: %{maintenance}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variable: %{maintenance}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{maintenance} !~ /Not in maintenance mode/i').
You can use the following variable: %{maintenance}

=back

=cut
