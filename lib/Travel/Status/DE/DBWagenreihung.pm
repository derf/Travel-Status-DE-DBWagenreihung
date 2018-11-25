package Travel::Status::DE::DBWagenreihung;

use strict;
use warnings;
use 5.020;

our $VERSION = '0.00';

use Carp qw(cluck confess);
use JSON;
use LWP::UserAgent;
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
		api_base      => $opt{api_base}
		  // 'https://www.apps-bahn.de/wr/wagenreihung/1.0',
		developer_mode => $opt{developer_mode},
		cache => $opt{cache},
		departure       => $opt{departure},
		json => JSON->new,
		serializable    => $opt{serializable},
		train_number    => $opt{train_number},
		user_agent      => $opt{user_agent},
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

	my $api_base = $self->{api_base};
	my $cache = $self->{cache};
	my $train_number = $self->{train_number};

	my $datetime = $self->{departure};

	if (ref($datetime) eq 'DateTime') {
		$datetime = $datetime->strftime('%Y%m%d%H%M');
	}

	my ($content, $err) = $self->get_with_cache($cache, "${api_base}/${train_number}/${datetime}");

	if ($err) {
		$self->{errstr} = "Failed to fetch station data: $err";
		return;
	}
	my $json = $self->{json}->decode($content);
	if ($self->{developer_mode}) {
		say $self->{json}->pretty->encode($json);
	}

	if (exists $json->{error}) {
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

sub wagons {
	my ($self) = @_;

	if (exists $self->{wagons}) {
		return @{$self->{wagons}};
	}

	for my $group (@{$self->{data}{istformation}{allFahrzeuggruppe}}) {
		for my $wagon (@{$group->{allFahrzeug}}) {
			push(@{$self->{wagons}}, Travel::Status::DE::DBWagenreihung::Wagon->new(%{$wagon}));
		}
	}
	return @{$self->{wagons} // []};
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
