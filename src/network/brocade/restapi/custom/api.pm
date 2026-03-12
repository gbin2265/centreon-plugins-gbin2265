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

package network::brocade::restapi::custom::api;

use strict;
use warnings;
use centreon::plugins::http;
use centreon::plugins::statefile;
use JSON::XS;
use MIME::Base64;
use Digest::MD5 qw(md5_hex);

sub new {
    my ($class, %options) = @_;
    my $self = {};
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
            'hostname:s'             => { name => 'hostname' },
            'port:s'                 => { name => 'port' },
            'proto:s'                => { name => 'proto' },
            'api-username:s'         => { name => 'api_username' },
            'api-password:s'         => { name => 'api_password' },
            'timeout:s'              => { name => 'timeout' },
            'unknown-http-status:s'  => { name => 'unknown_http_status' },
            'warning-http-status:s'  => { name => 'warning_http_status' },
            'critical-http-status:s' => { name => 'critical_http_status' }
        });
    }
    $options{options}->add_help(package => __PACKAGE__, sections => 'REST API OPTIONS', once => 1);

    $self->{output} = $options{output};
    $self->{http} = centreon::plugins::http->new(%options);
    $self->{cache} = centreon::plugins::statefile->new(%options);

    return $self;
}

sub set_options {
    my ($self, %options) = @_;

    $self->{option_results} = $options{option_results};
}

sub set_defaults {}

sub check_options {
    my ($self, %options) = @_;

    $self->{hostname} = (defined($self->{option_results}->{hostname})) ? $self->{option_results}->{hostname} : '';
    $self->{proto} = (defined($self->{option_results}->{proto})) ? $self->{option_results}->{proto} : 'https';
    $self->{port} = (defined($self->{option_results}->{port})) ? $self->{option_results}->{port} : 443;
    $self->{api_username} = (defined($self->{option_results}->{api_username})) ? $self->{option_results}->{api_username} : '';
    $self->{api_password} = (defined($self->{option_results}->{api_password})) ? $self->{option_results}->{api_password} : '';
    $self->{timeout} = (defined($self->{option_results}->{timeout})) ? $self->{option_results}->{timeout} : 30;
    $self->{unknown_http_status} = (defined($self->{option_results}->{unknown_http_status})) ? $self->{option_results}->{unknown_http_status} : '%{http_code} < 200 or %{http_code} >= 300';
    $self->{warning_http_status} = (defined($self->{option_results}->{warning_http_status})) ? $self->{option_results}->{warning_http_status} : '';
    $self->{critical_http_status} = (defined($self->{option_results}->{critical_http_status})) ? $self->{option_results}->{critical_http_status} : '';

    if ($self->{hostname} eq '') {
        $self->{output}->add_option_msg(short_msg => 'Need to specify --hostname option.');
        $self->{output}->option_exit();
    }
    if ($self->{api_username} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --api-username option.");
        $self->{output}->option_exit();
    }
    if ($self->{api_password} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --api-password option.");
        $self->{output}->option_exit();
    }

    $self->{cache}->check_options(option_results => $self->{option_results});

    return 0;
}

sub get_connection_infos {
    my ($self, %options) = @_;

    return $self->{hostname} . '_' . $self->{http}->get_port();
}

sub get_hostname {
    my ($self, %options) = @_;

    return $self->{hostname};
}

sub get_port {
    my ($self, %options) = @_;

    return $self->{port};
}

sub json_decode {
    my ($self, %options) = @_;

    $options{content} =~ s/\r//mg;
    my $decoded;
    eval {
        $decoded = JSON::XS->new->utf8->decode($options{content});
    };
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response: $@");
        $self->{output}->option_exit();
    }

    return $decoded;
}

sub build_options_for_httplib {
    my ($self, %options) = @_;

    $self->{option_results}->{hostname} = $self->{hostname};
    $self->{option_results}->{port} = $self->{port};
    $self->{option_results}->{proto} = $self->{proto};
    $self->{option_results}->{timeout} = $self->{timeout};
}

sub settings {
    my ($self, %options) = @_;

    return if (defined($self->{settings_done}));
    $self->build_options_for_httplib();
    $self->{http}->add_header(key => 'Accept', value => 'application/yang-data+json');
    $self->{http}->add_header(key => 'Content-Type', value => 'application/yang-data+json');
    $self->{http}->set_options(%{$self->{option_results}});
    $self->{settings_done} = 1;
}

