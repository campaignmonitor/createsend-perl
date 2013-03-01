#!/usr/bin/perl

use strict;
use Test::More;
use Test::Exception;
use Params::Util qw{_STRING};


if ( Params::Util::_STRING($ENV{'CAMPAIGN_MONITOR_API_KEY'}) ) {
	
	my $api_key = $ENV{'CAMPAIGN_MONITOR_API_KEY'};
	
	plan tests => 16;

	use_ok( 'Net::CampaignMonitor' );

  my $cm_secure_apikey = Net::CampaignMonitor->new({
    secure  => 1,
    api_key => $api_key,
  });

	my $cm_insecure_apikey = Net::CampaignMonitor->new({
    secure  => 0,
    api_key => $api_key,
  });

	my $cm_secure = Net::CampaignMonitor->new({
    secure  => 1,
  });

	my $cm_insecure = Net::CampaignMonitor->new({
    secure  => 0,
  });

  my $cm_flat = Net::CampaignMonitor->new(
    secure  => 0,
  );

  isa_ok( $cm_secure_apikey, 'Net::CampaignMonitor' );
  isa_ok( $cm_insecure_apikey, 'Net::CampaignMonitor' );
  isa_ok( $cm_secure, 'Net::CampaignMonitor' );
  isa_ok( $cm_insecure, 'Net::CampaignMonitor' );
  isa_ok( $cm_flat, 'Net::CampaignMonitor' );

  my $results = $cm_secure_apikey->account_clients();
  ok( Params::Util::_POSINT( $results->{code} ), 'Result code' );
  ok( Params::Util::_HASH( $results->{headers} ), 'Result headers' );
  ok( Params::Util::_ARRAY0( $results->{response} ), 'Result response' );
}

else {
	plan tests => 8;

	use_ok( 'Net::CampaignMonitor' );
}

# Get authorize_url excluding state
my $authorize_url = Net::CampaignMonitor->authorize_url(
  client_id => 8998879,
  redirect_uri => 'http://example.com/auth',
  scope => 'ViewReports,CreateCampaigns,SendCampaigns'
);

ok(Params::Util::_STRING($authorize_url), '$authorize_url is a string');
ok($authorize_url eq 'https://api.createsend.com/oauth?client_id=8998879&redirect_uri=http%3A%2F%2Fexample.com%2Fauth&scope=ViewReports%2CCreateCampaigns%2CSendCampaigns', '$authorize_url is as expected');

# Get authorize_url including state
$authorize_url = Net::CampaignMonitor->authorize_url(
  client_id => 8998879,
  redirect_uri => 'http://example.com/auth',
  scope => 'ViewReports,CreateCampaigns,SendCampaigns',
  state => 89879287
);

ok(Params::Util::_STRING($authorize_url), '$authorize_url is a string');
ok($authorize_url eq 'https://api.createsend.com/oauth?client_id=8998879&redirect_uri=http%3A%2F%2Fexample.com%2Fauth&scope=ViewReports%2CCreateCampaigns%2CSendCampaigns&state=89879287', '$authorize_url is as expected');

# Exchange OAuth token for access code - error case
throws_ok {
  my $token_details = Net::CampaignMonitor->exchange_token(
    client_id => -432109,
    client_secret => "not so secret",
    redirect_uri => "https://example.com",
    code => "code" ) }
  qr/^Error exchanging OAuth code for access token.*/,
  'exchange_token() should croak() if there is an error response from the OAuth receiver';


# Refresh OAuth token error case - no refresh token set
my $cm_refresh_error_no_token_set = Net::CampaignMonitor->new({
  secure  => 1
});

throws_ok {
  $cm_refresh_error_no_token_set->refresh_token() }
  qr/^Error refreshing OAuth token. No refresh token exists./,
  'refresh_token() should croak() if there is no refresh token set';

# Refresh OAuth token error case - no refresh token set
my $cm_refresh_error_from_post = Net::CampaignMonitor->new({
  secure  => 1,
  access_token => 'my access token',
  refresh_token => 'my refresh token'
});

throws_ok {
  $cm_refresh_error_from_post->refresh_token() }
  qr/^Error refreshing OAuth token. invalid_grant: Specified refresh_token was invalid or expired/,
  'refresh_token() should croak() if there is no refresh token set';
