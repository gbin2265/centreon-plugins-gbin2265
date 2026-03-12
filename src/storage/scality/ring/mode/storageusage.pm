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

package storage::scality::ring::mode::storageusage;
use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;

sub custom_usage_output {
    my ($self, %options) = @_;
    my ($used_value, $used_unit)   = $self->{perfdata}->change_bytes(value => $self->{result_values}->{used});
    my ($free_value, $free_unit)   = $self->{perfdata}->change_bytes(value => $self->{result_values}->{free});
    my ($total_value, $total_unit) = $self->{perfdata}->change_bytes(value => $self->{result_values}->{total});
    return sprintf(
        "used: %s%s, free: %s%s, total: %s%s (%.1f%%)",
        $used_value,  $used_unit,
        $free_value,  $free_unit,
        $total_value, $total_unit,
        $self->{result_values}->{prct_used}
    );
}

sub set_counters {
    my ($self, %options) = @_;
    $self->{maps_counters_type} = [
        { name => 'rings', type => 1, cb_prefix_output => 'prefix_ring_output',
          message_multiple => 'All rings storage usage OK', skipped_code => { -10 => 1 } },
    ];
    $self->{maps_counters}->{rings} = [
        { label => 'usage', nlabel => 'ring.storage.usage.bytes', set => {
            key_values => [ { name => 'used' }, { name => 'free' }, { name => 'total' },
                            { name => 'prct_used' }, { name => 'name' } ],
            closure_custom_output => $self->can('custom_usage_output'),
            perfdatas => [ {
                template => '%d', unit => 'B', min => 0, max => 'total',
                label_extra_instance => 1, instance_use => 'name',
                cast_int => 1,
            } ],
          }
        },
        { label => 'usage-free', nlabel => 'ring.storage.free.bytes', display_ok => 0, set => {
            key_values => [ { name => 'free' }, { name => 'used' }, { name => 'total' }, { name => 'name' } ],
            output_template => 'free: %s B',
            perfdatas => [ {
                template => '%d', unit => 'B', min => 0, max => 'total',
                label_extra_instance => 1, instance_use => 'name',
                cast_int => 1,
            } ],
          }
        },
        { label => 'usage-prct', nlabel => 'ring.storage.usage.percentage', display_ok => 0, set => {
            key_values => [ { name => 'prct_used' }, { name => 'name' } ],
            output_template => 'used: %.2f %%',
            perfdatas => [ {
                template => '%.2f', unit => '%', min => 0, max => 100,
                label_extra_instance => 1, instance_use => 'name',
            } ],
          }
        },
        { label => 'nodes', nlabel => 'ring.nodes.count', set => {
            key_values => [ { name => 'nodes' }, { name => 'name' } ],
            output_template => '%d node(s)',
            perfdatas => [ { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
        { label => 'objects', nlabel => 'ring.objects.count', set => {
            key_values => [ { name => 'objects' }, { name => 'name' } ],
            output_template => '%d unique object(s)',
            perfdatas => [ { template => '%d', min => 0, label_extra_instance => 1, instance_use => 'name' } ],
          }
        },
    ];
}

sub prefix_ring_output {
    my ($self, %options) = @_;
    return "Ring '" . $options{instance_value}->{name} . "' ";
}

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options, force_new_perfdata => 1);
    bless $self, $class;
    $options{options}->add_options(arguments => {
        'filter-name:s'  => { name => 'filter_name'  },
        'filter-type:s'  => { name => 'filter_type'  },
        'exclude-name:s' => { name => 'exclude_name' },
        'exclude-type:s' => { name => 'exclude_type' },
    });
    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;
    my $data  = $options{custom}->get_rings();
    my $items = ref($data) eq 'ARRAY' ? $data : [];

    $self->{rings} = {};
    foreach my $ring (@{$items}) {
        my $name = $ring->{name} // $ring->{id} // 'unknown';
        # Filters
        next if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' && $name                     !~ /$self->{option_results}->{filter_name}/);
        next if (defined($self->{option_results}->{filter_type}) && $self->{option_results}->{filter_type} ne '' && ($ring->{type} // $name)  !~ /$self->{option_results}->{filter_type}/i);
        # Excludes
        next if (defined($self->{option_results}->{exclude_name}) && $self->{option_results}->{exclude_name} ne '' && $name                   =~ /$self->{option_results}->{exclude_name}/);
        next if (defined($self->{option_results}->{exclude_type}) && $self->{option_results}->{exclude_type} ne '' && ($ring->{type} // $name) =~ /$self->{option_results}->{exclude_type}/i);

        my $total = $ring->{diskspace_total}     // 0 || 0;
        my $used  = $ring->{diskspace_used}      // 0 || 0;
        my $free  = $ring->{diskspace_available} // ($total - $used);
        my $prct  = $total > 0 ? ($used / $total * 100) : 0;

        $self->{rings}->{$name} = {
            name      => $name,
            total     => $total,
            used      => $used,
            free      => $free,
            prct_used => $prct,
            nodes     => ($ring->{number_of_nodes}          // 0) || 0,
            objects   => ($ring->{unique_number_of_objects} // 0) || 0,
        };
    }
    if (scalar(keys %{$self->{rings}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No rings found.");
        $self->{output}->option_exit();
    }
}
1;

__END__

=head1 MODE

Check Scality RING storage usage per ring.

=over 8

=item B<--filter-name>

Filter rings by name (regexp).

=item B<--filter-type>

Filter rings by type (regexp, e.g. DATA, META).

=item B<--exclude-name>

Exclude rings by name (regexp).

=item B<--exclude-type>

Exclude rings by type (regexp).

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'usage', 'usage-free', 'usage-prct', 'nodes', 'objects'.

=back

=cut
