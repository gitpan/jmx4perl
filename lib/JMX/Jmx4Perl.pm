#!/usr/bin/perl

=head1 NAME 

JMX::Jmx4Perl - Access to JMX via Perl

=head1 SYNOPSIS

Simple:

   use strict;
   use JMX::Jmx4Perl;
   use JMX::Jmx4Perl::Alias;   # Import certains aliases for MBeans

   print "Memory Used: ",
          JMX::Jmx4Perl
              ->new(url => "http://localhost:808get0/j4p-agent")
              ->get_attribute(MEMORY_HEAP_USED);

Advanced:

   use strict;
   use JMX::Jmx4Perl;
   use JMX::Jmx4Perl::Request;   # Type constants are exported here
   
   my $jmx = new JMX::Jmx4Perl(url => "http://localhost:8080/j4p-agent",
                               product => "jboss");
   my $request = new JMX::Jmx4Perl::Request(type => READ,
                                            mbean => "java.lang:type=Memory",
                                            attribute => "HeapMemoryUsage",
                                            path => "used");
   my $response = $jmx->request($request);
   print "Memory used: ",$response->value(),"\n";

   # Get general server information
   print "Server Info: ",$jmx->info();

=head1 DESCRIPTION

Jmx4Perl is here to connect the Java and Perl Enterprise world by providing
transparent access to the Java Management Extensions (JMX) from the perl side. 

It uses a traditional request-response paradigma for performing JMX operations
on a remote Java Virtual machine. 

There a various ways how JMX information can be transfered. For now, a single
operational mode is supported. It is based on an I<agent>, a small (~30k) Java
Servlet, which needs to deployed on a Java application server. It plays the
role of a proxy, which on one side communicates with the MBeans server in the
application server and transfers JMX related information via HTPP and JSON to
the client (i.e. this module). Please refer to L<JMX::Jmx4Perl::Manual> for
installation instructions howto deploy the agent servlet (which can be found in
the distribution as F<agent/j4p-agent.war>).

An alternative, and more 'java like' approach, is the usage of JSR 160
connectors. However, the default connectors provided by the Java Virtual
Machine (JVM) since version 1.5 support only propriertary protocols which
require serialized Java objects to be exchanged. This implies that a JVM needs
to be started on the client side, adding quite some overhead if used from
within Perl. Nevertheless, plans are underway to support this operational mode
as well, which allows for monitoring of Java application which are not running
in a servlet container.

For further discussion comparing both approaches, please refer to
L<JMX::Jmx4Perl::Manual> 

JMX itself knows about the following operations on so called I<MBeans>, which
are specific "managed beans" designed for JMX and providing access to
management functions:

=over

=item * 

Reading an writing of attributes of an MBean (like memory usage or connected
users) 

=item *

Executing of exposed operations (like triggering a garbage collection)

=item * 

Registering of notifications which are send from the application server to a
listener when a certain event happens.

=back

For now only reading of attributes are supported, but development has start to
support writing of attributes and executing of JMX operations. Notification
support might come (or not ;-)

=head1 METHODS

=over

=cut

package JMX::Jmx4Perl;

use Carp;
use JMX::Jmx4Perl::Request;
use strict;
use vars qw($VERSION $HANDLER_BASE_PACKAGE @PRODUCT_HANDLER_ORDERING);
use Data::Dumper;
use Module::Find;

$VERSION = "0.20_2";

my $REGISTRY = {
                # Agent based
                "agent" => "JMX::Jmx4Perl::Agent",
                "JMX::Jmx4Perl::Agent" => "JMX::Jmx4Perl::Agent",
                "JJAgent" => "JMX::Jmx4Perl::Agent",
               };

my %PRODUCT_HANDLER;

sub _register_handlers { 
    my $handler_package = shift;
    %PRODUCT_HANDLER = ();
    
    my @id2order = ();
    for my $handler (findsubmod $handler_package) {
        next unless $handler;
        my $handler_file = $handler;
        $handler_file =~ s|::|/|g;
        require $handler_file.".pm";
        next if $handler eq $handler_package."::BaseHandler";
        my $id = eval "${handler}::id()";
        croak "No id() method on $handler: $@" if $@;
        $PRODUCT_HANDLER{lc $id} = $handler;
        push @id2order, [ lc $id, $handler->order() ];
    }
    # Ordering Schema according to $handler->order():
    # -10,-5,-3,0,undef,undef,undef,1,8,9,1000
    my @high = map { $_->[0] } sort { $a->[1] <=> $b->[1] } grep { defined($_->[1]) && $_->[1] <= 0 } @id2order;
    my @med  = map { $_->[0] } grep { not defined($_->[1]) } @id2order;
    my @low  = map { $_->[0] } sort { $a->[1] <=> $b->[1] } grep { defined($_->[1]) && $_->[1] > 0 } @id2order;
    @PRODUCT_HANDLER_ORDERING = (@high,@med,@low);
}

