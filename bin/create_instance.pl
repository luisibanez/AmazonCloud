#!/usr/bin/perl 


# written by the following people:
# Fei-Yang(Arthur) Jen, arthur20249@gmail.com
# Quang Trinh, quang.trinh@gmail.com
#

use strict;
use warnings;
use File::Basename;
use Parallel::ForkManager;


# Function calls
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
my ($ami, $numberOfInstances, $keyPair, $securityGroup, $instanceType, $region, $availabilityZone, $instanceName, $authorizedPort_TCP, $authorizedPort_UDP) = parseOptions($configFile);

	
# get the default region and availability zone if users didn't put them in config file
if ((length($region) == 0) || (length($availabilityZone)==0)) 
{
	($region, $availabilityZone) = getRegionAndAvailableZone();
}


if ( (length($keyPair) == 0) || (length($securityGroup) == 0) || (length($instanceType) == 0) || (length($instanceName) == 0) || (length($ami) == 0) || (length($numberOfInstances)== 0)) {
	print "\n\nPlease check your config file and make sure all configuration attributes are defined!\n\n";
}

# Make sure all the paramenters have been specified in the config file before processing
if (length($keyPair) == 0) {
	print "\nNo KEY_PAIR value specified. Please check your config file!\n\n";
	exit (1);
} elsif (length($securityGroup) == 0) {
	print "\nNo SECURITY_GROUP value specified. Please check your config file!\n\n";
	exit (1);
} elsif (length($instanceType) == 0) {
	print "\nNo INSTANCE_TYPE value specified. Please check your config file!\n\n";
	exit (1);
} elsif (length($instanceName) == 0) {
	print "\nNo INSTANCE_NAME value specified. Please check your config file!\n\n";
	exit (1);
} elsif (length($ami) == 0) {
	print "\nNo AMI value specified. Please check your config file!\n\n";
	exit (1);
}


	
#print out attributes defined in config file 
printf ("\nLaunching your instance with the following attributes as defined in config file '$ARGV[0]':");
printf ("\n\n %-15s \t %-30s", "AMI:", $ami);
printf ("\n %-15s \t %-30s", "INSTANCE_NAME:", $instanceName);
printf ("\n %-15s \t %-30s", "KEY_PAIR:", $keyPair);
printf ("\n %-15s \t %-30s", "SECURITY_GROUP:", $securityGroup);
printf ("\n %-15s \t %-30s", "INSTANCE_TYPE:", $instanceType);
printf ("\n %-15s \t %-30s", "REGION:", $region);
printf ("\n %-15s \t %-30s", "AVAILABILITY_ZONE:", $availabilityZone);
printf ("\n %-15s \t %-30s", "AUTHORIZED_PORTS_TCP:", $authorizedPort_TCP);
printf ("\n %-15s \t %-30s", "AUTHORIZED_PORTS_UDP:", $authorizedPort_UDP);
printf ("\n %-15s \t %-30s", "NUMBER_OF_INSTANCES:", $numberOfInstances);
print "\n";
	

createKeypair($keyPair,$region);
createSecurityGroup($securityGroup, $region, $authorizedPort_TCP, $authorizedPort_UDP);


my $multiInstances = 0;
my $multiInstancesOutput = "";
	
if ($numberOfInstances > 1) {
	$multiInstances = 1;
}

my $manager = Parallel::ForkManager->new($numberOfInstances);
for (my $counter = 1; $counter <= $numberOfInstances; $counter++) {
	$manager->start and next;
	if ($numberOfInstances > 1) {
		$instanceName = $instanceName . "_" . $counter;
	}
	printf ("\nCreating Instance: $instanceName ...\n");
	my $str = createInstance($ami, $keyPair, $securityGroup, $instanceType, $instanceName, $region, $availabilityZone, $multiInstances);
	if (length($str) > 0) {
		print $str;
	}
	$manager->finish;
}
$manager->wait_all_children;



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
		if($i =~ /^NUMBER_OF_INSTANCES:/)
		{
			$numberOfInstances = $line[1];
			chomp($numberOfInstances);
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
			# replace spaces with '_'
			$instanceName =~ s/\ /_/g;
		} 
		elsif($i =~ /^AUTHORIZED_PORTS_TCP:/)
		{
			$authorizedPort_TCP = $line[1];
			chomp($authorizedPort_TCP);
		}
		elsif($i =~ /^AUTHORIZED_PORTS_UDP:/)
		{
			$authorizedPort_UDP = $line[1];
			chomp($authorizedPort_UDP);
		}
	}
	close FILE;
	return ($ami, $numberOfInstances, $keyPair, $securityGroup, $instanceType, $region, $availabilityZone, $instanceName, $authorizedPort_TCP, $authorizedPort_UDP);

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

