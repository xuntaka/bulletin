package App::Controller;

use Mojo::Base 'Mojolicious::Controller';

use JSON;
use Digest::MD5 qw(md5_hex);

has errors  => sub { App::Errors->new    };

my $json_handler = JSON->new->utf8->allow_nonref->convert_blessed->canonical;
my $json_handler_pretty = JSON->new->utf8->allow_nonref->convert_blessed->canonical->pretty;

sub is_post {
	my $self = shift;
	$self->req->method eq 'POST';
}

# Проверка параметра csrf_token == session('csrf_token')
sub is_protected {
	my $self = shift;
	my $csrf = $self->param('csrf_token');
	if (!$csrf && $self->req && $self->req->json) {
		$csrf = $self->req->json->{csrf_token};
	}
	return unless $csrf;
	return 1 if $csrf eq $self->csrf_token;
	warn "Bad CSRF code: $csrf != " . $self->csrf_token . "\n";
	return;
}

sub is_protected_post {
	my $self = shift;
	return $self->req->method eq 'POST' && $self->is_protected;
}

sub get_ip { # Может быть IPv6
  my $self = shift;
  $self->req->headers->header('X-Real-IP') ||
  $self->tx->{'remote_address'}            ||
  undef;
}

sub get_ua {
  my $self = shift;
  $self->req->headers->user_agent;
}

