package Net::CampaignMonitor;

use strict;

use 5.008005;
use REST::Client;
use Params::Util qw{_STRING _NONNEGINT _POSINT _HASH _HASHLIKE};
use JSON;

use version; our $VERSION = version->declare("v1.20.1");

sub new	{
		
	my ($class, $args) = @_;
	my $self = bless($args, $class);
	$self->{format} = 'json';
	
	if ( $self->{secure} == 1) {
		$self->{netloc}   = 'api.createsend.com:443';
		$self->{realm}    = 'api.createsend.com';
		$self->{protocol} = 'https://';
	}
	elsif ( $self->{secure} == 0) {
		$self->{netloc}   = 'api.createsend.com:80';
		$self->{realm}    = 'api.createsend.com';
		$self->{protocol} = 'http://';
	}
	else {
		$self->{netloc}   = 'api.createsend.com:443';
		$self->{realm}    = 'api.createsend.com';
		$self->{protocol} = 'https://';
	}
	
	unless( Params::Util::_POSINT($self->{timeout}) ) {
		$self->{timeout} = 600;
	}
		
	if ( (exists $self->{api_key} ) && !( Params::Util::_STRING( $self->{api_key} )) ) {
		Carp::croak("Missing or invalid api key");
	}
	
	if ( exists $self->{api_key} ) {
	
		#create and initialise the rest client
		$self->{client} = $self->create_rest_client();
		$self->account_systemdate();
		
		return $self;
	}
	else {
		return $self;
	}
}

sub create_rest_client {
	
	my ($self) = @_;
	
	my $client = REST::Client->new();
	$client->getUseragent->credentials($self->{netloc}, $self->{realm}, $self->{api_key}, "");
	$client->setFollow(1);
	$client->setTimeout($self->{timeout});
	return $client;
}

sub decode {
	my $self = shift;
	my $json = JSON->new->allow_nonref;
	
	if ( length $_[0] == 0 ) {
		return {};
	}
	else {
		return $json->decode( $_[0] );
	}
}

