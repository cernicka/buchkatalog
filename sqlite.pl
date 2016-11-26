#!/usr/bin/env perl

use Mojolicious::Lite;

# connect to database
use DBI;
my $dbh =
  DBI->connect( "dbi:SQLite:database.db", "", "", { sqlite_unicode => 1 } )
  or die "Could not connect";

# add helper methods for interacting with database
helper db => sub { $dbh; };

helper create_table => sub {
	my $self = shift;
	warn "Creating table 'people'\n";
	$self->db->do('CREATE TABLE people (name varchar(255), age int);');
};

helper select => sub {
	my $self = shift;
	my $sth =
	  eval { $self->db->prepare('SELECT * FROM people') } || return undef;
	$sth->execute;
	return $sth->fetchall_arrayref;
};

helper insert => sub {
	my $self = shift;
	my ( $name, $age ) = @_;
	my $sth =
	  eval { $self->db->prepare('INSERT INTO people VALUES (?,?)') } || return
	  undef;
	$sth->execute( $name, $age );
	return 1;
};

# if statement didn't prepare, assume its because the table doesn't exist
app->select || app->create_table;

# setup base route
any '/' => sub {
	my $self = shift;
	my $rows = $self->select;
	$self->stash( rows => $rows );
	$self->render('index');
};

# setup route which receives data and returns to /
any '/insert' => sub {
	my $self   = shift;
	my $name   = $self->param('name');
	my $age    = $self->param('age');
	my $insert = $self->insert( $name, $age );
	$self->redirect_to('/');
};

if ( exists $ENV{PAR_TEMP} && $^O eq "MSWin32" ) {
	system qw(start http://localhost:3000);
}

app->start;

__DATA__

@@ index.html.ep

<!DOCTYPE html>
<html>
<head><meta charset="utf-8" /><title>People</title></head>
<body>
  <form action="<%=url_for('insert')->to_abs%>" method="post">
    Name: <input type="text" name="name"> 
    Age: <input type="text" name="age"> 
    <input type="submit" value="Add">
  </form>
  <br>
  Data: <br>
  <table border="1">
    <tr>
      <th>Name</th>
      <th>Age</th>
    </tr>
    % foreach my $row (@$rows) {
      <tr>
		% foreach my $text (@$row) {
          <td><%= $text %></td>
        % }
      </tr>
    % }
  </table>
</body>
</html>