sub is_xhr {
	my $self = shift;
	my $format = $self->stash('format') || '';

	return 0 if $format eq 'html';
	return 1 if $format eq 'json';
	return 1 if $self->req->is_xhr;
	return 1 if ($self->req->headers->header('Content-Type') // '') =~ /json/i;
	return 1 if $self->req->json;
}

sub redirect_to_https {
	my $self = shift;
	my $url = $self->req->url->to_abs->userinfo(undef)->scheme('https');
	return $self->redirect_to($url)->render(text => "Redirecting to https", layout => undef);
}

sub forbidden {
	my $self    = shift;
	my $message = shift || '';
	my $caller  = join ':', (caller)[1,2];

	$message = $message ? 'forbidden: ' . $message : 'forbidden';

	$self->app->log->info($message . ' from ' . $caller);

	$message .= ' from ' . $caller
		if $self->is_dev;

	return $self->render_api('error', 'http_code' => 403, 'message' => $message, 'error' => $message)
		if $self->is_xhr;

	return $self->reply->forbidden(
		'message' => $message,
		'caller'  => $caller,
	);
}

sub not_found {
	my $self    = shift;
	my $message = shift || '';
	my $caller  = join ':', (caller)[1,2];

	$self->stash('message' => $message);
	$self->stash('caller'  => $caller );

	$message = $message ? 'not_found: ' . $message : 'not_found';

	$self->app->log->info($message . ' from ' . $caller);

	$message .= ' from ' . $caller
		if $self->is_dev;

	return $self->render_api('error', 'http_code' => 404, 'message' => $message, 'error' => $message)
		if $self->is_xhr;

	return $self->reply->not_found;
}

# Шорткаты для сообщений message_<type>[_html]
# type = 'success'|'warning'|'error' - тип блока
# _html - признак того, что в сообщении html и экспейпить не нужно
sub message_success      { $_[0]->flash('message' => ['success' => $_[0]->pre($_[1])]) }
sub message_success_html { $_[0]->flash('message' => ['success' => $_[1]            ]) }
sub message_info         { $_[0]->flash('message' => ['info'    => $_[0]->pre($_[1])]) }
sub message_info_html    { $_[0]->flash('message' => ['info'    => $_[1]            ]) }
sub message_warning      { $_[0]->flash('message' => ['warning' => $_[0]->pre($_[1])]) }
sub message_warning_html { $_[0]->flash('message' => ['warning' => $_[1]            ]) }
sub message_error        { $_[0]->flash('message' => ['error'   => $_[0]->pre(ref($_[1]) eq 'App::Errors::Error' ? $_[1]->text : $_[1])]) }
sub message_error_html   { $_[0]->flash('message' => ['error'   => ref($_[1]) eq 'App::Errors::Error' ? $_[1]->text : $_[1]]) }

sub _user_filters {
	my $self = shift;
	my @filters;
	foreach my $varname (@{$self->req->params}) {
		my $val = $self->param($varname);
		if (length($val) && $varname =~ /^filter_(.*?)(?:_(from|to))?$/) {
			my ($name, $cmp) = ($1, $2);
			$val =~ s/^(\d{1,2})\.(\d{1,2})\.(\d{4})/$3-$2-$1/;
			if ($cmp) {
				$cmp eq 'to' && $val =~ /^\d{4}-\d+-\d+$/ and $val .= ' 23:59:59';
				push @filters, $name => { $cmp eq 'from' ? '>=' : '<=' => $val };
			} else {
				push @filters, $name => $val;
			}
		}
	}
	return @filters;
}

sub render_file {
	my $self = shift;
	my %args = @_;
	my $filepath = $args{'filepath'};
	my $filedata = $args{'filedata'};
	
	unless ( $filedata || ( -f $filepath && -r $filepath ) ) {
		$self->app->log->error("No data to file and cannot read file [$filepath].");
		return;
	}
	
	my $filename = $args{'filename'} || fileparse($filepath);
	my $status   = $args{'status'}   || 200;
	
	my $headers = Mojo::Headers->new();
	$headers->add( 'Content-Type',        'application/x-download;name=' . $filename );
	$headers->add( 'Content-Disposition', 'attachment;filename=' . $filename );
	$self->res->content->headers($headers);
	
	my $file = Mojo::Asset::File->new;
	   $file = $file->path($filepath)      if ( $filepath && -f $filepath );
	   $file = $file->add_chunk($filedata) if ( $filedata );
	
	$self->res->content->asset( $file );
	
	return $self->rendered($status);
};

sub json_param {
	my ($self, $name, $errors) = @_;
	my $json = $self->param($name) or return;
	state $decoder = JSON->new->allow_nonref;
	my $v = eval { $decoder->decode($json) };
	if ($@) {
		$errors ||= App::Errors->new;
		$errors->add($name => $@);
	}
	return $v;
}

sub render_api {
	my ($self, $status, %data) = @_;

	my $pretty = $self->param('_pretty');
	my $http_code = delete $data{'http_code'} || 200;
	$data{'status'} = $status;
	delete $data{'object'} unless $data{'object'};

	if (my $errors = delete $data{'errors'} || $self->errors) {
		if (my $error = $errors->first) {
			# для совместимости со старыми форматами
			$data{'result'} = 'ERROR' if $data{'result'};

			$data{'status'} = 'error';
			$data{'error' } = $error->text;
			$data{'code'  } = $error->code if $error->code;
			$data{'errors'} = $errors->to_hash;
			$http_code    ||= $error->status if $error->status;
		}
	}

	my $json = ($pretty ? $json_handler_pretty : $json_handler)->encode(\%data);

	my $etag = '"'. md5_hex($json). '"';
	for ($self->res->headers) {
		$_->cache_control('private');
		$_->etag($etag);
		$_->content_type('application/json; charset=utf-8');
	}
	my $browser_etag = $self->req->headers->header('If-None-Match');
	if ($browser_etag && $browser_etag eq $etag) {
		#$self->res->code(304);
		$self->res->body('');
		$self->rendered(304);
		return;
	}

	$self->render(
		'data' => $json,
		($http_code ? ('status' => $http_code) : ()),
	);
}

# вырезает базовую аутентификацию
sub url_to_abs { $_[0]->req->url->to_abs->userinfo(undef) };

# https://github.com/mailru/FileAPI/blob/master/server/FileAPI.class.php#L109
sub render_fileapi {
	my ($self, $hashref) = @_;
	my $json = $json_handler->encode($hashref);
	my $httpStatus = 200;
	my $httpStatusText = 'OK';
	my $jsonp = $self->param('callback');
	$jsonp =~ s/\s+//;

	if (!$jsonp) {
		return $self->render(
			data => $json,
			format => ($self->req->headers->accept =~ m{application/json} || ($self->stash('format') || '') eq 'json' ? 'json' : 'html'),
		);
	} else {
		# https://github.com/mailru/FileAPI/#iframejsonp
		$json =~ s/([\\'"])/\\$1/g;
		return $self->render(
			format => 'html',
			data => <<END,
<script>
(function (ctx, jsonp){
	'use strict';
	var status = $httpStatus, statusText = "$httpStatusText", response = "$json";
	try {
		ctx[jsonp](status, statusText, response);
	} catch (e){
		var data = "{\\"id\\":\\"$jsonp\\",\\"status\\":"+status+",\\"statusText\\":\\""+statusText+"\\",\\"response\\":\\""+response.replace(/\\"/g, '\\\\\\"')+"\\"}";
		console.log(data);
		try {
			ctx.postMessage(data, document.referrer);
		} catch (e){}
	}
})(window.parent, '$jsonp');
</script>
END
		);
	}
}

1;
