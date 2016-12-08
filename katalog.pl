#!/usr/bin/env perl

# Martin Černička: a book library
# TODO: search with autocomplete? https://stackoverflow.com/questions/7358856/mojoliciouslite-jquery-autocomplete-question
# TODO: navigation using Mojolicious::Plugin::Toto, https://github.com/bduggan/beer
# TODO: save book pictures in a separate table
# TODO: check form values using Mojolicious::Plugin::Validator
# a bigger example: https://mrpws.blogspot.co.at/p/mojolociouslite-script-courts3pl.html

use common::sense;

use Mojolicious::Lite;
use DBI;
use SQL::Abstract;

my $dbh = DBI->connect( 'dbi:SQLite:dbname=katalog.db',
	'', '', { sqlite_unicode => 1 } );
my $sql = SQL::Abstract->new;

my @searched_columns = qw/id Kennziffer Autoren Titel/;

# all fields from the form, database table Buch
my @all_columns = (
	'Kennziffer',         'Erscheinungsjahr',
	'Kaufjahr',           'Titel',
	'Untertitel',         'Topografisch',
	'Verlag',             'ISBN',
	'Dokumentart',        'Format',
	'Seiten',             'Abbildungen',
	'Karten',             'Schluesselwoerter',
	'Standort',           'Abbildung',
	'Inhaltsverzeichnis', 'Zustand'
);