sub get_auth_token {
    my ($self, %options) = @_;

    my $has_cache_file = $self->{cache}->read(statefile => 'brocade_restapi_' . md5_hex($self->{hostname}) . '_' . md5_hex($self->{api_username}));
    my $auth_token = $self->{cache}->get(name => 'auth_token');
    my $expires_on = $self->{cache}->get(name => 'expires_on');

    # Token is valid for 30 minutes, we refresh after 25 minutes
    if ($has_cache_file == 0 || !defined($auth_token) || !defined($expires_on) || (($expires_on - time()) < 300)) {
        $self->settings();

        # Brocade REST API uses HTTP Basic Authentication for login
        my $basic_auth = MIME::Base64::encode_base64($self->{api_username} . ':' . $self->{api_password}, '');

        my $content = $self->{http}->request(
            method => 'POST',
            url_path => '/rest/login',
            post_param => [],
            header => [
                'Authorization: Basic ' . $basic_auth,
                'Accept: application/yang-data+json',
                'Content-Type: application/x-www-form-urlencoded'
            ],
            warning_status => '',
            unknown_status => '',
            critical_status => ''
        );

        if ($self->{http}->get_code() < 200 || $self->{http}->get_code() >= 300) {
            $self->{output}->add_option_msg(short_msg => "Login error [code: '" . $self->{http}->get_code() . "'] [message: '" . $self->{http}->get_message() . "']");
            $self->{output}->option_exit();
        }

        # Get Authorization header from response (contains session token)
        $auth_token = $self->{http}->get_header(name => 'Authorization');

        if (!defined($auth_token) || $auth_token eq '') {
            $self->{output}->add_option_msg(short_msg => "Cannot get authorization token from login response");
            $self->{output}->option_exit();
        }

        my $datas = {
            updated => time(),
            auth_token => $auth_token,
            expires_on => time() + 1800  # 30 minutes
        };
        $self->{cache}->write(data => $datas);
    }

    return $auth_token;
}

sub request_api {
    my ($self, %options) = @_;

    $self->settings();
    my $auth_token = $self->get_auth_token();

    my $content = $self->{http}->request(
        method => defined($options{method}) ? $options{method} : 'GET',
        url_path => '/rest/running/' . $options{endpoint},
        get_param => $options{get_param},
        header => [
            'Accept: application/yang-data+json',
            'Authorization: ' . $auth_token
        ],
        unknown_status => $self->{unknown_http_status},
        warning_status => $self->{warning_http_status},
        critical_status => $self->{critical_http_status}
    );

    if (!defined($content) || $content eq '') {
        $self->{output}->add_option_msg(short_msg => "API returns empty content [code: '" . $self->{http}->get_code() . "'] [message: '" . $self->{http}->get_message() . "']");
        $self->{output}->option_exit();
    }

    my $decoded = $self->json_decode(content => $content);
    if (!defined($decoded)) {
        $self->{output}->add_option_msg(short_msg => 'Error while retrieving data (add --debug option for detailed message)');
        $self->{output}->option_exit();
    }

    return $decoded;
}

# Optional API request - returns undef instead of error on 403/404
# Use for features that may not be enabled/licensed on all switches
sub request_api_optional {
    my ($self, %options) = @_;

    $self->settings();
    my $auth_token = $self->get_auth_token();

    my $content = $self->{http}->request(
        method => defined($options{method}) ? $options{method} : 'GET',
        url_path => '/rest/running/' . $options{endpoint},
        get_param => $options{get_param},
        header => [
            'Accept: application/yang-data+json',
            'Authorization: ' . $auth_token
        ],
        unknown_status => '',
        warning_status => '',
        critical_status => ''
    );

    my $http_code = $self->{http}->get_code();
    
    # Return undef for 403 (Forbidden) or 404 (Not Found) - feature not available
    if ($http_code == 403 || $http_code == 404) {
        return undef;
    }

    if (!defined($content) || $content eq '') {
        return undef;
    }

    my $decoded;
    eval {
        $decoded = JSON::XS->new->utf8->decode($content);
    };
    if ($@) {
        return undef;
    }

    return $decoded;
}

# Switch and chassis info
sub get_switch_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fibrechannel-switch/fibrechannel-switch');
}

sub get_chassis_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-chassis/chassis');
}

# Hardware components
sub get_fan_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fru/fan');
}

