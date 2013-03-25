package Net::CampaignMonitor;

use strict;

use 5.008005;
use MIME::Base64;
use REST::Client;
use Params::Util qw{_STRING _NONNEGINT _POSINT _HASH _HASHLIKE};
use JSON;
use Carp;
use URI::Escape;

use version; our $VERSION = version->declare("v2.1.0");
our $CAMPAIGN_MONITOR_DOMAIN = 'api.createsend.com';

sub authorize_url {
  my $class = shift;
  my ($args) = @_;
  unless(Params::Util::_HASH($args)) {
    $args = { @_ };
  }
  my $self = bless($args, $class);
  my $qs = 'client_id='.uri_escape($self->{client_id});
  $qs .= '&redirect_uri='.uri_escape($self->{redirect_uri});
  $qs .= '&scope='.uri_escape($self->{scope});
  if (exists $self->{state}) {
    $qs .= '&state='.uri_escape($self->{state});
  }
  return 'https://'.$Net::CampaignMonitor::CAMPAIGN_MONITOR_DOMAIN.'/oauth?'.$qs;
}

sub exchange_token {
  my $class = shift;
  my ($args) = @_;
  unless(Params::Util::_HASH($args)) {
    $args = { @_ };
  }
  my $self = bless($args, $class);
  my $oauth_client = Net::CampaignMonitor->create_oauth_client();
  my $body = 'grant_type=authorization_code';
  $body .= '&client_id='.uri_escape($self->{client_id});
  $body .= '&client_secret='.uri_escape($self->{client_secret});
  $body .= '&redirect_uri='.uri_escape($self->{redirect_uri});
  $body .= '&code='.uri_escape($self->{code});

  $oauth_client->POST('https://'.$Net::CampaignMonitor::CAMPAIGN_MONITOR_DOMAIN.'/oauth/token',
    $body, {'Content-type' => 'application/x-www-form-urlencoded'});
  my $result = $self->decode($oauth_client->responseContent());

  if (exists $result->{error}) {
    croak 'Error exchanging OAuth code for access token. '.$result->{error}.': '.$result->{error_description};
  }
  return $result;
}

