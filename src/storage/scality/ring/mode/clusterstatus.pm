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

package storage::scality::ring::mode::clusterstatus;
use base qw(centreon::plugins::templates::counter);
use strict;
use warnings;
use centreon::plugins::templates::catalog_functions qw(catalog_status_threshold_ng);

sub custom_status_output {
    my ($self, %options) = @_;
    return sprintf(
        "supv2 is '%s', bizstoresup is '%s' [version: %s]",
        $self->{result_values}->{supv2_status},
        $self->{result_values}->{bizstoresup_status},
        $self->{result_values}->{version}
    );
}

sub set_counters {
    my ($self, %options) = @_;
    $self->{maps_counters_type} = [
        { name => 'cluster', type => 0, message_separator => ', ' },
    ];
    $self->{maps_counters}->{cluster} = [
        { label => 'status', type => 2,
          critical_default => '%{supv2_status} !~ /^running$/i || %{bizstoresup_status} !~ /^running$/i',
          set => {
            key_values => [
                { name => 'supv2_status' },
                { name => 'bizstoresup_status' },
                { name => 'version' },
            ],
            closure_custom_output => $self->can('custom_status_output'),
            closure_custom_perfdata => sub { return 0; },
            closure_custom_threshold_check => \&catalog_status_threshold_ng,
          }
        },
        { label => 'rings', nlabel => 'cluster.rings.total.count', set => {
            key_values      => [ { name => 'rings_total' } ],
            output_template => '%d ring(s) total',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'rings-ok', nlabel => 'cluster.rings.ok.count', set => {
            key_values      => [ { name => 'rings_ok' } ],
            output_template => '%d ring(s) OK',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'rings-critical', nlabel => 'cluster.rings.critical.count', set => {
            key_values      => [ { name => 'rings_critical' } ],
            output_template => '%d ring(s) CRITICAL',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'servers', nlabel => 'cluster.servers.total.count', set => {
            key_values      => [ { name => 'servers_total' } ],
            output_template => '%d server(s) total',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'servers-ok', nlabel => 'cluster.servers.ok.count', set => {
            key_values      => [ { name => 'servers_ok' } ],
            output_template => '%d server(s) OK',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'servers-critical', nlabel => 'cluster.servers.critical.count', set => {
            key_values      => [ { name => 'servers_critical' } ],
            output_template => '%d server(s) CRITICAL',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'disks', nlabel => 'cluster.disks.total.count', set => {
            key_values      => [ { name => 'disks_total' } ],
            output_template => '%d disk(s) total',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'disks-ok', nlabel => 'cluster.disks.ok.count', set => {
            key_values      => [ { name => 'disks_ok' } ],
            output_template => '%d disk(s) OK',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'disks-critical', nlabel => 'cluster.disks.critical.count', set => {
            key_values      => [ { name => 'disks_critical' } ],
            output_template => '%d disk(s) CRITICAL',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'storenodes', nlabel => 'cluster.storenodes.total.count', set => {
            key_values      => [ { name => 'storenodes_total' } ],
            output_template => '%d storenode(s) total',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'storenodes-ok', nlabel => 'cluster.storenodes.ok.count', set => {
            key_values      => [ { name => 'storenodes_ok' } ],
            output_template => '%d storenode(s) running',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
        { label => 'storenodes-critical', nlabel => 'cluster.storenodes.critical.count', set => {
            key_values      => [ { name => 'storenodes_critical' } ],
            output_template => '%d storenode(s) not running',
            perfdatas       => [ { template => '%d', min => 0 } ],
          }
        },
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
    my $data       = $options{custom}->get_cluster_status();
    my $rings      = $options{custom}->get_rings();
    my $servers    = $options{custom}->get_nodes();
    my $disks      = $options{custom}->get_drives();
    my $storenodes = $options{custom}->get_storenodes();

    # Rings
    my ($rings_ok, $rings_crit) = (0, 0);
    foreach my $r (@{$rings}) {
        my $s = lc($r->{status} // 'unknown');
        if    ($s eq 'ok')       { $rings_ok++;   }
        elsif ($s =~ /critical/) { $rings_crit++; }
    }

    # Servers
    my ($srv_ok, $srv_crit) = (0, 0);
    foreach my $s (@{$servers}) {
        my $st = lc($s->{status} // 'unknown');
        if    ($st eq 'ok')       { $srv_ok++;   }
        elsif ($st =~ /critical/) { $srv_crit++; }
    }

    # Disks
    my ($disks_ok, $disks_crit) = (0, 0);
    foreach my $d (@{$disks}) {
        my $st = lc($d->{status} // 'unknown');
        if    ($st eq 'ok')       { $disks_ok++;   }
        elsif ($st =~ /critical/) { $disks_crit++; }
    }

    # Storenodes
    my ($sn_ok, $sn_crit) = (0, 0);
    foreach my $n (@{$storenodes}) {
        my $st = $n->{state} // 'unknown';
        if    ($st =~ /^RUN$/i) { $sn_ok++;   }
        else                    { $sn_crit++; }
    }

    $self->{cluster} = {
        supv2_status       => $data->{supv2_status}       // 'unknown',
        bizstoresup_status => $data->{bizstoresup_status} // 'unknown',
        version            => $data->{supapi_version}     // 'n/a',
        rings_total        => scalar(@{$rings}),
        rings_ok           => $rings_ok,
        rings_critical     => $rings_crit,
        servers_total      => scalar(@{$servers}),
        servers_ok         => $srv_ok,
        servers_critical   => $srv_crit,
        disks_total        => scalar(@{$disks}),
        disks_ok           => $disks_ok,
        disks_critical     => $disks_crit,
        storenodes_total   => scalar(@{$storenodes}),
        storenodes_ok      => $sn_ok,
        storenodes_critical => $sn_crit,
    };
}
1;

__END__

=head1 MODE

Check Scality RING cluster overall status and component counts.

=over 8

=item B<--unknown-status>

Define the conditions to match for the status to be UNKNOWN.
You can use the following variables: %{supv2_status}, %{bizstoresup_status}

=item B<--warning-status>

Define the conditions to match for the status to be WARNING.
You can use the following variables: %{supv2_status}, %{bizstoresup_status}

=item B<--critical-status>

Define the conditions to match for the status to be CRITICAL
(default: '%{supv2_status} !~ /^running$/i || %{bizstoresup_status} !~ /^running$/i').
You can use the following variables: %{supv2_status}, %{bizstoresup_status}

=item B<--warning-*> B<--critical-*>

Thresholds. Can be: 'rings', 'rings-ok', 'rings-critical',
'servers', 'servers-ok', 'servers-critical',
'disks', 'disks-ok', 'disks-critical',
'storenodes', 'storenodes-ok', 'storenodes-critical'.

=back

=cut
