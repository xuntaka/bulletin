#!/usr/bin/perl -w

use v5.18;
use utf8;

use FindBin;
use lib "$FindBin::Bin/../lib",
        "$FindBin::Bin/../extlib";
use local::lib "$FindBin::Bin/../local";

use Cwd;
use Carp;
use FindBin;
use Mojo::File;
use File::Path qw/make_path/;
use Mojo::Util qw/decode encode/;
use Mojolicious 6.55;
use Mojolicious::Plugin::Config;

use Data::Dumper;
$Data::Dumper::Indent = 1;

$SIG{__WARN__} = \&Carp::cluck;
$SIG{__DIE__ } = \&Carp::confess;

# warn Dumper \%ENV;

sub run {
	my $home = Mojo::Home->new(shift);

	my $config = Mojolicious::Plugin::Config->parse(
		decode('UTF-8', Mojo::File->new($ENV{'LOCAL_CONF'})->slurp)
	);

	my $ver = $ENV{'REVISION'} || '';
	   $ver =~ s/(\S{7}).*/$1/s;

	$config->{'release_version'} = $ver || time();

	say "Release: $config->{'release_version'}";

	my $mt = Mojo::Template->new->vars(1);

	my $protos_path = $home->path($ENV{'PROTOS'});
	foreach my $file ($protos_path->list_tree->each) {
		my $tmpl_fn = $file->to_rel($protos_path);

		next unless $tmpl_fn =~ /\.ep$/;

		my $fn = $tmpl_fn =~ s{\.ep$}{}r;

		say "Make $fn";

		my $output = $mt->render_file($file, {
			'config'   => $config,
			'approot'  => $home->to_string,
			'userhome' => $ENV{'HOME'}
		});

		my $f_out = $home->rel_file("/$fn");
		my $dir   = $f_out =~ s{/[^/]*$}{}r;
		make_path($dir, {'verbose' => 1});
		Mojo::File->new($f_out)->spurt(encode('UTF-8', $output));
		`chmod +x $f_out` if -x $file;
	}
}

my $approot = Cwd::abs_path($ENV{'CURDIR'} || "$FindBin::Bin/../");

run($approot);
