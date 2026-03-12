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

package hardware::server::hp::oneview::restapi::custom::api;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use centreon::plugins::http;
use centreon::plugins::statefile;
use JSON::XS;
use Digest::MD5 qw(md5_hex);

sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
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
        $options{options}->add_options(arguments =>  {
            'hostname:s'     => { name => 'hostname' },
            'port:s'         => { name => 'port'},
            'proto:s'        => { name => 'proto' },
            'api-username:s' => { name => 'api_username' },
            'api-password:s' => { name => 'api_password' },
            'api-domain:s'   => { name => 'api_domain' },
            'timeout:s'      => { name => 'timeout', default => 30 }
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
    $self->{timeout} = (defined($self->{option_results}->{timeout})) ? $self->{option_results}->{timeout} : 30;
    $self->{api_username} = (defined($self->{option_results}->{api_username})) ? $self->{option_results}->{api_username} : '';
    $self->{api_password} = (defined($self->{option_results}->{api_password})) ? $self->{option_results}->{api_password} : '';
    $self->{api_domain} = $self->{option_results}->{api_domain};

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
    if (defined($self->{session_id})) {
        $self->{http}->add_header(key => 'Auth', value => $self->{session_id});
    }
    $self->{http}->set_options(%{$self->{option_results}});
}

sub json_decode {
    my ($self, %options) = @_;

    # Guard against empty or whitespace-only response (e.g. HTTP 204 No Content)
    if (!defined($options{content}) || $options{content} !~ /\S/) {
        return undef if ($options{ignore_errors});
        $self->{output}->add_option_msg(short_msg => "Empty response received from API");
        $self->{output}->option_exit();
    }

    my $decoded;
    eval {
        $decoded = JSON::XS->new->utf8->decode($options{content});
    };
    if ($@) {
        return undef if ($options{ignore_errors});
        $self->{output}->add_option_msg(short_msg => "Cannot decode json response: $@");
        $self->{output}->option_exit();
    }

    return $decoded;
}

sub clean_session_id {
    my ($self, %options) = @_;

    # Explicitly logout on the server to free the session slot
    if (defined($self->{session_id})) {
        $self->{http}->request(
            method   => 'DELETE',
            url_path => '/rest/login-sessions',
            warning_status => '', unknown_status => '', critical_status => '',
        );
    }

    my $datas = { last_timestamp => time() };
    $self->{cache}->write(data => $datas);
    $self->{session_id} = undef;
}

sub decode_api_response {
    my ($self, %options) = @_;

    my $decoded = $self->json_decode(content => $options{content}, ignore_errors => $options{ignore_errors});
    if (!defined($decoded)) {
        return undef if ($options{ignore_errors});
        $self->{output}->add_option_msg(short_msg => "Error while retrieving data (add --debug option for detailed message)");
        $self->{output}->option_exit();
    }
    if (defined($decoded->{errorCode})) {
        if ($options{ignore_errors}) {
            $self->{output}->output_add(
                long_msg => sprintf("api warning: [%s] %s", $decoded->{errorCode}, $decoded->{message}),
                debug => 1
            );
            return undef;
        }
        # For session limit errors, just clear the cache without trying to DELETE
        # (we may not have a valid session to delete)
        if ($decoded->{errorCode} =~ /AUTHN_SESSION/) {
            my $datas = { last_timestamp => time() };
            $self->{cache}->write(data => $datas);
            $self->{session_id} = undef;
        } else {
            $self->clean_session_id();
        }
        $self->{output}->add_option_msg(short_msg => 'api error: ' . $decoded->{message});
        $self->{output}->option_exit();
    }

    return $decoded;
}

sub authenticate {
    my ($self, %options) = @_;

    my $has_cache_file = $self->{cache}->read(statefile => 'hp_oneview_' . md5_hex($self->{option_results}->{hostname}) . '_' . md5_hex($self->{option_results}->{api_username}));
    my $session_id     = $self->{cache}->get(name => 'session_id');
    my $last_timestamp = $self->{cache}->get(name => 'last_timestamp') // 0;

    # Renew session after 23h (OneView sessions expire after 24h by default)
    my $session_expired = (time() - $last_timestamp) > (23 * 3600);

    if ($has_cache_file == 0 || !defined($session_id) || $session_expired) {
        my $json_request = { userName => $self->{api_username}, password => $self->{api_password} };
        $json_request->{authLoginDomain} = $self->{api_domain} if (defined($self->{api_domain}) && $self->{api_domain} ne '');

        my $encoded;
        eval {
            $encoded = encode_json($json_request);
        };
        if ($@) {
            $self->{output}->add_option_msg(short_msg => 'Cannot encode json request');
            $self->{output}->option_exit();
        }

        my $content = $self->{http}->request(
            method => 'POST',
            url_path => '/rest/login-sessions',
            query_form_post => $encoded,
            warning_status => '', unknown_status => '', critical_status => '',
        );
        if ($self->{http}->get_code() != 200) {
            $self->{output}->add_option_msg(short_msg => "Login error [code: '" . $self->{http}->get_code() . "'] [message: '" . $self->{http}->get_message() . "']");
            $self->{output}->option_exit();
        }

        my $decoded = $self->json_decode(content => $content);

        if (defined($decoded) && defined($decoded->{sessionID})) {
            $session_id = $decoded->{sessionID};
        } else {
            $self->{output}->add_option_msg(short_msg => "Error retrieving session_id");
            $self->{output}->option_exit();
        }

        my $datas = { last_timestamp => time(), session_id => $session_id };
        $self->{cache}->write(data => $datas);
    }

    $self->{session_id} = $session_id;
    $self->{http}->add_header(key => 'Auth', value => $self->{session_id});
    my $content = $self->{http}->request(
        url_path => '/rest/version',
        warning_status => '', unknown_status => '', critical_status => ''
    );
    my $decoded = $self->decode_api_response(content => $content);
    if (!defined($decoded->{currentVersion})) {
        $self->{output}->add_option_msg(short_msg => 'Cannot get api version');
        $self->{output}->option_exit();
    }
    $self->{http}->add_header(key => 'X-Api-Version', value => $decoded->{currentVersion});
}

sub request_api {
    my ($self, %options) = @_;

    $self->settings();
    if (!defined($self->{session_id})) {
        $self->authenticate();
    }
    my $content = $self->{http}->request(
        %options, 
        warning_status => '', unknown_status => '', critical_status => ''
    );

    # Maybe there is an issue with the session_id. So we retry.
    if ($self->{http}->get_code() != 200) {
        $self->clean_session_id();
        $self->authenticate();
        $content = $self->{http}->request(%options, 
            warning_status => '', unknown_status => '', critical_status => ''
        );
    }

    return $self->decode_api_response(content => $content, ignore_errors => $options{ignore_errors});
}


# Fetch all members of a collection endpoint, handling HPE OneView pagination.
# Usage: $custom->request_api_all(url_path => '/rest/interconnects')
# Returns arrayref of all member objects.
sub request_api_all {
    my ($self, %options) = @_;

    my $base_url = $options{url_path};
    # Strip any existing start/count params so we control pagination
    $base_url =~ s/[?&]start=[^&]*//g;
    $base_url =~ s/[?&]count=[^&]*//g;
    $base_url =~ s/\?&/\?/g;
    $base_url =~ s/[?&]$//;

    my @all_members;
    my $start = 0;
    my $count = 100;

    while (1) {
        my $sep  = ($base_url =~ /\?/) ? '&' : '?';
        my $page = $self->request_api(
            url_path => "${base_url}${sep}start=${start}&count=${count}",
        );
        last if (!defined($page) || !defined($page->{members}) || scalar(@{$page->{members}}) == 0);
        push @all_members, @{$page->{members}};
        my $total = $page->{total} // 0;
        # Stop when we have all records according to the total field,
        # or when the API returns an empty nextPageUri / no next page hint.
        last if ($total > 0 && scalar(@all_members) >= $total);
        # If total is unknown, stop only when the API returns nothing more
        # (do NOT stop based on page size < requested count, as OneView
        #  enforces its own internal page size regardless of count param)
        last if ($total == 0 && scalar(@{$page->{members}}) == 0);
        $start += scalar(@{$page->{members}});
    }

    return { members => \@all_members };
}

1;

__END__

=head1 NAME

HP OneView Rest API

=head1 REST API OPTIONS

=over 8

=item B<--hostname>

Set hostname or IP of vsca.

=item B<--port>

Set port (default: '443').

=item B<--proto>

Specify https if needed (default: 'https').

=item B<--api-username>

Set username.

=item B<--api-password>

Set password.

=item B<--api-domain>

Set domain.

=item B<--timeout>

Threshold for HTTP timeout (default: '30').

=back

=cut
