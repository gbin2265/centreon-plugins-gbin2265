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

package storage::hp::msa2000::ssh::custom::custom;

use strict;
use warnings;
use centreon::plugins::ssh;
use centreon::plugins::misc;
use XML::LibXML::Simple;

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
            'hostname:s'        => { name => 'hostname' },
            'timeout:s'         => { name => 'timeout', default => 45 },
            'command:s'         => { name => 'command' },
            'command-path:s'    => { name => 'command_path' },
            'command-options:s' => { name => 'command_options' }
        });
    }
    $options{options}->add_help(package => __PACKAGE__, sections => 'SSH OPTIONS', once => 1);

    $self->{output} = $options{output};
    $self->{ssh} = centreon::plugins::ssh->new(%options);

    return $self;
}

sub set_options {
    my ($self, %options) = @_;

    $self->{option_results} = $options{option_results};
}

sub set_defaults {}

sub check_options {
    my ($self, %options) = @_;

    if (defined($self->{option_results}->{hostname}) && $self->{option_results}->{hostname} ne '') {
        $self->{ssh}->check_options(option_results => $self->{option_results});
    }

    centreon::plugins::misc::check_security_command(
        output => $self->{output},
        command => $self->{option_results}->{command},
        command_options => $self->{option_results}->{command_options},
        command_path => $self->{option_results}->{command_path}
    );

    $self->{hostname} = $self->{option_results}->{hostname};

    return 0;
}

sub execute_command {
    my ($self, %options) = @_;

    my $cmd = defined($options{command}) ? $options{command} : '';

    my $content;
    if (defined($self->{option_results}->{hostname}) && $self->{option_results}->{hostname} ne '') {
        ($content) = $self->{ssh}->execute(
            hostname => $self->{option_results}->{hostname},
            command => defined($self->{option_results}->{command}) && $self->{option_results}->{command} ne '' ? $self->{option_results}->{command} : $cmd,
            command_path => $self->{option_results}->{command_path},
            command_options => defined($self->{option_results}->{command_options}) && $self->{option_results}->{command_options} ne '' ? $self->{option_results}->{command_options} : undef,
            timeout => $self->{option_results}->{timeout}
        );
    } else {
        if (!defined($self->{option_results}->{command}) || $self->{option_results}->{command} eq '') {
            $self->{output}->add_option_msg(short_msg => 'please set --hostname option for ssh connection (or --command for local)');
            $self->{output}->option_exit();
        }
        ($content) = centreon::plugins::misc::execute(
            output => $self->{output},
            options => { timeout => $self->{option_results}->{timeout} },
            command => $self->{option_results}->{command},
            command_path => $self->{option_results}->{command_path},
            command_options => defined($self->{option_results}->{command_options}) && $self->{option_results}->{command_options} ne '' ? $self->{option_results}->{command_options} : undef
        );
    }

    return $content;
}

##############
# XML parsing for MSA 2060 output
# The MSA 2060 CLI returns XML with OBJECT and PROPERTY elements, like the P2000/MSA family.
# Example:
# <RESPONSE>
#   <OBJECT basetype="controllers" name="controller-a" oid="1">
#     <PROPERTY name="durable-id">controller_a</PROPERTY>
#     <PROPERTY name="health">OK</PROPERTY>
#     <PROPERTY name="health-numeric">0</PROPERTY>
#   </OBJECT>
# </RESPONSE>
##############
sub get_infos {
    my ($self, %options) = @_;

    my $content = $self->execute_command(command => $options{cmd});

    if (!defined($content) || $content eq '') {
        if (defined($options{no_quit}) && $options{no_quit} == 1) {
            return (!defined($options{key}) ? [] : {}, 0);
        }
        $self->{output}->add_option_msg(short_msg => "Cannot get information (empty response for command: $options{cmd})");
        $self->{output}->option_exit();
    }

    # The MSA may return multiple XML documents or extra text before the XML.
    # Try to extract the XML portion.
    if ($content =~ /(<\?xml.*)/ms) {
        $content = $1;
    } elsif ($content =~ /(<RESPONSE.*)/ms) {
        $content = $1;
    }

    # Remove self-closing tags that are not part of the data structure (e.g. <COMP G="0" P="1"/>)
    $content =~ s/<COMP[^>]*\/>//gi;

    # Ensure we have a proper closing </RESPONSE> tag
    if ($content =~ /<RESPONSE/i && $content !~ /<\/RESPONSE>/i) {
        $content .= '</RESPONSE>';
    }

    # Remove any trailing data after </RESPONSE>
    if ($content =~ /(<.*<\/RESPONSE>)/ms) {
        $content = $1;
    }

    my $xml;
    eval {
        $SIG{__WARN__} = sub {};
        $xml = XMLin($content, ForceArray => ['OBJECT', 'PROPERTY'], KeyAttr => []);
    };
    if ($@) {
        if (defined($options{no_quit}) && $options{no_quit} == 1) {
            return (!defined($options{key}) ? [] : {}, 0);
        }
        $self->{output}->add_option_msg(short_msg => "Cannot parse XML response: $@");
        $self->{output}->option_exit();
    }

    # Check for status/error objects
    my $results = {};
    $results = [] if (!defined($options{key}));

    return ($results, 1) if (!defined($xml->{OBJECT}));

    foreach my $obj (@{$xml->{OBJECT}}) {
        # Handle error responses
        if (defined($obj->{basetype}) && $obj->{basetype} eq 'status') {
            my ($return_code, $response) = (-1, 'n/a');
            foreach my $prop (@{$obj->{PROPERTY}}) {
                next if (!defined($prop->{name}));
                $return_code = $prop->{content} if ($prop->{name} eq 'return-code');
                $response = $prop->{content} if ($prop->{name} eq 'response');
            }

            if ($return_code != 0) {
                if (defined($options{no_quit}) && $options{no_quit} == 1) {
                    return (!defined($options{key}) ? [] : {}, 0);
                }
                $self->{output}->add_option_msg(short_msg => "Command error: $response");
                $self->{output}->option_exit();
            }
            next;
        }

        # Skip objects that don't match our base_type filter
        next if (defined($options{base_type}) && defined($obj->{basetype}) && $obj->{basetype} ne $options{base_type});

        my $properties = {};
        foreach my $prop (@{$obj->{PROPERTY}}) {
            next if (!defined($prop->{name}));

            if (!defined($options{properties_name}) || $prop->{name} =~ /$options{properties_name}/) {
                $properties->{ $prop->{name} } = defined($prop->{content}) ? $prop->{content} : '';
            }

            # Always capture the key property if defined
            if (defined($options{key}) && $prop->{name} eq $options{key}) {
                $properties->{ $prop->{name} } = defined($prop->{content}) ? $prop->{content} : '';
            }
        }

        if (defined($options{key})) {
            $results->{ $properties->{ $options{key} } } = $properties
                if (defined($properties->{ $options{key} }));
        } else {
            push @$results, $properties;
        }
    }

    return ($results, 1);
}

1;

__END__

=head1 NAME

ssh

=head1 SYNOPSIS

HPE MSA 2060 SSH custom mode with XML parsing.

=head1 SSH OPTIONS

=over 8

=item B<--hostname>

Hostname to query.

=item B<--timeout>

Timeout in seconds for the command (default: 45).

=item B<--command>

Command to get information. Used it you have output in a file.

=item B<--command-path>

Command path.

=item B<--command-options>

Command options.

=back

=head1 DESCRIPTION

B<custom>.

=cut