#function for creating the key file
sub createKeypair 
{
	my $key = shift;
	my $region = shift;

	my $outputFileName = $key . ".pem";

	my $cmdOutput = `ec2-describe-keypairs --region $region`;

	#if key exists, skip creating it otherwise make the key 
	if ($cmdOutput =~ /$key/)
	{
		print "\nKeypair '$key' exists ... skip creating it ...\n";
	} 
	else
	{
		print "\nCreating keypair '$key' ";
		$cmdOutput = `ec2-create-keypair $keyPair --region $region > $outputFileName`;
	
		# change permission so that key is not accessible by other users	
		system ("chmod 600 $outputFileName");
		print "Done ... \n";
	}
}

sub enable_ports {

	my $group = shift;
	my $authorizedPort = shift;
	my $port_type = shift;
	my $cmdOutput;
	my $size;
	my $ans;
	my $port_22 = 0;

	# Proceed to add all the ports
		my @ports = split (",", $authorizedPort);
		foreach my $i (@ports) {
			$i =~ s/^\s+//;
			my @j = split (":", $i);
			if ($j[0] eq "22") {
				$port_22 = 1;
			}
			$size = @j;
			if ($size == 2) {
			 	$cmdOutput = `ec2-authorize $group -P $port_type -p $j[0] -s $j[1]`;
			 	print "\nAuthorized $port_type Port: $j[0]; Source: $j[1] ... created ...\n";
			} else {
				$cmdOutput = `ec2-authorize $group -P $port_type -p $i`;
				print "\nAuthorized $port_type Port: $i; Source: 0.0.0.0/0 ... created ...\n";
			} 
		}
		if (!$port_22 && $port_type eq "TCP") {
			print "\n\n=========================================================================\n";
			print "\nNOTE:\n";
			print "\n\tAccording to your config file, you did not enable port 22 (SSH).\n";
			print "\tFor your convenience, prot 22 is recommanded to enable as you can ssh to your instance securely  with your specific key-pair!\n";
			print "\n\n=========================================================================\n";
			START:
			print "\nWould you like to enable port 22 ? [Y/n]";
			chomp($ans = <STDIN>);
			if ($ans eq "Y" || $ans eq "y") {
				$cmdOutput = `ec2-authorize $group -P $port_type -p 22`;
				print "\nAuthorized $port_type Port: 22; Source: 0.0.0.0/0 ... created ...\n";
			} elsif ($ans eq "N" || $ans eq "n") { 
				print "\nskip authorizing port 22 ...\n";
			} else {
				print "\nInvalid inputs\n";
				goto START;
			}
		}
}

# Function for creating the security group, group options maybe set to be more flexible later
sub createSecurityGroup 
{
	my $group = shift;
	my $region = shift;
	my $TCP_ports = shift;
	my $UDP_ports = shift;
	my $size;

	my $cmdOutput = `ec2-describe-group --region $region `;

	#if security group exists, skip process otherwise create the group
	if (($cmdOutput =~ /^GROUP/) && ($cmdOutput =~ /$group/)) {
		print "\nSecurity group '$group' exists ... skip creating it ...\n\n";
	} else {

		# Check if there has any value been specified in the config file for AUTHORIZED_PORTS
		if (length($TCP_ports) == 0) {
			print "\n\nCreating security group '$group', but no port is assigned to AUTHORIZED_PORTS!\n";
			print "Please check your config file to make sure all the paramenters have been specified!\n";
			print "Port: 22 is the recommanded port to enable as it allows you to ssh to the instance with the key-pair!\n\n";
			exit (1);
		} 

		print "\nCreating security group '$group' \n";
		# Create a security group first
		my $description = "Security group ( created by $0 )";
		$cmdOutput = `ec2-create-group $group --region $region -d \" $description \"`;
		
		# TCP Enable:
		enable_ports($group, $TCP_ports, "TCP");
		# UDP Enable:
		enable_ports($group, $UDP_ports, "UDP");

		END_point:
		print "\nAuthorized port Done ...\n\n";
	}
}

