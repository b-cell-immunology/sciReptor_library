#!/usr/bin/perl
#
# Process data from various tag files for subsequent insertion into the database
#
# USE FOLLOWING COMMAND TO UPLOAD TO DATABASE
# note: use from command line with --local-infile=1 option, otherwise the load data local... is blocked
# load data local infile 'tag_library.tsv' into table tags_library";
#
use strict;
use warnings;
use File::Find;
use Getopt::Long;

my %hash_matrix_batch;
my $re_filename_tags = qr/.*tags_[0-9.ki]+_([0-9]{2,3})x([0-9]{2,3})_matrix\.tsv$/;
my $re_tag_sanity = qr/^[ACGT]{16}$/;

my $filename_matrix_batch = "matrix_batches.tsv";
my $filename_output = "tag_library.tsv";

my $option_show_help = '';
my $option_directory = '.';

GetOptions (
	'help' => \$option_show_help,
	'directory=s' => \$option_directory
);

if ($option_show_help) {
	print "Usage: process_tags.pl [--directory=PATH]\n";
	print " --directory  : use directory PATH as working directory (default: current directory)\n";
	exit;
}

$option_directory =~ s/\/$//;

open my $fh_batches, "<", $option_directory . "/" . $filename_matrix_batch or die "Could not open input file " . $filename_matrix_batch;
while (<$fh_batches>) {
	next if ($. == 1);
	chomp $_;
	(my $matrix, my $batch) = split /\t/, $_;
	push @{$hash_matrix_batch{$matrix}{batch}}, $batch;
	$hash_matrix_batch{$matrix}{processed} = 0;
}
close $fh_batches;

open my $fh_output, ">", $option_directory . "/" . $filename_output or die "Could not open output file " . $filename_output;

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
	if ( defined $hash_matrix_batch{$matrix} ) {
		printf "[process_tags.pl][INFO] Processing matrix %s (used by %i batches).\n", $matrix, scalar @{$hash_matrix_batch{$matrix}{batch}};
		open my $fh_current, "<", $filename_current;
		while (<$fh_current>) {
			chomp $_;
			next if ($_ =~ m/number/);  # skip header line

			(my $id, my $col_tag, my $row_tag) = split /\t/, $_;

			foreach my $batch ( @{$hash_matrix_batch{$matrix}{batch}} ) {
				if ($row_tag) {
					if ( $row_tag =~ m/$re_tag_sanity/ ) {
						printf $fh_output "\tR%03d\t%s\t%s\t%s\n", $id, $row_tag, $matrix, $batch;
					} else {
						printf "[process_tags.pl][ERROR] Detected invalid row tag \"%s\" in matrix %s!\n", $row_tag, $matrix;
						exit 1;
					}
				}
				if ($col_tag) {
					if ( $col_tag =~ m/$re_tag_sanity/ ) {
						printf $fh_output "\tC%03d\t%s\t%s\t%s\n", $id, $col_tag, $matrix, $batch;
					} else {
						printf "[process_tags.pl][ERROR] Detected invalid column tag \"%s\" in matrix %s!\n", $col_tag, $matrix;
						exit 1;
					}
				}
			}
		}
		close $fh_current;
		$hash_matrix_batch{$matrix}{processed} = 1;
	} else {
		printf "[process_tags.pl][WARNING] Matrix size %s not defined in \"%s\". Tags file \"%s\" will be skipped!\n",
			$matrix, $filename_matrix_batch, $filename_current
		;
	}
}
close $fh_output;

foreach (keys %hash_matrix_batch) {
	if (! $hash_matrix_batch{$_}{processed}) {
		printf "[process_tags.pl][WARNING] No tags were processed for matrix %s (used by %i batches).\n", $_, scalar @{$hash_matrix_batch{$_}{batch}};
	}
}
