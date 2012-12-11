#!/usr/bin/perl

use strict;
use Test::More tests => 11;
use Params::Util qw{_STRING};
use Net::CampaignMonitor;

my $api_key = '';
my $cm;

if ( Params::Util::_STRING($ENV{'CAMPAIGN_MONITOR_API_KEY'}) ) {
  $api_key = $ENV{'CAMPAIGN_MONITOR_API_KEY'};
  $cm = Net::CampaignMonitor->new({
    secure  => 1,
    api_key => $api_key,
    domain => (defined($ENV{'CAMPAIGN_MONITOR_DOMAIN'}) ?
      $ENV{'CAMPAIGN_MONITOR_DOMAIN'} : 'api.createsend.com'),
  });
}

SKIP: {	
	skip 'Invalid API Key supplied', 11 if $api_key eq '';

	ok( $cm->account_clients()->{'code'} eq '200', 'Clients' );
	ok( $cm->account_billingdetails()->{'code'} eq '200', 'Billing details' );
	ok( $cm->account_countries()->{'code'} eq '200', 'Countries' );
	ok( $cm->account_timezones()->{'code'} eq '200', 'Timezones' );
	ok( $cm->account_systemdate()->{'code'} eq '200', 'System Date' );

	my %new_admin = (
		'EmailAddress'         	=> "jane.admin\@example.com",
		'Name'                 	=> "Jane Doe"
	);

	my %update_admin = (
		'email'					=> "jane.admin\@example.com",
		'EmailAddress'         	=> "jane.new\@example.com",
		'Name'                 	=> "Jane Doeman"
	);

	my $admin_email = "jane.new\@example.com";	

	ok( $cm->account_addadmin(%new_admin)->{code} eq '201', 'Added new admin' );
	ok( $cm->account_updateadmin(%update_admin)->{code} eq '200', 'Updated admin' );
	ok( $cm->account_getadmins()->{code} eq '200', 'Got admins' );	
	ok( $cm->account_getadmin($admin_email)->{code} eq '200', 'Got admin' );
	ok( $cm->account_getprimarycontact()->{code} eq '200', 'Got admin primary contact' );
	ok( $cm->account_deleteadmin($admin_email)->{code} eq '200', 'Delete admin' );
	
}





