package Travel::Status::DE::DBWagenreihung;

use strict;
use warnings;
use 5.020;

our $VERSION = '0.00';

use Carp qw(cluck confess);
use JSON;
use LWP::UserAgent;
use Travel::Status::DE::DBWagenreihung::Section;
use Travel::Status::DE::DBWagenreihung::Wagon;

sub new {
	my ( $class, %opt ) = @_;

	if ( not $opt{train_number} ) {
		confess('train_number option must be set');
	}

	if ( not $opt{departure} ) {
		confess('departure option must be set');
	}

	my $self = {
		api_base => $opt{api_base}
		  // 'https://www.apps-bahn.de/wr/wagenreihung/1.0',
		developer_mode => $opt{developer_mode},
		cache          => $opt{cache},
		departure      => $opt{departure},
		json           => JSON->new,
		serializable   => $opt{serializable},
		train_number   => $opt{train_number},
		user_agent     => $opt{user_agent},
	};

	bless( $self, $class );

	if ( not $self->{user_agent} ) {
		my %lwp_options = %{ $opt{lwp_options} // { timeout => 10 } };
		$self->{user_agent} = LWP::UserAgent->new(%lwp_options);
		$self->{user_agent}->env_proxy;
	}

	$self->get_wagonorder;

	return $self;
}

sub get_wagonorder {
	my ($self) = @_;

	my $api_base     = $self->{api_base};
	my $cache        = $self->{cache};
	my $train_number = $self->{train_number};

	my $datetime = $self->{departure};

	if ( ref($datetime) eq 'DateTime' ) {
		$datetime = $datetime->strftime('%Y%m%d%H%M');
	}

	my ( $content, $err )
	  = $self->get_with_cache( $cache,
		"${api_base}/${train_number}/${datetime}" );

	if ($err) {
		$self->{errstr} = "Failed to fetch station data: $err";
		return;
	}
	my $json = $self->{json}->decode($content);

	if ( exists $json->{error} ) {
		$self->{errstr} = 'Backend error: ' . $json->{error}{msg};
		return;
	}

	$self->{data} = $json->{data};
	$self->{meta} = $json->{meta};
}

sub error {
	my ($self) = @_;

	return $self->{errstr};
}

sub direction {
	my ($self) = @_;

	return $self->{direction};
}

sub platform {
	my ($self) = @_;

	return $self->{data}{istformation}{halt}{gleisbezeichnung};
}

sub sections {
	my ($self) = @_;

	if ( exists $self->{sections} ) {
		return @{ $self->{sections} };
	}

	for my $section ( @{ $self->{data}{istformation}{halt}{allSektor} } ) {
		my $pos = $section->{positionamgleis};
		if ( $pos->{startprozent} eq '' or $pos->{endeprozent} eq '' ) {
			next;
		}
		push(
			@{ $self->{sections} },
			Travel::Status::DE::DBWagenreihung::Section->new(
				name          => $section->{sektorbezeichnung},
				start_percent => $pos->{startprozent},
				end_percent   => $pos->{endeprozent},
				start_meters  => $pos->{startmeter},
				end_meters    => $pos->{endemeter},
			)
		);
	}

	return @{ $self->{sections} // [] };
}

sub station_ds100 {
	my ($self) = @_;

	return $self->{data}{istformation}{halt}{rl100};
}

sub station_name {
	my ($self) = @_;

	return $self->{data}{istformation}{halt}{bahnhofsname};
}

sub station_uic {
	my ($self) = @_;

	return $self->{data}{istformation}{halt}{evanummer};
}

sub train_type {
	my ($self) = @_;

	return $self->{data}{istformation}{zuggattung};
}

sub train_no {
	my ($self) = @_;

	return $self->{data}{istformation}{zugnummer};
}

sub train_subtype {
	my ($self) = @_;

	my @wagons = $self->wagons;

	my %ml = (
		'ICE 1'     => 0,
		'ICE 2'     => 0,
		'ICE 3'     => 0,
		'ICE 3 V'   => 0,
		'ICE 4'     => 0,
		'ICE T 411' => 0,
		'ICE T 415' => 0,
		'IC2'       => 0,
	);

	for my $wagon (@wagons) {
		if ( $wagon->model == 401
			or ( $wagon->model >= 801 and $wagon->model <= 804 ) )
		{
			$ml{'ICE 1'}++;
		}
		elsif ( $wagon->model == 402
			or ( $wagon->model >= 805 and $wagon->model <= 808 ) )
		{
			$ml{'ICE 2'}++;
		}
		elsif ( $wagon->model == 403 or $wagon->model == 406 ) {
			$ml{'ICE 3'}++;
		}
		elsif ( $wagon->model == 407 ) {
			$ml{'ICE 3 V'}++;
		}
		elsif ( $wagon->model == 412 or $wagon->model == 812 ) {
			$ml{'ICE 4'}++;
		}
		elsif ( $wagon->model == 411 ) {
			$ml{'ICE T 411'}++;
		}
		elsif ( $wagon->model == 415 ) {
			$ml{'ICE T 415'}++;
		}
		elsif ( $wagon->is_dosto ) {
			$ml{'IC2'}++;
		}
	}

	my @likelihood = reverse sort { $ml{$a} <=> $ml{$b} } keys %ml;

	if ( $ml{ $likelihood[0] } <= 2 ) {

		# inconclusive
		return '???';
	}

	return $likelihood[0];
}

sub wagons {
	my ($self) = @_;

	if ( exists $self->{wagons} ) {
		return @{ $self->{wagons} };
	}

	for my $group ( @{ $self->{data}{istformation}{allFahrzeuggruppe} } ) {
		for my $wagon ( @{ $group->{allFahrzeug} } ) {
			push(
				@{ $self->{wagons} },
				Travel::Status::DE::DBWagenreihung::Wagon->new( %{$wagon} )
			);
		}
	}
	if ( @{ $self->{wagons} } > 1 ) {
		if ( $self->{wagons}[0]->{position}{start_percent}
			> $self->{wagons}[-1]->{position}{start_percent} )
		{
			$self->{direction} = 100;
		}
		else {
			$self->{direction} = 0;
		}
	}
	@{ $self->{wagons} } = sort {
		$a->{position}->{start_percent} <=> $b->{position}->{start_percent}
	} @{ $self->{wagons} };
	return @{ $self->{wagons} // [] };
}

sub get_with_cache {
	my ( $self, $cache, $url ) = @_;

	if ( $self->{developer_mode} ) {
		say "GET $url";
	}

	if ($cache) {
		my $content = $cache->thaw($url);
		if ($content) {
			if ( $self->{developer_mode} ) {
				say '  cache hit';
			}
			return ( ${$content}, undef );
		}
	}

	if ( $self->{developer_mode} ) {
		say '  cache miss';
	}

	my $ua  = $self->{user_agent};
	my $res = $ua->get($url);

	if ( $res->is_error ) {
		return ( undef, $res->status_line );
	}
	my $content = $res->decoded_content;

	if ($cache) {
		$cache->freeze( $url, \$content );
	}

	return ( $content, undef );
}

1;