BEGIN {
    &_register_handlers("JMX::Jmx4Perl::Product");
}


=item $jmx = JMX::Jmx4Perl->new(mode => <access module>, product => <id>, ....)

Create a new instance. The call is dispatched to an Jmx4Perl implementation by
selecting an appropriate mode. For now, the only mode supported is "agent",
which uses the L<JMX::Jmx4Perl::Agent> backend. Hence, the mode can be
submitted for now.

If you provide a product id via the named parameter C<product> you can given
B<jmx4perl> a hint which server you are using. By default, this module uses
autodetection to guess the kind of server you are talking to. You need to
provide this argument only if you use B<jmx4perl>'s alias feature and if you
want to speed up things (autodetection can be quite slow since this requires
several JMX request to detect product specific MBean attributes).

Any other named parameters are interpreted by the backend, please
refer to its documentation for details (i.e. L<JMX::Jmx4Perl::Agent>)

=cut

sub new {
    my $class = shift;
    my $cfg = ref($_[0]) eq "HASH" ? $_[0] : {  @_ };
    
    my $mode = delete $cfg->{mode} || &autodiscover_mode();
    my $product = $cfg->{product} ? lc delete $cfg->{product} : undef;

    $class = $REGISTRY->{$mode} || croak "Unknown runtime mode " . $mode;
    if ($product && !$PRODUCT_HANDLER{lc $product}) {
        croak "No handler for product '$product'. Known Handlers are [".(join ", ",keys %PRODUCT_HANDLER)."]";
    }

    eval "require $class";
    croak "Cannot load $class: $@" if $@;

    my $self = { 
                cfg => $cfg,
                product => $product
             };
    bless $self,(ref($class) || $class);
    $self->init();
    return $self;
}

# ==========================================================================

=item $resp => $jmx->get_attribute(...)

  $value = $jmx->get_attribute($mbean,$attribute,$path) 
  $value = $jmx->get_attribute($alias)
  $value = $jmx->get_attribute(ALIAS)       # Literal alias as defined in
                                            # JMX::Jmx4Perl::Alias
  $value = $jmx->get_attribute({ domain => <domain>, 
                                 properties => { <key> => value }, 
                                 attribute => <attribute>, 
                                 path => <path> })
  $value = $jmx->get_attribute({ alias => <alias>, 
                                 path => <path })

Read a JMX attribute. In the first form, you provide the MBean name, the
attribute name and an optional path as positional arguments. The second
variant uses named parameters from a hashref. 

The Mbean name can be specified with the canoncial name (key C<mbean>), or with
a domain name (key C<domain>) and one or more properties (key C<properties> or
C<props>) which contain key-value pairs in a Hashref. For more about naming of
MBeans please refer to
L<http://java.sun.com/j2se/1.5.0/docs/api/javax/management/ObjectName.html> for
more information about JMX naming.

Alternatively, you can provide an alias, which gets resolved to its real name
by so called I<product handler>. Several product handlers are provided out of
the box. If you have specified a C<product> id during construction of this
object, the associated handler is selected. Otherwise, autodetection is used to
guess the product. Note, that autodetection is potentially slow since it
involves several JMX calls to the server. If you call with a single, scalar
value, this argument is taken as alias (without any path). If you want to use
aliases together with a path, you need to use the second form with a hash ref
for providing the (named) arguments. 

This method returns the value as it is returned from the server.

=cut 

sub get_attribute {
    my $self = shift;
    my ($object,$attribute,$path) = $self->_extract_get_set_parameters(with_value => 0,params => [@_]);
    croak "No object name provided" unless $object;

    if (ref($object) eq "CODE") {
        return $self->handle_attribute_by_handler($object);        
    }

    croak "No attribute provided for object $object" unless $attribute;

    my $request = JMX::Jmx4Perl::Request->new(READ,$object,$attribute,$path);
    my $response = $self->request($request);
    if ($response->status == 404) {
        return undef;
    }
    return $response->value;
}

