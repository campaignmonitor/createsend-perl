#!/usr/bin/perl

use strict;
use Test::More tests => 13;
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
	skip 'Invalid API Key supplied', 13 if $api_key eq '';

	my %new_client = (
		'CompanyName'  => "ACME Limited",
		'ContactName'  => "John Doe",
		'EmailAddress' => "john\@example.com",
		'Country'      => "Australia",
		'TimeZone'     => "(GMT+10:00) Canberra, Melbourne, Sydney"
	);

	my $created_client = $cm->account_clients(%new_client);

	ok( $created_client->{'code'} eq '201', 'Client created' );

	my $client_id = $created_client->{'response'};

	my %basic_access_settings = (
		'AccessLevel' => '23',
		'clientid'    => $client_id,
	);

	my %access_settings = (
		'AccessLevel' => '23',
		'Username'    => 'jdoe',
		'Password'    => 'password',
		'clientid'    => $client_id,
	);

	my %paging_info = (
		'page'           => '1',
		'pagesize'       => '100',
		'orderfield'     => 'email',
		'orderdirection' => 'asc',
		'clientid'       => $client_id,
	);

	my %replace_client = (
		'CompanyName'  => "ACME Limited",
		'ContactName'  => "John Doe",
		'EmailAddress' => "john\@example.com",
		'Country'      => "Australia",
		'TimeZone'     => "(GMT+10:00) Canberra, Melbourne, Sydney",
		'clientid'     => $client_id
	);

	my %payg = (
		'Currency'               => 'AUD',
		'CanPurchaseCredits'     => 'false',
		'ClientPays'             => 'true',
		'MarkupPercentage'       => '20',
		'MarkupOnDelivery'       => '5',
		'MarkupPerRecipient'     => '4',
		'MarkupOnDesignSpamTest' => '3',
		'clientid'               => $client_id,
	);

	my %monthly = (
		'Currency'               => 'AUD',
		'ClientPays'             => 'true',
		'MarkupPercentage'       => '20',
		'clientid'               => $client_id,
	);

	ok( $cm->client_clientid($client_id)->{code} eq '200', 'Got client details' );
	ok( $cm->client_campaigns($client_id)->{code} eq '200', 'Got client sent campaigns' );
	ok( $cm->client_drafts($client_id)->{code} eq '200', 'Got client draft campaigns' );
	ok( $cm->client_lists($client_id)->{code} eq '200', 'Got client subscriber lists' );
	ok( $cm->client_segments($client_id)->{code} eq '200', 'Got client segments' );
	ok( $cm->client_suppressionlist(%paging_info)->{code} eq '200', 'Got client suppression list' );
	ok( $cm->client_templates($client_id)->{code} eq '200', 'Got client templates' );
	ok( $cm->client_setbasics(%replace_client)->{code} eq '200', 'Set client basics' );
	ok( $cm->client_setaccess(%access_settings)->{code} eq '200', 'Set client access settings' );
	ok( $cm->client_setaccess(%basic_access_settings)->{code} eq '200', 'Set client basic access settings' );
	ok( $cm->client_setpaygbilling(%payg)->{code} eq '200', 'Set client PAYG billing' );
	ok( $cm->client_setmonthlybilling(%monthly)->{code} eq '200', 'Set client monthly billing' );
}