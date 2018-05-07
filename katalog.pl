#!/usr/bin/env perl

# Martin Černička: a book library
# Credits to Joel Berger for his excellent examples which got me started:
# Mojolicious http://blogs.perl.org/users/joel_berger/2012/10/a-simple-mojoliciousdbi-example.html
# SQL::Abstract https://gist.github.com/jberger/6984429

# TODO: search with autocomplete, without jquery https://stackoverflow.com/questions/7358856/mojoliciouslite-jquery-autocomplete-question
# TODO: navigation using Mojolicious::Plugin::Toto, https://github.com/bduggan/beer
# TODO: save book pictures in a separate table
# TODO: check form values using Mojolicious::Plugin::Validator
# TODO: include template, nice routes: https://github.com/shoorick/mojowka/blob/master/mojowka
# TODO: search -> edit: display a drop down menu with all entries and paging (JavaScript)

use Mojolicious::Lite;
use DBI;
use SQL::Abstract;
use Data::Dumper;

app->secrets( ['M4DYA6MaIQGIcuNj3'] );

# set this to the path you put your application into
# e.g. for "ProxyPass /katalog http://localhost:8081/", use app_path='katalog'
my $app_path = '';

my $dbh = DBI->connect( 'dbi:SQLite:dbname=katalog.sqlite',
	'', '', { sqlite_unicode => 1 } );
my $sql = SQL::Abstract->new;

my @searched_columns = qw/id Kennziffer Autoren Titel/;

sub create_db {
	$dbh->do("PRAGMA foreign_keys = ON");

	# TODO: check if the table exists and only insert upon creation
	$dbh->do(
		'CREATE TABLE IF NOT EXISTS Zustand (
				id INTEGER PRIMARY KEY,
				Beschreibung text)'
	);

	my $sth =
	  $dbh->prepare('insert into Zustand (id, Beschreibung) values ( ?, ?)');
	$sth->execute( 0, 'Eintrag vollständig' );
	$sth->execute( 1, 'Unkorrigiert' );
	$sth->execute( 2, 'Ausgeliehen' );

	$dbh->do(
		'CREATE TABLE IF NOT EXISTS Buch (
			id INTEGER PRIMARY KEY,
			Kennziffer TEXT NOT NULL,
			Erscheinungsjahr INTEGER,
			Kaufjahr INTEGER,
			Autoren TEXT,
			Titel TEXT,
			Untertitel TEXT,
			Topografisch TEXT,
			Verlag TEXT,
			ISBN TEXT,
			Dokumentart TEXT,
			Format TEXT,
			Seiten INTEGER,
			Abbildungen INTEGER,
			Karten INTEGER,
			Schlüsselwörter TEXT,
			Standort TEXT,
			Abbildung TEXT,
			Inhaltsverzeichnis TEXT,
			Zustand INTEGER references Zustand(id))'
	);

	return 1;
}

# save a new/updated/deleted record
# parameters: \%params - form fields
sub save_form {
	my $params = shift;

	my ( $query, @bind );

	if ( defined $params->{id} && $params->{submit} eq "Löschen" ) {
		( $query, @bind ) =
		  $sql->delete( "Buch", { id => $params->{id} } );
	} elsif ( defined $params->{id} ) {

		# remove $params not relevant to the query
		delete( $params->{submit} );

		( $query, @bind ) =
		  $sql->update( "Buch", $params, { id => $params->{id} } );
	} else {

		# remove $params not relevant to the query
		delete( $params->{submit} );

		( $query, @bind ) = $sql->insert( "Buch", $params );
	}

	my $sth = $dbh->prepare($query)
	  or die "could not prepare statement\n", $dbh->errstr;
	$sth->execute(@bind) or die "could not execute", $sth->errstr;

	# TODO: store uploaded file in table Bild
	#my $blob = `cat foo.jpg`;
	#my $sth  = $db->prepare("INSERT INTO Bild (data) VALUES (?)");
	#$sth->bind_param( 1, $blob, SQL_BLOB );
	#$sth->execute();
}

helper book_count => sub {
	my $c = shift;
	my $sth =
	  eval { $c->db->prepare('SELECT count(*) FROM Buch') } || return undef;
	$sth->execute;
	return $sth->fetchrow_array;
};

app->book_count || create_db();

