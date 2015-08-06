#!/usr/bin/perl

# Process data from various tag files for subsequent insertion into the database
#
# USE FOLLOWING COMMAND TO UPLOAD TO DATABASE
# note: use from command line with --local-infile=1 option, otherwise the load data local... is blocked
# load data local infile 'tag_library.csv' into table tags_library";

use DBI;
use warnings;

# tag batch:
# species_isotypes_number

my $batch48_g = 'Hs_G_001';
my $batch48_aegm = 'Hs_AEGM_001';
my $batch48_agm = 'Mm_AGM_001';
my $batch48_adgm = 'Mm_ADGM_001';
my $batch256_agm = 'Mm_AGM_002';

# open input and output files
open(CSV48, '<matrix48_48_tags.csv') or die "infile for 48_48 matrix not found";
open(COL240, '<matrix240_256_col5prime.txt') or die "infile for 240_256 cols not found";
open(ROW240, '<matrix240_256_row3prime.txt') or die "infile for 240_256 rows not found";
open(DBCSV, '>tag_library.csv') or die "outfile missing";

# get sequences from the 48_48 matrix
my $matrix = "48_48";

while(<CSV48>) {
	chomp $_;
	unless ($_ =~ m/row/) {
		($id, $col_tag, $row_tag) = split("\t", $_);
		# 0 padded
		$id = sprintf("%03d", $id);
		# Hs_G_001
		print DBCSV "\tR$id\t$row_tag\t$matrix\t$batch48_g\n";
		print DBCSV "\tC$id\t$col_tag\t$matrix\t$batch48_g\n";
		# Hs_AEGM_001
		print DBCSV "\tR$id\t$row_tag\t$matrix\t$batch48_aegm\n";
		print DBCSV "\tC$id\t$col_tag\t$matrix\t$batch48_aegm\n";
		# Mm_AGM_001
		print DBCSV "\tR$id\t$row_tag\t$matrix\t$batch48_agm\n";
		print DBCSV "\tC$id\t$col_tag\t$matrix\t$batch48_agm\n";
		# Mm_ADGM_001
		print DBCSV "\tR$id\t$row_tag\t$matrix\t$batch48_adgm\n";
		print DBCSV "\tC$id\t$col_tag\t$matrix\t$batch48_adgm\n";
	}
}


# get sequences from the 240_256 matrix
$matrix = "240_256";
my $count = 0;

while(<COL240>) {
	chomp $_;
	$count++;
	# 0 padded
	$count = sprintf("%03d", $count);
	# Mm_AGM_001
	print DBCSV "\tC$count\t$_\t$matrix\t$batch256_agm\n";
}

$count = 0;
while(<ROW240>) {
	chomp $_;
	$count++;
	# 0 padded
	$count = sprintf("%03d", $count);
	# Mm_AGM_001
	print DBCSV "\tR$count\t$_\t$matrix\t$batch256_agm\n";
}


# added for L matrix 08/2015 KI
my $batch72_64_aegm = 'Hs_AEGM_002';
open(CSV72_64, 'tag_table_4.5ki_72x64_matrix.csv') or die "infile for 72_64 matrix not found"; 
my $id_padded;
$matrix = "72_64";

while(<CSV72_64>) {
	chomp $_;
	unless ($_ =~ m/Number/) { # skip first line
		# parsing is different for line 64-72,  (no rows)
		if ($id <64) {
		  ($id, $col_tag, $row_tag) = split("\t", $_);
		  # 0 padded
		  $id_padded = sprintf("%03d", $id);
		  # Hs_G_001
		  print DBCSV "\tR$id_padded\t$row_tag\t$matrix\t$batch72_64_aegm\n";
		  print DBCSV "\tC$id_padded\t$col_tag\t$matrix\t$batch72_64_aegm\n";
		}
		else {
		  ($id, $col_tag) = split("\t", $_);
		  # 0 padded
		  $id_padded = sprintf("%03d", $id);
		  # Hs_G_001
		  print DBCSV "\tC$id_padded\t$col_tag\t$matrix\t$batch72_64_aegm\n";
		}

	}
}

close(CSV72_64);
close(CSV48);
close(COL240);
close(ROW240);
close(DBCSV);