=item $resp = $jmx->set_attribute(...)

  $new_value = $jmx->set_attribute($mbean,$attribute,$value,$path)
  $new_value = $jmx->set_attribute($alias,$value)
  $new_value = $jmx->set_attribute(ALIAS,$value)  # Literal alias as defined in
                                                  # JMX::Jmx4Perl::Alias
  $new_value = $jmx->set_attribute({ domain => <domain>, 
                                     properties => { <key> => value }, 
                                     attribute => <attribute>, 
                                     value => <value>,
                                     path => <path> })
  $new_value = $jmx->set_attribute({ alias => <alias>, 
                                     value => <value>,
                                     path => <path })

Method for writing an attribute. It has the same signature as L</get_attribute>
except that it takes an additional parameter C<value> for setting the value. It
returns the old value of the attribute (or the object pointed to by an inner
path). 

As for C<get_attribute> you can use a path to specify an inner part of a more
complex data structure. The value is tried to set on the inner object which is
pointed to by the given path. 

Please note that only basic data types can be set this way. I.e you can set
only values of the following types

=over

=item C<java.lang.String>

=item C<java.lang.Boolean>

=item C<java.lang.Integer>

=back

=cut

sub set_attribute { 
    my $self = shift;

    print Dumper(\@_);
    my ($object,$attribute,$path,$value) = 
      $self->_extract_get_set_parameters(with_value => 1,params => [@_]);
    croak "No object name provided" unless $object;

    if (ref($object) eq "CODE") {
        return $self->handle_attribute_by_handler($object,$value);        
    }
    croak "No attribute provided for object $object" unless $attribute;
    croak "No value to set provided for object $object and attribute $attribute" unless $value;

    my $request = JMX::Jmx4Perl::Request->new(WRITE,$object,$attribute,$value,$path);
    my $response = $self->request($request);
    if ($response->status == 404) {
        return undef;
    }
    return $response->value;
}

# Helper method for extracting parameters for the set/get methods.
sub _extract_get_set_parameters {
    my $self = shift;
    my %args = @_;
    my $p = $args{params};
    my $f = $p->[0];
    my $with_value = $args{with_value};

    my ($object,$attribute,$path,$value);
    if (ref($f) eq "HASH") {
        $value = $f->{value};
        if ($f->{alias}) {
            my $alias_path;
            ($object,$attribute,$alias_path) = 
              $self->resolve_alias($f->{alias});
            if (ref($object) eq "CODE") {
                # Let the handler do it
                return ($object,undef,undef,$args{with_value} ? $value : undef);
            }
            if ($alias_path) {
                $path = $f->{path} ? $f->{path} . "/" . $alias_path : $alias_path;
            } else { 
                $path = $f->{path};
            }
        } else {
            $object = $f->{mbean};
            if (!$object && $f->{domain} && ($f->{properties} || $f->{props})) {
                $object = $f->{domain} . ":";
                my $href = $f->{properties} || $f->{props};
                croak "'properties' is not a hashref" unless ref($href);
                for my $k (keys %{$href}) {
                    $object .= $k . "=" . $href->{$k};
                }
            }
            $attribute = $f->{attribute};
            $path = $f->{path};
        }        
    } else {
        if ( (@{$p} == 1 && !$args{with_value}) || 
             (@{$p} == 2 && $args{with_value})) {
            # A single argument can only be used as an alias
            ($object,$attribute,$path) = 
              $self->resolve_alias($f);
            $value = $_[1];
            if (ref($object) eq "CODE") {
                # Let the handler do it
                return ($object,undef,undef,$args{with_value} ? $value : undef);
            }
        } else {
            if ($args{with_value}) {
                ($object,$attribute,$value,$path) = @{$p};
            } else {
                ($object,$attribute,$path) = @{$p};
            }
        }
    }
    return ($object,$attribute,$path,$value);
}

=item $resp = $jmx->request($request)

Send a request to the underlying agent and return the response. This is an
abstract method which needs to be overwritten by a subclass. The argument must
be of type L<JMX::Jmx4Perl::Request> and it returns an object of type
L<JMX::Jmx4Perl::Response>.

=cut 

sub request {
    croak "Internal: Must be overwritten by a subclass";    
}


=item $info = $jmx->info($verbose)

Get a textual description of the server as returned by a product specific
handler (see L<JMX::Jmx4Perl::Product::BaseHandler>). It uses the
autodetection facility if no product is given explicitely during construction. 

If C<$verbose> is true, print even more information

=cut

sub info {
    my $self = shift;
    my $verbose = shift;
    my $handler = $self->{product_handler} || $self->_create_handler();
    return $handler->info($verbose);
}