#sub function for autodetecting when all volumes are ready to be labeled 
sub labelVolumes
{
	my $instanceID = shift;
	my $instanceName = shift;
	my $multiInstances = shift;

	my $readycounter = 0;
	my $timeoutcounter = 20;
	my $timeout = 1;
	
	#continuously run describe instance command to determine if there are more than 1 listed attached volumes
	while($timeoutcounter > 0)
	{
		my @ec2cmd = `ec2-describe-instances $instanceID`;
	
		foreach my $i (@ec2cmd)
		{	
			#counting the lines that start with blockdevice to obtain how many volumes are attached
			if($i =~ /^BLOCKDEVICE/)
			{
				$readycounter++;
			}
		}

		#if we determine there are 4 volumes attached, break out of the loop 
		if($readycounter >= 1)
		{
			#flip off timeout switch
			$timeout = 0;

			#call name volumes function and exit loop 
			if ($multiInstances == 0) {
				# call name_volumes.pl with 1 ( i.e., show outputs )
				system("bin/name_volumes.pl $instanceID $instanceName 1");
				print "\n\nAll volumes have been attached and labelled ...\n";
			} else {
				# call name_volumes.pl with 0 ( i.e., don't show outputs )
				system("bin/name_volumes.pl $instanceID $instanceName 0");
			}
			last;
		}
		else
		{
			#reset our current count
			$readycounter = 0;

			#otherwise we have to decrease a timeout counter and wait 30 seconds
			$timeoutcounter--;
			sleep 30;
		}
	}
	
	#if in the case that 600s have passed we will timeout and exit -- this should only happen in extreme cases 
	if($timeout == 1)
	{
		if ($multiInstances == 0) {
			print "\n\nOne or more volumes are not attached within the allowed time of 10 mins!\n";
			print "Please label your volumes manually later by running:";
			print "\n\n\tbin/name_volumes.pl $instanceID $instanceName 1";
			print "\n";
		}
	}
}

# return array of 2 elements: region and available zone 
sub getRegionAndAvailableZone 
{
	my $cmdOutput;
	my $cmd = "ec2-describe-availability-zones";
	my @data = ();

	#  2>&1 to capture both STDERR and STDOUT
	$cmdOutput =`$cmd 2>&1`;
	my @fields = split ("\n",$cmdOutput);
	foreach my $l (@fields)
	{
		if ($l =~ /^AVAILABILITYZONE/) {
			@fields = split ("\t",$l);
			push (@data, $fields[3]);
			push (@data, $fields[1]);
			return @data;
		}
	}
	print "\n\nNo default region and available zone!\n\n";
	exit (1);
}

