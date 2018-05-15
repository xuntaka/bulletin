package App::Router;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
	my ($self, $app) = @_;

	my $r = $app->routes;
		 $r->namespaces(['App::Controller']);

  $r->route('/')->to('main#main')->name('main');
	$r->route('/dl')->to('pdf#pdf')->name('pdf');
}

1;
