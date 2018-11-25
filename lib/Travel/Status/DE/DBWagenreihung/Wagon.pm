package Travel::Status::DE::DBWagenreihung::Wagon;

use strict;
use warnings;
use 5.020;
use utf8;

use parent 'Class::Accessor';
use Carp qw(cluck);

our $VERSION = '1.21';

Travel::Status::DE::DBWagenreihung::Wagon->mk_ro_accessors(
	qw(number section)
);

sub new {
	my ( $obj, %opt ) = @_;
	my $ref = \%opt;

	$ref->{number} = $ref->{wagenordnungsnummer};
	$ref->{section} = $ref->{fahrzeugsektor};

	return bless( $ref, $obj );
}

sub sections {
	my ($self) = @_;

	return @{$self->{sections}};
}

sub TO_JSON {
	my ($self) = @_;

	my %copy = %{$self};

	return {%copy};
}

1;