sub create_db {
	$dbh->do("PRAGMA foreign_keys = ON");
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

sub save_book {
	my $params = shift;

	my ( $query, @bind ) = $sql->insert( "Buch", $params );
	my $sth = $dbh->prepare($query)
	  or die "could not prepare statement\n", $dbh->errstr;
	$sth->execute(@bind) or die "could not execute", $sth->errstr;

	# for storing the uploaded file

	#my $blob = `cat foo.jpg`;
	#my $sth  = $db->prepare("INSERT INTO mytable VALUES (1, ?)");
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

	#$DB::single = 1;
	my ( $stmt, @bind ) =
	  $sql->select( 'Buch', $columns, $where, $order || [] );

	my $sth = $dbh->prepare($stmt);
	$sth->execute(@bind);

	return $sth;    #->fetchall_arrayref;
};

get '/' => sub {
	my $c = shift;
	$c->stash( count => $c->book_count() );
	$c->render('index');
};

get '/form' => sub {
	my $c    = shift;
	my $rows = $c->select_status();
	$c->stash( status => $rows );
} => 'form';

# save data from the form
post '/save' => sub {
	my $c = shift;

	my $params = $c->req->params->to_hash;
	save_book( $params, $c->req->uploads, $c->req->upload('Abbildung') );

	$c->redirect_to('/');
};

get '/search_sql' => sub {
	my $c = shift;
} => 'search_sql';

post '/search_sql' => sub {
	my $c = shift;

	$c->stash(
		sth => $c->search_sql(
			$c->param('sqltext'),
			undef, undef, \@searched_columns
		),
		searched_columns => \@searched_columns
	);

	# TODO: return also a list of matched IDs -> paging inside the results
} => 'search_sql_result';

get '/edit' => sub {
	my $c = shift;
	$c->stash( sth=>$c->search_sql( $c->param('id'), undef, undef, \@all_columns ) );

	# add submit button to template: save new, update?
} => 'form';

# automatically open a browser window in Windows
if ( exists $ENV{PAR_TEMP} && $^O eq "MSWin32" ) {
	system qw(start http://localhost:3000);
}

app->secrets( ['M4DYA6MaIQGIcuNj3'] );
app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Katalog';
<p>Bücher im Katalog: <%= $count %><br>

<p><ul>
	<li><a href="search">Suche</a>
	<li><a href="search_sql">Suche SQL</a>
	<li><a href="form">Neues Buch</a>
</ul>

@@ search_sql.html.ep
% layout 'default';
% title 'Suche im Katalog';
<p>Suchtext SQL eingeben.
<form enctype="multipart/form-data" method="post" action="<%= url_for('search_sql')->to_abs %>">
	<p><textarea name="sqltext"></textarea>
	<p><input type="submit" value="Suchen" />
</form>
</p>

@@ search_sql_result.html.ep
% layout 'default';
% title 'Suchergebnisse';
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

		<h1><a>Katalog: Buch bearbeiten oder einfügen</a></h1>
		<form class="appnitro" enctype="multipart/form-data" method="post" action="<%= url_for('save')->to_abs %>">
					<div class="form_description">
			<h2>Neues Buch aufnehmen</h2>
			<p>Pflichtfelder sind mit (*) markiert. Bei Mausbewegung über die Eingabefelder erscheint ein Hilfetext.</p>
		</div>						
			<ul >

					<li>
		<label class="description" for="element_1">Kennziffer, Erscheinungsjahr, Kaufjahr</label>
		<div>
			<input id="element_1" name="Kennziffer" value="<%= stash('Kennziffer') %>"
			% if (my $p = stash 'Kennziffer') { print("value=\"$p\" "); }
			class="element text small" type="text" maxlength="255" value=""/> 
			<input id="element_2" name="Erscheinungsjahr" class="element text small" type="text" maxlength="255" value=""/> 
			<input id="element_3" name="Kaufjahr" class="element text small" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_1"><small>Eindeutige Nummer in der Form JJJJ-xyz. Das Jahr, in dem das Buch aufgelegt wurde. Das Jahr, in dem das Buch erworben wurde.</small></p> 
		</li>		<li>
		<label class="description" for="element_4">Autoren </label>
		<div>
			<input id="element_4" name="Autoren" class="element text large" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_4"><small>Ein oder mehrere Autoren, durch Kommas getrennt.</small></p> 
		</li>		<li>
		<label class="description" for="element_5">Titel </label>
		<div>
			<input id="element_5" name="Titel" class="element text large" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_5"><small>Titel des Buchs</small></p> 
		</li>		<li>
		<label class="description" for="element_6">Untertitel </label>
		<div>
			<input id="element_6" name="Untertitel" class="element text large" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_6"><small>Untertitel des Buchs</small></p> 
		</li>		<li>
		<label class="description" for="element_9">Verlag </label>
		<div>
			<input id="element_9" name="Verlag" class="element text large" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_9"><small>Name des Verlags</small></p> 
		</li>		<li>
		<label class="description" for="element_10">ISBN </label>
		<div>
			<input id="element_10" name="ISBN" class="element text small" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_10"><small>ISBN oder, falls nicht vorhanden, Verlagsnummer oder andere Identifikationsnummer des Werkes.</small></p> 
		</li>		<li>
		<label class="description" for="element_11">Dokumentart </label>
		<div>
			<input id="element_11" name="Dokumentart" class="element text medium" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_11"><small>Art des Werks: Buch gebunden oder ungebunden, Ansichtskarte, usw.</small></p> 
		</li>		<li>
		<label class="description" for="element_12">Format </label>
		<div>
			<input id="element_12" name="Format" class="element text medium" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_12"><small>Maße des Buchs</small></p> 
		</li>		<li>
		<label class="description" for="element_13">Seiten, Abbildungen, Karten </label>
		<div>
			<input id="element_13" name="Seiten" class="element text small" type="text" maxlength="255" value=""/> 
			<input id="element_14" name="Abbildungen" class="element text small" type="text" maxlength="255" value=""/> 
			<input id="element_15" name="Karten" class="element text small" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_13"><small>Anzahl der Seiten, der Abbildungen und der Karten im Werk</small></p> 
		</li>		<li>
		<label class="description" for="element_16">Standort / Besitzer </label>
		<div>
			<input id="element_16" name="Standort" class="element text medium" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_16"><small>Bei Werken im Fremdbesitz wird der Standort und Besitzer eingetragen.</small></p> 
		</li>		<li>
		<label class="description" for="element_7">Topografisch </label>
		<div>
			<textarea id="element_7" name="Topografisch" class="element textarea medium"></textarea> 
		</div><p class="guidelines" id="guide_7"><small>Orte, die das Buch behandelt. Ein Wort = ein Ort.</small></p> 
		</li>		<li>
		<label class="description" for="element_8">Schlüsselwörter </label>
		<div>
			<textarea id="element_8" name="Schlüsselwörter" class="element textarea medium"></textarea>
		</div><p class="guidelines" id="guide_8"><small>Schlüsselwörter, die mit dem Werk zusammenhängen.</small></p> 
		</li>		<li>
		<label class="description" for="element_17">Abbildung </label>
		<div>
			<input id="element_17" name="Abbildung" class="element file" type="file"/> 
		</div> <p class="guidelines" id="guide_17"><small>Frontansicht des Werkes, Buchdeckel oder Titelblatt</small></p> 
		</li>		<li>
		<label class="description" for="element_18">Inhaltsverzeichnis</label>
		<div>
			<textarea id="element_18" name="Inhaltsverzeichnis" class="element textarea medium"></textarea> 
		</div><p class="guidelines" id="guide_18"><small>Das Inhaltsverzeichnis des Werkes.</small></p> 
		</li>		<li>
		<label class="description" for="element_19">Zustand</label>
		<div>
			<select id="element_19" name="Zustand" class="element select">
			% foreach my $option (@$status) {
			<option value="<%= @$option[0] %>"><%= @$option[1] %></option>
			% }
			</select> 
		</div><p class="guidelines" id="guide_19"><small>Zustand des Eintrags im Katalog.</small></p> 
		</li>

		<li class="buttons">
				<input type="submit" value="Speichern" />
		</li>
			</ul>
		</form>	
	</div>
	<img id="bottom" src="bottom.png" alt="">

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head><meta charset="utf-8" /><title><%= title %></title>
<link rel="stylesheet" type="text/css" href="view.css" media="all">
</head>
<body><%= content %></body></html>

