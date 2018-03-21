package App::Controller::Main;

use Mojo::Base 'App::Controller';

sub pdf {
	my $self = shift;

	if (defined $self->param('download')) {
		$self->res->headers->content_disposition('attachment; filename="bulletin.pdf"');
	}

	return $self->render(
		'format'  => 'pdf',
		'handler' => 'pdf',
	);
}

1;
