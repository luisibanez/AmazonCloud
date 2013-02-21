#!/usr/bin/perl

use warnings;
use strict;


my $configFile = $ARGV[0];
my $port = parseConfig($configFile);


sub parseConfig {
   my $fileName = shift;
   my @option;
   my @line;

   open FILE, $fileName or die "Cloud not find ${fileName}\n";
   @option = <FILE> ;

   foreach my $i (@option) {
     @line = split (" ", $i, 2);
     if($i =~ /^AUTHORIZED_PORTS:/) {
	  $port = $line[1];
     }
   }
   close FILE;
   return $port;
}


my @all_ports = split (",", $port);

foreach my $i (@all_ports) {
  print "$i\n";
}

foreach my $i (@all_ports) {
  $i =~ s/^\s+//;
  print "$i";
}



