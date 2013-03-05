#!/usr/bin/perl

use warnings;
use strict;

#
# written by the following people from modENCODE DCC group:
# Fei-Yang(Arthur) Jen, arthur20249@gmail.com
# Quang Trinh, quang.trinh@gmail.com
#

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
my $instanceName = parseOptions($configFile);
	
#print out existing options
printf ("\nTerminating instance with the following information as defined in config file '$ARGV[0]':");
printf ("\n %-15s \t %-30s", "INSTANCE_NAME:", $instanceName);
print "\n";

# Delete the instnace
delete_instnace($instanceName);


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
		@line = split(" ", $i);
		if($i =~ /^INSTANCE_NAME:/)
		{
			$instanceName = $line[1];
		} 
	}
	close FILE;
	return $instanceName;

}

#function to check if the enviornment has been set, if not run ". env.sh"
sub checkEnvironments
{
	# check to see if AWS_ACCESS_KEY and AWS_SECRET_KEY variables are set 
	if ((length($ENV{'AWS_ACCESS_KEY'}) == 0) || (length($ENV{'AWS_SECRET_KEY'}) == 0)) {
		print "\nPlease set your AWS_ACCESS_KEY and AWS_SECRET_KEY environment variables - see README file on how to do this.\n\n";
		exit(1);
	}
}

sub getInstanceID {

	my $instanceName = shift;

	# Find the instacne that we want to delete and collect the output
	my $cmdOut = `ec2-describe-instances | grep "$instanceName"`;
	my $instanceID = "";

	if (length($cmdOut) == 0) {
		print "\nERROR: ";
		print "\n\tThere does not exist an instance with the given INSTANCE_NAME: $instanceName in the config.txt";
		print "\n\tPlease check your config file ... \n\n";
		exit (2);
	} else {

		my @line = split("\n", $cmdOut);
		foreach my $i (@line) {
			if ($i =~ /^TAG/ && $i =~ /$instanceName/) {
				my @target = split("\t", $i);
				$instanceID = $target[2];
				return $instanceID;
			}
		}
	}
}


sub delete_instnace {
	my $instanceName = shift;
	my $instanceID = getInstanceID($instanceName);
	my $complete = 0;
	my $counter = 40;
	my $cmdOut;

	print "\nDeleting instance: $instanceName \($instanceID\) ... it may take a few secons ... \n\n";
	# Deleting the instance and collect the output
	$cmdOut = `ec2-terminate-instances $instanceID`;
	if ($? == 0) {
		
		while (!$complete) {
	
			#sleep for 3s before trying again
			sleep 3;
			# Deleting the instance and collect the output
			$cmdOut = `ec2-terminate-instances $instanceID`;
			my @line = split("\t", $cmdOut);
			my $previous_status = $line[2];
			chomp($previous_status);
			my $current_status = $line[3];
			chomp($current_status);
			
			if ($previous_status eq "terminated" && $current_status eq "terminated") {
		 		$complete = 1;
		 	} elsif ($counter == 0) {
		 		# After 120s (2 mins) has passed, we will automatially bounce the execution due to excessive time spent on waiting for response.
		 		print "\nUnable to delete instance: $instanceID. Please contact Amazon or terminate your instance through Amazon's web ineterface\n\n";
		 		exit (2);
		 	}
		 	else {
		 		$counter --; 
		 	}

		}
		print "\nInstnace: $instanceID has been terminated ... Done ...\n\n";

	} else {
		print "ERROR: Invalid instanceID: $instanceID ... \n\n";
		exit (2);
	}

}

#
#function which prints out the proper format of the function when the inputs are given incorrectly
#
sub usage
{
	print "\n";
	print "This script creates an instance of an AMI on Amazon Cloud. Please send questions/comments to help\@modencode.org.";
	print "\n\n\tusage: perl " . basename($0) . "  [ CONFIG_FILE ] ";
	print "\n\n\t\tFor example: \t $0 config.txt";
	print "\n\n";
	exit (2);
}





