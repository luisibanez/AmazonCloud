#!/usr/bin/perl

#global variables===============================
my $instanceid = $ARGV[0]; 
my $instanceName = $ARGV[1];

my $volid;
my $voltag;
my $clustername;
my $newtag;

#function calls===============================
print "Instance ID: $instanceid\n";
print "Instance Name: $instanceName\n";

get_volumeid();

# function definitions
#=========================
# obtain the volume ids from the argument instance id, store them in global variables
sub get_volumeid
{
	my $counter = 0;
	#create array for output
	my @ec2cmd = `ec2-describe-instances $instanceid`;

	#iterate through array looking for attached volumes and add appropriate tags
	foreach my $i (@ec2cmd)
	{
		if($i =~ /^BLOCKDEVICE/)
		{
			#separate the line by tabs and obtain the column with the volume id
			my @line = split("\t", $i);
			$volid = @line[2];
			$voltag = @line[1];
			$newtag = "${instanceid}_${instanceName}_${counter}";
			print "volumeid: $volid adding tag: ${newtag}\n";
			my $addtagcmd = `ec2-create-tags $volid --tag Name=$newtag`;
			$counter++;
		}
	}
}

