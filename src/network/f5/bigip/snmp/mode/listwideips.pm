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

package network::f5::bigip::snmp::mode::listwideips;

use base qw(centreon::plugins::mode);

use strict;
use warnings;

my $map_avail_state = {
    0 => 'none',
    1 => 'green',
    2 => 'yellow',
    3 => 'red',
    4 => 'blue',
    5 => 'gray',
};

my $map_enabled_state = {
    0 => 'none',
    1 => 'enabled',
    2 => 'disabled',
    3 => 'disabledbyparent',
};

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;

    $options{options}->add_options(arguments => {
        'filter-name:s' => { name => 'filter_name' }
    });

    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
}

sub manage_selection {
    my ($self, %options) = @_;

    # F5-BIGIP-GLOBAL-MIB::gtmWideipStatusTable
    my $mapping = {
        gtmWideipStatusAvailState   => { oid => '.1.3.6.1.4.1.3375.2.3.12.2.3.1.2', map => $map_avail_state },
        gtmWideipStatusEnabledState => { oid => '.1.3.6.1.4.1.3375.2.3.12.2.3.1.3', map => $map_enabled_state },
    };
    my $oid_gtmWideipStatusEntry = '.1.3.6.1.4.1.3375.2.3.12.2.3.1';

    my $snmp_result = $options{snmp}->get_table(
        oid => $oid_gtmWideipStatusEntry,
        nothing_quit => 1
    );

    my $results = {};
    foreach my $oid ($options{snmp}->oid_lex_sort(keys %{$snmp_result})) {
        next if ($oid !~ /^$mapping->{gtmWideipStatusAvailState}->{oid}\.(.*)$/);
        my $instance = $1;

        my $result = $options{snmp}->map_instance(
            mapping  => $mapping,
            results  => $snmp_result,
            instance => $instance
        );

        my @indexes = split(/\./, $instance);
        my $name_length = shift(@indexes);
        my $name = join('', map(chr($_), splice(@indexes, 0, $name_length)));

        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $name !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "skipping '" . $name . "': no matching filter.", debug => 1);
            next;
        }

        $results->{$name} = {
            status => $result->{gtmWideipStatusAvailState},
            state  => $result->{gtmWideipStatusEnabledState}
        };
    }

    return $results;
}

sub run {
    my ($self, %options) = @_;

    my $results = $self->manage_selection(%options);
    foreach my $name (sort keys %{$results}) {
        $self->{output}->output_add(
            long_msg => sprintf(
                '[name: %s] [status: %s] [state: %s]',
                $name,
                $results->{$name}->{status},
                $results->{$name}->{state}
            )
        );
    }

    $self->{output}->output_add(
        severity  => 'OK',
        short_msg => 'List Wide IPs:'
    );
    $self->{output}->display(nolabel => 1, force_ignore_perfdata => 1, force_long_output => 1);
    $self->{output}->exit();
}

sub disco_format {
    my ($self, %options) = @_;

    $self->{output}->add_disco_format(elements => ['name', 'status', 'state']);
}

sub disco_show {
    my ($self, %options) = @_;

    my $results = $self->manage_selection(%options);
    foreach my $name (sort keys %{$results}) {
        $self->{output}->add_disco_entry(
            name   => $name,
            status => $results->{$name}->{status},
            state  => $results->{$name}->{state}
        );
    }
}

1;

__END__

=head1 MODE

List GTM Wide IPs.

=over 8

=item B<--filter-name>

Filter Wide IP name (can be a regexp).

=back

=cut
