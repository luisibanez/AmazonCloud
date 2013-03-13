#!/usr/bin/perl

use warnings;
use strict;




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

	my $cmd = `ec2-describe-instances $instanceID | grep INSTANCE`;

	if (($cmd =~ /^INSTANCE/) && ($cmd =~ /running/)) {
		my @instance_info = split("\t", $cmd);
		$URL = $instance_info[3];
		$intHostname = $instance_info[4];
	} else {
		print "\nWARNING:";
		print "\n\tCurrent instance: $instanceName \($instanceID\) is either terminated or shutting-down.";
		print "\n\tSkipping this instance for SGE installation ... Continue ...\n\n";
	}
	return ($URL, $intHostname);
}



sub InstanceInfo_hash {
	
	my $instanceName = shift;
	my %URL_intHost_table;
	
	my %intHost_ID_table;
	my $instanceID;
	
	my $instanceURL;
	my $intHostname;

	my $cmd = `ec2-describe-instances | grep "$instanceName" | grep TAG`;
	if (length($cmd) == 0) {
		print "\nWARNING: ";
		print "\n\tThere does not exist an instance with the given INSTANCE_NAME: $instanceName in the config.txt";
		print "\n\tPlease check your config file make sure there are instances running before configuring SGE Cluster... \n\n";
		exit (1);
	}

	my @num_Instances = split("\n", $cmd);
	foreach my $i (@num_Instances) {
		my @current_instance = split("\t", $i);
		$instanceID = $current_instance[2];
		$instanceName = $current_instance[4];
		($instanceURL, $intHostname) = GetURL($instanceID, $instanceName);
		if ($instanceURL ne "") {
			$URL_intHost_table{$instanceURL} = $intHostname;
			$intHost_ID_table{$intHostname} = $instanceID;
		}

	}

	return (\%URL_intHost_table, \%intHost_ID_table);

}



sub Install_SGE {
	
	# Arguments
	my $instanceName = shift;
	my $instanceType = shift;

	# Public hostname: use to ssh to each instance and install SGE
	# Internal hostname: use for SGE configuration.
	my ($URL_intHost_hash_ref, $intHost_ID_hash_ref) = create_URL_to_ID_hash($instanceName);
	my %URL_intHost_hash = %$URL_intHost_hash_ref;
	my %intHost_ID_hash = %$intHost_ID_hash_ref;
	
	my @listOfURL= keys %URL_intHost_hash; # Use for SSH.
	my @llistOfintHost = values %URL_intHost_hash;

	my @t1 = keys %intHost_ID_hash;
	
	foreach my $i (@listOfURL) {
		print "$i\t";
	}
	print "\n";

	foreach my $i (@llistOfintHost) {
		print "$i\t";
	}
	print "\n";

	foreach my $i (@t1) {
		print "$i\t";
	}
	print "\n";


	# Other varaiables
	my $separator = 0;
	my $numCores = GetCPU($instanceType);
	my $current_instance_URL;

	foreach my $k (keys %URL_intHost_hash) {
		if ($separator == 0) {
			# This is Master
			$current_instance_URL = $k;


			$separator++; 
		}
	}

}