sub account_systemdate {
	
	my ($self) = @_;
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/systemdate.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub account_clients {

	if (scalar(@_) == 1) { #get the list of clients
		my ($self) = @_;
		my $results;
		$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients.".$self->{format});
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
	else { #create a new client
		my $self = shift;
		my %request = @_;
		
		my $json_request = encode_json \%request;
		my $results;
		
		$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/clients.".$self->{format}, $json_request);
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
}

sub account_countries {
	
	my ($self) = @_;
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/countries.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;	
}

sub account_timezones {
	
	my ($self) = @_;
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/timezones.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub account_apikey {
	
	my $self = shift;
	my $siteurl = $_[0];
	my $username = $_[1];
	my $password = $_[2];
	my $api_client = REST::Client->new();
	my $results;
	
	$api_client->getUseragent->credentials($self->{netloc}, $self->{protocol}.$self->{realm}."/api/v3/apikey.".$self->{format}, $username, $password);
	$api_client->setFollow(1);
	$api_client->setTimeout(60);
	
	$api_client->GET($self->{protocol}.$self->{realm}."/api/v3/apikey.".$self->{format}."?siteurl=".$siteurl);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $api_client->responseCode();
	$results->{'headers'} = $api_client->responseHeaders();
	
	return $results;
}




sub account_addadmin{ 
	
	my $self = shift;
	my (%request) = @_;

	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/admins.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}


sub account_updateadmin{
	
	my $self = shift;
	my (%request) = @_;
	my $email = $request{email};
	
	delete $request{email};
	
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/admins.".$self->{format}."?email=".$email, $json_request);
		
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub account_getadmins {
	
	my $self = shift;
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/admins.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}


sub account_getadmin{
	
	my $self = shift;
	my $email = $_[0];
	my $results;
		
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/admins.".$self->{format}."?email=".$email);
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	return $results;
}

sub account_deleteadmin {
	
	my $self = shift;
	my $email = $_[0];
	my $results;
		
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/admins.".$self->{format}."?email=".$email);
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub account_setprimarycontact {

	my $self = shift;
	my $email = $_[0];
	my $results;
	
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/primarycontact.".$self->{format}."?email=".$email);
		
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub account_getprimarycontact{
	
	my $self = shift;
	my $results;
		
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/primarycontact.".$self->{format});
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	return $results;
}


sub client_clientid {
	
	my $self = shift;
	my $client_id = $_[0];
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id.".".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_campaigns {
	
	my $self = shift;
	my $client_id = $_[0];
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/campaigns.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_drafts {
	
	my $self = shift;
	my $client_id = $_[0];
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/drafts.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_lists {
	
	my $self = shift;
	my $client_id = $_[0];
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/lists.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_segments {
	
	my $self = shift;
	my $client_id = $_[0];
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/segments.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_suppressionlist {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'email';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$input{clientid}."/suppressionlist.".$self->{format}."?page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_templates {
	
	my $self = shift;
	my $client_id = $_[0];
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/templates.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_setbasics {
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	
	delete $request{clientid};
	
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/setbasics.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_setaccess {
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	
	delete $request{clientid};
	
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/setaccess.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_setpaygbilling {
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	
	delete $request{clientid};
	
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/setpaygbilling.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_setmonthlybilling {
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	
	delete $request{clientid};
	
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/setmonthlybilling.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_delete {
	
	my $self = shift;
	my $client_id = $_[0];
	my $results;
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id.".".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}


sub client_addperson { 
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	
	delete $request{clientid};
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/people.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}


sub client_updateperson {
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	my $email = $request{email};
	
	delete $request{clientid};
	delete $request{email};
	
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/people.".$self->{format}."?email=".$email, $json_request);
		
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_getpeople {
	
	my $self = shift;
	my $client_id = $_[0];
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/people.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_getperson{
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	my $email = $request{email};
	my $results;
		
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/people.".$self->{format}."?email=".$email);
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	return $results;
}

sub client_deleteperson {
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	my $email = $request{email};
	my $results;
		
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/people.".$self->{format}."?email=".$email);
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_setprimarycontact {
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	my $email = $request{email};	
	my $results;
	
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/primarycontact.".$self->{format}."?email=".$email);
		
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub client_getprimarycontact{
	
	my $self = shift;
	my $client_id = $_[0];
	my $results;
		
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/clients/".$client_id."/primarycontact.".$self->{format});
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	return $results;
}

sub lists { #create a list
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	
	delete $request{clientid};
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/lists/".$client_id.".".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_listid {
	
	my $self = shift;
	
	if ( scalar(@_) == 1 ) { #get the list details
		my $list_id = $_[0];
		my $results;
		$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id.".".$self->{format});
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
	else { #updating a list
		my (%request) = @_;
		my $list_id = $request{listid};
	
		delete $request{listid};
		
		my $json_request = encode_json \%request;
		my $results;
		
		$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id.".".$self->{format}, $json_request);
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
}

sub list_stats {
	
	my $self = shift;
	my $list_id = $_[0];
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/stats.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_customfields {
	
	my $self = shift;
	
	if (scalar(@_) == 1) { #get the custom field details
		my $list_id = $_[0];
		my $results;
		$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/customfields.".$self->{format});
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
	else { #creating a custom field
		my (%request) = @_;
		my $list_id = $request{listid};

		delete $request{listid};
		
		my $json_request = encode_json \%request;
		my $results;
		
		$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/customfields.".$self->{format}, $json_request);
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
}

sub list_segments {
	
	my $self = shift;
	my $list_id = $_[0];
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/segments.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_active {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'date';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/lists/".$input{listid}."/active.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_unsubscribed {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'date';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/lists/".$input{listid}."/unsubscribed.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_bounced {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'date';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/lists/".$input{listid}."/bounced.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_options {

	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	my $customfield_key = $request{customfieldkey};

	delete $request{listid};
	delete $request{customfieldkey};
	
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/customfields/".$customfield_key."/options.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_delete_customfieldkey {

	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	my $customfield_key = $request{customfieldkey};
	my $results;
	
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/customfields/".$customfield_key.".".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_delete {

	my $self = shift;
	my $list_id = $_[0];
	my $results;
	
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id.".".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_webhooks {
	
	my $self = shift;

	if (scalar(@_) == 1) { #get the list of webhooks
		my $list_id = $_[0];
		my $results;
		$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/webhooks.".$self->{format});
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
	else { #create a new webhook
		my (%request) = @_;
		my $list_id = $request{listid};
	
		delete $request{listid};
		
		my $json_request = encode_json \%request;
		my $results;
		
		$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/webhooks.".$self->{format}, $json_request);
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
}

sub list_test {
	
	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	my $webhook_id = $request{webhookid};
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/webhooks/".$webhook_id."/test.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_delete_webhook {

	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	my $webhook_id = $request{webhookid};
	my $results;
	
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/webhooks/".$webhook_id.".".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_activate {
	
	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	my $webhook_id = $request{webhookid};
	my $results;
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/webhooks/".$webhook_id."/activate.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub list_deactivate {
	
	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	my $webhook_id = $request{webhookid};
	my $results;
	$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/lists/".$list_id."/webhooks/".$webhook_id."/deactivate.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub segments {
	
	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	
	delete $request{listid};
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/segments/".$list_id.".".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub segment_segmentid {
	
	my $self = shift;

	if (scalar(@_) == 1) { #get the segment details
		my $segment_id = $_[0];
		my $results;
		$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/segments/".$segment_id.".".$self->{format});
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
	else { #update the segment
		my (%request) = @_;
		my $segment_id = $request{segmentid};
		
		delete $request{segmentid};
		my $json_request = encode_json \%request;
		my $results;
		
		$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/segments/".$segment_id.".".$self->{format}, $json_request);
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
}

sub segment_rules {
	
	my $self = shift;
	my (%request) = @_;
	my $segment_id = $request{segmentid};
	
	delete $request{segmentid};
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/segments/".$segment_id."/rules.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub segment_active {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'date';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/segments/".$input{segmentid}."/active.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub segment_delete {

	my $self = shift;
	my $segment_id = $_[0];
	my $results;
	
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/segments/".$segment_id.".".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub segment_delete_rules {

	my $self = shift;
	my $segment_id = $_[0];
	my $results;
	
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/segments/".$segment_id."/rules.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub subscribers {
	
	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	
	delete $request{listid};
	
	if ($request{email}) { #get subscribers details
		my $results;
		$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/subscribers/".$list_id.".".$self->{format}."?email=".$request{email});
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
	else { #add subscriber
		my $json_request = encode_json \%request;
		my $results;
		
		$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/subscribers/".$list_id.".".$self->{format}, $json_request);
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
}

sub subscribers_import {
	
	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	
	delete $request{listid};
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/subscribers/".$list_id."/import.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub subscribers_history {
	
	my $self = shift;
	my (%request) = @_;
	my $list_id   = $request{listid};
	my $email     = $request{email};
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/subscribers/".$list_id."/history.".$self->{format}."?email=".$email);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub subscribers_unsubscribe {
	
	my $self = shift;
	my (%request) = @_;
	my $list_id = $request{listid};
	
	delete $request{listid};
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/subscribers/".$list_id."/unsubscribe.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}



sub templates {
	
	my $self = shift;

	if ( scalar(@_) == 1 ) { #get the template details
		my $template_id = $_[0];
		my $results;
		$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/templates/".$template_id.".".$self->{format});
		
		$results->{'response'} = $self->decode( $self->{client}->responseContent() );
		$results->{'code'} = $self->{client}->responseCode();
		$results->{'headers'} = $self->{client}->responseHeaders();
		
		return $results;
	}
	else {
		my (%request) = @_;
		if ( $request{templateid} ) { #update the template
			my $template_id = $request{templateid};
			
			delete $request{templateid};
			my $json_request = encode_json \%request;
			my $results;
			
			$self->{client}->PUT($self->{protocol}.$self->{realm}."/api/v3/templates/".$template_id.".".$self->{format}, $json_request);
			
			$results->{'response'} = $self->decode( $self->{client}->responseContent() );
			$results->{'code'} = $self->{client}->responseCode();
			$results->{'headers'} = $self->{client}->responseHeaders();
			
			return $results;
		}
		elsif ( $request{clientid} ) { #create a template
			my $client_id = $request{clientid};
			
			delete $request{clientid};
			my $json_request = encode_json \%request;
			my $results;
			
			$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/templates/".$client_id.".".$self->{format}, $json_request);
			
			$results->{'response'} = $self->decode( $self->{client}->responseContent() );
			$results->{'code'} = $self->{client}->responseCode();
			$results->{'headers'} = $self->{client}->responseHeaders();
			
			return $results;
		}
	}
}

sub templates_delete {

	my $self = shift;
	my $template_id = $_[0];
	my $results;
	
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/templates/".$template_id.".".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns {
	
	my $self = shift;
	my (%request) = @_;
	my $client_id = $request{clientid};
	
	delete $request{clientid};
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$client_id.".".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_send {
	
	my $self = shift;
	my (%request) = @_;
	my $campaign_id = $request{campaignid};
	
	delete $request{campaignid};
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$campaign_id."/send.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_sendpreview {
	
	my $self = shift;
	my (%request) = @_;
	my $campaign_id = $request{campaignid};
	
	delete $request{campaignid};
	my $json_request = encode_json \%request;
	my $results;
	
	$self->{client}->POST($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$campaign_id."/sendpreview.".$self->{format}, $json_request);
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_summary {
	
	my $self = shift;
	my $campaign_id = $_[0];
	my $results;
	
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$campaign_id."/summary.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_listsandsegments {
	
	my $self = shift;
	my $campaign_id = $_[0];
	my $results;
	
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$campaign_id."/listsandsegments.".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_recipients {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'date';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$input{campaignid}."/recipients.".$self->{format}."?page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_bounces {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'date';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$input{campaignid}."/bounces.".$self->{format}."?page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_opens {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'date';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$input{campaignid}."/opens.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_clicks {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'date';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$input{campaignid}."/clicks.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_unsubscribes {
	
	my $self = shift;
	my (%input) = @_;
	
	unless( Params::Util::_POSINT($input{page}) ) {
		$input{page} = 1;
	}
	unless( Params::Util::_POSINT($input{pagesize}) && $input{pagesize} >= 10 && $input{pagesize} <= 1000) {
		$input{pagesize} = 1000;
	}
	unless( Params::Util::_STRING($input{orderfield}) && ($input{orderfield} eq 'email' || $input{orderfield} eq 'name' || $input{orderfield} eq 'date')) {
		$input{orderfield} = 'date';
	}
	unless( Params::Util::_STRING($input{orderdirection}) && ($input{orderdirection} eq 'asc' || $input{orderdirection} eq 'desc')) {
		$input{orderdirection} = 'asc';
	}
	
	my $results;
	$self->{client}->GET($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$input{campaignid}."/unsubscribes.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

sub campaigns_delete {

	my $self = shift;
	my $campaign_id = $_[0];
	my $results;
	
	$self->{client}->DELETE($self->{protocol}.$self->{realm}."/api/v3/campaigns/".$campaign_id.".".$self->{format});
	
	$results->{'response'} = $self->decode( $self->{client}->responseContent() );
	$results->{'code'} = $self->{client}->responseCode();
	$results->{'headers'} = $self->{client}->responseHeaders();
	
	return $results;
}

1;

__END__

=pod

=head1 NAME

Net::CampaignMonitor - A Perl wrapper to the Campaign Monitor API.

=head1 VERSION

This documentation refers to version 1.02.

=head1 SYNOPSIS

 use Net::CampaignMonitor;
 my $cm = Net::CampaignMonitor->new({
		api_key => 'abcd1234abcd1234abcd1234',
		secure  => 1,
		timeout => 300,
		});

=head1 DESCRIPTION

B<Net::CampaignMonitor> provides a Perl wrapper to the Campaign Monitor API (v3).
 
=head1 METHODS

All methods return a hash containing the Campaign Monitor response code, the headers and the actual response.

	my %results = (
		code     => '',
		response => '',
		headers  => ''
	);

=head2 Construction and setup

=head2 new

	my $cm = Net::CampaignMonitor->new({
		api_key => 'abcd1234abcd1234abcd1234',
		secure  => 1,
		timeout => 300,
		});

Construct a new Net::CampaignMonitor object. Takes an optional hash reference of config options. The options are:

api_key - The api key for the Campaign Monitor account. If none is supplied the only function which will work is L<account_apikey|http://search.cpan.org/~jeffery/Net-CampaignMonitor-0.02/lib/Net/CampaignMonitor.pm#account_apikey>.

secure - Set to 1 (secure) or 0 (insecure) to determine whether to use http or https. Defaults to secure.

timeout - Set the timeout for the authentication. Defaults to 600 seconds.

=head2 account_clients

L<Getting your clients|http://www.campaignmonitor.com/api/account/#getting_your_clients>

	my $clients = $cm->account_clients();
	
L<Creating a client|http://www.campaignmonitor.com/api/clients/#creating_a_client>

	my $client = $cm->account_clients((
		'CompanyName'  => "ACME Limited",
		'Country'      => "Australia",
		'TimeZone'     => "(GMT+10:00) Canberra, Melbourne, Sydney"
	));

=head2 account_apikey

L<Getting your API key|http://www.campaignmonitor.com/api/account/#getting_your_api_key>

	my $apikey = $cm->account_apikey($siteurl, $username, $password)

=head2 account_countries

L<Getting valid countries|http://www.campaignmonitor.com/api/account/#getting_countries>

	my $countries = $cm->account_countries();

=head2 account_timezones

L<Getting valid timezones|http://www.campaignmonitor.com/api/account/#getting_timezones>

	my $timezones = $cm->account_timezones();

=head2 account_systemdate

L<Getting current date|http://www.campaignmonitor.com/api/account/#getting_systemdate>

	my $systemdate = $cm->account_systemdate();
	
	
	
=head2 account_addadmin 

L<Adds a new administrator to the account. An invitation will be sent to the new administrator via email.|http://www.campaignmonitor.com/api/account/#adding_an_admin>

	my $person_email = $cm->account_addadmin((
		'EmailAddress'         	=> "jane\@example.com",
		'Name'                 	=> "Jane Doe"
		));
	
=head2 account_updateadmin 

L<Updates the email address and/or name of an administrator.|http://www.campaignmonitor.com/api/account/#updating_an_admin>

	my $admin_email = $cm->account_updateadmin((		
		'email'					=> "jane\@example.com",
		'EmailAddress'         	=> "jane.new\@example.com",
		'Name'                 	=> "Jane Doeman"
		));

=head2 account_getadmins

L<Contains a list of all (active or invited) administrators associated with a particular account.|http://www.campaignmonitor.com/api/account/#getting_account_admins>

	my $admins = $cm->account_getadmins();
	
=head2 account_getadmin

L<Returns the details of a single administrator associated with an account. |http://www.campaignmonitor.com/api/account/#getting_account_admin>

	my $admin_details = $cm->account_getadmin($email);	
	
=head2 account_deleteadmin

L<Changes the status of an active administrator to a deleted administrator.|http://www.campaignmonitor.com/api/account/#deleting_an_admin>

	my $result = $cm->account_deleteadmin($admin_email);	
	
	
=head2 admin_setprimarycontact

L<Sets the primary contact for the account to be the administrator with the specified email address.|http://www.campaignmonitor.com/api/account/#setting_primary_contact>

	my $primarycontact_email = $cm->account_setprimarycontact($admin_email);		

=head2 account_getprimarycontact

L<Returns the email address of the administrator who is selected as the primary contact for this account.|http://www.campaignmonitor.com/api/account/#getting_primary_contact>

	my $primarycontact_email = $cm->account_getprimarycontact();		

=head2 campaigns

L<Creating a draft campaign|http://www.campaignmonitor.com/api/campaigns/#creating_a_campaign>

	my $campaign = $cm->campaigns((
		'clientid'   => 'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2',
		'ListIDs'    => [    
			'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1',
			'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1'
		       ],
		'FromName'   => 'My Name',
		'TextUrl'    => 'http://example.com/campaigncontent/index.txt',
		'Subject'    => 'My Subject',
		'HtmlUrl'    => 'http://example.com/campaigncontent/index.html',
		'SegmentIDs' => [   
			'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1',
			'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1'
			],
		'FromEmail'  => 'myemail@mydomain.com',
		'Name'       => 'My Campaign Name',
		'ReplyTo'    => 'myemail@mydomain.com',
	));

The clientid must be in the hash.

=head2 campaigns_send

L<Sending a draft campaign|http://www.campaignmonitor.com/api/campaigns/#sending_a_campaign>

	my $send_campaign = $cm->campaigns_send((
		'campaignid'        => 'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2',
		'SendDate'          => 'YYYY-MM-DD HH:MM',
		'ConfirmationEmail' => 'myemail@mydomain.com',
	));

The campaignid must be in the hash.

=head2 campaigns_sendpreview

L<Sending a campaign preview|http://www.campaignmonitor.com/api/campaigns/#sending_a_campaign_preview>

	my $send_preview_campaign = $cm->campaigns_sendpreview(
		  'campaignid'        => $campaign_id,
		  'PreviewRecipients' => [
					   'test1@example.com',
					   'test2@example.com'
					 ],
		  'Personalize'       => 'Random',
	));

The campaignid must be in the hash.

=head2 campaigns_summary

L<Campaign summary|http://www.campaignmonitor.com/api/campaigns/#campaign_summary>

	my $campaign_summary = $cm->campaigns_summary($campaign_id);

=head2 campaigns_listsandsegments

L<Campaign lists and segments|http://www.campaignmonitor.com/api/campaigns/#campaign_listsandsegments>

	my $campaign_listsandsegments = $cm->campaigns_listsandsegments($campaign_id);
	
=head2 campaigns_recipients

L<Campaign recipients|http://www.campaignmonitor.com/api/campaigns/#campaign_recipients>

	my $campaign_recipients = $cm->campaigns_recipients (
		'campaignid'     => $campaign_id,
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
	));

=head2 campaigns_bounces

L<Campaign bounces|http://www.campaignmonitor.com/api/campaigns/#campaign_bouncelist>

	my $campaign_bounces = $cm->campaigns_bounces (
		'campaignid'     => $campaign_id,
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
	));

=head2 campaigns_opens

L<Campaign opens|http://www.campaignmonitor.com/api/campaigns/#campaign_openslist>

	my $campaign_opens = $cm->campaigns_opens (
		'campaignid'     => $campaign_id,
		'date'           => '1900-01-01',
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
	));

=head2 campaigns_clicks

L<Campaign clicks|http://www.campaignmonitor.com/api/campaigns/#campaign_clickslist>

	my $campaign_clicks = $cm->campaigns_clicks (
		'campaignid'     => $campaign_id,
		'date'           => '1900-01-01',
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
	));

=head2 campaigns_unsubscribes

L<Campaign unsubscribes|http://www.campaignmonitor.com/api/campaigns/#campaign_unsubscribeslist>

	my $campaign_unsubscribes = $cm->campaigns_unsubscribes (
		'campaignid'     => $campaign_id,
		'date'           => '1900-01-01',
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
	));

=head2 campaigns_delete

L<Deleting a draft|http://www.campaignmonitor.com/api/campaigns/#deleting_a_campaign>

	my $campaign_delete = $cm->campaigns_delete($campaign_id);

=head2 client_clientid

L<Getting a client's details|http://www.campaignmonitor.com/api/clients/#getting_a_client>

	my $client_details = $cm->client_clientid($client_id);
	
=head2 client_campaigns

L<Getting sent campaigns|http://www.campaignmonitor.com/api/clients/#getting_client_campaigns>

	my $client_campaigns = $cm->client_campaigns($client_id);

=head2 client_drafts

L<Getting draft campaigns|http://www.campaignmonitor.com/api/clients/#getting_client_drafts>

	my $client_drafts = $cm->client_drafts($client_id);

=head2 client_lists

L<Getting subscriber lists|http://www.campaignmonitor.com/api/clients/#getting_client_lists>

	my $client_lists = $cm->client_lists($client_id);

=head2 client_segments

L<Getting segments|http://www.campaignmonitor.com/api/clients/#getting_client_segments>

	my $client_segments = $cm->client_segments($client_id);

=head2 client_suppressionlist

L<Getting suppression list|http://www.campaignmonitor.com/api/clients/#getting_client_suppressionlist>

	my $client_suppressionlist = $cm->client_suppressionlist((
		'clientid'       => $client_id,
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
	));

=head2 client_templates

L<Getting templates|http://www.campaignmonitor.com/api/clients/#getting_client_templates>

	my $client_templates = $cm->client_templates($client_id);

=head2 client_setbasics

L<Setting basic details|http://www.campaignmonitor.com/api/clients/#setting_basic_details>

	my $client_basic_details = $cm->client_setbasics((
		'clientid'     => $client_id,
		'CompanyName'  => "ACME Limited",
		'Country'      => "Australia",
		'TimeZone'     => "(GMT+10:00) Canberra, Melbourne, Sydney",
	));

=head2 client_setaccess

L<Setting access settings|http://www.campaignmonitor.com/api/clients/#setting_access_details>

Changing access level only

	my $client_access-settings = $cm->client_setaccess((
		'clientid'    => $client_id,
		'AccessLevel' => '23',
	));

Setting username and password

	my $client_access-settings = $cm->client_setaccess((
		'clientid'    => $client_id,
		'AccessLevel' => '23',
		'Username'    => 'jdoe',
		'Password'    => 'safepassword',
	));

=head2 client_setpaygbilling

L<Setting PAYG billing|http://www.campaignmonitor.com/api/clients/#setting_payg_billing>

	my $client_payg = $cm->client_setpaygbilling((
		'clientid'               => $client_id,
		'Currency'               => 'AUD',
		'CanPurchaseCredits'     => 'false',
		'ClientPays'             => 'true',
		'MarkupPercentage'       => '20',
		'MarkupOnDelivery'       => '5',
		'MarkupPerRecipient'     => '4',
		'MarkupOnDesignSpamTest' => '3',
	));

=head2 client_setmonthlybilling

L<Setting monthly billing|http://www.campaignmonitor.com/api/clients/#setting_monthly_billing>

	my $client_monthly = $cm->client_setmonthlybilling((
		'clientid'               => $client_id,
		'Currency'               => 'AUD',
		'ClientPays'             => 'true',
		'MarkupPercentage'       => '20',
	));

=head2 client_delete

L<Deleting a client|http://www.campaignmonitor.com/api/clients/#deleting_a_client>

	my $client_deleted = $cm->client_delete($client_id);
	
	
=head2 client_addperson 

L<Adds a new person to the client.|http://www.campaignmonitor.com/api/clients/#adding_a_person>

	my $person_email = $cm->client_addperson((
		'clientid'             	=> $client_id,
		'EmailAddress'         	=> "joe\@example.com",
		'Name'                 	=> "Joe Doe",
		'AccessLevel'         	=> 23,
		'Password'          	=> "safepassword"
		));
	
=head2 client_updateperson 

L<Updates any aspect of a person including their email address, name and access level..|http://www.campaignmonitor.com/api/clients/#updating_a_person>

	my $person_email = $cm->client_updateperson((
		'clientid'             	=> $client_id,
		'email'         		=> "joe\@example.com",
		'EmailAddress'         	=> "joe.new\@example.com",
		'Name'                 	=> "Joe Doe",
		'AccessLevel'         	=> 23,
		'Password'          	=> "safepassword"
		));

=head2 client_getpeople

L<Contains a list of all (active or invited) people associated with a particular client.|http://www.campaignmonitor.com/api/clients/#getting_client_people>

	my $client_access-settings = $cm->client_getpeople($client_id);
	
=head2 client_getperson

L<Returns the details of a single person associated with a client. |http://www.campaignmonitor.com/api/clients/#getting_client_person>

	my $person_details = $cm->client_getperson((
		'clientid'          => $client_id,
		'email'         	=> "joe\@example.com",
		));	
	
=head2 client_deleteperson

L<Contains a list of all (active or invited) people associated with a particular client.|http://www.campaignmonitor.com/api/clients/#deleting_a_person>

	my $result = $cm->client_deleteperson((
		'clientid'          => $client_id,
		'email'         	=> "joe\@example.com",
		));	
	
	
=head2 client_setprimarycontact

L<Sets the primary contact for the client to be the person with the specified email address.|http://www.campaignmonitor.com/api/clients/#setting_primary_contact>

	my $primarycontact_email = $cm->client_setprimarycontact((
		'clientid'          => $client_id,
		'email'         	=> "joe\@example.com",
		));		

=head2 client_getprimarycontact

L<Returns the email address of the person who is selected as the primary contact for this client.|http://www.campaignmonitor.com/api/clients/#getting_primary_contact>

	my $primarycontact_email = $cm->client_getprimarycontact($client_id);		
		
	
=head2 lists

L<Creating a list|http://www.campaignmonitor.com/api/lists/#creating_a_list>

	my $list = $cm->lists((
		'clientid'                => $client_id,
		'Title'                   => 'Website Subscribers',
		'UnsubscribePage'         => 'http://www.example.com/unsubscribed.html',
		'ConfirmedOptIn'          => 'false',
		'ConfirmationSuccessPage' => 'http://www.example.com/joined.html',
	));
	
=head2 list_listid

L<List details|http://www.campaignmonitor.com/api/lists/#getting_list_details>

	my $list = $cm->list_listid($list_id);
	
L<Updating a list|http://www.campaignmonitor.com/api/lists/#updating_a_list>

	my $updated_list = $cm->list_listid((
		'listid'                  => $list_id,
		'Title'                   => 'Website Subscribers',
		'UnsubscribePage'         => 'http://www.example.com/unsubscribed.html',
		'ConfirmedOptIn'          => 'false',
		'ConfirmationSuccessPage' => 'http://www.example.com/joined.html',
	));
	
=head2 list_stats

L<List stats|http://www.campaignmonitor.com/api/lists/#getting_list_stats>

	my $list_stats = $cm->list_stats($list_id);

=head2 list_customfields

L<List custom fields|http://www.campaignmonitor.com/api/lists/#getting_list_custom_fields>

	my $list_customfields = $cm->list_customfields($list_id);
	
=head2 list_segments

L<List segments|http://www.campaignmonitor.com/api/lists/#getting_list_segments>

	my $list_segments = $cm->list_segments($list_id);

=head2 list_active

L<Active subscribers|http://www.campaignmonitor.com/api/lists/#getting_active_subscribers>

	my $list_active_subscribers = $cm->list_active((
		'listid'         => $list_id,
		'date'           => '1900-01-01',
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
	));

=head2 list_unsubscribed

L<Unsubscribed subscribers|http://www.campaignmonitor.com/api/lists/#getting_unsubscribed_subscribers>

	my $list_unsubscribed_subscribers = $cm->list_unsubscribed((
		'listid'         => $list_id,
		'date'           => '1900-01-01',
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
	));

=head2 list_bounced

L<Bounced subscribers|http://www.campaignmonitor.com/api/lists/#getting_bounced_subscribers>

	my $list_bounced_subscribers = $cm->list_bounced((
		'listid'         => $list_id,
		'date'           => '1900-01-01',
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
	));

=head2 list_customfields

L<Creating a custom field|http://www.campaignmonitor.com/api/lists/#creating_a_custom_field>

	my $custom_field = $cm->list_customfields((
		'listid'    => $list_id,
		'FieldName' => 'Newsletter Format',
		'DataType'  => 'MultiSelectOne',
		'Options'   => [ "HTML", "Text" ],
	));
	
=head2 list_options

L<Updating custom field options|http://www.campaignmonitor.com/api/lists/#updating_custom_field_options>

	my $updated_options = $cm->list_options((
		'listid'              => $list_id,
		'KeepExistingOptions' => 'true',
		'Options'             => [ "First Option", "Second Option", "Third Option" ],
		'customfieldkey'      => '[NewsletterFormat]',
	));

=head2 list_delete_customfieldkey

L<Deleting a custom field|http://www.campaignmonitor.com/api/lists/#deleting_a_custom_field>

	my $deleted_customfield = $cm->list_delete_customfieldkey((
		'listid'         => $list_id,
		'customfieldkey' => '[NewsletterFormat]',
	));

=head2 list_delete

L<Deleting a list|http://www.campaignmonitor.com/api/lists/#deleting_a_list>

	my $deleted_list = $cm->list_delete($list_id);
	
=head2 list_webhooks

L<List webhooks|http://www.campaignmonitor.com/api/lists/#getting_list_webhooks>

	my $webhooks = $cm->list_webhooks($list_id);

L<Creating a webhook|http://www.campaignmonitor.com/api/lists/#creating_a_webhook>

	my $webhook = $cm->list_webhooks((
		'listid'        => $list_id,
		'Events'        => [ "Subscribe" ],
		'Url'           => 'http://example.com/subscribe',
		'PayloadFormat' => 'json',
	));

=head2 list_test

L<Testing a webhook|http://www.campaignmonitor.com/api/lists/#testing_a_webhook>

	my $webhook = $cm->list_test((
		'listid'    => $list_id,
		'webhookid' => $webhook_id,
	));

=head2 list_delete_webhook

L<Deleting a webhook|http://www.campaignmonitor.com/api/lists/#deleting_a_webhook>

	my $deleted_webhook = $cm->list_delete_webhook((
		'listid'    => $list_id,
		'webhookid' => $webhook_id,
	));

=head2 list_activate

L<Activating a webhook|http://www.campaignmonitor.com/api/lists/#activating_a_webhook>

	my $activated_webhook = $cm->list_activate((
		'listid'    => $list_id,
		'webhookid' => $webhook_id,
	));

=head2 list_deactivate

L<Deactivating a webhook|http://www.campaignmonitor.com/api/lists/#deactivating_a_webhook>

	my $deactivated_webhook = $cm->list_deactivate((
		'listid'    => $list_id,
		'webhookid' => $webhook_id,
	));

=head2 segments

L<Creating a segment|http://www.campaignmonitor.com/api/segments/#creating_a_segment>

	my $segment = $cm->segments((
		'listid' => $list_id,
		'Rules' => [
				{
					'Subject' => 'EmailAddress',
					'Clauses' => [
						'CONTAINS @domain.com'
					]
				},
				{
					'Subject' => 'DateSubscribed',
					'Clauses' => [
						'AFTER 2009-01-01',
						'EQUALS 2009-01-01'
					]
				},
				{
					'Subject' => 'DateSubscribed',
					'Clauses' => [
						'BEFORE 2010-01-01'
					]
				}
			],
		'Title' => 'My Segment',
	));

=head2 segment_segmentid

L<Updating a segment|http://www.campaignmonitor.com/api/segments/#updating_a_segment>

	my $updated_segment = $cm->segment_segmentid((
		'segmentid' => $segment_id,
		'Rules' => [
				{
					'Subject' => 'EmailAddress',
					'Clauses' => [
						'CONTAINS @domain.com'
					]
				},
				{
					'Subject' => 'DateSubscribed',
					'Clauses' => [
						'AFTER 2009-01-01',
						'EQUALS 2009-01-01'
					]
				},
				{
					'Subject' => 'DateSubscribed',
					'Clauses' => [
						'BEFORE 2010-01-01'
					]
				}
			],
		'Title' => 'My Segment',
	));

L<Getting a segment's details|http://www.campaignmonitor.com/api/segments/#getting_a_segment>

	my $updated_segment = $cm->segment_segmentid($segment_id);

=head2 segment_rules

L<Adding a segment rule|http://www.campaignmonitor.com/api/segments/#adding_a_segment_rule>

	my $new_rules = $cm->segment_rules((
		'segmentid' => $segment_id,
		'Subject' => 'Name',
		'Clauses' => [
			'NOT_PROVIDED',
			'EQUALS Subscriber Name'
		],
	));

=head2 segment_active

L<Getting segment subscribers|http://www.campaignmonitor.com/api/segments/#getting_segment_subs>

	my $segment_subs = $cm->segment_active((
		'segmentid'         => $segment_id,
		'date'              => '1900-01-01',
		'page'              => '1',
		'pagesize'          => '100',
		'orderfield'        => 'email',
		'orderdirection'    => 'asc',
	));

=head2 segment_delete

L<Deleting a segment|http://www.campaignmonitor.com/api/segments/#deleting_a_segment>

	my $deleted_segment = $cm->segment_delete($segment_id);
	
=head2 segment_delete_rules

L<Deleting a segment's rules|http://www.campaignmonitor.com/api/segments/#deleting_segment_rules>

	my $deleted_segment_rules = $cm->segment_delete_rules($segment_id);

=head2 subscribers

L<Adding a subscriber|http://www.campaignmonitor.com/api/subscribers/#adding_a_subscriber>

	my $added_subscriber = $cm->subscribers((
		'listid'       => $list_id,
		'Resubscribe'  => 'true',
		'CustomFields' => [
			{
				'Value' => 'http://example.com',
				'Key'   => 'website'
			},
			{
				'Value' => 'magic',
				'Key'   => 'interests'
			},
			{
				'Value' => 'romantic walks',
				'Key'   => 'interests'
			}
		],
		'Name'         => 'New Subscriber',
		'EmailAddress' => 'subscriber@example.com',
	));

L<Getting a subscriber's details|http://www.campaignmonitor.com/api/subscribers/#getting_subscriber_details>

	my $subs_details = $cm->subscribers((
		'listid' => $list_id,
		'email'  => 'subscriber@example.com',
	));

=head2 subscribers_import

L<Importing many subscribers|http://www.campaignmonitor.com/api/subscribers/#importing_subscribers>

	my $imported_subs = $cm->subscribers_import((
		'listid'       => $list_id,
		'Subscribers' => [
			{
				'CustomFields' => [
					{
						'Value' => 'http://example.com',
						'Key' => 'website'
					},
					{
						'Value' => 'magic',
						'Key' => 'interests'
					},
					{
						'Value' => 'romantic walks',
						'Key' => 'interests'
					}
				],
				'Name' => 'New Subscriber One',
				'EmailAddress' => 'subscriber1@example.com'
			},
			{
				'Name' => 'New Subscriber Two',
				'EmailAddress' => 'subscriber2@example.com'
			},
			{
				'Name' => 'New Subscriber Three',
				'EmailAddress' => 'subscriber3@example.com'
			}
		],
		'Resubscribe' => 'true',
	));

=head2 subscribers_history

L<Getting a subscriber's history|http://www.campaignmonitor.com/api/subscribers/#getting_subscriber_history>

	my $subs_history = $cm->subscribers_history((
		'listid' => $list_id,
		'email'  => 'subscriber@example.com',
	));

=head2 subscribers_unsubscribe

L<Unsubscribing a subscriber|http://www.campaignmonitor.com/api/subscribers/#unsubscribing_a_subscriber>

	my $unsub_sub = $cm->subscribers_unsubscribe((
		'listid'        => $list_id,
		'EmailAddress'  => 'subscriber@example.com',
	));

=head2 templates

L<Getting a template|http://www.campaignmonitor.com/api/templates/#getting_a_template>

	my $template = $cm->templates($template_id);

L<Creating a template|http://www.campaignmonitor.com/api/templates/#creating_a_template>

	my $template = $cm->templates((
		'clientid'      => $client_id
		'ZipFileURL'    => 'http://example.com/files.zip',
		'HtmlPageURL'   => 'http://example.com/index.html',
		'ScreenshotURL' => 'http://example.com/screenshot.jpg',
		'Name'          => 'Template Two',
	));

L<Updating a template|http://www.campaignmonitor.com/api/templates/#updating_a_template>

	my $updated_template = $cm->templates(
		'templateid'      => $template_id
		'ZipFileURL'    => 'http://example.com/files.zip',
		'HtmlPageURL'   => 'http://example.com/index.html',
		'ScreenshotURL' => 'http://example.com/screenshot.jpg',
		'Name'          => 'Template Two',
	));

=head2 templates_delete

L<Deleting a template|http://www.campaignmonitor.com/api/templates/#deleting_a_template>

	my $deleted_template = $cm->templates_delete($template_id);

=head1 INSTALLATION NOTES

In order to run the full test suite you will need to provide an API Key. This can be done in the following way.

	cpan CAMPAIGN_MONITOR_API_KEY=<your_api_key> Net::CampaignMonitor
	
If you do not do this almost all of the tests will be skipped.

=head1 BUGS

Not quite a bug. This module uses L<REST::Client>. REST::Client fails to install properly on Windows due to this L<bug|https://rt.cpan.org/Public/Bug/Display.html?id=65803>. You will need to make REST::Client install without running tests to install it.

=head1 MAINTAINER

Campaign Monitor, E<lt>support@campaignmonitor.com<gt>

=head1 AUTHOR

Jeffery Candiloro <jeffery@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2012, Campaign Monitor  E<lt>support@campaignmonitor.com<gt>. All rights reserved.

Copyright (c) 2011, Jeffery Candiloro  E<lt>jeffery@cpan.org<gt>.  All rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.
