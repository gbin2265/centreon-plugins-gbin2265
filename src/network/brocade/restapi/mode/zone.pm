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

package network::brocade::restapi::mode::zone;

use base qw(centreon::plugins::templates::counter);

use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_zone_status_output {
    my ($self, %options) = @_;

    return sprintf(
        "status: %s, active config: %s",
        $self->{result_values}->{status},
        $self->{result_values}->{active_config}
    );
}

sub set_counters {
    my ($self, %options) = @_;

    $self->{maps_counters_type} = [
        { name => 'global', type => 0, message_separator => ' - ' }
    ];

    $self->{maps_counters}->{global} = [
        {
            label => 'zone-status',
            type => 2,
            critical_default => '%{status} !~ /enabled/i',
            set => {
                key_values => [ { name => 'status' }, { name => 'active_config' } ],
                closure_custom_output => $self->can('custom_zone_status_output'),
                closure_custom_perfdata => sub { return 0; },
                closure_custom_threshold_check => \&catalog_status_threshold_ng
            }
        },
        { label => 'zones-active', nlabel => 'zone.active.count', set => {
                key_values => [ { name => 'zones_active' } ],
                output_template => 'active zones: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'zones-defined', nlabel => 'zone.defined.count', set => {
                key_values => [ { name => 'zones_defined' } ],
                output_template => 'defined zones: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'aliases-defined', nlabel => 'zone.aliases.defined.count', set => {
                key_values => [ { name => 'aliases_defined' } ],
                output_template => 'defined aliases: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'configs-defined', nlabel => 'zone.configs.defined.count', set => {
                key_values => [ { name => 'configs_defined' } ],
                output_template => 'defined configs: %s',
                perfdatas => [
                    { template => '%s', min => 0 }
                ]
            }
        },
        { label => 'db-size', nlabel => 'zone.database.size.bytes', display_ok => 0, set => {
                key_values => [ { name => 'db_size' } ],
                output_template => 'database size: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0 }
                ]
            }
        },
        { label => 'db-size-max', nlabel => 'zone.database.size.max.bytes', display_ok => 0, set => {
                key_values => [ { name => 'db_size_max' } ],
                output_template => 'database max size: %s %s',
                output_change_bytes => 1,
                perfdatas => [
                    { template => '%s', unit => 'B', min => 0 }
                ]
            }
        },
        { label => 'db-usage-prct', nlabel => 'zone.database.usage.percentage', set => {
                key_values => [ { name => 'db_usage_prct' } ],
                output_template => 'database usage: %.2f %%',
                perfdatas => [
                    { template => '%.2f', unit => '%', min => 0, max => 100 }
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
    });

    return $self;
}

sub manage_selection {
    my ($self, %options) = @_;

    my $effective = $options{custom}->get_zone_effective();
    my $defined = $options{custom}->get_zone_defined();

    $self->{global} = {};

    # Parse effective configuration
    my $eff_data = $effective->{'Response'}->{'effective-configuration'} // 
                   $effective->{'brocade-zone'}->{'effective-configuration'} // {};
    
    my $active_config = $eff_data->{'cfg-name'} // 'none';
    my $status = defined($eff_data->{'cfg-name'}) && $eff_data->{'cfg-name'} ne '' ? 'enabled' : 'disabled';
    my $db_size = $eff_data->{'db-committed'} // $eff_data->{'db-transaction-committed'} // 0;
    my $db_max = $eff_data->{'db-max'} // $eff_data->{'db-max-size'} // 0;
    my $db_usage = ($db_max > 0) ? ($db_size / $db_max * 100) : 0;

    # Count active zones
    my $active_zones = $eff_data->{'enabled-zone'} // [];
    $active_zones = [$active_zones] if (ref($active_zones) ne 'ARRAY');
    my $zones_active_count = scalar(@{$active_zones});

    # Parse defined configuration
    my $def_data = $defined->{'Response'}->{'defined-configuration'} // 
                   $defined->{'brocade-zone'}->{'defined-configuration'} // {};

    # Count defined zones
    my $def_zones = $def_data->{'zone'} // [];
    $def_zones = [$def_zones] if (ref($def_zones) ne 'ARRAY');
    my $zones_defined_count = scalar(@{$def_zones});

    # Count defined aliases
    my $def_aliases = $def_data->{'alias'} // [];
    $def_aliases = [$def_aliases] if (ref($def_aliases) ne 'ARRAY');
    my $aliases_defined_count = scalar(@{$def_aliases});

    # Count defined configs
    my $def_configs = $def_data->{'cfg'} // [];
    $def_configs = [$def_configs] if (ref($def_configs) ne 'ARRAY');
    my $configs_defined_count = scalar(@{$def_configs});

    $self->{global} = {
        status => $status,
        active_config => $active_config,
        zones_active => $zones_active_count,
        zones_defined => $zones_defined_count,
        aliases_defined => $aliases_defined_count,
        configs_defined => $configs_defined_count,
        db_size => $db_size,
        db_size_max => $db_max,
        db_usage_prct => $db_usage
    };
}

1;

__END__

=head1 MODE

Check zone configuration status.

=over 8

=item B<--unknown-zone-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{status}, %{active_config}

=item B<--warning-zone-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{status}, %{active_config}

=item B<--critical-zone-status>

Define the conditions to match for the status to be CRITICAL (default: '%{status} !~ /enabled/i').
You can use the following variables: %{status}, %{active_config}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be:
'zones-active', 'zones-defined', 'aliases-defined', 'configs-defined',
'db-size', 'db-size-max', 'db-usage-prct'.

=back

=cut
