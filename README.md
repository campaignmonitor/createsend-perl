# createsend-perl [![Build Status](https://secure.travis-ci.org/campaignmonitor/createsend-perl.png?branch=master)][travis]
A Perl library for the [Campaign Monitor API](http://www.campaignmonitor.com/api/).

[travis]: http://travis-ci.org/campaignmonitor/createsend-perl

## Installation

Download and install using CPAN:

```
cpan Net::CampaignMonitor
```

## Authenticating

The Campaign Monitor API supports authentication using either OAuth or an API key.

### Using OAuth

TODO: Instructions...

Once you have an access token and refresh token for your user, you can authenticate and make further API calls like so:

```perl
use Net::CampaignMonitor;
my $cm = Net::CampaignMonitor->new({
  access_token => 'your access token',
  refresh_token => 'your refresh token',
  secure  => 1,
});
my $clients = $cm->account_clients();
```

All OAuth tokens have an expiry time, and can be renewed with a corresponding refresh token. If your access token expires when attempting to make an API call, your code should handle the case when a `401 Unauthorized` response is returned with a Campaign Monitor error code of `121: Expired OAuth Token`. Here's an example of how you could do this:

```perl
use Net::CampaignMonitor;
my $cm = Net::CampaignMonitor->new({
  access_token => 'your access token',
  refresh_token => 'your refresh token',
  secure  => 1,
});
my $clients = $cm->account_clients();

# If you receive '121: Expired OAuth Token', refresh the access token
if ($clients->{code} eq '401' && $clients->{response}->{Code} eq '121') {
  my $result = $cm->refresh_token();
  # Save $result->{access_token}, $result->{expires_in}, and $result->{refresh_token}
  $clients = $cm->account_clients(); # Make the call again
}
```

### Using an API key

```perl
use Net::CampaignMonitor;
my $cm = Net::CampaignMonitor->new({
  api_key => 'abcd1234abcd1234abcd1234',
  secure  => 1,
});
my $clients = $cm->account_clients();
```

All methods return a hash containing the Campaign Monitor response code, the headers and the actual response.

```perl
my %results = (
  code     => '',
  response => '',
  headers  => ''
);
```

Samples for each of the methods and further documentation is available on CPAN or perldocs, e.g.

```
perldoc Net::CampaignMonitor
```

## Contributing
1. Fork the repository
2. Make your changes, including tests for your changes.
3. Ensure that the build passes, by running:

    ```
    export CAMPAIGN_MONITOR_API_KEY={Your API key to use for running the tests}
    cpanm --quiet --installdeps --notest .
    perl Makefile.PL && make test
    ```

    CI runs on: `5.10`, `5.12`, `5.14`, and `5.16`.

4. It should go without saying, but do not increment the version number in your commits.
5. Submit a pull request.