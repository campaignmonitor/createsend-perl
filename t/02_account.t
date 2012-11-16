#!/usr/bin/perl

use strict;
use Test::More tests => 4;
use Params::Util qw{_STRING};
use Net::CampaignMonitor;

my $api_key = '';
my $cm;

if ( Params::Util::_STRING($ENV{'CAMPAIGN_MONITOR_API_KEY'}) ) {
	
	$api_key = $ENV{'CAMPAIGN_MONITOR_API_KEY'};
	
	$cm = Net::CampaignMonitor->new({
			secure  => 1, 
			api_key => $api_key,
		  });
}

SKIP: {	
	skip 'Invalid API Key supplied', 4 if $api_key eq '';
		  
	ok( $cm->account_clients()->{'code'} eq '200', 'Clients' );

	ok( $cm->account_countries()->{'code'} eq '200', 'Countries' );

	ok( $cm->account_timezones()->{'code'} eq '200', 'Timezones' );

	ok( $cm->account_systemdate()->{'code'} eq '200', 'System Date' );
}