package App::Controller::Main;

use Mojo::Base 'App::Controller';

sub main {
	my $self = shift;

	return $self->render();
}

1;
