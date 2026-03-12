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

package storage::hp::msa2000::restapi::custom::api;

use strict;
use warnings;
use centreon::plugins::http;
use centreon::plugins::statefile;
use JSON::XS;
use Digest::MD5 qw(md5_hex);

sub new {
    my ($class, %options) = @_;
    my $self  = {};
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
            'port:s'         => { name => 'port'},
            'proto:s'        => { name => 'proto' },
            'api-username:s' => { name => 'api_username' },
            'api-password:s' => { name => 'api_password' },
            'timeout:s'      => { name => 'timeout', default => 30 },
            'token-maxage:s' => { name => 'token_maxage', default => 900 }
        });
    }
    
    $options{options}->add_help(package => __PACKAGE__, sections => 'REST API OPTIONS', once => 1);

    $self->{output} = $options{output};
    $self->{http} = centreon::plugins::http->new(%options, default_backend => 'curl');
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

    $self->{hostname} = (defined($self->{option_results}->{hostname})) ? $self->{option_results}->{hostname} : undef;
    $self->{port} = (defined($self->{option_results}->{port})) ? $self->{option_results}->{port} : 443;
    $self->{proto} = (defined($self->{option_results}->{proto})) ? $self->{option_results}->{proto} : 'https';
    $self->{timeout} = (defined($self->{option_results}->{timeout})) ? $self->{option_results}->{timeout} : 30;
    $self->{api_username} = (defined($self->{option_results}->{api_username})) ? $self->{option_results}->{api_username} : undef;
    $self->{api_password} = (defined($self->{option_results}->{api_password})) ? $self->{option_results}->{api_password} : undef;
    $self->{token_maxage} = (defined($self->{option_results}->{token_maxage})) ? $self->{option_results}->{token_maxage} : 900;

    if (!defined($self->{hostname}) || $self->{hostname} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --hostname option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{api_username}) || $self->{api_username} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --api-username option.");
        $self->{output}->option_exit();
    }
    if (!defined($self->{api_password}) || $self->{api_password} eq '') {
        $self->{output}->add_option_msg(short_msg => "Need to specify --api-password option.");
        $self->{output}->option_exit();
    }

    $self->{cache}->check_options(option_results => $self->{option_results});

    return 0;
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

    $self->build_options_for_httplib();
    $self->{http}->add_header(key => 'Content-Type', value => 'application/json;charset=UTF-8');
    $self->{http}->add_header(key => 'Accept', value => 'application/json;charset=UTF-8');
    $self->{http}->set_options(%{$self->{option_results}});
}