sub get_ps_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fru/power-supply');
}

sub get_blade_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fru/blade');
}

sub get_sensor_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fru/sensor');
}

# FC ports
sub get_fcport_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-interface/fibrechannel');
}

sub get_fcport_statistics {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-interface/fibrechannel-statistics');
}

# Fabric
sub get_fabric_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fabric/fabric-switch');
}

# MAPS
sub get_maps_status {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-maps/switch-status-policy-report');
}

sub get_maps_system_resources {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-maps/system-resources');
}

# Media/SFP
sub get_media_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-media/media-rdp');
}

# CPU and Memory
sub get_cpu_usage {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fru/cpu');
}

sub get_memory_usage {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fru/memory');
}

# HA Status
sub get_ha_status {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-chassis/ha-status');
}

# Zone
sub get_zone_effective {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-zone/effective-configuration');
}

sub get_zone_defined {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-zone/defined-configuration');
}

# License
sub get_license_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-license/license');
}

# Trunk
sub get_trunk_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fibrechannel-trunk/trunk');
}

sub get_trunk_performance {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fibrechannel-trunk/performance');
}

# Credit Recovery
sub get_credit_recovery {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-chassis/credit-recovery');
}

# FDMI
sub get_fdmi_info {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fdmi/hba');
}

# Name Server
sub get_name_server {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-name-server/fibrechannel-name-server');
}

# Extension Tunnel (FCIP) - optional, only if FCIP is configured
sub get_extension_tunnel {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-extension-tunnel/extension-tunnel');
}

sub get_extension_circuit {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-extension-tunnel/extension-circuit');
}

sub get_extension_circuit_statistics {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-extension-tunnel/extension-circuit-statistics');
}

# Diagnostics (D-port) - optional, only if D-port tests are running
sub get_diagnostics {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-fibrechannel-diagnostics/fibrechannel-diagnostics');
}

# Logical Switch (Virtual Fabrics)
sub get_logical_switch {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-fibrechannel-logical-switch/fibrechannel-logical-switch');
}

# FCR Routing - optional, only if FC Routing is configured
sub get_fcr_configuration {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-fibrechannel-routing/routing-configuration');
}

sub get_fcr_edge_fabric {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-fibrechannel-routing/edge-fabric-alias');
}

sub get_fcr_backbone_fabric {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-fibrechannel-routing/backbone-fabric-info');
}

# NTP / Time
sub get_clock_server {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-time/clock-server');
}

sub get_ntp_clock_server {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-time/ntp-clock-server');
}

sub get_time_zone {
    my ($self, %options) = @_;

    return $self->request_api(endpoint => 'brocade-time/time-zone');
}

# Access Gateway (optional - only if AG mode is enabled)
sub get_ag_nport_map {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-access-gateway/n-port-map');
}

sub get_ag_fport_list {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-access-gateway/f-port-list');
}

sub get_ag_policy {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-access-gateway/policy');
}

sub get_ag_port_group {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-access-gateway/port-group');
}

# LLDP (optional - only if LLDP is enabled)
sub get_lldp_global {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-lldp/lldp-global');
}

sub get_lldp_neighbor {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-lldp/lldp-neighbor-details');
}

# Security certificates
sub get_security_certificate {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-security/security-certificate');
}

sub get_security_certificate_action {
    my ($self, %options) = @_;

    return $self->request_api_optional(endpoint => 'brocade-security/security-certificate-action');
}

1;

__END__

=head1 NAME

Brocade FOS REST API

=head1 SYNOPSIS

Brocade Fibre Channel Switch REST API (FOS 8.2.1+)

=head1 REST API OPTIONS

=over 8

=item B<--hostname>

Brocade switch hostname or IP address.

=item B<--port>

Port used (default: 443)

=item B<--proto>

Specify https if needed (default: 'https')

=item B<--api-username>

API username.

=item B<--api-password>

API password.

=item B<--timeout>

Set HTTP timeout in seconds (default: 30).

=item B<--unknown-http-status>

Threshold unknown for http response code (default: '%{http_code} < 200 or %{http_code} >= 300')

=item B<--warning-http-status>

Warning threshold for http response code.

=item B<--critical-http-status>

Critical threshold for http response code.

=back

=head1 DESCRIPTION

Custom REST API module for Brocade Fibre Channel switches running Fabric OS 8.2.1+.
Handles token-based authentication with automatic caching and renewal.

=cut
