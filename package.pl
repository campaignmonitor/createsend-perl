#!/usr/bin/perl

if (@ARGV < 1) {
	print ("Usage: package.pl <version number> \ne.g. package.pl 1.03");
	exit;
}
my $version = $ARGV[0];

# ensure that the version number in the module is the same as passed argument
my $moduleVersion = `grep VERSION ./lib/Net/CampaignMonitor.pm`;
if ($moduleVersion !~ m/$version/) {
	print ('Error: $VERSION set in Net/CampaignMonitor.pm is not version '.$version);
	exit;
}

# show warning if Changes file hasn't been updated with version description
my $changeDesc = `grep $version ./Changes`;
if ($changeDesc !~ m/$version/) {
	print ('Warning: Changes file does not contain version '.$version."\n");
}

my $package = "Net-CampaignMonitor";
my $packageName = $package."-".$version;

if (-e "../$packageName")	{
	`rm -rf ../$packageName`;
}
`mkdir ../$packageName`;
`cp -r * ../$packageName/.`;

`cd .. && tar cvPf $packageName.tar $packageName --exclude .git --exclude .gitignore --exclude .travis.yml --exclude package.pl; gzip $packageName.tar`;
`rm -rf ../$packageName`;

print "Successfully created distribution ../$packageName.tar.gz" 