sub new {
  my $class = shift;
  my ($args) = @_;
  unless(Params::Util::_HASH($args)) {
    if (@_ % 2 == 0) {
      $args = { @_ };
    } else {
      croak 'Error parsing constructor arguments, no hashref and odd number of arguments supplied';
    }
  }
  my $self = bless($args, $class);
  $self->{format} = 'json';
  $self->{useragent} = 'createsend-perl-'.$Net::CampaignMonitor::VERSION;
  unless( Params::Util::_STRING($self->{domain}) ) {
    $self->{domain} = $Net::CampaignMonitor::CAMPAIGN_MONITOR_DOMAIN;
  }

  if ($self->{secure} == 1) {
    $self->{netloc}   = $self->{domain}.':443';
    $self->{protocol} = 'https://';
  } elsif ($self->{secure} == 0) {
    $self->{netloc}   = $self->{domain}.':80';
    $self->{protocol} = 'http://';
  } else {
    $self->{netloc}   = $self->{domain}.':443';
    $self->{protocol} = 'https://';
  }

  unless( Params::Util::_POSINT($self->{timeout}) ) {
    $self->{timeout} = 600;
  }

  if ( (exists $self->{api_key} ) && !( Params::Util::_STRING( $self->{api_key} )) ) {
    Carp::croak("Missing or invalid api key");
  }

  if ( (exists $self->{access_token} ) && !( Params::Util::_STRING( $self->{access_token} )) ) {
    Carp::croak("Missing or invalid OAuth access token");
  }

  if ( exists $self->{api_key} || exists $self->{access_token} ) {
    # Create and initialise the rest client
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

  my $ua = LWP::UserAgent->new;
  $ua->agent($self->{useragent});
  if (exists $self->{access_token}) {
    $ua->default_header('Authorization' => 'Bearer '.$self->{access_token});
  } elsif (exists $self->{api_key}) {
    $ua->default_header('Authorization' => 'Basic '.encode_base64($self->{api_key}.':x'));
  }
  my $client = REST::Client->new({useragent => $ua});
  $client->setFollow(1);
  $client->setTimeout($self->{timeout});
  return $client;
}

sub create_oauth_client {
  my $ua = LWP::UserAgent->new;
  my $client = REST::Client->new({useragent => $ua});
  $client->setFollow(1);
  $client->setTimeout(600);
  return $client;
}

sub refresh_token {
  my ($self) = @_;

  if (!exists $self->{refresh_token} ||
    (exists $self->{refresh_token} && !(Params::Util::_STRING($self->{refresh_token})))) {
    croak 'Error refreshing OAuth token. No refresh token exists.';
  }
  my $oauth_client = Net::CampaignMonitor->create_oauth_client();
  my $body = 'grant_type=refresh_token&refresh_token='.uri_escape($self->{refresh_token});
  $oauth_client->POST($self->{protocol}.$self->{domain}.'/oauth/token', $body,
    {'Content-type' => 'application/x-www-form-urlencoded'});
  my $result = $self->decode($oauth_client->responseContent());

  if (exists $result->{error}) {
    croak 'Error refreshing OAuth token. '.$result->{error}.': '.$result->{error_description};
  }

  # Set the access token and refresh token, and re-create the client
  $self->{access_token} = $result->{access_token};
  $self->{refresh_token} = $result->{refresh_token};
  $self->{client} = $self->create_rest_client();
  return $result;
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
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/systemdate.".$self->{format});
  
  return $self->_build_results();
}

sub account_billingdetails {
  my ($self) = @_;
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/billingdetails.".$self->{format});

  return $self->_build_results();
}

sub account_clients {
  if (scalar(@_) == 1) { # Get the list of clients
    my ($self) = @_;
    $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients.".$self->{format});
    
    return $self->_build_results();
  }
  else { # Create a new client
    my $self = shift;
    my %request = @_;
    
    my $json_request = encode_json \%request;
    
    $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/clients.".$self->{format}, $json_request);
    
    return $self->_build_results();
  }
}

sub account_countries {
  my ($self) = @_;
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/countries.".$self->{format});
  
  return $self->_build_results();  
}

sub account_timezones {
  my ($self) = @_;
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/timezones.".$self->{format});
  
  return $self->_build_results();
}

sub account_apikey {
  my $self = shift;
  my $siteurl = $_[0];
  my $username = $_[1];
  my $password = $_[2];
  my $ua = LWP::UserAgent->new;
  $ua->agent($self->{useragent});
  $ua->default_header('Authorization' => 'Basic '.encode_base64($username.':'.$password));
  my $api_client = REST::Client->new({useragent => $ua});

  $api_client->setFollow(1);
  $api_client->setTimeout(60); 
  my $results;
 
  $api_client->GET($self->{protocol}.$self->{domain}."/api/v3/apikey.".$self->{format}."?siteurl=".$siteurl);

  $results->{'response'} = $self->decode( $api_client->responseContent() );
  $results->{'code'} = $api_client->responseCode();
  $results->{'headers'} = $api_client->responseHeaders();
  
  return $results;
}

sub account_addadmin{ 
  my $self = shift;
  my (%request) = @_;

  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/admins.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub account_updateadmin{
  my $self = shift;
  my (%request) = @_;
  my $email = $request{email};
  
  delete $request{email};
  
  my $json_request = encode_json \%request;
  
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/admins.".$self->{format}."?email=".$email, $json_request);
    
  return $self->_build_results();
}

sub account_getadmins {
  my $self = shift;
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/admins.".$self->{format});
  
  return $self->_build_results();
}

sub account_getadmin{
  my $self = shift;
  my $email = $_[0];
    
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/admins.".$self->{format}."?email=".$email);

  return $self->_build_results();
}

sub account_deleteadmin {
  my $self = shift;
  my $email = $_[0];
    
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/admins.".$self->{format}."?email=".$email);
  return $self->_build_results();
}

sub account_setprimarycontact {
  my $self = shift;
  my $email = $_[0];
  
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/primarycontact.".$self->{format}."?email=".$email);
    
  return $self->_build_results();
}

sub account_getprimarycontact{
  my $self = shift;
    
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/primarycontact.".$self->{format});

  return $self->_build_results();
}


sub client_clientid {
  my $self = shift;
  my $client_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id.".".$self->{format});
  
  return $self->_build_results();
}

sub client_campaigns {
  my $self = shift;
  my $client_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/campaigns.".$self->{format});
  
  return $self->_build_results();
}

sub client_drafts {
  my $self = shift;
  my $client_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/drafts.".$self->{format});
  
  return $self->_build_results();
}

sub client_scheduled {
  my $self = shift;
  my $client_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/scheduled.".$self->{format});
  
  return $self->_build_results();
}

sub client_lists {
  my $self = shift;
  my $client_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/lists.".$self->{format});
  
  return $self->_build_results();
}

sub client_listsforemail {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  my $email = $request{email};

  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/listsforemail.".$self->{format}."?email=".$email);

  return $self->_build_results();
}

sub client_segments {
  my $self = shift;
  my $client_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/segments.".$self->{format});
  
  return $self->_build_results();
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
  
    $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$input{clientid}."/suppressionlist.".$self->{format}."?page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});

  return $self->_build_results();
}

sub client_suppress {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  
  delete $request{clientid};
  my $json_request = encode_json \%request;

  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/suppress.".$self->{format}, $json_request);

  return $self->_build_results();
}

sub client_unsuppress {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  my $email = $request{email};
  
  delete $request{clientid};
  delete $request{email};
  my $json_request = encode_json \%request;

  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/unsuppress.".$self->{format}."?email=".$email, $json_request);

  return $self->_build_results();
}

sub client_templates {
  my $self = shift;
  my $client_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/templates.".$self->{format});
  
  return $self->_build_results();
}

sub client_setbasics {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  
  delete $request{clientid};
  
  my $json_request = encode_json \%request;
  
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/setbasics.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub client_setpaygbilling {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  
  delete $request{clientid};
  
  my $json_request = encode_json \%request;
  
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/setpaygbilling.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub client_setmonthlybilling {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  
  delete $request{clientid};
  
  my $json_request = encode_json \%request;
  
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/setmonthlybilling.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub client_transfercredits {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};

  delete $request{clientid};
  my $json_request = encode_json \%request;

  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/credits.".$self->{format}, $json_request);

  return $self->_build_results();
}

sub client_delete {
  my $self = shift;
  my $client_id = $_[0];
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id.".".$self->{format});
  
  return $self->_build_results();
}

sub client_addperson {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  
  delete $request{clientid};
  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/people.".$self->{format}, $json_request);
  
  return $self->_build_results();
}


sub client_updateperson {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  my $email = $request{email};
  
  delete $request{clientid};
  delete $request{email};
  
  my $json_request = encode_json \%request;
  
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/people.".$self->{format}."?email=".$email, $json_request);
    
  return $self->_build_results();
}

sub client_getpeople {
  my $self = shift;
  my $client_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/people.".$self->{format});
  
  return $self->_build_results();
}

sub client_getperson {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  my $email = $request{email};
    
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/people.".$self->{format}."?email=".$email);

  return $self->_build_results();
}

sub client_deleteperson {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  my $email = $request{email};
    
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/people.".$self->{format}."?email=".$email);

  return $self->_build_results();
}

sub client_setprimarycontact {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  my $email = $request{email};  
  
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/primarycontact.".$self->{format}."?email=".$email);
    
  return $self->_build_results();
}

sub client_getprimarycontact{
  my $self = shift;
  my $client_id = $_[0];
    
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/clients/".$client_id."/primarycontact.".$self->{format});

  return $self->_build_results();
}

sub lists { # Create a list
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  
  delete $request{clientid};
  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/lists/".$client_id.".".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub list_listid {
  my $self = shift;
  
  if ( scalar(@_) == 1 ) { # Get the list details
    my $list_id = $_[0];
    $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id.".".$self->{format});
    
    return $self->_build_results();
  }
  else { # Updating a list
    my (%request) = @_;
    my $list_id = $request{listid};
  
    delete $request{listid};
    
    my $json_request = encode_json \%request;
    
    $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id.".".$self->{format}, $json_request);
    
    return $self->_build_results();
  }
}

