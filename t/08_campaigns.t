#!/usr/bin/perl

use strict;
use Test::More tests => 11;
use Net::CampaignMonitor;
use Params::Util qw{_STRING};

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
	skip 'Invalid API Key supplied', 11 if $api_key eq '';

	my $client_id = $cm->account_clients()->{response}->[0]->{ClientID};
	my $list_id   = $cm->client_lists($client_id)->{response}->[0]->{ListID};

	my %campaign = (
		  'ListIDs' => [
				 $list_id,
			       ],
		  'FromName' => 'My Name',
		  'TextUrl' => 'http://media.netcomm.com.au/public/assets/file/0003/70833/full_width.html',
		  'Subject' => 'My Subject',
		  'HtmlUrl' => 'http://media.netcomm.com.au/public/assets/file/0003/70833/full_width.html',
		  'SegmentIDs' => [],
		  'FromEmail' => 'myemail@mydomain.com',
		  'Name'      => 'My Campaign Name'.time,
		  'ReplyTo'   => 'myemail@mydomain.com',
		  'clientid'  => $client_id
		);

	my $created_campaign = $cm->campaigns(%campaign);

	ok( $created_campaign->{code} eq '201', 'Draft campaign created' );

	my $campaign_id = $created_campaign->{response};

	my %campaign_send = (
		  'SendDate'          => '2011-12-01 00:01',
		  'ConfirmationEmail' => 'myemail@mydomain.com',
		  'campaignid'        => $campaign_id
	);

	my %campaign_sendpreview = (
		  'PreviewRecipients' => [
					   'test1@example.com',
					   'test2@example.com'
					 ],
		  'Personalize'       => 'Random',
		  'campaignid'        => $campaign_id
	);

	my %paging_info = (
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
		'campaignid'     => $campaign_id,
	);

	my %paging_info_date = (
		'date'           => '1900-01-01',
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
		'campaignid'     => $campaign_id,
	);

	ok( $cm->campaigns_send(%campaign_send)->{code} eq '200', 'Campaign send' );
	ok( $cm->campaigns_sendpreview(%campaign_sendpreview)->{code} eq '200', 'Campaign send previews' );
	ok( $cm->campaigns_summary($campaign_id)->{code} eq '200', 'Campaign summary' );
	ok( $cm->campaigns_listsandsegments($campaign_id)->{code} eq '200', 'Campaign lists and segments' );
	ok( $cm->campaigns_recipients(%paging_info)->{code} eq '200', 'Campaign recipients' );
	ok( $cm->campaigns_bounces(%paging_info)->{code} eq '200', 'Campaign bounces' );
	ok( $cm->campaigns_opens(%paging_info_date)->{code} eq '200', 'Campaign opens' );
	ok( $cm->campaigns_clicks(%paging_info_date)->{code} eq '200', 'Campaign clicks' );
	ok( $cm->campaigns_unsubscribes(%paging_info_date)->{code} eq '200', 'Campaign unsubscribes' );
	ok( $cm->campaigns_delete($campaign_id)->{code} eq '200', 'Campaign deleted' );
}