package App::Router;

use Mojo::Base 'Mojolicious::Plugin';

sub register {
	my ($self, $app) = @_;

	my $r = $app->routes;
		 $r->namespaces(['App::Controller']);

	$r->route('/')->to('main#pdf')->name('main');
}

1;
