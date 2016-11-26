#!/usr/bin/env perl
use Mojolicious::Lite;

get '/' => sub {
  my $c = shift;
  $c->render(template => 'index');
};

get '/d' => sub {
  my $c = shift;
  $c->render(template => 'data');
};

app->start;
__DATA__

@@ index.html.ep
% layout 'default';
% title 'Welcome';
<h1>Welcome to the Mojolicious real-time web framework!</h1>
To learn more, you can browse through the documentation
<br>Look at the data <%= link_to('here' => '/d') %>.

@@ data.html.ep
% layout 'default';
% title 'Data';
<h1>Here comes the data!</h1>
Back <%= link_to('to /' => '/') %>.

@@ layouts/default.html.ep
<!DOCTYPE html>
<html>
  <head><title><%= title %></title></head>
  <body><%= content %></body>
</html>