sub list_stats {
  my $self = shift;
  my $list_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/stats.".$self->{format});
  
  return $self->_build_results();
}

sub list_customfields {
  my $self = shift;
  
  if (scalar(@_) == 1) { # Get the custom field details
    my $list_id = $_[0];
    $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/customfields.".$self->{format});
    
    return $self->_build_results();
  }
  else { # Create a new custom field
    my (%request) = @_;
    my $list_id = $request{listid};

    delete $request{listid};
    
    my $json_request = encode_json \%request;
    
    $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/customfields.".$self->{format}, $json_request);
    
    return $self->_build_results();
  }
}

sub list_customfields_update {
  my $self = shift;
  my (%request) = @_;
  my $list_id   = $request{listid};
  my $key     = $request{customfieldkey};

  delete $request{listid};
  delete $request{customfieldkey};
  my $json_request = encode_json \%request;

  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/customfields/".$key.".".$self->{format}, $json_request);

  return $self->_build_results();
}

sub list_segments {
  my $self = shift;
  my $list_id = $_[0];
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/segments.".$self->{format});
  
  return $self->_build_results();
}

sub list_active {
  my $self = shift;
  my (%input) = @_;
  
  unless( Params::Util::_STRING($input{date}) ) {
    $input{date} = '';
  }
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$input{listid}."/active.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
}

sub list_unconfirmed {
  my $self = shift;
  my (%input) = @_;

  unless( Params::Util::_STRING($input{date}) ) {
    $input{date} = '';
  }
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

  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$input{listid}."/unconfirmed.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});

  return $self->_build_results();
}

sub list_unsubscribed {
  my $self = shift;
  my (%input) = @_;
  
  unless( Params::Util::_STRING($input{date}) ) {
    $input{date} = '';
  }
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$input{listid}."/unsubscribed.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
}

sub list_deleted {
  my $self = shift;
  my (%input) = @_;

  unless( Params::Util::_STRING($input{date}) ) {
    $input{date} = '';
  }
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

  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$input{listid}."/deleted.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
}

sub list_bounced {
  my $self = shift;
  my (%input) = @_;
  
  unless( Params::Util::_STRING($input{date}) ) {
    $input{date} = '';
  }
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$input{listid}."/bounced.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
}

sub list_options {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};
  my $customfield_key = $request{customfieldkey};

  delete $request{listid};
  delete $request{customfieldkey};
  
  my $json_request = encode_json \%request;
  
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/customfields/".$customfield_key."/options.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub list_delete_customfieldkey {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};
  my $customfield_key = $request{customfieldkey};
  
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/customfields/".$customfield_key.".".$self->{format});
  
  return $self->_build_results();
}

