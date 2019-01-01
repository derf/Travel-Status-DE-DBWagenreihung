package Travel::Status::DE::DBWagenreihung::Wagon;

use strict;
use warnings;
use 5.020;
use utf8;

use parent 'Class::Accessor';
use Carp qw(cluck);

our $VERSION = '0.00';

Travel::Status::DE::DBWagenreihung::Wagon->mk_ro_accessors(
	qw(attributes class_type has_ac has_accessibility has_bistro has_compartments
	  has_multipurpose is_dosto is_interregio is_locomotive is_powercar number
	  section type)
);

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

	my $self = bless( $ref, $obj );

	$self->parse_type;

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

	return $self;
}

sub attributes {
	my ($self) = @_;

	return @{ $self->{attributes} // [] };
}

sub parse_type {
	my ($self) = @_;

	my $type = $self->{type};
	my @desc;

# Thanks to <https://www.deutsche-reisezugwagen.de/lexikon/erklarung-der-gattungszeichen/>

	if ( $type =~ m{^D} ) {
		$self->{is_dosto} = 1;
		push( @desc, 'Doppelstock' );
	}

	if ( $type =~ m{b} ) {
		$self->{has_accessibility} = 1;
		push( @desc, 'Behindertengerechte Ausstattung' );
	}

	if ( $type =~ m{d} ) {
		$self->{has_multipurpose} = 1;
		push( @desc, 'Mehrzweckraum' );
	}

	if ( $type =~ m{f} ) {
		push( @desc, 'Steuerabteil' );
	}

	if ( $type =~ m{i} ) {
		$self->{is_interregio} = 1;
		push( @desc, 'Interregiowagen' );
	}

	if ( $type =~ m{m} ) {

		# ?
	}

	if ( $type =~ m{p} ) {
		$self->{has_ac} = 1;
		push( @desc, 'klimatisiert' );
		push( @desc, 'Großraum' );
	}

	if ( $type =~ m{v} ) {
		$self->{has_ac}           = 1;
		$self->{has_compartments} = 1;
		push( @desc, 'klimatisiert' );
		push( @desc, 'Abteilwagen' );
	}

	$self->{attributes} = \@desc;
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
