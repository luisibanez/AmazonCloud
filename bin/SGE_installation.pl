#!/usr/bin/perl

use warnings;
use strict;
use Data::Dumper;
use feature 'say';



if (@ARGV != 1) {
	usage();
}


my $configFile = $ARGV[0];



my ($keyPair, $securityGroup, $instanceName, $numberOfInstance, $instanceType, $region, $availabilityZone) = parseOption($configFile);

#print out attributes defined in config file 
printf ("\nInstalling SGE with the following attributes as defined in config file '$ARGV[0]':");
printf ("\n %-15s \t %-30s", "INSTANCE_NAME:", $instanceName);
printf ("\n %-15s \t %-30s", "KEY_PAIR:", $keyPair);
printf ("\n %-15s \t %-30s", "SECURITY_GROUP:", $securityGroup);
printf ("\n %-15s \t %-30s", "INSTANCE_TYPE:", $instanceType);
printf ("\n %-15s \t %-30s", "REGION:", $region);
printf ("\n %-15s \t %-30s", "AVAILABILITY_ZONE:", $availabilityZone);
printf ("\n %-15s \t %-30s", "NUMBER_OF_INSTANCES:", $numberOfInstance);
print "\n\n";

=head
my %test_URL = id_and_instanceURL_table($instanceName);
foreach my $key (keys %test_URL) {
	printf ("\nInstance_Name: $key\tURL: $test_URL{$key}");
}
print "\n\n";
=cut

Install_SGE($instanceName, $instanceType);



sub parseOption {

	my $filename = shift;
	my @line;
	my @options;

	open FILE, $filename or die "Cloud not open $filename";
	@options = <FILE>;


	foreach my $i (@options) {

		@line = split(" ", $i);	
		if ($i =~ /^KEY_PAIR:/) {
			$keyPair = $line[1];
		} elsif ($i =~ /^SECURITY_GROUP:/) {
			$securityGroup = $line[1]; 
		} elsif ($i =~ /^INSTANCE_NAME:/) {
			$instanceName = $line[1];
		} elsif ($i =~ /^NUMBER_OF_INSTANCES:/) {
			$numberOfInstance = $line[1];
		} elsif ($i =~ /^INSTANCE_TYPE:/){
			$instanceType = $line[1];
		} elsif ($i =~ /^REGION:/) {
			$region = $line[1];
		} elsif ($i =~ /^AVAILABILITY_ZONE:/) {
			$availabilityZone = $line[1];
		}		

	}
	close FILE;

	return ($keyPair, $securityGroup, $instanceName, $numberOfInstance, $instanceType, $region, $availabilityZone);

}


sub GetCPU {
	
	my $instanceType = shift;
	my $numCores;

	if ($instanceType eq "t1.micro") {
		$numCores = 1;
	} elsif ($instanceType eq "m1.small") {
		$numCores = 1;
	} elsif ($instanceType eq "m1.medium") {
		$numCores = 2;
	} elsif ($instanceType eq "m1.large") {
		$numCores = 4;
	} elsif ($instanceType eq "m1.xlarge"){
		$numCores = 8;
	} elsif ($instanceType eq "m3.xlarge") {
		$numCores = 13;
	} elsif ($instanceType eq "m3.2xlarge") {
		$numCores = 26;
	} elsif ($instanceType eq "m2.xlarge") {
		$numCores = 6.5;
	} elsif ($instanceType eq "m2.2xlarge") {
		$numCores = 13;
	} elsif ($instanceType eq "m2.4xlarge") {
		$numCores = 26;
	} elsif ($instanceType eq "c1.medium") {
		$numCores = 5;
	} elsif ($instanceType eq "c1.xlarge") {
		$numCores = 20;
	} elsif ($instanceType eq "hs1.8xlarge") {
		$numCores = 35;
	}

	return $numCores;
}


sub GetURL {
	
	my $instanceID = shift; 
	my $instanceName = shift; # For Error checking.
	my $URL = "";
	my $intHostname = "";
	my $IP;

	my $cmd = `ec2-describe-instances $instanceID | grep INSTANCE`;

	if (($cmd =~ /^INSTANCE/) && ($cmd =~ /running/)) {
		my @instance_info = split("\t", $cmd);
		$URL = $instance_info[3];
		$intHostname = $instance_info[4];
		$IP = $instance_info[17];
	} else {
		print "\nWARNING:";
		print "\n\tCurrent instance: $instanceName \($instanceID\) is either terminated or shutting-down.";
		print "\n\tSkipping this instance for SGE installation ... Continue ...\n\n";
	}
	return ($URL, $intHostname, $IP);
}



sub Get_Instance_Info_Hash {
	
	my $instancePrefix = shift;
	my $counter = 0;
	my %Info_hash;

	# Instance's infomation
	my $instanceName;
	my $instanceID;
	my $instanceURL;
	my $instanceRole;
	my $intHostname;
	my $intIP;

	my $cmd = `ec2-describe-instances | grep "$instancePrefix" | grep TAG`;
	if (length($cmd) == 0) {
		print "\nWARNING: ";
		print "\n\tThere does not exist an instance with the given INSTANCE_NAME: $instancePrefix in the config.txt";
		print "\n\tPlease check your config file make sure there are instances running before configuring SGE Cluster... \n\n";
		exit (1);
	}

	my @num_Instances = split("\n", $cmd);
	foreach my $i (@num_Instances) {
		my @current_instance = split("\t", $i);
		
		# Configure instance ID
		$instanceID = $current_instance[2];

		# Configure instance URL and internal hostname
		($instanceURL, $intHostname, $intIP) = GetURL($instanceID, $instanceName);
		
		if ($instanceURL ne "") {
			
			# Configure instance name and role. 
			if ($counter == 0) {
				$instanceRole = "master";
				$instanceName = $instancePrefix."_".$instanceRole;
				$counter++;
			} else {
				$instanceRole = "compute";
				$instanceName = $instancePrefix."_".$instanceRole."_".$counter;
				$counter++;
			}
			$Info_hash{$instanceURL}{"Internal_HostName"} = $intHostname;
			$Info_hash{$instanceURL}{"Internal_IP"} = $intIP;
			$Info_hash{$instanceURL}{"Name"} = $instanceName;
			$Info_hash{$instanceURL}{"ID"} = $instanceID;
			$Info_hash{$instanceURL}{"Role"} = $instanceRole;
		}
		

	}

	return %Info_hash;

}



sub Install_SGE {
	
	# Arguments
	my $instancePrefix = shift;
	my $instanceType = shift;

	my %instance_info = Get_Instance_Info_Hash($instancePrefix);

	print Dumper(\%instance_info);
	# Other varaiables
	my $separator = 0;
	my $numCores = GetCPU($instanceType);
	my $current_instance_URL;
=head
	foreach my $k (keys %URL_intHost_hash) {
		if ($separator == 0) {
			# This is Master
			$current_instance_URL = $k;


			$separator++; 
		}
	}
=cut
}

