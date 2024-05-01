package Mojolicious::Plugin::Data::Transfigure;
use v5.26;

use Mojo::Base 'Mojolicious::Plugin';

use Data::Transfigure;

use experimental qw(signatures);

sub register($self, $app, $conf) {
  my @renderers = ($conf->{renderers} // [])->@*;

  my $t = Data::Transfigure->dbix();
  $app->helper(default_output_transfigurator => sub($c) {$t});

  $app->hook(before_render => sub ($c, $args) {
    my $lt = delete($args->{transfigurator}) // $t;
    foreach my $k (keys($args->%*)) {
      $args->{$k} = $lt->transfigure($args->{$k}) if(grep { $_ eq $k } @renderers)
    }
  });
}

1;