#function which creates the instance on the amazon cloud 
sub createInstance
{
	my $ami = shift;
	my $keyPair = shift;
	my $securityGroup = shift;
	my $instanceType = shift;
	my $instanceName = shift;
	my $region = shift;
	my $availabilityZone = shift;
	my $multiInstances = shift;

	my $instanceID;
	my $cmd ;
	my $cmdOutput;
	my $returnStr = "";


	# add ephemeral devices - see http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/instance-types.html
	# http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/InstanceStorage.html
	if ($instanceType =~ /m1\.medium/) {
		$cmd ="ec2-run-instances $ami -k $keyPair -g $securityGroup -t $instanceType -b \"/dev/sdb1=ephemeral0\" --region $region --availability-zone $availabilityZone ";	
	} elsif ($instanceType =~ /m1\.large/) {
		$cmd ="ec2-run-instances $ami -k $keyPair -g $securityGroup -t $instanceType -b \"/dev/sdb1=ephemeral0\" -b \"/dev/sdb2=ephemeral1\" --region $region --availability-zone $availabilityZone ";	
	} else {
		$cmd ="ec2-run-instances $ami -k $keyPair -g $securityGroup -t $instanceType --region $region --availability-zone $availabilityZone ";	
	}

	#  2>&1 to capture both STDERR and STDOUT
	$cmdOutput =`$cmd 2>&1`;
	if (checkRunInstanceError($cmdOutput) == 1) {
		print "\nError launching your Amazon instance :";
		print "\n\n$cmdOutput";
		print "\n\n";
		exit (1);
	} else {
		# print only if launching a single instance 
		if ($multiInstances == 0) {
			print "\nLaunching your instance $instanceName ... \n";
		}
	}

	$instanceID = getInstanceID($cmdOutput);

	# label the instance 
	$cmdOutput = `ec2-create-tags $instanceID  -t Name=\"$instanceName\"`;
	
	my $URL = GetURL($instanceID);

	#label Galaxy volumes
	labelVolumes($instanceID, $instanceName, $multiInstances);
	
	# print only if lauching a single instance 
	if ($multiInstances == 0) {
		print "\n\nYour instance name/URL is:\n\t" . $URL;
		print "\n\nTo login to your instance, use this command:\n\tssh -i " . $keyPair . ".pem  ubuntu@" . $URL ;
		print "\n\nTo terminate your instance, use this command:\n\tec2-terminate-instances $instanceID ";
		print "\n\nPlease send questions/comments to help\@modencode.org\n\n";
	} else {
		$returnStr = "\n$instanceName\tHOST_NAME:\t" . $URL;
		$returnStr = $returnStr . "\n$instanceName\tSSH_CMD:\tssh -i " . $keyPair . ".pem  ubuntu@" . $URL;
		$returnStr = $returnStr . "\n$instanceName\tTERMINATE_CMD:\tec2-terminate-instances $instanceID ";
		$returnStr = $returnStr . "\n";
	}
	return $returnStr;
}

# check for error after running an instance 
# return 0 if there is no error
# return 1 if there is an error 
sub checkRunInstanceError
{
	my $str = shift;
	my $instanceID = "";
	my @fields = split ("\n",$str);

	foreach my $l (@fields)
	{
		if ($l =~ /^RESERVATION/) 
		{
			return 0;
		}
	}
	return 1;
}


#sub function which is used to get the id of the instance being launched
sub getInstanceID
{
	my $str = shift;
	my $instanceID = "";
	my @fields = split ("\n",$str);

	foreach my $l (@fields)
	{
		if ($l =~ /^INSTANCE/) 
		{
			my @f = split("\t",$l);
			$instanceID = $f[1];
			last;
		}
	}
	return $instanceID;
}

#sub function used to output the url used for cloudman and ssh
sub GetURL 
{
	my $instanceID = shift;
	my @cmdOutput;
	my $URL;
	my $complete = 0;
	my @fields;

	# wait for another 45 seconds to ensure all services are started 
	sleep 45;

	while (!$complete) 
	{
		# wait another 5 secs before trying again
		sleep 5;
	
		@cmdOutput = `ec2-describe-instances $instanceID`;
		foreach my $line (@cmdOutput)
		{
			if (($line =~ /^INSTANCE/) && ($line =~ /running/)) 
			{
				my @f = split("\t",$line);
				$URL = $f[3];
				$complete = 1;
				last;
			}
		}
	}

	return $URL;
}


#function which prints out the proper format of the function when the inputs are given incorrectly
sub usage
{
	print "\n";
	print "This script creates an Amazon instance based on the input configuration file.\nPlease send questions/comments to help\@modencode.org.";
	print "\n\n\tusage: perl " . basename($0) . "  [ CONFIG_FILE ] ";
	print "\n\n\t\tFor example:\tperl " . basename($0) . " config.txt";
	print "\n\n";
	exit (2);
}
