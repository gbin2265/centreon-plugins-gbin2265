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

package storage::scality::ring::custom::api;

use strict;
use warnings;
use centreon::plugins::http;
use JSON::XS;
use MIME::Base64;

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
            'hostname:s'              => { name => 'hostname' },
            'port:s'                  => { name => 'port',           default => 443 },
            'proto:s'                 => { name => 'proto',          default => 'https' },
            'api-username:s'          => { name => 'api_username' },
            'api-password:s'          => { name => 'api_password' },
            'auth-mode:s'             => { name => 'auth_mode',      default => 'keycloak' },
            'keycloak-url:s'          => { name => 'keycloak_url' },
            'keycloak-realm:s'        => { name => 'keycloak_realm', default => 'ring' },
            'keycloak-client:s'       => { name => 'keycloak_client', default => 'supervisor_ui' },
            'keycloak-client-secret:s'=> { name => 'keycloak_client_secret' },
            'timeout:s'               => { name => 'timeout',        default => 30 },
            'insecure'                => { name => 'insecure' },
            'ssl-opt:s@'              => { name => 'ssl_opt' },
            'api-limit:s'             => { name => 'api_limit',              default => 1000 },
            'unknown-http-status:s'   => { name => 'unknown_http_status' },
            'warning-http-status:s'   => { name => 'warning_http_status' },
            'critical-http-status:s'  => { name => 'critical_http_status' },
        });
    }

    $options{options}->add_help(package => __PACKAGE__, sections => 'REST API OPTIONS', once => 1);

    $self->{output} = $options{output};
    $self->{http}   = centreon::plugins::http->new(%options, default_backend => 'curl');
    $self->{token}  = undef;

    return $self;
}

sub set_options {
    my ($self, %options) = @_;
    $self->{option_results} = $options{option_results};
}

sub set_defaults {}