sub list_delete {
  my $self = shift;
  my $list_id = $_[0];
  
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id.".".$self->{format});
  
  return $self->_build_results();
}

sub list_webhooks {
  my $self = shift;

  if (scalar(@_) == 1) { #get the list of webhooks
    my $list_id = $_[0];
    $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/webhooks.".$self->{format});
    
    return $self->_build_results();
  }
  else { #create a new webhook
    my (%request) = @_;
    my $list_id = $request{listid};
  
    delete $request{listid};
    
    my $json_request = encode_json \%request;
    
    $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/webhooks.".$self->{format}, $json_request);
    
    return $self->_build_results();
  }
}

sub list_test {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};
  my $webhook_id = $request{webhookid};
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/webhooks/".$webhook_id."/test.".$self->{format});
  
  return $self->_build_results();
}

sub list_delete_webhook {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};
  my $webhook_id = $request{webhookid};
  
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/webhooks/".$webhook_id.".".$self->{format});
  
  return $self->_build_results();
}

sub list_activate {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};
  my $webhook_id = $request{webhookid};
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/webhooks/".$webhook_id."/activate.".$self->{format});
  
  return $self->_build_results();
}

sub list_deactivate {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};
  my $webhook_id = $request{webhookid};
  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/lists/".$list_id."/webhooks/".$webhook_id."/deactivate.".$self->{format});
  
  return $self->_build_results();
}

sub segments {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};
  
  delete $request{listid};
  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/segments/".$list_id.".".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub segment_segmentid {
  my $self = shift;

  if (scalar(@_) == 1) { #get the segment details
    my $segment_id = $_[0];
    $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/segments/".$segment_id.".".$self->{format});
    
    return $self->_build_results();
  }
  else { #update the segment
    my (%request) = @_;
    my $segment_id = $request{segmentid};
    
    delete $request{segmentid};
    my $json_request = encode_json \%request;
    
    $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/segments/".$segment_id.".".$self->{format}, $json_request);
    
    return $self->_build_results();
  }
}

sub segment_rules {
  my $self = shift;
  my (%request) = @_;
  my $segment_id = $request{segmentid};
  
  delete $request{segmentid};
  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/segments/".$segment_id."/rules.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub segment_active {
  my $self = shift;
  my (%input) = @_;

  unless( Params::Util::_STRING($input{date}) ) {
    $input{date} = '';
  }
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/segments/".$input{segmentid}."/active.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
}

sub segment_delete {
  my $self = shift;
  my $segment_id = $_[0];
  
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/segments/".$segment_id.".".$self->{format});
  
  return $self->_build_results();
}

sub segment_delete_rules {
  my $self = shift;
  my $segment_id = $_[0];
  
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/segments/".$segment_id."/rules.".$self->{format});
  
  return $self->_build_results();
}

sub subscribers {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};

  delete $request{listid};

  if ($request{email}) { # Get subscribers details
    $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/subscribers/".$list_id.".".$self->{format}."?email=".$request{email});
    
    return $self->_build_results();
  }
  else { # Add subscriber
    my $json_request = encode_json \%request;
    
    $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/subscribers/".$list_id.".".$self->{format}, $json_request);
    
    return $self->_build_results();
  }
}

sub subscribers_update {
  my $self = shift;
  my (%request) = @_;
  my $list_id   = $request{listid};
  my $email     = $request{email};

  delete $request{listid};
  delete $request{email};
  my $json_request = encode_json \%request;

  $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/subscribers/".$list_id.".".$self->{format}."?email=".$email, $json_request);

  return $self->_build_results();
}

sub subscribers_import {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};
  
  delete $request{listid};
  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/subscribers/".$list_id."/import.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub subscribers_history {
  my $self = shift;
  my (%request) = @_;
  my $list_id   = $request{listid};
  my $email     = $request{email};
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/subscribers/".$list_id."/history.".$self->{format}."?email=".$email);
  
  return $self->_build_results();
}

