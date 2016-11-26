#!/usr/bin/perl

use Mojolicious::Lite;
use Mojolicious::Plugin::TtRenderer;

# automatically render *.html.tt templates
plugin 'tt_renderer';

any '/example_form' => sub {
    my ($self) = @_;
    $self->stash( result => $self->param('user_input') );
};

app->start;
