package PciIds::Address::Pci;
use strict;
use warnings;
use PciIds::Address::Toplevel;
use base 'PciIds::Address::Base';

sub new( $ ) {
	my( $address ) = @_;
	return PciIds::Address::Toplevel::new( $address ) if( $address =~ /^PC\/?$/ );
	return bless PciIds::Address::Base::new( $address );
}

sub pretty( $ ) {
	my $self = shift;
	$_ = $self->get();
	s/^PC\/?//;
	s/\//:/g;
	s/([0-9a-f]{4,4})([0-9a-f]{4,4})/$1 $2/g;
	my $prefix = '';
	if( /:.*:/ ) {
		$prefix = 'Subsystem';
	} elsif( /:/ ) {
		$prefix = 'Device';
	} else {
		$prefix = 'Vendor';
	}
	return $prefix.' '. $_;
}

sub tail( $ ) {
	my( $new ) = ( shift->get() );
	$new =~ s/.*\/(.)/$1/;
	$new =~ s/([0-9a-f]{4,4})([0-9a-f]{4,4})/$1 $2/g;
	return $new;
}

sub restrictRex( $$ ) {
	my( $self, $restrict ) = @_;
	my( $result ) = ( $restrict =~ /^([a-f0-9]{1,4})/ );#TODO every time?
	return $result;
}

sub leaf( $ ) {
	return ( shift->get() =~ /\/.*\/.*\// );
}

sub append( $$ ) {
	my( $self, $suffix ) = @_;
	return ( undef, 'You can not add to leaf node' ) if( $self->leaf() );
	$suffix =~ s/ //g;
	return ( undef, "Invalid ID syntax" ) unless ( ( ( $self->get() !~ /^PC\/.*\// ) && ( $suffix =~ /^[0-9a-f]{4}$/ ) ) || ( ( $self->get() =~ /^PC\/.*\// ) && ( $suffix =~ /^[0-9a-f]{8}$/ ) ) );
	return ( PciIds::Address::Base::new( $self->{'value'} . ( ( $self->{'value'} =~ /\/$/ ) ? '' : '/' ) . $suffix ), undef );
}

1;