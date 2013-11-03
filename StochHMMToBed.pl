#!/usr/bin/perl

#################################################################
# StochHMMToBed.pl						#
# This script parse SkewR posterior output file (from STDOUT)	#
# into a concatenated bed file. Bed file coordinate 		#
# will be zero-based [start,end] of StochHMM output.		#
# (Use perldoc for more explanation)				#
#								#
# By Stella Hartono, UC Davis, 2012				#
# This script is provided "as is" without warranty of any kind.	#
#################################################################

use strict; use warnings; 
use Getopt::Std; 
use vars qw($opt_h $opt_c $opt_i $opt_l $opt_s $opt_o $opt_t);
getopts("hc:i:l:s:o:t:g:");

# Check for input sanity and get states from stochhmm output
my ($input) = @ARGV;
my ($output, $threshold, $length, $colors, $states) = check_sanity($input);
my @state = @{$states};
my %color = %{$colors};

# Open input and output, and print track header into output file
open (my $in , "<", $input)  or die "Cannot read from $input: $!\n";
open (my $out, ">", $output) or die "Cannot write to $output: $!\n";
my ($output_name) = get_filename($output);
print $out "track name=\"$output_name\" description=\"$output_name\" itemRgb=\"On\"\nvisibility=1\n";

# Set up global variables which temporarily store "current" values when processing input file
my ($current_chr, $current_state);
my ($start_coor, $previous_coor) = ("-1", "-1"); 

my %data;	# hash that store values for each coordinate
my @state_pos;	# array to store state position

my $linecount   	= 0; 	   # Variable to store line count
my $store_data_check	= 0; 	   # Boolean to store data or not (0 is don't store)

# Process the StochHMM posterior probability file
while (my $line = <$in>) {
	chomp($line);
	$linecount++; # Count line number
	
	# Set up global variables to process the desired StochHMM posterior probability file
	# Line with "Posterior Probabilities Table" means it's the end of the previous data
	# so we stop storing data
	if ($line =~ /Posterior Probabilities Table/) {
		$store_data_check = 0;
	}

	# Line with "Sequence" contain new chromosome info.
	elsif ($line =~ /Sequence.+>/) {
	
		# If current state is not initial state (undefined) then we print out the previously stored data
		# and erase the previous data so the hash won't get too big.
		# If we at the end of file, this command won't be invoked. Therefore we will print the
		# last stored data at the end of this loop.
		if (defined($current_state)) {
			# Print each state's peaks coordinate which length is above threshold length
			# Then erase data so the hash won't get too big.
			print_data(\%data, $current_chr, $out);
			%data = (); 
		}

		# Reset global variables to be used in processing the data of the new chromosome.
		undef($current_state);
		$start_coor  = "-1";
	
		# Get the new chromosome stored in global variable
		($current_chr)   = $line =~ /Sequence.+>(\w+)/;
		print "Processing chromosome $current_chr\n";
		die "Fatal error: Undefined chromosome at line $linecount: $line\n" if not defined($current_chr);
	}

	# Line with "Position" contains StochHMM state position information we need to store.
	# The subsequent line below "Position" contain data of coordinate and each state's posterior probability
	# Posterior probability below user-inputted StochHMM threshold (not this script's threshold) will be blank
	elsif ($line =~ /^Position/) {
		my ($name, @state_names) = split("\t", $line); # Name is "Position", which we don't use.

		# Get the position of states stored in global array state_pos
		# (position means where each user-inputted state is located in the StochHMM output file)
		for (my $i = 0; $i < @state_names; $i++) {
			for (my $j = 0; $j < @state; $j++) {
				$state_pos[$i] = $state[$j] if $state_names[$i] eq $state[$j];
			}
		}
		$store_data_check = 1; # Start storing data at next line
	}

	# If boolean store_data_check is 1, we start storing adjacent coordinates and 
	# as a peak if the probability is above this script's user-inputted threshold
	# Btw, posterior probability below user-inputted StochHMM threshold 
	# (not this script's threshold) will be shown blank by StochHMM
	elsif ($store_data_check == 1 and $line =~ /^\d+/) {

		die "Fatal error: Undefined chrosome at line $linecount: $line\n" if not defined($current_chr);
		my ($current_coor, @vals) = split("\t", $line);

		if (defined($current_coor) and $current_coor =~ /^\d+$/) {
			
			my ($value, $state); # Variable to temporarily store value of the state.

			# We assume StochHMM threshold is above 0.5, therefore only 1 state will have a numeric probability.
			for (my $i = 0; $i < @vals; $i++) {
				next if $vals[$i] !~ /^\d+\.?\d*$/; # Skip the state if value is blank.
				$state = $state_pos[$i];
				$value = $vals[$i];
			}
			die "Fatal error: Undefined state at line $linecount: chrom $current_chr $line\n" unless defined($state);

			next if $value < $threshold;
			# If current state is initial (not defined), or state changes, or previous coordinate is not adjacent
			# of current coordinate, then we store the temporarily-recorded peak
			# and record the current state, start coordinate of that state, and end coordinate of that state
			if (not defined($current_state) or $current_state ne $state or $current_coor -1 != $previous_coor) {
				delete($data{$start_coor}) if defined($current_state) and $data{$start_coor}{end} - $start_coor + 1 < $length;
				$current_state  = $state;
				$start_coor     = $current_coor;
				$previous_coor  = $current_coor;
				
				# Explanation about how the hash below is stored:
				# A peak at state $current_state, chromosome $current_chr, 
				# starting at coordinate $start_coor, currently ends at $current_coor
				$data{$start_coor}{state} = $current_state;
				$data{$start_coor}{end}   = $current_coor;
			}

			# If the current coordinate is adjacent to previous coordinate, then we define
			# new end coordinate for that peak as $current_coor 
			elsif ($previous_coor == $current_coor - 1) {
				$data{$start_coor}{end} = $current_coor;
				$previous_coor		= $current_coor;
			}
			else {
				print "Fatal error: Unknown reason at $linecount: $line\nPlease report this bug to srhartono\@ucdavis.edu";
				$store_data_check = 0;
			}
		}
		else {
			print "Fatal error: Unknown reason at $linecount: $line\nPlease report this bug to srhartono\@ucdavis.edu";
			$store_data_check = 0;
		}
	}
}
close $in;