sub check_options {
    my ($self, %options) = @_;
    $self->{hostname}               = $self->{option_results}->{hostname}               // '';
    $self->{port}                   = $self->{option_results}->{port}                   // 443;
    $self->{proto}                  = $self->{option_results}->{proto}                  // 'https';
    $self->{timeout}                = $self->{option_results}->{timeout}                // 30;
    $self->{username}               = $self->{option_results}->{api_username}           // '';
    $self->{password}               = $self->{option_results}->{api_password}           // '';
    $self->{auth_mode}              = lc($self->{option_results}->{auth_mode}           // 'keycloak');
    $self->{keycloak_url}           = $self->{option_results}->{keycloak_url}           // '';
    $self->{keycloak_realm}         = $self->{option_results}->{keycloak_realm}         // 'ring';
    $self->{keycloak_client}        = $self->{option_results}->{keycloak_client}        // 'supervisor_ui';
    $self->{keycloak_client_secret} = $self->{option_results}->{keycloak_client_secret} // '';
    $self->{insecure}               = $self->{option_results}->{insecure}               // undef;
    $self->{ssl_opt}                = $self->{option_results}->{ssl_opt}                // [];
    $self->{api_limit}              = $self->{option_results}->{api_limit}              // 1000;
    $self->{unknown_http_status}    = $self->{option_results}->{unknown_http_status}    // '%{http_code} < 200 or %{http_code} >= 300';
    $self->{warning_http_status}    = $self->{option_results}->{warning_http_status}    // '';
    $self->{critical_http_status}   = $self->{option_results}->{critical_http_status}   // '';

    if ($self->{hostname} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --hostname option.");
        $self->{output}->option_exit();
    }
    if ($self->{username} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --api-username option.");
        $self->{output}->option_exit();
    }
    if ($self->{password} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --api-password option.");
        $self->{output}->option_exit();
    }
    if ($self->{auth_mode} !~ /^(keycloak|basic)$/) {
        $self->{output}->add_option_msg(short_msg => "--auth-mode must be 'keycloak' or 'basic'.");
        $self->{output}->option_exit();
    }

    # Keycloak URL valt terug op hostname als niet opgegeven
    if ($self->{auth_mode} eq 'keycloak' && $self->{keycloak_url} eq '') {
        $self->{keycloak_url} = $self->{proto} . '://' . $self->{hostname};
    }

    return 0;
}

##############################################
# Auth: Keycloak (Resource Owner Password Grant)
##############################################

sub _get_token {
    my ($self) = @_;
    return if (defined($self->{token}) && $self->{token} ne '');

    my ($kc_proto, $kc_host, $kc_port) = ('https', '', 443);
    if ($self->{keycloak_url} =~ m{^(https?)://([^/:]+)(?::(\d+))?}) {
        $kc_proto = $1;
        $kc_host  = $2;
        $kc_port  = $3 // ($kc_proto eq 'https' ? 443 : 80);
    } else {
        $kc_host = $self->{keycloak_url};
    }

    my $token_path = '/auth/realms/' . $self->{keycloak_realm} .
                     '/protocol/openid-connect/token';

    my %http_options = (
        hostname        => $kc_host,
        port            => $kc_port,
        proto           => $kc_proto,
        url_path        => $token_path,
        timeout         => $self->{timeout},
        method          => 'POST',
        header          => ['Content-Type: application/x-www-form-urlencoded'],
        query_form_post => 'grant_type=password'
                         . '&client_id='     . _url_encode($self->{keycloak_client})
                         . '&client_secret=' . _url_encode($self->{keycloak_client_secret})
                         . '&username='      . _url_encode($self->{username})
                         . '&password='      . _url_encode($self->{password}),
        unknown_status  => '',
        warning_status  => '',
        critical_status => '',
    );

    if (defined($self->{insecure})) { $http_options{insecure} = $self->{insecure}; }
    if (scalar(@{$self->{ssl_opt}}) > 0) { $http_options{ssl_opt} = $self->{ssl_opt}; }

    my $content   = $self->{http}->request(%http_options);
    my $http_code = $self->{http}->get_code();

    if ($http_code == 401 || $http_code == 400) {
        $self->{output}->add_option_msg(
            short_msg => "Keycloak authentication failed (HTTP $http_code): " .
                         "invalid credentials, realm '$self->{keycloak_realm}' or " .
                         "client '$self->{keycloak_client}'."
        );
        $self->{output}->option_exit();
    }
    if ($http_code != 200) {
        $self->{output}->add_option_msg(
            short_msg => "Keycloak token endpoint returned HTTP $http_code " .
                         "(URL: $self->{keycloak_url}$token_path)"
        );
        $self->{output}->option_exit();
    }

    my $decoded;
    eval { $decoded = JSON::XS->new->utf8->decode($content); };
    if ($@ || !defined($decoded->{access_token})) {
        $self->{output}->add_option_msg(
            short_msg => "Cannot retrieve access_token from Keycloak: $@"
        );
        $self->{output}->option_exit();
    }

    $self->{token} = $decoded->{access_token};
}

##############################################
# Auth: Basic — bouw Authorization header
##############################################

sub _basic_auth_header {
    my ($self) = @_;
    return 'Basic ' . encode_base64($self->{username} . ':' . $self->{password}, '');
}

sub _url_encode {
    my ($str) = @_;
    $str =~ s/([^A-Za-z0-9\-_.~])/sprintf("%%%02X", ord($1))/ge;
    return $str;
}

##############################################
# Generic GET — kiest auth methode automatisch
##############################################

sub _request {
    my ($self, %options) = @_;

    # Bepaal Authorization header op basis van auth_mode
    my $auth_header;
    if ($self->{auth_mode} eq 'keycloak') {
        $self->_get_token();
        $auth_header = 'Authorization: Bearer ' . $self->{token};
    } else {
        $auth_header = 'Authorization: ' . $self->_basic_auth_header();
    }

    my %http_options = (
        hostname        => $self->{hostname},
        port            => $self->{port},
        proto           => $self->{proto},
        url_path        => '/api/v0.1' . $options{path},
        timeout         => $self->{timeout},
        header          => [ $auth_header, 'Accept: application/json' ],
        unknown_status  => $self->{unknown_http_status},
        warning_status  => $self->{warning_http_status},
        critical_status => $self->{critical_http_status},
    );

    my $content   = $self->{http}->request(%http_options);
    my $http_code = $self->{http}->get_code();

    if ($http_code == 401 && $self->{auth_mode} eq 'keycloak') {
        $self->{token} = undef;
        $self->_get_token();
        $http_options{header} = [
            'Authorization: Bearer ' . $self->{token},
            'Accept: application/json',
        ];
        $content   = $self->{http}->request(%http_options);
        $http_code = $self->{http}->get_code();
    }

    if ($http_code == 401) {
        $self->{output}->add_option_msg(
            short_msg => "HTTP 401 on $options{path}: authentication failed " .
                         "(mode: $self->{auth_mode}, user: '$self->{username}')."
        );
        $self->{output}->option_exit();
    }
    if ($http_code == 403) {
        $self->{output}->add_option_msg(
            short_msg => "HTTP 403 on $options{path}: user '$self->{username}' " .
                         "lacks permissions."
        );
        $self->{output}->option_exit();
    }
    if ($http_code != 200) {
        $self->{output}->add_option_msg(
            short_msg => "HTTP $http_code returned for path: $options{path}"
        );
        $self->{output}->option_exit();
    }
    if (!defined($content) || $content eq '') {
        $self->{output}->add_option_msg(
            short_msg => "Empty response for path: $options{path}"
        );
        $self->{output}->option_exit();
    }

    my $decoded;
    eval { $decoded = JSON::XS->new->utf8->decode($content); };
    if ($@) {
        $self->{output}->add_option_msg(short_msg => "Cannot decode JSON: $@");
        $self->{output}->option_exit();
    }

    return $decoded;
}

##############################################
# Public API methods
##############################################

sub get_cluster_status { my ($self) = @_; return $self->_request(path => '/status/'); }

sub _get_items {
    my ($self, %options) = @_;

    my @all_items;
    my $offset = 0;
    my $limit  = $self->{api_limit};

    while (1) {
        my $sep   = ($options{path} =~ /\?/) ? '&' : '?';
        my $path  = $options{path} . $sep . 'limit=' . $limit . '&offset=' . $offset;
        my $data  = $self->_request(path => $path);

        # Geen _items structuur — geef data direct terug
        if (!defined($data->{_items})) {
            return $data;
        }

        my $page_count = scalar(@{$data->{_items}});
        push @all_items, @{$data->{_items}};

        # Stop als we minder items kregen dan de limiet — laatste pagina bereikt
        last if ($page_count < $limit);

        $offset += $limit;
    }

    return \@all_items;
}

sub get_nodes       { my ($self) = @_; return $self->_get_items(path => '/servers/');           }
sub get_storenodes  { my ($self) = @_; return $self->_get_items(path => '/storenodes/');        }
sub get_volumes     { my ($self) = @_; return $self->_get_items(path => '/volumes/');           }
sub get_connectors  { my ($self) = @_; return $self->_get_items(path => '/volume_connectors/'); }
sub get_rings       { my ($self) = @_; return $self->_get_items(path => '/rings/');             }
sub get_drives      { my ($self) = @_; return $self->_get_items(path => '/disks/');             }
sub get_s3_clusters { my ($self) = @_; return $self->_get_items(path => '/s3_clusters/');       }

1;

__END__

=head1 NAME

storage::scality::ring::custom::api - Scality RING Supervisor API connector

=head1 REST API OPTIONS

=over 8

=item B<--hostname>

IP address or FQDN of the Scality Supervisor (required).

=item B<--port>

API port (default: 443).

=item B<--proto>

Protocol: http or https (default: https).

=item B<--api-username>

Username for authentication (required).

=item B<--api-password>

Password for authentication (required).

=item B<--auth-mode>

Authentication mode: 'keycloak' or 'basic' (default: keycloak).
Use 'basic' for older Scality installations without Keycloak.

=item B<--keycloak-url>

Keycloak base URL (required when using keycloak auth mode).
Example: --keycloak-url=https://keycloak.example.com

=item B<--keycloak-realm>

Keycloak realm (default: ring).

=item B<--keycloak-client>

Keycloak client ID (default: supervisor_ui).

=item B<--keycloak-client-secret>

Keycloak client secret (optional).

=item B<--timeout>

HTTP request timeout in seconds (default: 30).

=item B<--insecure>

Disable SSL certificate verification.

=item B<--ssl-opt>

Custom SSL options (repeatable). Example: --ssl-opt="SSL_version => TLSv1"

=item B<--api-limit>

Number of items to fetch per API page for pagination (default: 1000).

=item B<--unknown-http-status>

Define the conditions to match for the status to be UNKNOWN (default: '%{http_code} < 200 or %{http_code} >= 300').

=item B<--warning-http-status>

Define the conditions to match for the status to be WARNING.

=item B<--critical-http-status>

Define the conditions to match for the status to be CRITICAL.

=back

=head1 DESCRIPTION

B<custom>.

=cut