sub subscribers_unsubscribe {
  my $self = shift;
  my (%request) = @_;
  my $list_id = $request{listid};
  
  delete $request{listid};
  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/subscribers/".$list_id."/unsubscribe.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub subscribers_delete {
  my $self = shift;
  my (%request) = @_;
  my $list_id   = $request{listid};
  my $email     = $request{email};

  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/subscribers/".$list_id.".".$self->{format}."?email=".$email);

  return $self->_build_results();
}

sub templates {
  my $self = shift;

  if ( scalar(@_) == 1 ) { #get the template details
    my $template_id = $_[0];
    $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/templates/".$template_id.".".$self->{format});
    
    return $self->_build_results();
  }
  else {
    my (%request) = @_;
    if ( $request{templateid} ) { #update the template
      my $template_id = $request{templateid};
      
      delete $request{templateid};
      my $json_request = encode_json \%request;
      
      $self->{client}->PUT($self->{protocol}.$self->{domain}."/api/v3/templates/".$template_id.".".$self->{format}, $json_request);
      
      return $self->_build_results();
    }
    elsif ( $request{clientid} ) { #create a template
      my $client_id = $request{clientid};
      
      delete $request{clientid};
      my $json_request = encode_json \%request;
      
      $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/templates/".$client_id.".".$self->{format}, $json_request);
      
      return $self->_build_results();
    }
  }
}

sub templates_delete {
  my $self = shift;
  my $template_id = $_[0];
  
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/templates/".$template_id.".".$self->{format});
  
  return $self->_build_results();
}

sub campaigns {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};
  
  delete $request{clientid};
  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$client_id.".".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub campaigns_fromtemplate {
  my $self = shift;
  my (%request) = @_;
  my $client_id = $request{clientid};

  delete $request{clientid};
  my $json_request = encode_json \%request;

  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$client_id."/fromtemplate.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub campaigns_send {
  my $self = shift;
  my (%request) = @_;
  my $campaign_id = $request{campaignid};
  
  delete $request{campaignid};
  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$campaign_id."/send.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub campaigns_unschedule {
  my $self = shift;
  my (%request) = @_;
  my $campaign_id = $request{campaignid};

  delete $request{campaignid};
  my $json_request = encode_json \%request;

  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$campaign_id."/unschedule.".$self->{format}, $json_request);

  return $self->_build_results();
}

sub campaigns_sendpreview {
  my $self = shift;
  my (%request) = @_;
  my $campaign_id = $request{campaignid};
  
  delete $request{campaignid};
  my $json_request = encode_json \%request;
  
  $self->{client}->POST($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$campaign_id."/sendpreview.".$self->{format}, $json_request);
  
  return $self->_build_results();
}

sub campaigns_summary {
  my $self = shift;
  my $campaign_id = $_[0];
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$campaign_id."/summary.".$self->{format});
  
  return $self->_build_results();
}

sub campaigns_emailclientusage {
  my $self = shift;
  my $campaign_id = $_[0];

  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$campaign_id."/emailclientusage.".$self->{format});

  return $self->_build_results();
}

sub campaigns_listsandsegments {
  my $self = shift;
  my $campaign_id = $_[0];
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$campaign_id."/listsandsegments.".$self->{format});
  
  return $self->_build_results();
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$input{campaignid}."/recipients.".$self->{format}."?page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$input{campaignid}."/bounces.".$self->{format}."?page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$input{campaignid}."/opens.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$input{campaignid}."/clicks.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$input{campaignid}."/unsubscribes.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
}

sub campaigns_spam {
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
  
  $self->{client}->GET($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$input{campaignid}."/spam.".$self->{format}."?date=".$input{date}."&page=".$input{page}."&pagesize=".$input{pagesize}."&orderfield=".$input{orderfield}."&orderdirection=".$input{orderdirection});
  
  return $self->_build_results();
}

sub campaigns_delete {
  my $self = shift;
  my $campaign_id = $_[0];
  
  $self->{client}->DELETE($self->{protocol}.$self->{domain}."/api/v3/campaigns/".$campaign_id.".".$self->{format});
  
  return $self->_build_results();
}

sub _build_results {
  my ($self) = @_;
  my $client = $self->{client};
  my $results;
  $results->{response}  = $self->decode( $client->responseContent() );
  $results->{code}      = $client->responseCode();
  $results->{headers}   = +{ map { $_ => scalar $client->responseHeader($_) } $client->responseHeaders() };
  return $results;
}

1;

__END__

=pod

=head1 NAME

Net::CampaignMonitor - A Perl wrapper for the Campaign Monitor API.

=head1 VERSION

This documentation refers to version v2.1.0.

=head1 SYNOPSIS

  use Net::CampaignMonitor;
  my $cm = Net::CampaignMonitor->new({
    access_token => 'your access token',
    refresh_token => 'your refresh token',
    secure  => 1,
    timeout => 300,
  });

=head1 DESCRIPTION

B<Net::CampaignMonitor> provides a Perl wrapper for the Campaign Monitor API.

=head1 METHODS

=head2 OAuth utility methods

=head2 authorize_url

Get the authorization URL for your OAuth application, given the application's Client ID, Redirect URI, Permission scope, and optional state data.

  my $authorize_url = Net::CampaignMonitor->authorize_url({
    client_id => 'Your app client ID',
    redirect_uri => 'Redirect URI for your application',
    scope => 'The permission scope required by your application',
    state => 'Optional state data'
  });

=head2 exchange_token

Exchange a unique OAuth code for an OAuth access token and refresh token.

  my $token_details = Net::CampaignMonitor->exchange_token(
    client_id => 'Client ID for your application',
    client_secret => 'Client Secret for your application',
    redirect_uri => 'Redirect URI for your application',
    code => 'A unique code for your user' # Get the code parameter from the query string
  );

The resulting variable $token_details will be of the form:

  {
    'refresh_token' => 'refresh token',
    'expires_in' => 1209600, # seconds until the access token expires
    'access_token' => 'access token'
  }

=head2 Construction and setup

=head2 new