sub json_decode {
    my ($self, %options) = @_;

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

sub clean_token {
    my ($self, %options) = @_;

    my $datas = { last_timestamp => time() };
    $options{statefile}->write(data => $datas);
    $self->{token} = undef;
    $self->{session_url} = undef;
    $self->{http}->add_header(key => 'X-Auth-Token', value => undef);
}

sub authenticate {
    my ($self, %options) = @_;

    my $has_cache_file = $options{statefile}->read(statefile => 'msa_redfish_' . md5_hex($self->{option_results}->{hostname}) . '_' . md5_hex($self->{option_results}->{api_username}));
    my $token = $options{statefile}->get(name => 'token');
    my $session_url = $options{statefile}->get(name => 'session_url');
    my $last_timestamp = $options{statefile}->get(name => 'last_timestamp');

    # Check if cached token is still valid (not expired)
    my $token_age = defined($last_timestamp) ? (time() - $last_timestamp) : 0;
    my $token_expired = ($token_age > $self->{token_maxage}) ? 1 : 0;

    if ($has_cache_file == 0 || !defined($token) || $token_expired) {
        # If we have an old session, try to clean it up first
        if (defined($token) && defined($session_url) && $token_expired) {
            $self->{output}->output_add(long_msg => "Cached token expired (age: ${token_age}s > maxage: $self->{token_maxage}s), logging out old session", debug => 1);
            eval {
                $self->{http}->add_header(key => 'X-Auth-Token', value => $token);
                $self->{http}->request(
                    method => 'DELETE',
                    hostname => $self->{hostname},
                    port => $self->{port},
                    proto => $self->{proto},
                    url_path => $session_url,
                    warning_status => '', unknown_status => '', critical_status => ''
                );
            };
            $self->{http}->add_header(key => 'X-Auth-Token', value => undef);
        }

        my $json_request = { UserName => $self->{api_username}, Password => $self->{api_password} };
        my $encoded;
        eval {
            $encoded = encode_json($json_request);
        };
        if ($@) {
            $self->{output}->add_option_msg(short_msg => "Cannot encode json request");
            $self->{output}->option_exit();
        }

        my $content = $self->{http}->request(
            method => 'POST',
            hostname => $self->{hostname},
            port => $self->{port},
            proto => $self->{proto},
            url_path => '/redfish/v1/SessionService/Sessions',
            query_form_post => $encoded,
            warning_status => '', unknown_status => '', critical_status => ''
        );
        if ($self->{http}->get_code() < 200 || $self->{http}->get_code() >= 300) {
            $self->{output}->add_option_msg(short_msg => "Login error [code: '" . $self->{http}->get_code() . "'] [message: '" . $self->{http}->get_message() . "']");
            $self->{output}->option_exit();
        }

        $token = $self->{http}->get_header(name => 'X-Auth-Token');
        if (!defined($token)) {
            $self->{output}->add_option_msg(short_msg => "Error retrieving token");
            $self->{output}->option_exit();
        }

        # Get session URL from Location header or response body for logout
        $session_url = $self->{http}->get_header(name => 'Location');
        if (!defined($session_url) || $session_url eq '') {
            eval {
                my $decoded = JSON::XS->new->utf8->decode($content);
                if (defined($decoded) && defined($decoded->{'@odata.id'})) {
                    $session_url = $decoded->{'@odata.id'};
                }
            };
        }
        # Normalize: strip protocol/host prefix if present, keep only path
        if (defined($session_url) && $session_url =~ /^https?:\/\/[^\/]+(\/redfish\/.+)/) {
            $session_url = $1;
        }

        $self->{output}->output_add(long_msg => "New session created [token: " . substr($token, 0, 8) . "...] [session: " . ($session_url // 'unknown') . "]", debug => 1);

        my $datas = { last_timestamp => time(), token => $token, session_url => $session_url };
        $options{statefile}->write(data => $datas);
    } else {
        $self->{output}->output_add(long_msg => "Reusing cached token (age: ${token_age}s)", debug => 1);
    }

    $self->{token} = $token;
    $self->{session_url} = $session_url;
    $self->{http}->add_header(key => 'X-Auth-Token', value => $self->{token});
}

sub logout {
    my ($self, %options) = @_;

    # Guard: all required objects must still be alive
    return if (!defined($self->{token}));
    return if (!defined($self->{session_url}));
    return if (!defined($self->{http}));
    return if (!defined($self->{hostname}));

    eval {
        if (defined($self->{output})) {
            $self->{output}->output_add(long_msg => "Logging out session: " . $self->{session_url}, debug => 1);
        }

        $self->{http}->request(
            method => 'DELETE',
            hostname => $self->{hostname},
            port => $self->{port},
            proto => $self->{proto},
            url_path => $self->{session_url},
            warning_status => '', unknown_status => '', critical_status => ''
        );
    };

    # Clear cached token so next run creates a fresh session
    if (defined($self->{cache})) {
        eval { $self->clean_token(statefile => $self->{cache}); };
    }
    $self->{token} = undef;
    $self->{session_url} = undef;
}

sub DESTROY {
    my ($self) = @_;

    # During global destruction, objects may already be freed.
    # ${^GLOBAL_PHASE} is available in Perl 5.14+
    return if (defined(${^GLOBAL_PHASE}) && ${^GLOBAL_PHASE} eq 'DESTRUCT');

    eval { $self->logout(); };
}

sub request_api {
    my ($self, %options) = @_;

    $self->settings();
    if (!defined($self->{token})) {
        $self->authenticate(statefile => $self->{cache});
    }

    # Validate url_path to prevent invalid URLs from causing DNS resolution errors
    if (defined($options{url_path}) && $options{url_path} !~ /^\//) {
        $self->{output}->output_add(long_msg => "Skipping invalid url_path: " . $options{url_path}, debug => 1);
        return undef;
    }

    my $content = $self->{http}->request(
        %options,
        hostname => $self->{hostname},
        port => $self->{port},
        proto => $self->{proto},
        warning_status => '', unknown_status => '', critical_status => ''
    );

    my $code = $self->{http}->get_code();
    return undef if (defined($options{ignore_codes}) && defined($options{ignore_codes}->{$code}));

    # Maybe there is an issue with the token. So we retry with a fresh session.
    if ($code == 401 || $code == 403) {
        $self->clean_token(statefile => $self->{cache});
        $self->authenticate(statefile => $self->{cache});
        $content = $self->{http}->request(
            %options,
            hostname => $self->{hostname},
            port => $self->{port},
            proto => $self->{proto},
            warning_status => '', unknown_status => '', critical_status => ''
        );
        $code = $self->{http}->get_code();
    }

    return undef if (defined($options{ignore_codes}) && defined($options{ignore_codes}->{$code}));

    if ($code < 200 || $code >= 300) {
        my $decoded;
        eval {
            $decoded = $self->json_decode(content => $content);
        };
        my $error_message = 'unknown error';
        if (defined($decoded) && defined($decoded->{error})) {
            $error_message = defined($decoded->{error}->{message}) ? $decoded->{error}->{message} : 'API error';
        }
        $self->{output}->add_option_msg(short_msg => "API request error [code: $code] [message: $error_message]");
        $self->{output}->option_exit();
    }

    my $decoded = $self->json_decode(content => $content);
    if (!defined($decoded)) {
        $self->{output}->add_option_msg(short_msg => "Error while retrieving data (add --debug option for detailed message)");
        $self->{output}->option_exit();
    }

    return $decoded;
}

1;

__END__

=head1 NAME

HPE MSA 2000/2060 Redfish Rest API

=head1 REST API OPTIONS

=over 8

=item B<--hostname>

Set hostname or IP of the MSA storage system.

=item B<--port>

Set port (default: '443').

=item B<--proto>

Specify https if needed (default: 'https').

=item B<--api-username>

Set username.

=item B<--api-password>

Set password.

=item B<--timeout>

Threshold for HTTP timeout (default: '30').

=item B<--token-maxage>

Maximum age in seconds for a cached session token before forcing
a new login (default: '900'). The MSA default session inactivity
timeout is 30 minutes (1800s). Set this lower than the MSA timeout
to prevent stale token errors.

=back

=cut
