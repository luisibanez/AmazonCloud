#!/usr/bin/perl

use warnings;
use strict;
use Scalar::Util qw(looks_like_number);

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
	my %ID_table;
	my $counter = 0;
	my $instanceID;
	my $instanceURL;
	my $index;
	my $ans;

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
				$instanceURL = GetURL($instanceID);

				if (length($instanceURL) == 0) {
					$instanceURL = "Terminated";
				}

				my $instance = $instanceID." ".$instanceURL;
				$ID_table{$counter} = $instance;
				$counter++;
			}
		}
		# Add exit option
		$ID_table{"Q"} = "Exit";
	}

	# Check the size of the ID_table
	my $hash_size = keys %ID_table;
	# Prompt to let user choose which instance to terminate
	if ($hash_size == 1) {
		return $ID_table{0};
	} else {
		print "\n\nThere are more than one instances with the same INSTANE_NAME: $instanceName\.";
		START:
		print "\nPlease choose which one to terminate:\n";
		foreach my $key (sort keys %ID_table){
			print "\n$key).  $ID_table{$key}";
		}
		print "\n\nPlease select which instance you would like to terminate (0, 1, 2, ... ): ";
		chomp($index = <STDIN>);

		# Validate user inputs
		if ($index eq "Q") {
			print "\nAction has been canceled.";
			print "\nNo instance is terminated.\n\n";
			exit (0);
		} elsif ($index ne "Q" && !looks_like_number($index)) {
			print "\nInvalid inputs ...\n";
			goto START;
		} elsif ($index > ($hash_size - 2)) {
			print "\nSelected instance does not exist.";
			goto START;
		}


		print "\nTerminating wrong instances could potentially make your life mesirable\.\n";
		print "Are you sure \"$index: $ID_table{$index}\" is the instance that you want to terminate [Y/n] ? ";
		chomp($ans = <STDIN>);
	}
	if ($ans eq "y" || $ans eq "Y") {
		return $ID_table{$index};
	} else {
		print "\nAction has been canceled.";
		print "\nNo instance is terminated.\n\n";
		exit (0);
	}

}


sub delete_instnace {
	my $instanceName = shift;
	my $instance = getInstanceID($instanceName);
	my $complete = 0;
	my $counter = 40;
	my $cmdOut;

	my @line = split(" ", $instance);
	my $instanceID = $line[0];
	print "\nDeleting instance: $instanceName \($instanceID\) ... it may take a few secons ... \n\n";
	# Deleting the instance and collect the output
	$cmdOut = `ec2-terminate-instances $instanceID`;
	if ($? == 0) {
		
		while (!$complete) {
	
			#sleep for 3s before trying again
			sleep 3;
			# Deleting the instance and collect the output
			$cmdOut = `ec2-terminate-instances $instanceID`;
			my @line = split(" ", $cmdOut);
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
#sub function used to output the url used for cloudman and ssh
#
sub GetURL 
{
	my $instanceID = shift;
	my @cmdOutput;
	my $URL;
	my $complete = 0;
	my @fields;

	while (!$complete) 
	{
	
		@cmdOutput = `ec2-describe-instances $instanceID`;
		foreach my $line (@cmdOutput)
		{
			if (($line =~ /^INSTANCE/) && ($line =~ /running/)) {
				my @f = split("\t",$line);
				$URL = $f[3];
				$complete = 1;
			} elsif (($line =~ /^INSTANCE/) && ($line =~/terminated/)) {
				$complete = 1;
			}
		}
	}
	return $URL;
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