If you want to authenticate using OAuth:

  my $cm = Net::CampaignMonitor->new({
    access_token => 'your access token',
    refresh_token => 'your refresh token',
    secure  => 1,
    timeout => 300,
  });

Or if you want to authenticate using an API key:

  my $cm = Net::CampaignMonitor->new({
    api_key => 'abcd1234abcd1234abcd1234',
    secure  => 1,
    timeout => 300,
  });

Construct a new Net::CampaignMonitor object. Takes an optional hash reference of config options. The options are:

access_token - The OAuth access token to use when making Campaign Monitor API requests.

refresh_token - The OAuth refresh token to use to renew access_token when it expires.

api_key - The api key for the Campaign Monitor account. If none is supplied the only function which will work is L<account_apikey|http://search.cpan.org/~jeffery/Net-CampaignMonitor-0.02/lib/Net/CampaignMonitor.pm#account_apikey>.

secure - Set to 1 (secure) or 0 (insecure) to determine whether to use http or https. Defaults to secure.

timeout - Set the timeout for the authentication. Defaults to 600 seconds.

=head2 OAuth-specific functionality

=head2 refresh_token

Refresh the current OAuth access token using the current refresh token. After making this call successfully, you will be able to continue making further API calls.

  my $new_token_details = $cm->refresh_token();

The resulting variable $new_token_details will be of the form:

  {
    'refresh_token' => 'new refresh token',
    'expires_in' => 1209600, # seconds until the new access token expires
    'access_token' => 'new access token'
  }

=head2 Core API functionality

All the following methods return a hash containing the Campaign Monitor response code, the headers and the actual response.

  my %results = (
    code     => '',
    response => '',
    headers  => ''
  );

=head2 account_clients

L<Getting your clients|http://www.campaignmonitor.com/api/account/#getting_your_clients>

  my $clients = $cm->account_clients();
  
L<Creating a client|http://www.campaignmonitor.com/api/clients/#creating_a_client>

  my $client = $cm->account_clients((
    'CompanyName'  => "ACME Limited",
    'Country'      => "Australia",
    'TimeZone'     => "(GMT+10:00) Canberra, Melbourne, Sydney"
  ));

=head2 account_billingdetails

L<Getting your billing details|http://www.campaignmonitor.com/api/account/#getting_your_billing_details>

  my $billing_details = $cm->account_billingdetails()

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
    'EmailAddress'          => "jane\@example.com",
    'Name'                  => "Jane Doe"
    ));
  
=head2 account_updateadmin 