helper select => sub {
	my $table = shift;
	$dbh->do("select count(*) from $table");
};

helper select_status => sub {
	my $c   = shift;
	my $sth = $c->db->prepare("select id, Beschreibung from Zustand");
	$sth->execute;
	return $sth->fetchall_arrayref;
};

# this is what the code actually looks like, when bracketed
helper(
	db => sub {
		$dbh;
	}
);

helper search_sql => sub {
	my ( $c, $where, $order, $columns ) = @_;

	my ( $stmt, @bind ) =
	  $sql->select( 'Buch', $columns, $where, $order || [] );

	my $sth = $dbh->prepare($stmt);
	$sth->execute(@bind);

	return $sth;
};

get '/' => sub {
	my $c = shift;
	$c->redirect_to('/home');
};

get '/home' => sub {
	my $c = shift;
	$c->stash( count => $c->book_count() );
} => 'index';

get '/form' => sub {
	my $c    = shift;
	my $rows = $c->select_status();
	$c->stash( buch_status => $rows );
} => 'form';

# save data from the form
post '/save' => sub {
	my $c      = shift;
	my $params = $c->req->params->to_hash;

	save_form( $params, $c->req->uploads, $c->req->upload('Abbildung') );

	$c->redirect_to('/home');
};

get '/search_form' => 'search_form';

any '/search' => sub {
	my $c = shift;

	if ( $c->param('search') eq 'Suchen SQL' ) {
		$c->stash(
			sth => $c->search_sql(
				$c->param('sqltext'), 'Kennziffer',
				undef,                \@searched_columns
			),
			searched_columns => \@searched_columns
		);
	}

} => 'search_sql_result';

get '/edit' => sub {
	my $c           = shift;
	my $status_rows = $c->select_status();

	# get the row for a given 'id'
	my $sth =
	  $c->search_sql( { id => $c->param('id') } );

	# 'id' is unique, we only need to fetch one row. store the field values.
	my $form = $sth->fetchrow_hashref;
	foreach my $key ( keys %$form ) {
		$c->stash( $key => $form->{$key} );
	}

	$c->stash( buch_status => $status_rows );
} => 'form';

# get highest Kennziffer from database and return a new one
# parameters: Erscheinungsjahr
# returns: Kennziffer
# example: for Erscheinungsjahr=2017 returns "2017 - 003"
get '/kennziffer' => sub {
	my $c = shift;

	my $sth = $dbh->prepare(
		"select max(Kennziffer) from Buch where Kennziffer like ?");
	$sth->execute( $c->param('erscheinungsjahr').'%' );
	my ($kennziffer) = $sth->fetchrow_array;

	my ( $year, $number );
	if ( defined $kennziffer && $kennziffer ne "" ) {
		( $year, $number ) = ( $kennziffer =~ /([0-9]+).*-.*([0-9]+)/ );
		$number++;
	} else {
		( $year, $number ) = ( $c->param('erscheinungsjahr'), 1 );
	}

	# output txt instead of html
	$c->render(text => "$year - " . sprintf( "%03d", $number), format => 'txt');
};

#
# change the base path, if deployed under a reverse proxy, e.g. with Apache:
#	ProxyRequests Off
#	ProxyPreserveHost Off
#	ProxyPass /katalog/ http://localhost:8081/
#	ProxyPassReverse /katalog/ http://localhost:8081/
#	RequestHeader set X-Request-Base https://host.domain/katalog
#
app->hook(
	before_dispatch => sub {
		my $c = shift;
		if ( my $base = $c->req->headers->header('X-Request-Base') ) {
			$c->req->url->base( Mojo::URL->new($base) );
		}
	}
);

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Katalog';
<p>Bücher im Katalog: <%= $count %>

<br><br>Version 2016-12-23: Erste Internetversion. Menü auf jeder Webseite hinzugefügt.
<hr><p align="right">Autor: Martin Černička <a href="mailto:martin@cernicka.eu">&lt;martin@cernicka.eu&gt;</a></p>

@@ search_form.html.ep
% layout 'default';
% title 'Katalog: Suche';
<p>Suchtext eingeben
<form method="get" action="<%= url_for('search')->to_abs %>">
	<p><textarea name="sqltext"></textarea>
	<p><input type="submit" name="search" value="Suchen SQL" />
	<input type="submit" name="search" value="Suchen" />