=item ($object,$attribute,$path) = $self->resolve_alias($alias)

Resolve an alias for an attibute. This is done by querying registered product
handlers for resolving an alias. This method will croak if a handler could be
found but not such alias is known by C<jmx4perl>. 

If the C<product> was not set during construction, the first call to this
method will try to autodetect the server. If it cannot determine the proper
server it will throw an exception. 

Returns the object, attribute, path triple which can be used for requesting the
server or C<undef> if the handler can not resolve this alias.

A handler can decide to handle the fetching of the alias value directly. In
this case, this metod returns the code reference which needs to be executed
with the handler as argument (see "handle_attribute_by_handler") below. 

=cut

sub resolve_alias {
    my $self = shift;
    my $alias = shift || croak "No alias provided";

    my $handler = $self->{product_handler} || $self->_create_handler();    
    return $handler->alias($alias);
}

=item $attribute_value = $self->handle_attribute_by_handler($coderef,$value)

Execute a subroutine with the current handler as argument and returns the
return value of this subroutine. This method is used in conjunction with
C<resolve_alias> to allow handler a more sophisticated way to access
the MBeanServer. Additionally, it allows for mangling the output, too.

The subroutine is supposed to handle reading and writing of attributes. An
optional second parameter specifies the value to set. If this is missing, a
read is requested. 

=cut

sub handle_attribute_by_handler {
    my $self = shift;
    my $code = shift;
    my $handler = $self->{product_handler} || $self->_create_handler();    
    return &{$code}($handler,@_);
}

=item $product = $self->product_id()

For supported application servers, this methods returns the name of the
product. This product is either detected automatically or provided during
construction time.

=cut 

sub product {
    my $self = shift;
    my $handler = $self->{product_handler} || $self->_create_handler();
    return $handler->name();
}

sub _create_handler {
    my $self = shift;
    $self->{product} ||= $self->_autodetect_product();
    croak "Cannot autodetect server product" unless $self->{product};
    
    $self->{product_handler} = $self->_new_handler($self->{product});
    return $self->{product_handler};        
}

sub _autodetect_product {
    my $self = shift;
    for my $id (@PRODUCT_HANDLER_ORDERING) {
        my $handler = $self->_new_handler($id);
        return $id if $handler->autodetect();
    }
    return undef;
}

sub _new_handler {
    my $self = shift;
    my $product = shift;

    my $handler = eval $PRODUCT_HANDLER{$product}."->new(\$self)";
    croak "Cannot create handler ",$self->{product},": $@" if $@;
    return $handler;
}


=item $value = $jmx->list($path)

