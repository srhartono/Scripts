#!/usr/bin/perl

use strict; use warnings; use mitochy;

my ($input) = @ARGV;
die "usage: $0 <input>\n" unless @ARGV;

my ($folder, $name) = mitochy::getFilename($input, "folder");

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
