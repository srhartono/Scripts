#!/usr/bin/perl

use strict; use warnings;

my ($input) = @ARGV;
die "usage: $0 <input>\n" unless @ARGV;

my ($folder, $name) = getFilename($input, "folder");

open (my $in, "<", $input) or die "Cannot read from $input: $!\n";
open (my $out, ">", "$name.out") or die "Cannot write to $name.out: $!\n";

my $linecount = 0;
my %data;
while (my $line = <$in>) {
	$linecount ++;
	chomp($line);
	my @arr = split("\t", $line);
	if ($linecount > 5) {
		my ($match, $strand, $name, $chr, $start, $end) = ($arr[0],$arr[8], $arr[9], $arr[13], $arr[15], $arr[16]);
		if (not defined($data{$name}) or $data{$name}{match} < $match) {
			$data{$name}{chr}    = $chr;
			$data{$name}{start}  = $start;
			$data{$name}{end}    = $end;
			$data{$name}{strand} = $strand;
			$data{$name}{match}  = $match;
			$data{$name}{line}   = "$chr\t$start\t$end\t$name\t$match\t$strand";
		}
	}
}

close $in;
close $out;

foreach my $name (sort {$data{$a}{chr} cmp $data{$b}{chr} || $data{$a}{start} <=> $data{$b}{start}} keys %data) {
	print "$data{$name}{line}\n";
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
