package Travel::Status::DE::DBWagenreihung::Wagon;

use strict;
use warnings;
use 5.020;
use utf8;

use parent 'Class::Accessor';
use Carp qw(cluck);

our $VERSION = '0.00';

Travel::Status::DE::DBWagenreihung::Wagon->mk_ro_accessors(
	qw(class_type has_bistro number section)
);

sub new {
	my ( $obj, %opt ) = @_;
	my $ref = \%opt;

	$ref->{class_type} = 0;
	$ref->{has_bistro} = 0;
	$ref->{number} = $ref->{wagenordnungsnummer};
	$ref->{section} = $ref->{fahrzeugsektor};

	if ($ref->{kategorie} =~ m{SPEISEWAGEN}) {
		$ref->{has_bistro} = 1;
	}

	if ($ref->{fahrzeugtyp} =~ m{^AB}) {
		$ref->{class_type} = 12;
	}
	elsif ($ref->{fahrzeugtyp} =~ m{^A}) {
		$ref->{class_type} = 1;
	}
	elsif ($ref->{fahrzeugtyp} =~ m{^B|^WR}) {
		$ref->{class_type} = 2;
	}

	return bless( $ref, $obj );
}

sub is_first_class {
	my ($self) = @_;

	if ($self->{fahrzeugtyp} =~ m{^A}) {
		return 1;
	}
	return 0;
}

sub is_second_class {
	my ($self) = @_;

	if ($self->{fahrzeugtyp} =~ m{^A?B}) {
		return 1;
	}
	return 0;
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
