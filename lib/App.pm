package App;

use utf8;
use v5.18;

use Mojo::Base 'Mojolicious';

use Carp qw(confess croak longmess);

use Mojo::Loader qw[find_modules load_class];
use Mojo::ByteStream;
use Mojo::Util qw(camelize decamelize);

use JSON;
use Data::Dumper;
use FindBin;
use App::Controller;

{
	$Data::Dumper::Indent = 1; $Data::Dumper::Useqq = 1;
	no strict 'refs'; no warnings 'redefine';
	*{'Data::Dumper::qquote'} = sub {qq{"$_[0]"}}; # вывод русского текста
}

our $VERSION = '10.3';

=encoding utf8

=cut

has is_cli  => undef; # detect CLI
has request_cache => sub { +{} };

has 'ua_name' => 'Mozilla/5.0 (compatible; BulletinBot; +http://bulletin.mvl.space/)';

sub ua {
	my $self = shift;
	# 'ua' - глобальный. Переопределение параметров ua влияют на всех
	my $ua = $self->SUPER::ua(@_);
	$ua->transactor->name($self->ua_name);
	return $ua;
};

sub is_dev { shift->mode eq 'development' }

# This method will run once at server start
sub startup {
	my $self = shift;

	$self->plugin('Config', 'file' => $self->home->rel_file('conf/app.conf'));

	$self->set_mode;
	$self->set_logs;

	$self->sessions->cookie_name  ($self->config->{'cookie'}->{'name'  });
	$self->sessions->cookie_domain($self->config->{'cookie'}->{'domain'});

	$self->secrets(['Q8qnavDE6xaTTyvP8YfZ8kMQ']);

	$self->types->type('json' => 'application/json; charset=utf-8');
	$self->types->type('xml'  => 'text/xml; charset=utf-8');
	$self->types->type('fo'   => 'text/xml; charset=utf-8');
	$self->types->type('pdf'  => 'application/pdf');

	my $https_conf = $self->config->{'https'};
		 $https_conf = { on => $https_conf } unless ref $https_conf;

	$self->plugin('App::Plugin::Pdf');

	$self->controller_class('App::Controller');

	$self->plugin('App::Router');

	$self->_load_modules;

	$self->_hooks;

	$self->log->info('Started in ' . $self->mode . ' mode.');

	no warnings 'once';
	$::app = $self; # App не имеет глобального акцессора, и к нему нельзя получить доступ даже из модели :( Поэтому так
}

sub set_mode {
	my $self = shift;
	my $mode = shift || $self->config->{'mode'};

	$self->mode($mode) if $mode && $mode ne $self->mode; # Если режим из конфига не совпадает с режимом, в котором запустились, то переключаемся.
}

=head2 set_logs

Всё, что связано с настройкой логов

=cut

sub set_logs {
	my $self = shift;
	my $name = $self->mode;
	my $home = $self->home;

	if ($self->is_cli) {
		($name) = $0 =~ m{(?:.*/)?(.+)\.pl$};
	}

	if ($name && -w $home->rel_file('log')) {
		$self->log(
			Mojo::Log->new(
				'path' => $home->rel_file("log/$name.log"),
			)
		);
	}

	$self->log->level('info') unless $self->is_dev;
}

sub _load_modules {
	my $self = shift;

	load_class('Data::Page');

	$self->_load_models($_) foreach qw[
		App::Errors
	];
}

sub _load_models { #recursion
	my $self = shift;
	my $model = shift or return;

	my $e = load_class($model); return if ref $e;
	foreach (find_modules($model)) {
		my $e = load_class($_); next if ref $e;
		$self->_load_models($_);
	}
}

sub _hooks {
	my $app = shift;

	#referral
	$app->hook('before_dispatch' => sub { $app->sessions->secure(1) });
	$app->hook('after_dispatch'  => sub { $app->request_cache({}) }); # flush req. cache
}

1;
