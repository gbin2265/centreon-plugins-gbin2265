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

package storage::hp::msa2000::ssh::mode::enclosures;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;

    return sprintf('status: %s [model: %s, disks: %s, PSUs: %s, fans: %s]',
        $self->{result_values}->{health},
        $self->{result_values}->{model},
        $self->{result_values}->{number_of_disks},
        $self->{result_values}->{number_of_psus},
        $self->{result_values}->{number_of_fans}
    );
}

sub prefix_enclosure_output {
    my ($self, %options) = @_;

    return "Enclosure '" . $options{instance_value}->{display} . "' ";
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'enclosure', type => 1, cb_prefix_output => 'prefix_enclosure_output', message_multiple => 'All enclosures are ok' }
    ];

    $self->{maps_counters}->{enclosure} = [
        {
            label => 'status',
            type => 2,
            unknown_default => '%{health} =~ /unknown/i',
            warning_default => '',
            critical_default => '%{health} =~ /degraded|fault|failed|error/i',
            set => {
                key_values => [
                    { name => 'health' }, { name => 'display' }, { name => 'model' },
                    { name => 'number_of_disks' }, { name => 'number_of_psus' }, { name => 'number_of_fans' },
                    { name => 'reason' }
                ],
                closure_custom_output => $self->can('custom_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'enclosure-power', nlabel => 'enclosure.power.watts', set => {
                key_values => [ { name => 'power' }, { name => 'display' } ],
                output_template => 'power: %.2f W',
                perfdatas => [
                    { template => '%.2f', unit => 'W', min => 0, label_extra_instance => 1, instance_use => 'display' }
                ]
            }
        }
    ];
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-enclosure-id:s' => { name => 'filter_enclosure_id' },
        'exclude-enclosure-id:s' => { name => 'exclude_enclosure_id' }
    });

    return $self;
}

my $map_health = {
    0 => 'ok', 1 => 'degraded',
    2 => 'fault', 3 => 'unknown',
    4 => 'not available',
};

sub manage_selection {
    my ($self, %options) = @_;

    my ($result) = $options{custom}->get_infos(
        cmd => 'show enclosure',
        base_type => 'enclosures',
        properties_name => '^(?:durable-id|enclosure-id|name|model|vendor|midplane-serial-number|number-of-disks|number-of-power-supplies|number-of-coolings-elements|status|status-numeric|health|health-numeric|health-reason|health-recommendation|enclosure-power|description|part-number|revision|midplane-type)$'
    );

    $self->{enclosure} = {};

    my @items = ref($result) eq 'ARRAY' ? @$result : values %$result;

    foreach my $enc (@items) {
        my $enc_id = defined($enc->{'enclosure-id'}) ? $enc->{'enclosure-id'} :
                     (defined($enc->{'durable-id'}) ? $enc->{'durable-id'} : 'unknown');
        my $name = 'Enclosure ' . $enc_id;

        if (defined($self->{option_results}->{filter_enclosure_id}) && $self->{option_results}->{filter_enclosure_id} ne '' &&
            $enc_id !~ /$self->{option_results}->{filter_enclosure_id}/) {
            $self->{output}->output_add(long_msg => "skipping enclosure '" . $name . "': no matching filter.", debug => 1);
            next;
        }
        if (defined($self->{option_results}->{exclude_enclosure_id}) && $self->{option_results}->{exclude_enclosure_id} ne '' &&
            $enc_id =~ /$self->{option_results}->{exclude_enclosure_id}/) {
            $self->{output}->output_add(long_msg => "skipping enclosure '" . $name . "': matched exclude.", debug => 1);
            next;
        }

        my $health = defined($enc->{'health-numeric'}) ?
            ($map_health->{ $enc->{'health-numeric'} } // 'unknown') :
            (defined($enc->{'health'}) ? lc($enc->{'health'}) : 'unknown');

        my $power = defined($enc->{'enclosure-power'}) ? $enc->{'enclosure-power'} : undef;
        if (defined($power)) {
            $power =~ s/[^\d.]//g;
            $power = undef if ($power eq '');
        }

        $self->{enclosure}->{$enc_id} = {
            display => $name,
            health => $health,
            model => defined($enc->{'model'}) ? $enc->{'model'} : '-',
            number_of_disks => defined($enc->{'number-of-disks'}) ? $enc->{'number-of-disks'} : '-',
            number_of_psus => defined($enc->{'number-of-power-supplies'}) ? $enc->{'number-of-power-supplies'} : '-',
            number_of_fans => defined($enc->{'number-of-coolings-elements'}) ? $enc->{'number-of-coolings-elements'} : '-',
            reason => defined($enc->{'health-reason'}) ? $enc->{'health-reason'} : '',
            power => $power,
        };

        $self->{output}->output_add(long_msg => sprintf(
            "enclosure '%s' [model: %s] [serial: %s] [vendor: %s]",
            $name,
            defined($enc->{'model'}) ? $enc->{'model'} : '-',
            defined($enc->{'midplane-serial-number'}) ? $enc->{'midplane-serial-number'} : '-',
            defined($enc->{'vendor'}) ? $enc->{'vendor'} : '-'
        ));
    }

    if (scalar(keys %{$self->{enclosure}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => 'No enclosure found.');
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check enclosures health and power consumption.

=over 8

=item B<--filter-enclosure-id>

Filter enclosures by ID (can be a regexp).

=item B<--exclude-enclosure-id>

Exclude enclosures by ID (can be a regexp).

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{health} =~ /unknown/i').
You can use the following variables: %{health}, %{display}, %{model}, %{reason}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING (default: '%{health} =~ /degraded/i').
You can use the following variables: %{health}, %{display}, %{model}, %{reason}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL (default: '%{health} =~ /fault|failed|error/i').
You can use the following variables: %{health}, %{display}, %{model}, %{reason}

=item B<--warning-*> B<--critical-*>

Thresholds.
Can be: 'enclosure-power' (W).

=back

=cut
