# $Id: DBI.pm,v 1.3 2002/02/07 17:21:56 matt Exp $

package XML::Generator::DBI;
use strict;

use MIME::Base64;
use XML::SAX::Base;

use vars qw($VERSION @ISA);

$VERSION = '0.02';
@ISA = ('XML::SAX::Base');

sub execute {
    my $self = shift;
    my ($query, $bind, %p) = @_;
    
    my %params = (
        RootElement => "database",
        QueryElement => "select",
        RowElement => "row",
        ColumnsElement => "columns",
        ColumnElement => "column",
        %$self, %p,
        );
    
    # This might confuse people, but the methods are actually
    # called on this proxy object, which is a mirror of $self
    # with the new params inserted.
    my $proxy = bless \%params, ref($self);
    
    # turn on throwing exceptions
    local $proxy->{dbh}->{RaiseError} = 1;
    
    my $sth;
    if (ref($query)) {
        # assume its a statement handle
        $sth = $query;
        $query = "Unknown - executing statement handle";
    }
    else {
        $sth = $proxy->{dbh}->prepare($query);
    }
    
    my @bind;
    if (defined($bind)) {
        @bind = ref($bind) ? @{$bind} : ($bind);
    }
    
    $sth->execute(@bind);
    
    my @row;
    my $names = $params{LowerCase} ? $sth->{NAME_lc} : $sth->{NAME};
    $sth->bind_columns( 
            \( @row[ 0 .. $#{$names} ] )
        );
    
    $proxy->SUPER::start_document({});
    
    $proxy->send_start($params{RootElement});
    $proxy->send_start($params{QueryElement}, 1, query => $query);
    
    # output columns if necessary
    
#     use Data::Dumper;
#     my $type_info_all = $proxy->{dbh}->type_info_all;
#     warn(Dumper($type_info_all));
    
    if ($params{ShowColumns}) {
        my $types = $sth->{TYPE};
        my $precision = $sth->{PRECISION};
        my $scale = $sth->{SCALE};
        my $null = $sth->{NULLABLE};
        $proxy->send_start($params{ColumnsElement}, 2);
        foreach my $i (0 .. $#{$names}) {
            my $type_info = $proxy->{dbh}->type_info($types->[$i]);
            if ($params{AsAttributes}) {
                my %attribs;
                $attribs{name} = $names->[$i];
                $attribs{type} = $type_info->{TYPE_NAME} if $type_info->{TYPE_NAME};
                $attribs{size} = $type_info->{COLUMN_SIZE} if $type_info->{COLUMN_SIZE};
                $attribs{precision} = $precision->[$i] if defined($precision->[$i]);
                $attribs{scale} = $scale->[$i] if defined($scale->[$i]);
                $attribs{nullable} = (!$null->[$i] ? "NOT NULL" : ($null->[$i] == 1) ? "NULL" : "UNKNOWN") if defined($null->[$i]);
                
                $proxy->send_tag($params{ColumnElement}, undef, 3, %attribs);
            }
            else {
                $proxy->send_start($params{ColumnElement}, 3);

                $proxy->send_tag(name => $names->[$i], 4);
                $proxy->send_tag(type => $type_info->{TYPE_NAME}, 4) if $type_info->{TYPE_NAME};
                $proxy->send_tag(size => $type_info->{COLUMN_SIZE}, 4) if $type_info->{COLUMN_SIZE};
                $proxy->send_tag(precision => $precision->[$i], 4) if defined($precision->[$i]);
                $proxy->send_tag(scale => $scale->[$i], 4) if defined($scale->[$i]);
                $proxy->send_tag(nullable => (!$null->[$i] ? "NOT NULL" : ($null->[$i] == 1 ? "NULL" : "UNKNOWN")), 4) if defined($null->[$i]);

                $proxy->send_end($params{ColumnElement}, 3);
            }
        }
        $proxy->send_end($params{ColumnsElement}, 2);
    }
    
    while ($sth->fetch) {
        # TODO: Handle binary data
        foreach (@row) {
            if (defined($_) && /[\x00-\x08\x0A-\x0C\x0E-\x19]/) {
                # in foreach loops, $_ is an lvalue!
                $_ = MIME::Base64::encode_base64($_);
            }
        }
        if ($params{AsAttributes}) {
            my %attribs = map { $names->[$_] => $row[$_] } # create hash
                          grep { defined $row[$_] } # remove undef ones
                          (0 .. $#{$names});
            
            $proxy->send_tag($params{RowElement}, undef, 2, %attribs);
        }
        else {
            $proxy->send_start($params{RowElement}, 2);
            foreach my $i (0 .. $#{$names}) {
                $proxy->send_tag($names->[$i], $row[$i], 3) if defined($row[$i]);
            }
            $proxy->send_end($params{RowElement}, 2);
        }
    }
    $proxy->send_end($params{QueryElement}, 1);
    $proxy->send_end($params{RootElement});
    
    $proxy->SUPER::end_document({});
}

# SAX utility functions

sub send_tag {
    my $self = shift;
    my ($name, $contents, $indent, %attributes) = @_;
    $self->SUPER::characters({ Data => (" " x $indent) }) if $indent && $self->{Indent};
    $self->SUPER::start_element({ Name => $name, Attributes => \%attributes });
    $self->SUPER::characters({ Data => $contents });
    $self->SUPER::end_element({ Name => $name });
    $self->new_line if $self->{Indent};
}

sub send_start {
    my $self = shift;
    my ($name, $indent, %attributes) = @_;
    $self->SUPER::characters({ Data => (" " x $indent) }) if $indent && $self->{Indent};
    $self->SUPER::start_element({ Name => $name, Attributes => \%attributes });
    $self->new_line if $self->{Indent};
}

sub send_end {
    my $self = shift;
    my ($name, $indent) = @_;
    $self->SUPER::characters({ Data => (" " x $indent) }) if $indent && $self->{Indent};
    $self->SUPER::end_element({ Name => $name });
    $self->new_line if $self->{Indent};
}

sub new_line {
    my $self = shift;
    $self->SUPER::characters({ Data => "\n" });
}

1;
__END__

=head1 NAME

XML::Generator::DBI - Generate SAX events from SQL queries

=head1 SYNOPSIS

  use XML::Generator::DBI;
  use XML::Handler::YAWriter;
  use DBI;
  my $ya = XML::Handler::YAWriter->new(AsFile => "-");
  my $dbh = DBI->connect("dbi:Pg:dbname=foo", "user", "pass");
  my $generator = XML::Generator::DBI->new(
                        Handler => $ya, 
                        dbh => $dbh
                        );
  $generator->execute($sql, [@bind_params]);

=head1 DESCRIPTION

This module is a replacement for the outdated DBIx::XML_RDB module.

It generates SAX events from SQL queries against a DBI connection.
Unlike DBIx::XML_RDB, it does not create a string directly, instead
you have to use some sort of SAX handler module. If you wish to
create a string or write to a file, use YAWriter, as shown in the
above SYNOPSIS section. Alternatively you might want to generate
a DOM tree or XML::XPath tree, which you can do with either of those
module's SAX handlers (known as Builders in those distributions).

The XML structure created is as follows:

  <database>
    <select query="SELECT * FROM foo">
      <row>
        <column1>1</column1>
        <column2>fubar</column2>
      </row>
      <row>
        <column1>2</column1>
        <column2>intravert</column2>
      </row>
    </select>
  </database>

Alternatively, pass the option AsAttributes => 1 to either the
execute() method, or to the new() method, and your XML will look
like:

  <database>
    <select query="SELECT * FROM foo">
      <row column1="1" column2="fubar"/>
      <row column1="2" column2="intravert"/>
    </select>
  </database>

Note that with attributes, ordering of columns is likely to be lost,
but on the flip side, it may save you some bytes.

Nulls are handled by excluding either the attribute or the tag.

=head1 API

=head2 XML::Generator::DBI->new()

Create a new XML generator.

Parameters are passed as key/value pairs:

=over 4

=item Handler (required)

A SAX handler to recieve the events.

=item dbh (required)

A DBI handle on which to execute the queries. Must support the
prepare, execute, fetch model of execution, and also support
type_info if you wish to use the ShowColumns option (see below).

=item AsAttributes

The default is to output everything as elements. If you wish to
use attributes instead (perhaps to save some bytes), you can
specify the AsAttributes option with a true value.

=item RootElement

You can specify the root element name by passing the parameter
RootElement => "myelement". The default root element name is
"database".

=item QueryElement

You can specify the query element name by passing the parameter
QueryElement => "thequery". The default is "select".

=item RowElement

You can specify the row element name by passing the parameter
RowElement => "item". The default is "row".

=item Indent

By default this module does no indenting (which is different from
the previous version). If you want the XML beautified, pass the
Indent option with a true value.

=item ShowColumns

If you wish to add information about the columns to your output,
specify the ShowColumns option with a true value. This will then
show things like the name and data type of the column, whether the
column is NULLABLE, the precision and scale, and also the size of
the column. All of this information is from $dbh->type_info() (see
perldoc DBI), and may change as I'm not 100% happy with the output.

=back

=head2 $generator->execute($query, $bind, %params)

You execute a query and generate results with the execute method.

The first parameter is a string containing the query. The second is
a single or set of bind parameters. If you wish to make it more than
one bind parameter, it must be passed as an array reference:

    $generator->execute(
        "SELECT * FROM Users WHERE name = ?
         AND password = ?",
         [ $name, $password ],
         );

Following the bind parameters you may pass any options you wish to
use to override the above options to new(). Thus allowing you to
turn on and off certain options on a per-query basis.

=head1 Other Information

Binary data is encoded using Base64. If you are using AsElements,
the element containing binary data will have an attribute 
xml:encoding="base64". We detect binary data as anything containing
characters outside of the XML UTF-8 allowed character set.

NB: Binary encoding is actually on the TODO list :-)

I'm thinking about adding something that will do nesting, so that
if you get back:

       id   activity     colour
  =============================
        1       food      green
        1     garden     yellow
        2     garden        red

It will automatically try and nest it as:

  <database>
    <select query="SELECT id, activity, colour FROM Favourites">
        <id>
          <value>1</value>
            <activity>food</activity>
            <colour>green</colour>
            <activity>garden</activity>
            <colour>yellow</colour>
        </id>
        <id>
          <value>2</value>
          <activity>garden</activity>
          <colour>red</colour>
        </id>
    </select>
  </database>

(the format above isn't considered set in stone, comments welcome)

I would only be able to do this based on changes in the value in a 
particular column, rather than how certain technologies (e.g. MS SQL
Server 2000) do it based on the joins used.

=head1 AUTHOR

Matt Sergeant, matt@sergeant.org

=head1 LICENSE

This is free software, you may use it and distribute it under the
same terms as Perl itself. Specifically this is the Artistic License,
or the GNU GPL Version 2.

=head1 SEE ALSO

PerlSAX, L<XML::Handler::YAWriter>.

=cut
