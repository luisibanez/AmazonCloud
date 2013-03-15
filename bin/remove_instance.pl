#!/usr/bin/perl

use warnings;
use strict;
use File::Basename;
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
get_target($instanceName);

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

#
# Function to check if the enviornment has been set, if not run ". env.sh"
#
sub checkEnvironments
{
	# check to see if AWS_ACCESS_KEY and AWS_SECRET_KEY variables are set 
	if ((length($ENV{'AWS_ACCESS_KEY'}) == 0) || (length($ENV{'AWS_SECRET_KEY'}) == 0)) {
		print "\nPlease set your AWS_ACCESS_KEY and AWS_SECRET_KEY environment variables - see README file on how to do this.\n\n";
		exit(1);
	}
}

#
# Function to get the instnaces' IDs.
#
sub get_target {

	my $instanceName = shift;

	# Find the instacne that we want to delete and collect the output
	my $cmdOut = `ec2-describe-instances | grep "$instanceName"`;
	my $allInstance = "";
	my $counter = 1;
	my %ID_table;
	my $instanceID;
	my $instanceURL;
	my $index;
	my $ans;

	# Construct ID_table
	if (length($cmdOut) == 0) {

		print "\nWARNING: ";
		print "\n\tThere does not exist instances with the given INSTANCE_NAME: $instanceName";
		print "\n\tMaybe all the instances with the given name have been terminated";
		print "\n\tPlease check your config file to make sure INSTANCE_NAME is defined to the name you want ... ";
		print "\n\nAbort(1)\n\n";
		exit (1);

	} else {

		my @line = split("\n", $cmdOut);
		foreach my $i (@line) {
			if ($i =~ /^TAG/ && $i =~ /$instanceName/) {
				my @target = split("\t", $i);
				$instanceID = $target[2];
				$instanceURL = GetURL($instanceID);
				# Check if the instance is still running or terminated
				if (length($instanceURL) == 0) {
					$instanceURL = "Terminated";
				}
				# Concatenate two striing variables and return a newe string representing specific instances 
				$allInstance = $instanceID." ".$allInstance;
				my $instance = $instanceID." ".$instanceURL;
				$ID_table{$counter} = $instance;
				$counter++;
			}
		}
		# Add remove_all / exit option
		$ID_table{"A"} = "Terminate All";
		$ID_table{"Q"} = "Exit";

	}

	# Check the size of the ID_table
	my $hash_size = keys %ID_table;

	# Prompt to let user choose which instance to terminate
	if ($hash_size == 3) {
		return $ID_table{"1"};
	} else {
		print "\n\nThere are more than one instances with the same INSTANE_NAME: $instanceName\.";
		START:
		print "\nPlease choose which one to terminate:\n";
		foreach my $key (sort keys %ID_table){
			print "\n$key).  $ID_table{$key}";
		}
		print "\n\nPlease select instance that you would like to terminate (0, 1, 2, ... ): ";
		chomp($index = <STDIN>);

		# Validate user inputs
		if ($index eq "Q" || $index eq "q") {
			print "\n\t-  Action has been canceled.";
			print "\n\t-  No instance is terminated.\n\n";
			exit (0);
		} elsif ($index eq "A" || $index eq "a") {
			print "\nTerminating wrong instances could potentially make your life mesirable\.\n";
			print "I have accidentally terminated wrong instance. I got suspended from using AWS for 3 months :( !\n";
			print "Please be extra cautious !!\n";	
			print "Are you sure you want to terminate all instance [Y/n] ? ";
			chomp($ans = <STDIN>);
		} elsif ($index ne "Q" && !looks_like_number($index)) {
			print "\n\t-  Invalid inputs ...\n";
			goto START;
		} elsif ($index > ($hash_size - 2)) {
			print "\n\t-  Selected instance does not exist.\n";
			goto START;
		} else {
			print "\nTerminating wrong instances could potentially make your life mesirable\.\n";
			print "I have accidentally terminated wrong instance. I got suspended from using AWS for 3 months :( !\n";
			print "Please be extra cautious !!\n";	
			print "Are you sure \" $index: $ID_table{$index} \" is the instance that you want to terminate [Y/n] ? ";
			chomp($ans = <STDIN>);
		}
	}
	if ($ans eq "y" || $ans eq "Y") {
		if ($index eq "A" || $index eq "a") {
			delete_instnace($allInstance, $index);
		} else {
			delete_instnace($ID_table{$index}, $index);
		}
	} else {
		print "\n-  Action has been canceled.";
		print "\n-  No instance is terminated.\n\n";
		exit (0);
	}

}


sub check_termination_status {

	my $timer = shift;
	my $instance_to_delete = shift;
	my @cmdOut = shift;
	my $complete;

	#sleep for 3s before trying again
	sleep 3;
	# Deleting the instance and collect the output
	@cmdOut = `ec2-terminate-instances $instance_to_delete`;
	foreach my $i (@cmdOut) {
		my @line = split(" ", $i);
		my $previous_status = $line[2];
		chomp($previous_status);
		my $current_status = $line[3];
		chomp($current_status);
		if ($previous_status eq "terminated" && $current_status eq "terminated") {
			$complete = 1;
		} elsif ($previous_status ne "terminated" || $current_status ne "terminated"){
			$complete = 0;
			return ($complete, $timer);
		}
		 elsif ($timer == 0) {
			# After 120s (2 mins) has passed, we will automatially bounce the execution due to excessive time spent on waiting for response.
			print "\nUnable to delete instances. Please contact Amazon or terminate your instance through Amazon's web ineterface\n\n";
			exit (2);
		} else {
			$timer --; 
		}
	}

	return ($complete, $timer);

}



sub delete_instnace {

	#
	my $complete = 0;
	my $timer = 40;
	my @cmdOut;

	# Collect necessary information about the instnace before proceed with deletion
	my $instance_to_delete = shift;
	my $signle_all = shift;


	if ($signle_all eq "A") {
		
		print "\nDeleting all instances ... it may take a few secons ... \n\n";
		@cmdOut = `ec2-terminate-instances $instance_to_delete`;
		if ($? == 0) {
			while (!$complete) {
				($complete, $timer) = check_termination_status($timer, $instance_to_delete, \@cmdOut);
			}
			print "\nAll instances have been terminated ... Done ...\n\n";
		}

	} else {

		my @target = split(" ", $instance_to_delete);
		my $instance_to_delete = $target[0];
		my $instanceStatus = $target[1];
	
		if ($instanceStatus eq "Terminated") {
			print "\nInstance name: $instanceName \($instance_to_delete\) has alread been terminated ... ";
			print "\nNo action requires!\n\n";
			exit (0);
		}

		print "\nDeleting instance: $instanceName \($instance_to_delete\) ... it may take a few secons ... \n\n";
		# Deleting the instance and collect the output
		@cmdOut = `ec2-terminate-instances $instance_to_delete`;
		if ($? == 0) {
		
			while (!$complete) {
				($complete, $timer) = check_termination_status($timer, $instance_to_delete, \@cmdOut);
			}
			print "\nInstance: $instance_to_delete has been terminated ... Done ...\n\n";

		} else {
			print "ERROR: Invalid instanceID: $instance_to_delete ... \n\n";
			exit (2);
		}
	}

}

#
# Function used to output the url used for cloudman and ssh
#
sub GetURL 
{
	my $instanceID = shift;
	my @cmdOutput;
	my $URL;
	my $complete = 0;

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
# Function which prints out the proper format of the function when the inputs are given incorrectly
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