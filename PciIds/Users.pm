package PciIds::Users;
use strict;
use warnings;
use base 'Exporter';
use PciIds::Db;
use DBI;
use PciIds::Config;
use Digest::MD5 qw(md5_base64 md5_hex);#TODO Some better algorithm?
use HTML::Entities;
use PciIds::Startup;
use PciIds::Log;
use Apache2::Connection;

my( %privnames, %privnums );

our @EXPORT = qw(&addUser &emailConfirm &checkConfirmHash &saltedPasswd &genAuthToken &checkAuthToken &hasRight &getRightDefs &genResetHash &changePasswd &pushProfile);

sub saltedPasswd( $$ ) {
	my( $email, $passwd ) = @_;
	my $salt = $config{'passwdsalt'};
	return md5_base64( "$email:$passwd:$salt" );
}

sub genResetHash( $$$$ ) {
	my( $id, $email, $login, $passwd ) = @_;
	my $salt = $config{'regmailsalt'};
	return md5_hex( "$id:$email:$login:$passwd:$salt" );
}

sub emailConfirm( $ ) {
	my( $email ) = @_;
	my $salt = $config{'regmailsalt'};
	return md5_hex( $email.$salt );
}

sub checkConfirmHash( $$ ) {
	my( $email, $hash ) = @_;
	return 0 unless( ( defined $email ) && ( defined $hash ) );
	my( $expected ) = emailConfirm( $email );
	return ( $expected eq $hash );
}

sub addUser( $$$$ ) {
	my( $tables, $name, $email, $passwd ) = @_;
	my $salted = saltedPasswd( $email, $passwd );
	tlog( "Creating user $email" . ( ( defined $name ) ? " - $name" : '' ) );
	my $id = $tables->addUser( $name, $email, $salted );
	tlog( "User ($email) id: $id" );
	return $id;
}

sub changePasswd( $$$$ ) {
	my( $tables, $id, $passwd, $email ) = @_;
	my $salted = saltedPasswd( $email, $passwd );
	$tables->changePasswd( $id, $salted );
}

sub genAuthToken( $$$$ ) {
	my( $tables, $id, $req, $rights ) = @_;
	unless( defined $rights ) {#Just logged in
		my $from = $req->connection()->remote_ip();
		$tables->setLastLog( $id, $from );
		$rights = $tables->rights( $id );
	}
	my $haveRights = scalar @{$rights};
	my $time = time;
	my $ip = $req->connection()->remote_ip();
	return "$id:$haveRights:$time:".md5_hex( "$id:$time:$ip:".$config{'authsalt'} );
}

sub checkAuthToken( $$$ ) {
	my( $tables, $req, $token ) = @_;
	my( $id, $haveRights, $time, $hex ) = defined( $token ) ? split( /:/, $token ) : ();
	return ( 0, 0, 0, [], "Not logged in" ) unless( defined $hex );
	my $ip = $req->connection()->remote_ip();
	my $expected = md5_hex( "$id:$time:$ip:".$config{'authsalt'} );
	my $actTime = time;
	my $tokOk = ( $expected eq $hex );
	my $authed = ( $tokOk && ( $time + $config{'authtime'} > $actTime ) );
	my $regen = $authed && ( $time + $config{'regenauthtime'} < $actTime );
	my $rights = [];
	if( $haveRights ) {
		foreach( @{$tables->rights( $id )} ) {
			my %r;
			( $r{'id'} ) = @{$_};
			$r{'name'} = $privnames{$r{'id'}};
			push @{$rights}, \%r;
		}
	}
	return ( $authed, $id, $regen, $rights, $authed ? undef : ( $tokOk ? "Login timed out" : "Not logged in x" ) );
}

sub hasRight( $$ ) {
	my( $rights, $name ) = @_;
	foreach( @{$rights} ) {
		return 1 if( $_->{'name'} eq $name );
	}
	return 0;
}

sub getRightDefs() {
	return ( \%privnums, \%privnames );
}

sub pushProfile( $$$$ ) {
	my( $tables, $id, $oldData, $data ) = @_;
	my( $email, $passwd ) = ( $data->{'email'}, $data->{'current_password'} );
	if( ( defined $passwd ) && ( $passwd ne '' ) ) {
		my $salted = saltedPasswd( $email, $passwd );
		$tables->setEmail( $id, $email, $salted );
	}
	$data->{'login'} = undef if ( defined $data->{'login'} ) && ( $data->{'login'} eq '' );
	$data->{'xmpp'} = undef if ( defined $data->{'xmpp'} ) && ( $data->{'xmpp'} eq '' );
	$tables->pushProfile( $id, $data->{'login'}, $data->{'xmpp'}, $data->{'email_time'}, $data->{'xmpp_time'} );
	changePasswd( $tables, $id, $data->{'password'}, $email ) if ( defined $data->{'password'} ) && ( $data->{'password'} ne '' );
}

checkConf( [ 'passwdsalt', 'regmailsalt', 'authsalt' ] );
defConf( { 'authtime' => 2100, 'regenauthtime' => 300 } );

open PRIVS, $directory."/rights" or die "Could not open privilege definitions\n";
foreach( <PRIVS> ) {
	my( $num, $name ) = /^(\d+)\s+(.*)$/ or die "Invalid syntax in privileges\n";
	$privnames{$num} = $name;
	$privnums{$name} = $num;
}
close PRIVS;

1;