Get all MBeans as registered at the specified server. A C<$path> can be
specified in order to fetchy only a subset of the information. When no path is
given, the returned value has the following format

  $value = { 
              <domain> => 
              { 
                <canonical property list> => 
                { 
                    "attr" => 
                    { 
                       <atrribute name> => 
                       {
                          desc => <description of attribute>
                          type => <java type>, 
                          rw => true/false 
                       }, 
                       .... 
                    },
                    "op" => 
                    { 
                       <operation name> => 
                       { 
                         desc => <description of operation>
                         ret => <return java type>
                         args => [{ desc => <description>, name => <name>, type => <java type>}, .... ]
                       },
                       ....
                },
                .... 
              }
              .... 
           };

A complete path has the format C<"E<lt>domainE<gt>/E<lt>property
listE<gt>/("attribute"|"operation")/E<lt>indexE<gt>">
(e.g. C<java.lang/name=Code Cache,type=MemoryPool/attribute/0>). A path can be
provided partially, in which case the remaining map/array is returned. See also
L<JMX::Jmx4Perl::Agent::Protocol> for a more detailed discussion of inner
pathes. 

=cut

sub list {
    my $self = shift;
    my $path = shift;

    my $request = JMX::Jmx4Perl::Request->new(LIST,$path);
    my $response = $self->request($request);
    return $response->value;    
}


=item $formatted_text = $jmx->formatted_list($path)

=item $formatted_text = $jmx->formatted_list($resp)

Get the a formatted string representing the MBeans as returnded by C<list()>.
C<$path> is the optional inner path for selecting only a subset of all mbean.
See C<list()> for more details. If called with a L<JMX::Jmx4Perl::Response>
object, the list and the optional path will be taken from the provided response
object and not fetched again from the server.

=cut

sub formatted_list {
    my $self = shift;
    my $path_or_resp = shift;
    my $path;
    my $list;
    
    if ($path_or_resp && UNIVERSAL::isa($path_or_resp,"JMX::Jmx4Perl::Response")) {
        $path = $path_or_resp->request->get("path");
        $list = $path_or_resp->value;
    } else {
        $path = $path_or_resp;
        $list = $self->list($path);
    }
    
    my @path = ();
    @path = split m|/|,$path if $path;
    croak "A path can be used only for a domain name or MBean name" if @path > 2;
    my $intent = "";

    my $ret = &_format_map("",$list,\@path,0);
}

my $SPACE = 4;
my @SEPS = (":");
my $CURRENT_DOMAIN = "";

sub _format_map { 
    my ($ret,$map,$path,$level) = @_;
    
    my $p = shift @$path;
    my $sep = $SEPS[$level] ? $SEPS[$level] : "";
    if ($p) {
        $ret .= "$p".$sep;
        if (!@$path) {
            my $s = length($ret);
            $ret .= "\n".("=" x length($ret))."\n\n";
        }
        $ret = &_format_map($ret,$map,$path,$level);
    } else {
        for my $d (keys %$map) {
            my $prefix = "";
            if ($level == 0) {
                $CURRENT_DOMAIN = $d;
            } elsif ($level == 1) {
                $prefix = $CURRENT_DOMAIN . ":";
            } 
            $ret .= &_get_space($level).$prefix.$d.$sep."\n" unless ($d eq "attr" || $d eq "op");
            my @args = ($ret,$map->{$d},$path);
            if ($d eq "attr") {
                $ret = &_format_attr_or_op(@args,$level,"attr","Attributes",\&_format_attribute);
            } elsif ($d eq "op") {
                $ret = &_format_attr_or_op(@args,$level,"op","Operations",\&_format_operation);
            } else {
                $ret = &_format_map(@args,$level+1);
                if ($level == 0) {
                    $ret .= "-" x 80 . "\n";
                } elsif ($level == 1) {
                    $ret .= "\n";
                }
            }
        }
    }
    return $ret;
}

sub _format_attr_or_op {
    my ($ret,$map,$path,$level,$top_key,$label,$format_sub) = @_;

    my $p = shift @$path;
    if ($p eq $top_key) {
        $p = shift @$path;
        if ($p) {
            $ret .= " ".$p."\n";
            return &$format_sub($ret,$p,$map->{$p},$level);
        } else {
            $ret .= " $label:\n";
        }
    } else {
        $ret .= &_get_space($level)."$label:\n";
    }
    for my $key (keys %$map) {
        $ret = &$format_sub($ret,$key,$map->{$key},$level+1);
    }
    return $ret;
}

sub _format_attribute {
    my ($ret,$name,$attr,$level) = @_;
    $ret .= &_get_space($level);
    $ret .= sprintf("%-35s %s\n",$name,$attr->{type}.((!$attr->{rw} || "false" eq lc $attr->{rw}) ? " [ro]" : "").", \"".$attr->{desc}."\"");
    return $ret;
}

sub _format_operation {
    my ($ret,$name,$op,$level) = @_;
    $ret .= &_get_space($level);
    my $method = &_format_method($name,$op->{args},$op->{ret});
    $ret .= sprintf("%-35s \"%s\"\n",$method,$op->{desc});
    return $ret;
}

sub _format_method { 
    my ($name,$args,$ret_type) = @_;
    my $ret = $ret_type." ".$name."(";
    if ($args) {
        for my $a (@$args) {
            $ret .= $a->{type} . " " . $a->{name} . ",";
        }
        chop $ret if @$args;
    }
    $ret .= ")";
    return $ret;
}

sub _get_space {
    my $level = shift;
    return " " x ($level * $SPACE);
}

sub cfg {
    my $self = shift;
    my $key = shift;
    my $val = shift;
    my $ret = $self->{cfg}->{$key};
    if (defined $val) {
        $self->{cfg}->{$key} = $val;
    }
    return $ret;
}

# ==========================================================================
# Methods used for overwriting

# Init method called during construction
sub init {
    # Do nothing by default
}

# ==========================================================================
#

sub autodiscover_mode {

    # For now, only *one* mode is supported. Additional
    # could be added (like calling up a local JVM)
    return "agent";
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

=head1 PROFESSIONAL SERVICES

Just in case you need professional support for this module (or Nagios or JMX in
general), you might want to have a look at
http://www.consol.com/opensource/nagios/. Contact roland.huss@consol.de for
further information (or use the contact form at http://www.consol.com/contact/)

=head1 AUTHOR

roland@cpan.org

=cut

1;
