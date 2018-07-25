package App::Controller::Pdf;

use Mojo::Base 'App::Controller';
use Mojo::File;
use Mojo::Util qw/decode encode/;

use Data::Dumper;

sub parse_klenovaya {
	my $records = shift;
	my $flats   = shift;

	sub RK {
		my $R = shift;
# № Кв/ мм	Этаж	Тип объекта	ФИО	Телефон	E-mail	Площадь квартиры	Кол-во долей	Всего долей	Голосов	Процент голосов	№ Свидетельства о госрегистрации (или ДДУ + акт ПП)	Дата регистрации	Член ТСЖ	Процентов голосов члена ТСЖ
# [Tue Jul 24 11:24:04 2018] [error] $VAR1 = [
#   1,
#   2,
#   "Квартира",
#   "Селиверстова Оксана Анатольевна",
#   "",
#   "",
#   "106,9", 6
#   1,
#   1,
#   "#ИМЯ?",
#   "#ИМЯ?",
#   "№ 50:11:0020306:5284-50/011/2017-1", 11
#   "14.09.2017",
#   "*",
#   "#ИМЯ?"
# ];

		my $res = {
			'type'     => lc $R->[2],
			'area'     => 0 + $R->[6] =~ s/,/./r, #/
			'doc_type' => ($R->[11] =~ /^№/ ? '№ Свидетельства о госрегистрации' : 'ДДУ + акт ПП'),
			'doc_num'  => $R->[11] =~ s/^№ //r, #/
			'doc_date' => $R->[12],
			'address'  => $R->[0] =~ s/^мм //r, #/
		};

		return $res;
	}

	my $record_raw = {};

	foreach (@$records) {
		next if /^\t/;
		my $R = [split /\t/];

		# next unless $R->[1] =~ /^\d/;
		# next unless $R->[4] eq 'частное лицо';
		next unless $R->[3];
		next if $R->[3] =~ /^"/;

		push @{$record_raw->{$R->[3]}}, RK($R);
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

	return $records;
}

sub parse_lesnaya {
	my $records = shift;
	my $flats   = shift;

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

	my $record_raw = {};

	foreach (@$records) {
		next unless /^\d/;
		my $R = [split /\t/];

		next unless $R->[1] =~ /^\d/;
		next unless $R->[4] eq 'частное лицо';
		# next unless $R->[3] eq 'Совместная собственность';

		push @{$record_raw->{$R->[2]}}, R($R);
	}

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

	return $records;
}

sub pdf {
	my $self = shift;

	my $house = $self->param('house');
	$house = 17 unless $house =~ /^(?:3|16|17|18)$/;

	my $flats = {map {$_ => 1} split ',', $self->param('flats')};

	if (defined $self->param('download')) {
		$self->res->headers->content_disposition('attachment; filename="bulletin_' . $house . ($self->param('flats') ? '_' . $self->param('flats') : '') . '.pdf"');
	}

	my $file = [ split /\n/, decode('UTF-8', Mojo::File->new('reestr/' . $house . '.r.csv')->slurp)];

	my $records;
	my $template = 'pdf/pdf';
	if ($house =~ /^(?:16|17|18)$/) {
		$records = parse_lesnaya($file, $flats);
	}
	else {
		$template = 'pdf/klenovaya/pdf';
		$records = parse_klenovaya($file, $flats);
	}

	return $self->render(
		'template' => $template,
		'format'   => 'pdf',
		'handler'  => 'pdf',
		'house'    => $house,
		# 'records' => [grep {$_->{'name'} =~ /^Саф/} @$records],
		'records'  => $records || [],
	);
}

1;
