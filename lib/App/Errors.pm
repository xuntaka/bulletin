package App::Errors;

use Mojo::Base -base;

sub add {
	my $self = shift;

	push @{$self->{'errors'}->{@_ > 1 ? shift : 'error'}},
		App::Errors::Error->new(
			@_ > 1 || ref $_[0] eq 'HASH' ? @_ : ('text' => $_[0])
		);
}

# Добавляет ошибки переданного Errors в текущий
sub merge {
	my $self = shift;
	my $errors = shift;
	return unless $errors->count;
	foreach ($errors->keys) {
		$self->add($_ => $errors->on($_));
	}
}

sub on {
	my $errors = shift->{'errors'} or return;
	
	foreach (@_) {
		my $v = $errors->{$_};
		return wantarray ? @$v : $v->[0] if $v;
	}
	return;
}

sub all {
	my $errors = shift->{'errors'} or return;
	return map { @$_ } values %$errors;
}

sub first_on {
	my $errors = shift->{'errors'} or return undef;
	
	foreach (@_) {
		my $v = $errors->{$_};
		return $v->[0] if $v;
	}
	return undef;
}

sub first {
	my $errors = shift->{'errors'} or return undef;
	
	foreach (sort keys %$errors) {
		my $v = $errors->{$_};
		return $v->[0] if $v;
	}
	return undef;
}

sub first_all {
	my $self = shift;
	
	+{
		map {
			$_ => $self->first_on($_)
		} sort keys %{$self->{'errors'} || {}}
	};
}

sub keys {
	my $errors = shift->{'errors'} or return;
	keys %$errors;
}

sub to_hash { shift->{'errors'} }
sub TO_JSON { shift->{'errors'} }
sub count { scalar shift->keys }
sub clean { delete shift->{'errors'} }
sub all_ref { [map { ''.$_ } shift->all] } # Массив строк

sub str_dump {
	my $self = shift;
	my $str = '';
	foreach my $k ($self->keys) {
		foreach ($self->on($k)) {
			$str .= "$k: $_\n";
		}
	}
	return $str;
}

1;