</form>
</p>

@@ search_sql_result.html.ep
% layout 'default';
% title 'Katalog: Suchergebnisse';
% # TODO: store also the list of found IDs -> paging inside the results.
% #       problem: cookie size limit of 4096 B.

<table border="1">
	<tr><th>Aktion</th>
	% foreach my $header (@$searched_columns) {
		<th><%= $header %></th>
	% }
	</tr>

	% while( my $row = $sth->fetchrow_hashref) {
		<tr><td><a href="<%= url_for('edit')->query(id => $row->{id})->to_abs %>">Ändern</a></a></td>
		% foreach my $field (@$searched_columns) {
			<td><%= $row->{$field} %></td>
		% }
		</tr>
	% }
</table>


@@ form.html.ep
% layout 'default';
% title 'Katalog: Buch bearbeiten';
<!--<body id="main_body" >-->

	<img id="top" src="top.png" alt="">
	<div id="form_container">

		<h1><a>Katalog: Buch einfügen oder bearbeiten</a></h1>
		<form class="appnitro" autocomplete="off" enctype="multipart/form-data" method="post" action="<%= url_for('save')->to_abs %>">
			% if (stash('id')) {
				<input type="hidden" name="id" value="<%= stash('id') %>">
			% }

					<div class="form_description">
			<h2>Neues Buch aufnehmen</h2>
			<p>Pflichtfelder sind mit (*) markiert. Bei Mausbewegung über die Eingabefelder erscheint ein Hilfetext.</p>
		</div>						
			<ul >
					<li>
		<label class="description" for="element_1">Erscheinungsjahr, Kennziffer, Kaufjahr</label>
		<div>
			<input id="element_1" autofocus name="Erscheinungsjahr" value="<%= stash('Erscheinungsjahr') %>" class="element text small" type="text" maxlength="255" onchange="changeEventHandler()"> 
			<input id="element_2" name="Kennziffer" value="<%= stash('Kennziffer') %>" class="element text small" type="text" maxlength="255" > 
			<input id="element_3" name="Kaufjahr" value="<%= stash('Kaufjahr') %>" class="element text small" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_1"><small>Das Jahr, in dem das Buch aufgelegt wurde. Eindeutige Nummer in der Form JJJJ - xyz. Das Jahr, in dem das Buch erworben wurde.</small></p> 
		</li>		<li>
		<label class="description" for="element_4">Autoren </label>
		<div>
			<input id="element_4" name="Autoren" value="<%= stash('Autoren') %>" class="element text large" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_4"><small>Ein oder mehrere Autoren, durch Kommas getrennt.</small></p> 
		</li>		<li>
		<label class="description" for="element_5">Titel </label>
		<div>
			<input id="element_5" name="Titel" value="<%= stash('Titel') %>" class="element text large" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_5"><small>Titel des Buchs</small></p> 
		</li>		<li>
		<label class="description" for="element_6">Untertitel </label>
		<div>
			<input id="element_6" name="Untertitel" value="<%= stash('Untertitel') %>" class="element text large" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_6"><small>Untertitel des Buchs</small></p> 
		</li>		<li>
		<label class="description" for="element_9">Verlag </label>
		<div>
			<input id="element_9" name="Verlag" value="<%= stash('Verlag') %>" class="element text large" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_9"><small>Name des Verlags</small></p> 
		</li>		<li>
		<label class="description" for="element_10">ISBN </label>
		<div>
			<input id="element_10" name="ISBN" value="<%= stash('ISBN') %>" class="element text small" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_10"><small>ISBN oder, falls nicht vorhanden, Verlagsnummer oder andere Identifikationsnummer des Werkes.</small></p> 
		</li>		<li>
		<label class="description" for="element_11">Dokumentart </label>
		<div>
			<input id="element_11" name="Dokumentart" value="<%= stash('Dokumentart') %>" class="element text medium" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_11"><small>Art des Werks: Buch gebunden oder ungebunden, Ansichtskarte, usw.</small></p> 
		</li>		<li>
		<label class="description" for="element_12">Format </label>
		<div>
			<input id="element_12" name="Format" value="<%= stash('Format') %>" class="element text medium" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_12"><small>Maße des Buchs</small></p> 
		</li>		<li>
		<label class="description" for="element_13">Seiten, Abbildungen, Karten </label>
		<div>
			<input id="element_13" name="Seiten" value="<%= stash('Seiten') %>" class="element text small" type="text" maxlength="255" > 
			<input id="element_14" name="Abbildungen" value="<%= stash('Abbildungen') %>" class="element text small" type="text" maxlength="255" > 
			<input id="element_15" name="Karten" value="<%= stash('Karten') %>" class="element text small" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_13"><small>Anzahl der Seiten, der Abbildungen und der Karten im Werk</small></p> 
		</li>		<li>
		<label class="description" for="element_16">Standort / Besitzer </label>
		<div>
			<input id="element_16" name="Standort" value="<%= stash('Standort') %>" class="element text medium" type="text" maxlength="255" > 
		</div><p class="guidelines" id="guide_16"><small>Bei Werken im Fremdbesitz wird der Standort und Besitzer eingetragen.</small></p> 
		</li>		<li>
		<label class="description" for="element_7">Topografisch </label>
		<div>
			<textarea id="element_7" name="Topografisch" class="element textarea medium"><%= stash('Topografisch') %></textarea> 
		</div><p class="guidelines" id="guide_7"><small>Orte, die das Buch behandelt. Ein Wort = ein Ort.</small></p> 
		</li>		<li>
		<label class="description" for="element_8">Schlüsselwörter </label>
		<div>
			<textarea id="element_8" name="Schlüsselwörter" class="element textarea medium"><%= stash('Schlüsselwörter') %></textarea>
		</div><p class="guidelines" id="guide_8"><small>Schlüsselwörter, die mit dem Werk zusammenhängen.</small></p> 
		</li>		<li>
		<label class="description" for="element_17">Abbildung </label>
		<div>
			<input id="element_17" name="Abbildung" class="element file" type="file"/> 
		</div> <p class="guidelines" id="guide_17"><small>Frontansicht des Werkes, Buchdeckel oder Titelblatt</small></p> 
		</li>		<li>
		<label class="description" for="element_18">Inhaltsverzeichnis</label>
		<div>
			<textarea id="element_18" name="Inhaltsverzeichnis" class="element textarea medium"><%= stash('Inhaltsverzeichnis') %></textarea> 
		</div><p class="guidelines" id="guide_18"><small>Das Inhaltsverzeichnis des Werkes.</small></p> 
		</li>		<li>
		<label class="description" for="element_19">Zustand</label>
		<div>
			<select id="element_19" name="Zustand" class="element select">
			% foreach my $option (@$buch_status) {
			<option value="<%= @$option[0] %>"
			% if (@$option[0] eq stash('Zustand')) {
				selected
			%	}
			><%= @$option[1] %></option>
			% }
			</select> 
		</div><p class="guidelines" id="guide_19"><small>Zustand des Eintrags im Katalog.</small></p> 
		</li>

		<li class="buttons">
				<input type="submit" name="submit" value="Speichern" />
				<input type="submit" name="submit" value="Löschen" />
		</li>
			</ul>
		</form>	
	</div>
	<img id="bottom" src="bottom.png" alt="">

	<script>
	var xhr = new XMLHttpRequest();

	xhr.onload = function () {
    	if (xhr.readyState === xhr.DONE) {
        	if (xhr.status === 200) {
				document.getElementsByName("Kennziffer")[0].value = xhr.responseText;
        	}
    	}
	}

	function changeEventHandler() {
		if (document.getElementsByName("Erscheinungsjahr")[0].value == "")
			document.getElementsByName("Kennziffer")[0].value="Erscheinungsjahr eingeben!";
		else {
			xhr.open('GET', '<%= url_for('/kennziffer') %>?erscheinungsjahr=' + document.getElementsByName("Erscheinungsjahr")[0].value, true);
			xhr.responseType = 'text';
			xhr.send(null);
		}
	}
	</script>

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head><meta charset="utf-8" /><title><%= title %></title>
<link rel="stylesheet" type="text/css" href="view.css" media="all">
</head>
<body>
	<a href="<%= url_for('/home') %>">Home</a> | 
	<a href="<%= url_for('/search_form') %>">Suche</a> | 
	<a href="<%= url_for('/form') %>">Neues Buch</a>
<%= content %></body></html>

