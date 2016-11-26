#!/usr/bin/env perl

use common::sense;

use Mojolicious::Lite;
use DBI;
use SQL::Abstract;

# all fields from the form, database table Buch
my @fields = (
	'Kennziffer',         'Erscheinungsjahr',
	'Kaufjahr',           'Titel',
	'Untertitel',         'Topografisch',
	'Verlag',             'ISBN',
	'Dokumentart',        'Format',
	'Seiten',             'Abbildungen',
	'Karten',             'Schlüsselwörter',
	'Standort',           'Abbildung',
	'Inhaltsverzeichnis', 'Zustand'
);

sub db_connect {
	return DBI->connect( 'dbi:SQLite:dbname=katalog.db',
		'', '', { sqlite_unicode => 1 } );
}

sub create_db {
	my $db = db_connect();

	$db->do("PRAGMA foreign_keys = ON");
	$db->do(
		'CREATE TABLE IF NOT EXISTS Zustand (
				id INTEGER PRIMARY KEY,
				Beschreibung text)'
	);

	my $sth =
	  $db->prepare('insert into Zustand (id, Beschreibung) values ( ?, ?)');
	$sth->execute( 0, 'Eintrag vollständig' );
	$sth->execute( 1, 'Unkorrigiert' );
	$sth->execute( 2, 'Ausgeliehen' );

	$db->do(
		'CREATE TABLE IF NOT EXISTS Buch (
			id INTEGER PRIMARY KEY,
			Kennziffer TEXT NOT NULL,
			Erscheinungsjahr INTEGER,
			Kaufjahr INTEGER,
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
	my $blob = `cat foo.jpg`;

	#my $sth  = $db->prepare("INSERT INTO mytable VALUES (1, ?)");
	#$sth->bind_param( 1, $blob, SQL_BLOB );
	#$sth->execute();
}

# this is what the code actually looks like, when bracketed
helper(
	db => sub {
		state $db = db_connect();
	}
);

helper sql_select => sub {
	my ( $c, $search, $order ) = @_;

	my @columns = qw/ip country_name city latitude longitude/;
	my @where =
	  map { +{ $_ => { '-like' => $search } } } ( $search ? @columns : () );

	my $sql = SQL::Abstract->new;
	my ( $stmt, @bind ) =
	  $sql->select( 'geo_data', \@columns, \@where, $order || [] );

	return $stmt, \@bind;
};

get '/' => sub {
	my $c = shift;
} => 'index';

get '/form' => sub {
	my $c = shift;
} => 'form';

# save data from the form
post '/save' => sub {
	my $c = shift;

	# for storing the form fields
	my %form;

	foreach my $field (@fields) {
		$form{$field} = $c->param($field);
	}

	save_book( \%form );

	#my $insert = $c->insert( $name, $age );

	$c->redirect_to('/');
};

get '/search_sql' => sub {
	my $c = shift;
} => 'search_sql';

post '/search_sql' => sub {
	my $c = shift;

} => 'search_sql_result';    # or call form()

