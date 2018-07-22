package App::Plugin::Pdf;

use Mojo::Base 'Mojolicious::Plugin';

use IPC::Open2;
use File::Temp ();

sub register {
	my ($self, $app) = @_;

	$app->renderer->add_handler(pdf => sub {
		my ($renderer, $c, $output, $options) = @_;

		my $fop = $options->{format} eq 'pdf';
		{
			local $options->{handler}; # ep
			local $options->{format} = 'fo' if $fop;

			$renderer->_render_template($c, $output, $options);
		}

		if ($fop) { # fo => pdf
			delete $options->{encoding};
			my $tmp = File::Temp->new(SUFFIX => '.pdf');

			my($chld_out, $chld_in);
			$app->log->info("Run fop");
			my $pid = open2($chld_out, $chld_in,
				$app->config->{path}{fop} || 'fop',
				'-c' => $app->config->{path}{conf}. '/fop.xml',
				'-fo' => '-',
				'-pdf' => $tmp->filename
			);
			print $chld_in Encode::encode('utf-8', $$output);
			close $chld_in;

			waitpid( $pid, 0 );
			my $child_exit_status = $? >> 8;
			$app->log->info("Stop fop: $child_exit_status");
			
			local $/;
			$$output = <$tmp>;
		}

		return 1;
	});
}

1;
