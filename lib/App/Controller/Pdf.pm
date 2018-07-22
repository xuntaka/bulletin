package App::Controller::Pdf;

use Mojo::Base 'App::Controller';
use Mojo::File;
use Mojo::Util qw/decode encode/;

sub R {
	my $R = shift;

	my $res = {
		'type'     => ($R->[1] =~ /мм/ || $R->[7] < 12 ? 'машиноместо' : 'квартира'),
		'area'     => 0 + $R->[7] =~ s/,/./r, #/
		'doc_type' => (length($R->[13]) > 16 ? 'Запись в ЕГРП' : $R->[12]),
		'doc_num'  => $R->[13],
		'doc_date' => $R->[14],
		'address'  => $R->[1] =~ s/ мм$//r, #/
	};

	return $res;
}

sub pdf {
	my $self = shift;

	my $house = $self->param('house');
	$house = 17 unless $house =~ /^(?:16|17|18)$/;

	my $flats = {map {$_ => 1} split ',', $self->param('flats')};

	if (defined $self->param('download')) {
		$self->res->headers->content_disposition('attachment; filename="bulletin_' . $house . ($self->param('flats') ? '_' . $self->param('flats') : '') . '.pdf"');
	}

	my $file = [ split /\n/, decode('UTF-8', Mojo::File->new('reestr/' . $house . '.r.csv')->slurp)];
	my $record_raw = {};

	foreach (@$file) {
		next unless /^\d/;
		my $R = [split /\t/];

		next unless $R->[1] =~ /^\d/;
		next unless $R->[4] eq 'частное лицо';
		# next unless $R->[3] eq 'Совместная собственность';

		push @{$record_raw->{$R->[2]}}, R($R);
	}

	# my $records = [];

	foreach (keys %$record_raw) {
		next unless /;/;

		# Совместная собственность
		my @names = split /\s*;\s*/;
		my @rr = @{delete $record_raw->{$_}};

		$_->{'area'} /= @names foreach @rr;

		foreach (@names) {
			# push @$records, {'name' => $_, 'data' => \@rr};
			push @{$record_raw->{$_}}, @rr;
		}
	}

	my $records = [
		sort {$a->{'data'}->[0]->{'address'} <=> $b->{'data'}->[0]->{'address'}}
		grep {!%$flats ? 1 : $flats->{$_->{'data'}->[0]->{'address'}}}
		map {
			{
				'name' => $_,
				'data' => [
					sort {$a->{'type'} cmp $b->{'type'}}
					@{$record_raw->{$_}}
				]
			}
		}
		keys %$record_raw
	];

	return $self->render(
		'format'  => 'pdf',
		'handler' => 'pdf',
		'house'   => $house,
		# 'records' => [grep {$_->{'name'} =~ /^Саф/} @$records],
		'records' => $records,
	);
}

1;
