#!/usr/bin/perl 

#
# written by the following people from modENCODE DCC group:
# Ziru Zhou, ziruzhou@gmail.com
# Kar Ming Chu, mr.kar.ming.chu@gmail.com
# Quang Trinh, quang.trinh@gmail.com
# Fei-Yang(Arthur) Jen
#

use strict;
use warnings;
use File::Basename;


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

createKeypair($keyPair,$region);
createSecurityGroup($securityGroup, $region, $authorizedPort);
createInstance($ami, $keyPair, $securityGroup, $instanceType, $instanceName, $region, $availabilityZone);



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
		print "... done\n";
	}
}

#function for creating the security group, group options maybe set to be more flexible later
sub createSecurityGroup 
{
	my $group = shift;
	my $region = shift;
	my $authorizedPort = shift;

	my $cmdOutput = `ec2-describe-group --region $region `;

	#if security group exists, skip process otherwise create the group
	if (($cmdOutput =~ /^GROUP/) && ($cmdOutput =~ /$group/)) 
	{
		print "\nSecurity group '$group' exists ... skip creating it ...\n";
	}
	else 
	{
		print "\nCreating security group '$group' ";
		# Create a security group first
		$cmdOutput = `ec2-create-group $group --region $region -d \"Security group to use with modENCODE AMI ( created by modENCODE_galaxy_create.pl )\"`;
		# Proceed to add all the ports
		my @ports = split (",", $authorizedPort);
		foreach my $i (@ports) {
			$i =~ s/^\s+//;
			$cmdOutput = `ec2-authorize $group -P tcp -p $i`;
			print "\nAuthorized Port: $i ... created ...";
		}
		print "... done\n";
	}
}

#sub function for autodetecting when all volumes are ready to be labeled 
sub labelVolumes
{
	my $instanceID = shift;
	my $instanceName = shift;
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
			system("bin/name_volumes.pl $instanceID $instanceName");
			print "\n\nAll modENCODE volumes have been attached ...\n";
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
		print "\n\nOne or more volumes are not attached within the allowed time!\n";
		print "Please label your Galaxy volumes manually later by running:";
		print "\n\n\tbin/name_volumes.pl $instanceID $instanceName";
		print "\n";
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
	my $instanceID;
	my $cmd ;
	my $cmdOutput;


	$cmd ="ec2-run-instances $ami -k $keyPair -g $securityGroup -t $instanceType --region $region --availability-zone $availabilityZone ";	

	#  2>&1 to capture both STDERR and STDOUT
	$cmdOutput =`$cmd 2>&1`;
	if (checkRunInstanceError($cmdOutput) == 1) {
		print "\nError launching Galaxy:";
		print "\n\n$cmdOutput";
		print "\n\n";
		exit (1);
	} else {
		print "\nLaunching instance ... ";
	}

	$instanceID = getInstanceID($cmdOutput);

	# label the instance 
	$cmdOutput = `ec2-create-tags $instanceID  -t Name=$instanceName`;
	
	my $URL = GetURL($instanceID);

	#label Galaxy volumes
	labelVolumes($instanceID, $instanceName);
	
	print "\n\nTo access modENCODE instance, go to this URL:\n\t" . $URL;
	print "\n\nTo login to modENCODE instance, use this command:\n\tssh -i " . $keyPair . ".pem  ubuntu@" . $URL ;
	print "\n\nPlease send questions/comments to help\@modencode.org\n\n";
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
	print "This script creates an instance of an AMI on Amazon Cloud. Please send questions/comments to help\@modencode.org.";
	print "\n\n\tusage: perl " . basename($0) . "  [ CONFIG_FILE ] ";
	print "\n\n\t\tFor example: \t $0 config.txt";
	print "\n\n";
	exit (2);
}

