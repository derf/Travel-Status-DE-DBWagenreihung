package Travel::Status::DE::DBWagenreihung::Group;

use strict;
use warnings;
use 5.020;
use utf8;

use parent 'Class::Accessor';

our $VERSION = '0.13';

Travel::Status::DE::DBWagenreihung::Group->mk_ro_accessors(
	qw(id train_no type origin destination));

sub new {
	my ( $obj, %opt ) = @_;
	my $ref = \%opt;

	return bless( $ref, $obj );
}

sub set_traintype {
	my ( $self, $i, $tt ) = @_;
	$self->{type} = $tt;
	for my $wagon ( $self->wagons ) {
		$wagon->set_traintype( $i, $tt );
	}
}

sub sort_wagons {
	my ($self) = @_;

	@{ $self->{wagons} }
	  = sort { $a->{position}{start_percent} <=> $b->{position}{start_percent} }
	  @{ $self->{wagons} };
}

sub wagons {
	my ($self) = @_;

	return @{ $self->{wagons} // [] };
}

sub TO_JSON {
	my ($self) = @_;

	my %copy = %{$self};

	return {%copy};
}

1;
