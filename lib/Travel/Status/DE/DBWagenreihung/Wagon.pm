package Travel::Status::DE::DBWagenreihung::Wagon;

use strict;
use warnings;
use 5.020;
use utf8;

use parent 'Class::Accessor';
use Carp qw(cluck);

our $VERSION = '0.00';

Travel::Status::DE::DBWagenreihung::Wagon->mk_ro_accessors(
	qw(class_type has_bistro is_locomotive is_powercar number section));

sub new {
	my ( $obj, %opt ) = @_;
	my $ref = {};

	$ref->{class_type}    = 0;
	$ref->{has_bistro}    = 0;
	$ref->{is_locomotive} = 0;
	$ref->{is_powercar}   = 0;
	$ref->{number}        = $opt{wagenordnungsnummer};
	$ref->{section}       = $opt{fahrzeugsektor};
	$ref->{type}          = $opt{fahrzeugtyp};

	if ( $opt{kategorie} =~ m{SPEISEWAGEN} ) {
		$ref->{has_bistro} = 1;
	}
	elsif ( $opt{kategorie} eq 'LOK' ) {
		$ref->{is_locomotive} = 1;
	}
	elsif ( $opt{kategorie} eq 'TRIEBKOPF' ) {
		$ref->{is_powercar} = 1;
	}

	if ( $opt{fahrzeugtyp} =~ m{AB} ) {
		$ref->{class_type} = 12;
	}
	elsif ( $opt{fahrzeugtyp} =~ m{A} ) {
		$ref->{class_type} = 1;
	}
	elsif ( $opt{fahrzeugtyp} =~ m{B|WR} ) {
		$ref->{class_type} = 2;
	}

	my $pos = $opt{positionamhalt};

	$ref->{position}{start_percent} = $pos->{startprozent};
	$ref->{position}{end_percent}   = $pos->{endeprozent};
	$ref->{position}{start_meters}  = $pos->{startmeter};
	$ref->{position}{end_meters}    = $pos->{endemeter};

	return bless( $ref, $obj );
}

sub is_first_class {
	my ($self) = @_;

	if ( $self->{type} =~ m{^A} ) {
		return 1;
	}
	return 0;
}

sub is_second_class {
	my ($self) = @_;

	if ( $self->{type} =~ m{^A?B} ) {
		return 1;
	}
	return 0;
}

sub sections {
	my ($self) = @_;

	return @{ $self->{sections} };
}

sub TO_JSON {
	my ($self) = @_;

	my %copy = %{$self};

	return {%copy};
}

1;