# Print out peaks stored in last data hash
print_data(\%data, $current_chr, $out);

###############
# SUBROUTINES #
###############

sub check_sanity {
	my ($input) = @_;

	print_usage() and die "\n"	if ($opt_h);
	print_usage() and die "Fatal Error: Missing input file\n\n"	unless defined($input);

	my ($name)    = get_filename($input);
	my $output    = defined($opt_o) ? $opt_o : get_filename($input) . ".bed";
	my $threshold = defined($opt_t) ? $opt_t : 0.95;
	my $length    = defined($opt_l) ? $opt_l : 300;
	my $colors    = $opt_c;
	my $states     = $opt_s;
	
	print "
Input parameters:
Input file:	$input
Output file:	$output
Threshold:	$threshold
Min Length:	$length
";
	print "States:	$states\n" if defined($states);
	print "Colors:	$colors\n" if defined($colors);

	# Input
	print_usage() and die "Input does not exists\n\n" if not -e $input;

	# Get state and color into their arrays
	# Then further process color into red green and blue values
	# Processing States
	my @state_in_file;
	my @states;
	open (my $in, "<", $input) or die "Cannot read from $input: $!\n";
	while (my $line = <$in>) {
		chomp($line);
		if ($line =~ /^Position/) {
			@state_in_file = split("\t", $line);
			shift(@state_in_file);
			print "States undefined: Using states defined in StochHMM output file: @state_in_file\n" if not defined($states);
			if (defined($states)) {
				@states = split(",", $states);
				print "Warning: Number of state defined is not the same as number of states in StochHMM output file\n" unless @state_in_file == @states;
				for (my $i = 0; $i < @state_in_file; $i++) {
					my $state = $state_in_file[$i];
					if (not grep(/^$state$/, @states)) {
						print "Warning: StochHMM output state $state is not defined in your input states\n";
					}
				}
				for (my $i = 0; $i < @state; $i++) {
					my $state = $states[$i];
					if (not grep(/^$state$/, @state_in_file)) {
						die "Fatal Error: Your input state $state is not defined in StochHMM output states\nYour states: @states\n\n";
					}
				}
			}
			else {
				@states = @state_in_file;
			}
			last;
		}
	}
	close $in;
		
	# Processing Color
	my %colors;
	if (defined($colors)) {
		my @color = split(",", $colors);
		print "Warning: Different number of state and color: missing color will be black\n" unless @states == @color;
		for (my $i = 0; $i < @color; $i++) {
			if ($color[$i] !~ /^r\d+g\d+b\d+$/i) {
				print_usage() and die "Fatal Error: Undefined color $color[$i]: Make sure it is in this format: r1g1b1,r2g2b2\n\n";
			}
			my ($red, $green, $blue) = $color[$i] =~ /r(\d+)g(\d+)b(\d+)/;
			last if not defined($states[$i]);
			$colors{$states[$i]} = "$red,$green,$blue";
		}
		for (my $i = @color; $i < @states; $i++) {
			$colors{$states[$i]} = "0,0,0";
		}

		print "Colors for each state: ";
		foreach my $state (sort keys %colors) {
			print "$state: $colors{$state} " if defined($colors{$state});
		}
		print "\n";
	}
	else {
		print "Colors undefined: All states will have black color rgb(0,0,0)\n";
		for (my $i = 0; $i < @states; $i++) {
			$colors{$states[$i]} = "0,0,0";
		}
	}

	# Length
	print_usage() and die "Fatal Error: Length must be a positive integer\n\n" if ($length !~ /^\d+$/ or $length < 0);

	# Output
	open (my $out, ">", $output) or die "Cannot write to $output: $!\n\n";
	close $out;
	
	# Threshold
	print_usage() and die "Fatal Error: Threshold must be between number between (including) 0 and 1\n\n" if ($threshold !~ /^\d+\.?\d*$/ or $threshold > 1 or $threshold < 0);

	print "\n";
	return($output, $threshold, $length, \%colors, \@states);	
}

