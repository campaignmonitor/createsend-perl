#!/usr/bin/perl

use strict;
use Test::More;
use Params::Util qw{_STRING};

if ( Params::Util::_STRING($ENV{'CAMPAIGN_MONITOR_API_KEY'}) ) {
	
	my $api_key = $ENV{'CAMPAIGN_MONITOR_API_KEY'};
	
	plan tests => 5;

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

	isa_ok( $cm_secure_apikey, 'Net::CampaignMonitor' );
	isa_ok( $cm_insecure_apikey, 'Net::CampaignMonitor' );
	isa_ok( $cm_secure, 'Net::CampaignMonitor' );
	isa_ok( $cm_insecure, 'Net::CampaignMonitor' );
}

else {
	plan tests => 1;

	use_ok( 'Net::CampaignMonitor' );
}