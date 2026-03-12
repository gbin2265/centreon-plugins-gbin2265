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

package hardware::server::dell::idrac::restapi::custom::api;

use strict;
use warnings;
use centreon::plugins::http;
use centreon::plugins::statefile;
use JSON::XS;
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
            'hostname:s'     => { name => 'hostname' },
            'port:s'         => { name => 'port' },
            'proto:s'        => { name => 'proto' },
            'api-username:s' => { name => 'api_username' },
            'api-password:s' => { name => 'api_password' },
            'timeout:s'      => { name => 'timeout' }
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
    $self->{port} = (defined($self->{option_results}->{port})) ? $self->{option_results}->{port} : 443;
    $self->{proto} = (defined($self->{option_results}->{proto})) ? $self->{option_results}->{proto} : 'https';
    $self->{api_username} = (defined($self->{option_results}->{api_username})) ? $self->{option_results}->{api_username} : '';
    $self->{api_password} = (defined($self->{option_results}->{api_password})) ? $self->{option_results}->{api_password} : '';
    $self->{timeout} = (defined($self->{option_results}->{timeout})) ? $self->{option_results}->{timeout} : 30;

    if ($self->{hostname} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --hostname option.");
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

sub settings {
    my ($self, %options) = @_;

    $self->{http}->set_options(%{$self->{option_results}});
    $self->{http}->add_header(key => 'Content-Type', value => 'application/json');
    $self->{http}->add_header(key => 'Accept', value => 'application/json');
}

sub get_connection_info {
    my ($self, %options) = @_;
    return $self->{hostname} . ':' . $self->{port};
}

sub get_hostname {
    my ($self, %options) = @_;
    return $self->{hostname};
}

sub get_auth_token {
    my ($self, %options) = @_;

    my $has_cache_file = $self->{cache}->read(
        statefile => 'idrac_restapi_' . md5_hex($self->{hostname} . '_' . $self->{api_username})
    );
    my $token = $self->{cache}->get(name => 'token');
    my $token_time = $self->{cache}->get(name => 'token_time');
    my $session_location = $self->{cache}->get(name => 'session_location');

    if ($has_cache_file == 0 || !defined($token) || (time() - $token_time) > 600) {
        $self->settings();

        my $post_data = JSON::XS->new->encode({
            UserName => $self->{api_username},
            Password => $self->{api_password}
        });

        my $content = $self->{http}->request(
            method => 'POST',
            hostname => $self->{hostname},
            port => $self->{port},
            proto => $self->{proto},
            url_path => '/redfish/v1/SessionService/Sessions',
            query_form_post => $post_data,
            timeout => $self->{timeout},
            warning_status => '',
            unknown_status => '',
            critical_status => ''
        );

        my $header = $self->{http}->get_header(name => 'X-Auth-Token');
        $session_location = $self->{http}->get_header(name => 'Location');

        if (!defined($header) || $header eq '') {
            $self->{output}->add_option_msg(short_msg => "Cannot get token.");
            $self->{output}->option_exit();
        }

        $token = $header;
        $self->{cache}->write(data => {
            token => $token,
            token_time => time(),
            session_location => $session_location
        });
    }

    $self->{token} = $token;
    $self->{session_location} = $session_location;
}

sub request_api {
    my ($self, %options) = @_;

    $self->get_auth_token();
    $self->settings();
    $self->{http}->add_header(key => 'X-Auth-Token', value => $self->{token});

    my $endpoint = $options{endpoint};
    if (!defined($endpoint) && defined($options{url_path})) {
        $endpoint = $options{url_path};
    }

    my $content = $self->{http}->request(
        method => 'GET',
        hostname => $self->{hostname},
        port => $self->{port},
        proto => $self->{proto},
        url_path => $endpoint,
        timeout => $self->{timeout},
        warning_status => '',
        unknown_status => '',
        critical_status => ''
    );

    my $response_code = $self->{http}->get_code();

    if ($response_code == 401) {
        $self->{cache}->write(data => { token => undef, token_time => 0 });
        $self->{output}->add_option_msg(short_msg => "Authentication failed. Token expired or invalid.");
        $self->{output}->option_exit();
    }

    if ($response_code == 404) {
        return undef if (defined($options{ignore_error}) && $options{ignore_error});
        $self->{output}->add_option_msg(short_msg => "Endpoint not found: $endpoint");
        $self->{output}->option_exit();
    }

    if ($response_code >= 400) {
        return undef if (defined($options{ignore_error}) && $options{ignore_error});
        $self->{output}->add_option_msg(short_msg => "api request error: " . ($content || 'unknown'));
        $self->{output}->option_exit();
    }

    my $decoded;
    eval {
        $decoded = JSON::XS->new->decode($content);
    };
    if ($@) {
        return undef if (defined($options{ignore_error}) && $options{ignore_error});
        $self->{output}->add_option_msg(short_msg => "Cannot decode JSON response: $@");
        $self->{output}->option_exit();
    }

    return $decoded;
}

1;

__END__

=head1 NAME

Dell iDRAC 9 Redfish REST API

=head1 REST API OPTIONS

Dell iDRAC 9 Redfish REST API connection options.

=over 8

=item B<--hostname>

iDRAC hostname or IP address.

=item B<--port>

Port used (default: 443)

=item B<--proto>

Specify https if needed (default: 'https')

=item B<--api-username>

API username.

=item B<--api-password>

API password.

=item B<--timeout>

Set timeout in seconds (default: 30).

=back

=cut
