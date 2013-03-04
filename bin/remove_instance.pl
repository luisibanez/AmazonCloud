#!/usr/bin/perl

use warnings;
use strict;


#function calls
#=================================================================
if(@ARGV != 1)
{
	usage();
}

# Set config file's name
my $configFile = $ARGV[0];

# Check for AWS security key
checkEnvironments();

# Parse the config file
my ($ami, $keyPair, $securityGroup, $instanceType, $region, $availabilityZone, $instanceName, $authorizedPort) = parseOptions($configFile);

# modENCODE AMI is only supported in US EAST region
if (((length($region) > 0) && ($region !~ /east/)) 
	|| ((length($availabilityZone) > 0) && ($availabilityZone !~ /east/)))
{
	print "\n\nAt the moment, modENCODE AMI is supported only in US East region!  Please change your configuration!\n\n";
	exit (1);
}
	
# get the default region and availability zone if users didn't put them in config file
if ((length($region) == 0) || (length($availabilityZone)==0)) 
{
	($region, $availabilityZone) = getRegionAndAvailableZone();
}

if ( (length($keyPair) == 0) || (length($securityGroup) == 0) || (length($instanceType) == 0) || (length($instanceName) == 0) || (length($ami) == 0) ) {
	print "\n\nPlease check your config file and make sure all options are defined!\n\n";
	exit (1);
}
	
#print out existing options
printf ("\nLaunching modENCODE instance with the following information as defined in config file '$ARGV[0]':");
printf ("\n %-15s \t %-30s", "AMI:", $ami);
printf ("\n %-15s \t %-30s", "INSTANCE_NAME:", $instanceName);
printf ("\n %-15s \t %-30s", "KEY_PAIR:", $keyPair);
printf ("\n %-15s \t %-30s", "SECURITY_GROUP:", $securityGroup);
printf ("\n %-15s \t %-30s", "INSTANCE_TYPE:", $instanceType);
printf ("\n %-15s \t %-30s", "REGION:", $region);
printf ("\n %-15s \t %-30s", "AVAILABILITY_ZONE:", $availabilityZone);
printf ("\n %-15s \t %-30s", "AUTHORIZED_PORTS:", $authorizedPort);
print "\n";


#function declarations
#=================================================================

sub parseOptions
{
	#assign config filename, open and read its contents into an array
	my $filename = shift;
	my @line;
	my @options;

	open FILE, $filename or die "Could not find ${filename}\n";
	@options = <FILE>;

	#more options maybe added later in configuration file following format of:
	#	label: value
	foreach my $i (@options)
	{
		@line = split(" ", $i, 2); #split into only two fields. 
		if($i =~ /^AMI:/)
		{
			$ami = $line[1];
			chomp($ami);
		}
		elsif($i =~ /^KEY_PAIR:/)
		{
			$keyPair = $line[1];
			chomp($keyPair);
		}
		elsif($i =~ /^SECURITY_GROUP:/)
		{
			$securityGroup = $line[1];
			chomp($securityGroup);
		}
		elsif($i =~ /^INSTANCE_TYPE:/)
		{
			$instanceType = $line[1];
			chomp($instanceType);
		}
		elsif($i =~ /^REGION:/)
		{
			$region = $line[1];
			chomp($region);
		}
		elsif($i =~ /^AVAILABILITY_ZONE:/)
		{
			$availabilityZone = $line[1];
			chomp($availabilityZone);
		}
		elsif($i =~ /^INSTANCE_NAME:/)
		{
			$instanceName = $line[1];
			chomp($instanceName);
		} 
		elsif($i =~ /^AUTHORIZED_PORTS:/)
		{
			$authorizedPort = $line[1];
			chomp($authorizedPort);
		}
	}
	close FILE;
	return ($ami, $keyPair, $securityGroup, $instanceType, $region, $availabilityZone, $instanceName, $authorizedPort);

}