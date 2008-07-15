package PciIds::Address::Base;
use strict;
use warnings;
use PciIds::Address;

sub new( $ ) {
	return bless {
		'value' => shift
	}
}

sub get( $ ) {
	return shift->{'value'};
}

sub parent( $ ) {
	my( $new ) = ( shift->get() );
	$new =~ s/[^\/]+\/?$//;
	return PciIds::Address::new( $new );
}

sub tail( $ ) {
	my( $new ) = ( shift->get() );
	$new =~ s/.*\/(.)/$1/;
	return $new;
}

sub canAddComment( $ ) {
	return 1; #By default, comments can be added anywhere
}

sub canAddItem( $ ) { return !shift->leaf(); }

sub defaultRestrict( $ ) { return "" };

sub defaultRestrictList( $ ) { return [] };

1;