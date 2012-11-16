createsend-perl
===============

A Perl library for the Campaign Monitor API 

## Installation and usage
 
Download and install using CPAN, e.g.

	cpan Net::CampaignMonitor

Include the module in the required script and initialise using your API key: 	
	 
	use Net::CampaignMonitor;
	my $cm = Net::CampaignMonitor->new({
                api_key => 'abcd1234abcd1234abcd1234',
                secure  => 1,
                timeout => 300,
                });

All methods return a hash containing the Campaign Monitor response code, the headers and the actual response.
        
		my %results = (
                code     => '',
                response => '',
                headers  => ''
        );
		
Samples for each of the methods and further documentation is available on CPAN or perldocs, e.g.

	perldoc Net::CampaignMonitor
	
## Contributing
1. Fork the repository
2. Make your changes, including tests for your changes.
3. Ensure that the build passes, by running all the tests in the .\t directory.
4. It should go without saying, but do not increment the version number in your commits.
5. Submit a pull request.