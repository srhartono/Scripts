#!/usr/bin/perl

use strict; use warnings;

my ($input) = @ARGV;
die "usage: $0 <input>\n" unless @ARGV;

my ($folder, $name) = getFilename($input, "folder");

open (my $in, "<", $input) or die "Cannot read from $input: $!\n";

my %data;
while (my $line = <$in>) {
	chomp($line);
	next if $line =~ /#/;
	my @arr = split("\t", $line);
	my ($chr, $start, $end, $name, $type, $strand, $tstart, $tend, $tname, $tstrand, $overlap) = ($arr[0], $arr[1], $arr[2], $arr[3], $arr[4], $arr[5], $arr[7], $arr[8], $arr[9], $arr[11], $arr[12]);
	next if $strand ne $tstrand;
	if (not defined($data{$tname}) or $data{$tname}{overlap} < $overlap) {
		$data{$tname}{overlap} 	= $overlap;
		$data{$tname}{line}    	= $line;
		$data{$tname}{chr} 	= $chr;
		$data{$tname}{start} 	= $start;
		$data{$tname}{end} 	= $end;
		$data{$tname}{line} 	= "$chr\t$start\t$end\t$name\t$type\t$strand";
	}
}

close $in;

foreach my $tname (sort {$data{$a}{chr} cmp $data{$b}{chr} || $data{$a}{start} <=> $data{$b}{start}} keys %data) {
	print "$data{$tname}{line}\n";
}


sub getFilename {
        my ($fh, $type) = @_;

        die "getFilename <fh> <type (folder, full, folderfull, all)\n" unless defined($fh);

        # Split folder and fullname
        my (@splitname) = split("\/", $fh);
        my $fullname = pop(@splitname);
        my @tempfolder = @splitname;
        my $folder = join("\/", @tempfolder);

        # Split fullname and shortname (dot separated)
        @splitname = split(/\./, $fullname);
        my $shortname = $splitname[0];
        return($shortname)                      if not defined($type);
        return($fullname)                       if defined($type) and $type =~ /full/;
        return($folder, $shortname)             if defined($type) and $type =~ /folder/;
        return($folder, $fullname)              if defined($type) and $type =~ /folderfull/;
        return($folder, $fullname, $shortname)  if defined($type) and $type =~ /all/;
}