sub print_data {
	my ($data, $chr, $out) = @_;
	foreach my $coor (sort {$a <=> $b} keys %data) {
		my $state = $data{$coor}{state};
		my $end   = $data{$coor}{end}  ;
		my $diff  = $end - $coor + 1;

		# Get color information for the state
		my $current_color = defined($color{$state}) ? $color{$state} : "0,0,0";
		next if $end - $coor + 1 < $length;
		print $out "$chr\t$coor\t$end\t$state\t$diff\t+\t$coor\t$end\t$current_color\n";
	}
}
sub print_usage {
	print "
usage: $0 [options] <Input file>

Input file: A StochHMM posterior probability STDOUT result, perldoc for more info.

Options:
-o: Output file. Default: <input name>.bed
    A bed file (zero-based) with color information
-s: Desired state (case-sensitive). Default: Get all states.
    Format is comma-separated (STATE1,STATE2,STATE3).
-t: Minimum posterior probability threshold [0-1]. Default: 0.
    Format is \"equal or more than\" (probability >= -t)
-l: Minimum length of a peak to be recorded. Default: 0.
    Format is \"equal or more than\" (peak length >= -l)
-c: Color information for each state. Default: 0,0,0 (black).
\n";
}

sub get_filename {
	my ($fh, $type) = @_;
	my (@splitname) = split("\/", $fh);
	my $name = $splitname[@splitname-1];
	pop(@splitname);
	my $folder = join("\/", @splitname);
	@splitname = split(/\./, $name);
	$name = $splitname[0];
	return($name) if not defined($type);
	return($folder, $name) if $type eq "folder";
}

=head1 NAME

StochHMMToBed.pl

=head1 USAGE

usage: $0 -i <StochHMM output posterior probability file> -o <output> -s <state1,state2,etc> -c <r1g1b1,r2g2b2,etc> -t <min threshold [0-1]> -l <length [int];

=head1 DESCRIPTION

This script parse SkewR posterior output file into a concatenated bed file. 
For Bed format information, go to http://genome.ucsc.edu/FAQ/FAQformat.html#format1

The Bed file format is zero-based start and end. Therefore if a peak in StochHMM start 
at coordinate A and end at coordinate B, the bed file will start at A and end at B.

For example, if the StochHMM probability of a one state is:

 Posterior Probabilities Table
 Model:	MODEL
 Sequence:	>chr1 XXXXX
 Probability of Sequence from Forward: Natural Log'd	-593058.2935
 Probability of Sequence from Backward:Natural Log'd	-593058.9325
 Position	STATE
 100	1
 101	1
 102	1
 103	1
 104	1
 105	1
 536	1
 537	1
 538	1
 (etc...)

The coordinates below will be written in the output bed file:

 chr1	100	105	STATE	1	+	100	105	0,0,0
 chr1	536	538	STATE	1	+	536	538	0,0,0

=head1 AUTHOR

Stella R. Hartono (srhartono@ucdavis.edu)

=head1 COPYRIGHT

Copyright 2012 Stella Hartono.

Permission is granted to copy, distribute and/or modify this document
under the terms of the GNU Free Documentation License, Version 1.3
or any later version published by the Free Software Foundation;
with no Invariant Sections, no Front-Cover Texts, and no Back-Cover Texts.
A copy of the license is included in the section entitled "GNU
Free Documentation License".

=head1 DISCLAIMER

This script is provided "as is" without warranty of any kind.

=cut

__END__
