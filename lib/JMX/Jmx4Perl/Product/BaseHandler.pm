#!/usr/bin/perl

package JMX::Jmx4Perl::Product::BaseHandler;

use strict;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Request;
use JMX::Jmx4Perl::Alias;
use Carp qw(croak);
use Data::Dumper;

=head1 NAME

JMX::Jmx4Perl::Product::BaseHandler - Base package for product specific handler 

=head1 DESCRIPTION

This base class is used for specific L<JMX::Jmx4Perl::Product> in order
to provide some common functionality. Extends this package if you want to hook
in your own product handler. Any module below
C<JMX::Jmx4Perl::Product::> will be automatically picked up by
L<JMX::Jmx4Perl>.

=head1 METHODS

=over 

=item $handler = JMX::Jmx4Perl::Product::MyHandler->new($jmx4perl);

Constructor which requires a L<JMX::Jmx4Perl> object as single argument. If you
overwrite this method in a subclass, dont forget to call C<SUPER::new>, but
normally there is little need for overwritting new.

=cut


sub new {
    my $class = shift;
    my $jmx4perl = shift || croak "No associated JMX::Jmx4Perl given";
    my $self = { 
                jmx4perl => $jmx4perl
               };
    bless $self,(ref($class) || $class);
    $self->{aliases} = $self->_init_aliases();
    return $self;
}

=item $id = $handler->id()

Return the id of this handler, which must be unique among all handlers. This
method is abstract and must be overwritten by a subclass

=cut 

sub id { 
    croak "Must be overwritten to return a name";
}

=item $id = $handler->name()

Return this handler's name. This method returns by default the id, but can 
be overwritten by a subclass to provide something more descriptive.

=cut 

sub name { 
    return shift->id;
}

=item $version = $handler->version() 

Get the version of the underlying application server or return C<undef> if the
version can not be determined. Please note, that this method can be only called
after autodetect() has been called since this call is normally used to fill in
that version number.

=cut

sub version {
    
}

=item $is_product = $handler->autodetect()

Return true, if the appserver to which the given L<JMX::Jmx4Perl> (at
construction time) object is connected can be handled by this product
handler. If this module detects that it definitely can not handler this
application server, it returnd false. If an error occurs during autodectection,
this method should return C<undef>.

=cut

sub autodetect {
    my ($self) = @_;
    croak "Must be overwritten to return true " . 
      "in case we detect the server as the server we can handle";       
}

=item print $handler->description() 

Print an informal message about the handler under question. Should be
overwritten to print a more exhaustive description text

=cut

sub description {
    my $self = shift;
    return $self->id(); # By default, only the id is returned.
}


=item $can_jsr77 = $handler->jsr77()

Return true if the app server represented by this handler is an implementation
of JSR77, which provides a well defined way how to access deployed applications
and other stuff on a JEE Server. I.e. it defines how MBean representing this
information has to be named. This base class returns false, but this method can
be overwritten by a subclass.

=cut

sub jsr77 {
    return undef;
}

=item ($mbean,$attribute,$path) = $self->attribute_alias($alias)

Return the mbean and attribute name for an registered alias. A subclass should
call this parent method if it doesn't know about this alias, since JVM
specific MBeans are aliased here.

Returns undef if this product handler doesn't know about the provided alias. 

=cut 

sub attribute_alias {
    my ($self,$alias_or_name) = @_;
    my $alias;
    if (UNIVERSAL::isa($alias_or_name,"JMX::Jmx4Perl::Alias::Object")) {
        $alias = $alias_or_name;
    } else {
        $alias = JMX::Jmx4Perl::Alias->by_name($alias_or_name) 
          || croak "No alias $alias_or_name known";
    }
    my $aliasref = $self->resolve_attribute_alias($alias) || $alias->default();
    return $aliasref ? @$aliasref : undef;
}

=item $description = $self->info()

Get a textual description of the product handler. By default, it prints
out the id, the version and well known properties known by the Java VM

=cut

sub info {
    my $self = shift;
    
    my $ret = "";
    $ret .= $self->server_info;
    $ret .= "-" x 80 . "\n";
    $ret .= $self->jvm_info;    
}


# Examines internal alias hash in order to return handler specific aliases
# Can be overwritten if something more esoteric is required
sub resolve_attribute_alias {
    my $self = shift;
    my $alias = shift;
    $alias = $alias->{alias} if (UNIVERSAL::isa($alias,"JMX::Jmx4Perl::Agent::Object"));
    my $aliases = $self->{aliases}->{attributes};
    return $aliases && $aliases->{$alias};
}


# Internal method which sould be overwritten to return the special map (like in
# Aliases) for this product containing specific ($mbean,$attribute,$path) tuples1

sub _init_aliases {
    my $self = shift;
    return {};
}


=item $has_attribute = $handler->try_attribute($jmx4perl,$property,$object,$attribute,$path)

Internal method which tries to request an attribute. If it could not be found,
it returns false. 

The first arguments C<$property> specifies an property of this object, which is
set with the value of the found attribute or C<0> if this attribute does not
exist. 

The server call is cached internally by examing C<$property>. So, never change
or set this property on this object manually.

=cut

sub try_attribute {
    my ($self,$property,$object,$attribute,$path) = @_;
    
    my $jmx4perl = $self->{jmx4perl};

    if (defined($self->{$property})) {
        return length($self->{$property});
    }
    my $request = JMX::Jmx4Perl::Request->new(READ,$object,$attribute,$path);
    my $response = $jmx4perl->request($request);
    if ($response->status == 404) {
        $self->{$property} = "";
    } elsif ($response->is_ok) {
        $self->{$property} = $response->value;
    } else {
        croak "Error while trying to autodetect ",$self->id(),": ",$response->error_text();
    }
    return length($self->{$property});
}

=item $server_info = $handler->server_info()

Get's a textual description of the server. By default, this includes the id and
the version, but can (and should) be overidden by a subclass to contain more
specific information

=cut

sub server_info { 
    my $self = shift;
    my $jmx4perl = $self->{jmx4perl};
    
    my $ret = "";
    $ret .= sprintf("%-10.10s %s\n","Name:",$self->name);
    $ret .= sprintf("%-10.10s %s\n","Version:",$self->version);
    return $ret;
}

=item jvm_info = $handler->jvm_info()

Get information which is based on well known MBeans which are available for
every Virtual machine.

=cut

sub jvm_info {
    my $self = shift;
    my $jmx4perl = $self->{jmx4perl};
    
    my $ret = "";
    $ret .= "Memory:\n";
    $ret .= sprintf("   %-20.20s %s\n","Heap-Memory used:",int($jmx4perl->get_attribute(MEMORY_HEAP_USED)/(1024*1024)) . " MB");
}


=back

=head1 LICENSE

This file is part of jmx4perl.

Jmx4perl is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 2 of the License, or
(at your option) any later version.

jmx4perl is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with jmx4perl.  If not, see <http://www.gnu.org/licenses/>.

A commercial license is available as well. Please contact roland@cpan.org for
further details.

=head1 AUTHOR

roland@cpan.org

=cut

1;