if ( exists $ENV{PAR_TEMP} && $^O eq "MSWin32" ) {
	system qw(start http://localhost:3000);
}

app->start;

__DATA__

@@ index.html.ep
% layout 'default';
% title 'Katalog';
<p>Bücher im Katalog: <%= Model::Buch->count %><br>

<ul>
	<li><a href="search">Suche</a>
	<li><a href="search_sql">Suche SQL</a>
	<li><a href="form">Neues Buch</a>
</ul>

@@ search_sql.html.ep
% layout 'default';
% title 'Suche im Katalog';

@@ form.html.ep
% layout 'default';
% title 'Katalog: Buch bearbeiten';
<!--<body id="main_body" >

	<img id="top" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAwIAAAAKCAYAAAAHB+lIAAAABGdBTUEAANbY1E9YMgAAABl0RVh0U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAEzSURBVHja7NvrbsIwDAbQpBT2/q87xrIVtZPrXrQhlU3aOZJJIOW/Pxxqa60AAAD/Sz+81Fr3nqkPngEAAMdqj5wNw4D+G819XdlXgQAAAP5MAGg/DQb9RkO/tsbaCwUAAMDzwkBcY9V0Ft/PgsBe89+ldSsUAAAAzw0Bsd7TmkPAVxjYmwjE5n+oU9jnUCAMAADA74SA2PwPdRt78xwKNicCJYWALoWAPoWBriwnBAAAwPFBoKXmP4eAGAZKmU8IVoNAvg50CiHgnALBqSynAwAAwPFBIP7afxvrLQSAKQxMz9ewnwWBfMUnTgLOK5UnBNN3AACAY+UQMAWA61g1Nf75D8T3z9cmAvk60ND4Xz7rZVwvZT4hiGHAVAAAAI7TynIScB3DwOvYm2+FgKnuPgQYAGd6YIIkTAoCAAAAAElFTkSuQmCC" alt="">
	<div id="form_container">

		<h1><a>Katalog: Buch bearbeiten oder einfügen</a></h1>
		<form class="appnitro" enctype="multipart/form-data" method="post" action="">
					<div class="form_description">
			<h2>Neues Buch aufnehmen</h2>
			<p>Pflichtfelder sind mit (*) markiert. Bei Mausbewegung über die Eingabefelder erscheint ein Hilfetext.</p>
		</div>						
			<ul >

					<li>
		<label class="description" for="element_1">Kennziffer, Erscheinungsjahr, Kaufjahr</label>
		<div>
			<input id="element_1" name="Kennziffer" class="element text small" type="text" maxlength="255" value=""/> 
			<input id="element_2" name="Erscheinungsjahr" class="element text small" type="text" maxlength="255" value=""/> 
			<input id="element_3" name="Kaufjahr" class="element text small" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_1"><small>Eindeutige Nummer in der Form JJJJ-xyz. Das Jahr, in dem das Buch aufgelegt wurde. Das Jahr, in dem das Buch erworben wurde.</small></p> 
		</li>		<li>
		<label class="description" for="element_4">Titel </label>
		<div>
			<input id="element_4" name="Titel" class="element text large" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_4"><small>Titel des Buchs</small></p> 
		</li>		<li>
		<label class="description" for="element_5">Untertitel </label>
		<div>
			<input id="element_5" name="Untertitel" class="element text large" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_5"><small>Untertitel des Buchs</small></p> 
		</li>		<li>
		<label class="description" for="element_6">Topografisch </label>
		<div>
			<textarea id="element_6" name="Topografisch" class="element textarea medium"></textarea> 
		</div><p class="guidelines" id="guide_6"><small>Orte, die das Buch behandelt. Ein Wort = ein Ort.</small></p> 
		</li>		<li>
		<label class="description" for="element_7">Verlag </label>
		<div>
			<input id="element_7" name="Verlag" class="element text large" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_7"><small>Name des Verlags</small></p> 
		</li>		<li>
		<label class="description" for="element_8">ISBN </label>
		<div>
			<input id="element_8" name="ISBN" class="element text small" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_8"><small>ISBN oder, falls nicht vorhanden, Verlagsnummer oder andere Identifikationsnummer des Werkes.</small></p> 
		</li>		<li>
		<label class="description" for="element_9">Dokumentart </label>
		<div>
			<input id="element_9" name="Dokumentart" class="element text medium" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_9"><small>Art des Werks: Buch gebunden oder ungebunden, Ansichtskarte, usw.</small></p> 
		</li>		<li>
		<label class="description" for="element_10">Format </label>
		<div>
			<input id="element_10" name="Format" class="element text medium" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_10"><small>Maße des Buchs</small></p> 
		</li>		<li>
		<label class="description" for="element_11">Seiten, Abbildungen, Karten </label>
		<div>
			<input id="element_11" name="Seiten" class="element text small" type="text" maxlength="255" value=""/> 
			<input id="element_11" name="Abbildungen" class="element text small" type="text" maxlength="255" value=""/> 
			<input id="element_11" name="Karten" class="element text small" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_11"><small>Anzahl der Seiten, der Abbildungen und der Karten im Werk</small></p> 
		</li>		<li>
		<label class="description" for="element_12">Standort / Besitzer </label>
		<div>
			<input id="element_12" name="Standort" class="element text medium" type="text" maxlength="255" value=""/> 
		</div><p class="guidelines" id="guide_12"><small>Bei Werken im Fremdbesitz wird der Standort und Besitzer eingetragen.</small></p> 
		</li>		<li>
		<label class="description" for="element_13">Abbildung </label>
		<div>
			<input id="element_13" name="Abbildung" class="element file" type="file"/> 
		</div> <p class="guidelines" id="guide_13"><small>Frontansicht des Werkes, Buchdeckel oder Titelblatt</small></p> 
		</li>		<li>
		<label class="description" for="element_14">Inhaltsverzeichnis</label>
		<div>
			<textarea id="element_14" name="Inhaltsverzeichnis" class="element textarea medium"></textarea> 
		</div><p class="guidelines" id="guide_14"><small>Das Inhaltsverzeichnis des Werkes.</small></p> 
		</li>		<li>
		<label class="description" for="element_15">Zustand</label>
		<div>
			<select multiple id="element_15" name="Zustand" class="element select">
			%# foreach my $option (@{$status}) { >
			<option value="<%#= $option->id >"><%#= $option->State></option>
			%# }
			</select> 
		</div>
		</li>

		<li class="buttons">
				<input type="submit" value="Speichern" />
		</li>
			</ul>
		</form>	
	</div>
	<img id="bottom" src="data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAwIAAAAKCAYAAAAHB+lIAAAABGdBTUEAANbY1E9YMgAAABl0RVh0U29mdHdhcmUAQWRvYmUgSW1hZ2VSZWFkeXHJZTwAAAFBSURBVHja7N1RT4MwGAXQMuv8/z9XGVRI2uSzlmU+DE08J7kBBnzPvRtkUyklTZuU0p7LlpeavOW15rrlrW6v4Vy79lLv3wMAADxHqVm3LDXzltuWj5r3up3DuXbtfl/Z5cHgtS7ol8Hifq2DclcCLvW8IgAAAM8tAm1dHsvArWauJeAWCkC7tsRBuRs4KgOxeSyhAMQSMCkCAABwWhEogzIQC8GoBMSkfDC8De6Pl0EB8GsAAACcXwbWO4VgVAK+yHeGpq41tOGxBMQAAADnlYF+rT5KOSoDuRs2hf32eFDpjvsXg2MJUAgAAOC5BaDfL4MFf/840Lf78wPDp7A9eolYCQAAgPPLQOoW+2VQAMpoyNGjQdNBc/DtPwAA/N1i8Mj+sAike63h4HOFAAAAfrcA/Pj8tP+hGAAA8L98CjAAlCWZhVgMBgwAAAAASUVORK5CYII=" alt="">

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
<head><meta charset="utf-8" /><title><%= title %></title></head>
<link rel="stylesheet" type="text/css" href="view.css" media="all">
</head>
<body><%= content %></body></html>
255:	final indentation level: -1
255:	To save a full .LOG file rerun with -g