L<Updates the email address and/or name of an administrator.|http://www.campaignmonitor.com/api/account/#updating_an_admin>

  my $admin_email = $cm->account_updateadmin((    
    'email'         => "jane\@example.com",
    'EmailAddress'          => "jane.new\@example.com",
    'Name'                  => "Jane Doeman"
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

=head2 campaigns_fromtemplate

L<Creating a campaign from a template|http://www.campaignmonitor.com/api/campaigns/#creating_a_campaign_from_template>

  my $template_content = {
    'Singlelines' => [
      {
        'Content' => "This is a heading",
        'Href' => "http://example.com/"
      }
    ],
    'Multilines' => [
      {
        'Content' => "<p>This is example</p><p>multiline <a href=\"http://example.com\">content</a>...</p>"
      }
    ],
    'Images' => [
      {
        'Content' => "http://example.com/image.png",
        'Alt' => "This is alt text for an image",
        'Href' => "http://example.com/"
      }
    ],
    'Repeaters' => [
      {
        'Items' => [
          (
            'Layout' => "My layout",
            'Singlelines' => [
              {
                'Content' => "This is a repeater heading",
                'Href' => "http://example.com/"
              }
            ],
            'Multilines' => [
              {
                'Content' => "<p>This is example</p><p>multiline <a href=\"http://example.com\">content</a>...</p>"
              }
            ],
            'Images' => [
              {
                'Content' => "http://example.com/repeater-image.png",
                'Alt' => "This is alt text for a repeater image",
                'Href' => "http://example.com/"
              }
            ]
          }
        ]
      }
    ]
  };

The $template_content variable as defined above would be used to fill the
content of a template with markup similar to the following:

  <html>
    <head><title>My Template</title></head>
    <body>
      <p><singleline>Enter heading...</singleline></p>
      <div><multiline>Enter description...</multiline></div>
      <img id="header-image" editable="true" width="500" />
      <repeater>
        <layout label="My layout">
          <div class="repeater-item">
            <p><singleline></singleline></p>
            <div><multiline></multiline></div>
            <img editable="true" width="500" />
          </div>
        </layout>
      </repeater>
      <p><unsubscribe>Unsubscribe</unsubscribe></p>
    </body>
  </html>     


  my $campaign = $cm->campaigns_fromtemplate((
    'clientid'         => 'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2',
    'Name'             => 'My Campaign Name',
    'Subject'          => 'My Subject',
    'FromName'         => 'My Name',
    'FromEmail'        => 'myemail@mydomain.com',
    'ReplyTo'          => 'myemail@mydomain.com',
    'ListIDs'          => [
      'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1',
      'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1'
     ],
    'SegmentIDs'       => [   
      'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1',
      'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1'
     ],
     'TemplateID'      => '82938273928739287329873928379283',
     'TemplateContent' => $template_content,
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

=head2 campaigns_unschedule

L<Unscheduling a scheduled campaign|http://www.campaignmonitor.com/api/campaigns/#unscheduling_a_campaign>

  my $unscheduled = $cm->campaigns_unschedule((
    'campaignid'        => 'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2',
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

=head2 campaigns_summary

L<Campaign email client usage|http://www.campaignmonitor.com/api/campaigns/#campaign_email_client_usage>

  my $email_client_usage = $cm->campaigns_emailclientusage($campaign_id);

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

=head2 campaigns_spam

L<Campaign spam complaints|http://www.campaignmonitor.com/api/campaigns/#campaign_spam_complaints>

  my $campaign_spam = $cm->campaigns_spam (
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

=head2 client_drafts

L<Getting scheduled campaigns|http://www.campaignmonitor.com/api/clients/#scheduled_campaigns>

  my $client_scheduled = $cm->client_scheduled($client_id);

=head2 client_lists

L<Getting subscriber lists|http://www.campaignmonitor.com/api/clients/#getting_client_lists>

  my $client_lists = $cm->client_lists($client_id);

=head2 client_listsforemail

L<Getting lists for an email address|http://www.campaignmonitor.com/api/clients/#lists_for_email>

  my $lists = $cm->client_listsforemail((
    'clientid' => $client_id,
    'email'    => 'example@example.com',
  ));

=head2 client_segments

L<Getting segments|http://www.campaignmonitor.com/api/clients/#getting_client_segments>

  my $client_segments = $cm->client_segments($client_id);

=head2 client_idionlist

L<Getting suppression list|http://www.campaignmonitor.com/api/clients/#getting_client_suppressionlist>

  my $client_suppressionlist = $cm->client_suppressionlist((
    'clientid'       => $client_id,
    'page'           => '1',
    'pagesize'       => '100',
    'orderfield'     => 'email',
    'orderdirection' => 'asc',
  ));
  
=head2 client_suppress

L<Suppress email addresses|http://www.campaignmonitor.com/api/clients/#suppress_email_addresses>

  my $suppressed = $cm->client_suppress((
    'EmailAddresses' => [ 'example123@example.com', 'example456@example.com' ],
    'clientid' => $client_id,
  ));

=head2 client_unsuppress

L<Unsuppress an email address|http://www.campaignmonitor.com/api/clients/#unsuppress_an_email>

  my $unsuppressed = $cm->client_unsuppress((
    'email' => 'example123@example.com',
    'clientid' => $client_id,
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

=head2 client_transfercredits

L<Transfer credits to/from a client|http://www.campaignmonitor.com/api/clients/#transfer_credits>

  my $result = $cm->client_transfercredits((
    'clientid'                      => $client_id,
    'Credits'                       => '0',
    'CanUseMyCreditsWhenTheyRunOut' => 'true',
  ));

=head2 client_delete

L<Deleting a client|http://www.campaignmonitor.com/api/clients/#deleting_a_client>

  my $client_deleted = $cm->client_delete($client_id);
  
  
=head2 client_addperson 

L<Adds a new person to the client.|http://www.campaignmonitor.com/api/clients/#adding_a_person>

  my $person_email = $cm->client_addperson((
    'clientid'              => $client_id,
    'EmailAddress'          => "joe\@example.com",
    'Name'                  => "Joe Doe",
    'AccessLevel'           => 23,
    'Password'            => "safepassword"
    ));
  
=head2 client_updateperson 

L<Updates any aspect of a person including their email address, name and access level..|http://www.campaignmonitor.com/api/clients/#updating_a_person>

  my $person_email = $cm->client_updateperson((
    'clientid'              => $client_id,
    'email'             => "joe\@example.com",
    'EmailAddress'          => "joe.new\@example.com",
    'Name'                  => "Joe Doe",
    'AccessLevel'           => 23,
    'Password'            => "safepassword"
    ));

=head2 client_getpeople

L<Contains a list of all (active or invited) people associated with a particular client.|http://www.campaignmonitor.com/api/clients/#getting_client_people>

  my $client_access-settings = $cm->client_getpeople($client_id);
  
=head2 client_getperson

L<Returns the details of a single person associated with a client. |http://www.campaignmonitor.com/api/clients/#getting_client_person>

  my $person_details = $cm->client_getperson((
    'clientid'          => $client_id,
    'email'           => "joe\@example.com",
    )); 
  
=head2 client_deleteperson

L<Contains a list of all (active or invited) people associated with a particular client.|http://www.campaignmonitor.com/api/clients/#deleting_a_person>

  my $result = $cm->client_deleteperson((
    'clientid'          => $client_id,
    'email'           => "joe\@example.com",
    )); 
  
  
=head2 client_setprimarycontact

L<Sets the primary contact for the client to be the person with the specified email address.|http://www.campaignmonitor.com/api/clients/#setting_primary_contact>

  my $primarycontact_email = $cm->client_setprimarycontact((
    'clientid'          => $client_id,
    'email'           => "joe\@example.com",
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
    'UnsubscribeSetting'      => 'AllClientLists',
    'ConfirmedOptIn'          => 'false',
    'ConfirmationSuccessPage' => 'http://www.example.com/joined.html',
  ));
  
=head2 list_listid

L<List details|http://www.campaignmonitor.com/api/lists/#getting_list_details>

  my $list = $cm->list_listid($list_id);

L<Updating a list|http://www.campaignmonitor.com/api/lists/#updating_a_list>

  my $updated_list = $cm->list_listid((
    'listid'                    => $list_id,
    'Title'                     => 'Website Subscribers',
    'UnsubscribePage'           => 'http://www.example.com/unsubscribed.html',
    'UnsubscribeSetting'        => 'AllClientLists',
    'ConfirmedOptIn'            => 'false',
    'ConfirmationSuccessPage'   => 'http://www.example.com/joined.html',
    'AddUnsubscribesToSuppList' => 'true',
    'ScrubActiveWithSuppList'   => 'true',
  ));

=head2 list_stats

L<List stats|http://www.campaignmonitor.com/api/lists/#getting_list_stats>

  my $list_stats = $cm->list_stats($list_id);

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

=head2 list_unconfirmed

L<Unconfirmed subscribers|http://www.campaignmonitor.com/api/lists/#unconfirmed_subscribers>

  my $unconfirmed_subscribers = $cm->list_unconfirmed((
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

=head2 list_deleted

L<Deleted subscribers|http://www.campaignmonitor.com/api/lists/#deleted_subscribers>

  my $list_deleted_subscribers = $cm->list_deleted((
    'listid'         => $list_id,
    'date'           => '1900-01-01',
    'page'           => '1',
    'pagesize'       => '100',
    'orderfield'     => 'email',
    'orderdirection' => 'asc',
  ));

=head2 list_bounced

L<Bounced subscribers|http://www.campaignmonitor.com/api/lists/#bounced_subscribers>

  my $list_bounced_subscribers = $cm->list_bounced((
    'listid'         => $list_id,
    'date'           => '1900-01-01',
    'page'           => '1',
    'pagesize'       => '100',
    'orderfield'     => 'email',
    'orderdirection' => 'asc',
  ));

=head2 list_customfields

L<List custom fields|http://www.campaignmonitor.com/api/lists/#getting_list_custom_fields>

  my $list_customfields = $cm->list_customfields($list_id);

L<Creating a custom field|http://www.campaignmonitor.com/api/lists/#creating_a_custom_field>

  my $custom_field = $cm->list_customfields((
    'listid'    => $list_id,
    'FieldName' => 'Newsletter Format',
    'DataType'  => 'MultiSelectOne',
    'Options'   => [ "HTML", "Text" ],
  ));

=head2 list_customfields_update

L<Updating a custom field|http://www.campaignmonitor.com/api/lists/#updating_a_custom_field>

  my $updated_custom_field = $cm->list_customfields_update((
    'listid'         => $list_id,
    'customfieldkey' => '[NewsletterFormat]',
    'FieldName' => 'Renamed Newsletter Format',
    'VisibleInPreferenceCenter' => 'false',
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
    'RestartSubscriptionBasedAutoresponders' => 'true',
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

=head2 subscribers_update

L<Updating a subscriber|http://www.campaignmonitor.com/api/subscribers/#updating_a_subscriber>

  my $updated_subscriber = $cm->subscribers_update((
    'Resubscribe'  => 'true',
    'RestartSubscriptionBasedAutoresponders' => 'true',
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
        'Value' => '',
        'Key'   => 'interests',
        'Clear' => 'true'
      }
    ],
    'Name'         => 'Renamed Subscriber',
    'EmailAddress' => 'subscriber@example.com',
    'listid'       => $list_id,
    'email'        => 'subscriber@example.com'
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
            'Key' => '',
            'Clear' => 'true'
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
    'QueueSubscriptionBasedAutoResponders' => 'false',
    'RestartSubscriptionBasedAutoresponders' => 'true',
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

=head2 subscribers_delete

L<Deleting a subscriber|http://www.campaignmonitor.com/api/subscribers/#deleting_a_subscriber>

  my $deleted = $cm->subscribers_delete((
    'listid'        => $list_id,
    'email'         => 'subscriber@example.com',
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

Campaign Monitor <support@campaignmonitor.com>

=head1 AUTHOR

Jeffery Candiloro <jeffery@cpan.org>

=head1 COPYRIGHT

Copyright (c) 2012, Campaign Monitor  E<lt>support@campaignmonitor.com<gt>. All rights reserved.

Copyright (c) 2011, Jeffery Candiloro  E<lt>jeffery@cpan.org<gt>.  All rights reserved.

This program is free software; you can redistribute it and/or modify it under the same terms as Perl itself.

The full text of the license can be found in the LICENSE file included with this module.
