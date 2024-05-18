package Mojolicious::Plugin::Data::Transfigure;
use v5.26;

# ABSTRACT: Mojolicious adapter for Data::Transfigure

use Mojo::Base 'Mojolicious::Plugin';

use Data::Transfigure;
use List::Util qw(any);
use Readonly;

Readonly::Scalar my $DEFAULT_PREFIX => 'transfig';

use experimental qw(signatures);

sub register($self, $app, $conf) {
  my @renderers = ($conf->{renderers} // [qw(json)])->@*;
  my $prefix    = $conf->{prefix}     // $DEFAULT_PREFIX;
  my $bare      = $conf->{bare};

  # default OUTPUT transfigurator
  my $t_out = $bare ? Data::Transfigure->bare() : Data::Transfigure->dbix();
  $t_out->add_transfigurators(
    qw(
      Data::Transfigure::HashKeys::CamelCase 
      Data::Transfigure::HashKeys::CapitalizedIDSuffix 
      Data::Transfigure::HashFilter::Undef
      Data::Transfigure::Tree::Merge
    )
  ) unless($bare);
  
  # default INPUT transfigurator
  my $t_in = $bare ? Data::Transfigure->bare() : Data::Transfigure->new();
  $t_in->add_transfigurators(qw(
    Data::Transfigure::HashKeys::SnakeCase
  )) unless($bare);

  # helpers to provide access to default transfigurators (for adding transfigurations)
  $app->helper("$prefix.input"  => sub($c) {$t_in });
  $app->helper("$prefix.output" => sub($c) {$t_out});

  # helper to apply transfigurator (default or custom) to request body JSON
  $app->helper("$prefix.json" => sub($c, %args) {
    my $lt = exists($args{transfigurator}) ? delete($args{transfigurator}) : $t_in;
    my $data = $c->req->json;
    return defined($lt) ? $lt->transfigure($data) : $data;
  });

  # Render hook to apply transfigurator (default or custom) to request output
  $app->hook(before_render => sub ($c, $args) {
    my $lt = exists($args->{transfigurator}) ? delete($args->{transfigurator}) : $t_out;
    foreach my $k (keys($args->%*)) {
      if(defined($lt) && any { $_ eq $k } @renderers) {
        $args->{$k} = $lt->transfigure($args->{$k});
      }
    }
  });
}

1;
