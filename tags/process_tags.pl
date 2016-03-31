#!/usr/bin/perl
#
# Process data from various tag files for subsequent insertion into the database
#
# USE FOLLOWING COMMAND TO UPLOAD TO DATABASE
# note: use from command line with --local-infile=1 option, otherwise the load data local... is blocked
# load data local infile 'tag_library.csv' into table tags_library";
#
use strict;
use warnings;
use File::Find;

my $option_directory = ".";
my $re_filename_tags = qr /.*tags_[0-9.ki]+_([0-9]{2,3})x([0-9]{2,3})_matrix\.tsv$/;

my %hash_matrix_batch;

open my $fh_batches, "<", "matrix_batches.tsv" or die "Could not open matrix_batches.tsv";
foreach (<$fh_batches>) {
	chomp $_;
	(my $matrix, my $batch) = split /\t/, $_;
	push @{$hash_matrix_batch{$matrix}}, $batch;
}
close $fh_batches;

open my $fh_output, ">", "tag_library.csv" or die "Could not open tag_library.csv";

my @list_files_tags = ();
{
    sub sub_find_regex_files {
        m/$re_filename_tags/ &&
        -f $_ &&
        push @list_files_tags, $File::Find::name;
    }
    find(\&sub_find_regex_files,("$option_directory"))
}

foreach my $filename_current ( sort @list_files_tags ) {

	my $matrix = $filename_current;
	$matrix =~ s/$re_filename_tags/$1_$2/;
	open my $fh_current, "<", $filename_current;
	while (<$fh_current>) {
		chomp $_;
		next if ($_ =~ m/number/);  # skip header line

		(my $id, my $col_tag, my $row_tag) = split /\t/, $_;

		foreach my $batch ( @{$hash_matrix_batch{$matrix}} ) {
			if ($row_tag) {
				printf $fh_output "\tR%03d\t%s\t%s\t%s\n", $id, $row_tag, $matrix, $batch;
			}
			if ($col_tag) {
				printf $fh_output "\tC%03d\t%s\t%s\t%s\n", $id, $col_tag, $matrix, $batch;
			}
		}
	}
	close $fh_current;
}

close $fh_output;
