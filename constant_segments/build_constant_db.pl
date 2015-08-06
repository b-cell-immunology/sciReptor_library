#!/usr/bin/perl

=head1 NAME

build_constant_db

=head1 SYNOPSIS

build_constant_db.pl

=head1 ARGUMENTS 



=head1 DESCRIPTION



=head1 HISTORY

=cut

use DBI;
use strict;
use warnings;
use Getopt::Long;
use Bio::SeqIO;

my $lib_input = "";
my $species = "";
my $fasta_file = "";
my $mysql_group = "";
my $parse_bool = 0;

&GetOptions(
	"mysql_group=s"	=> \$mysql_group,
	"lib=s"			=> \$lib_input,
	"sp=s"			=> \$species,
	"fasta=s"		=> \$fasta_file,
	"parse!"		=> \$parse_bool
);

# Set up logging
# prefix for logging, telling where log comes from
my $log_prefix = "[build_constant_db] [LOG] ";
my $error_prefix = "[build_constant_db] [ERR] ";

# get library database scheme, exit if not given
my $library_scheme;
if ($lib_input) {$library_scheme = $lib_input;}
else {die "No library specified with -lib argument.";}

# Get species and check if its meaningfull
unless ($species eq "human" || $species eq "mouse") {
  if ($species) {
    die "$error_prefix Species $species is not supported. Only human or mouse.\n";
  }
  else { die "$error_prefix Missing species definition in command line argument -sp." }
}

die "No mysql_group as in ~/.my.cnf file specified with -mysql_group argument." unless $mysql_group;

# constant database fasta file is defined in the config
my $const_fasta = $fasta_file; 


# Get database handle for database passed in the command line. Requires authentication via ".my.cnf" file.
my $dsn="DBI:mysql:$library_scheme;mysql_read_default_file=~/.my.cnf;mysql_read_default_group=$mysql_group;";
my $dbh = DBI->connect($dsn,undef,undef,{PrintError=>1});


# Insert Information from fasta file
#
# Switch "--parse" will activative parsing of additional information from FASTA header. These are the following fields:
# reference assembly (e.g. NCBIm38), chromosome, physical position lower boundary [bp] (inclusive),  physical position
# upper boundary [bp] (inclusive), orientation
#
my $insert_seg_statement;
if ($parse_bool) {
	print "$log_prefix Switch \"--parse\" is set. Will attempt to parse chromosomal location information from FASTA headers.\n";
	$insert_seg_statement = "INSERT INTO $library_scheme.constant_library (species_id, name, locus, sequence, ref_assembly, ref_chromosome, ref_pos_bound_low, ref_pos_bound_up, ref_ori) values (?,?,?,?,?,?,?,?,?)";
} else {
	print "$log_prefix Switch \"--parse\" is NOT set. Chromosomal location information will be ignored.\n";
	$insert_seg_statement = "INSERT INTO $library_scheme.constant_library (species_id, name, locus, sequence) values (?,?,?,?)";
}
my $ins_seq_query = $dbh->prepare($insert_seg_statement);


# open and read fasta file

my $fasta_in = Bio::SeqIO->new(-file => $const_fasta, -format => 'fasta') or die "$error_prefix could not open $const_fasta";

while (my $seq = $fasta_in->next_seq()) {
	my $seq_id =  $seq->id;
	print "$log_prefix Processing $seq_id\n";

	my ($ref_assembly, $ref_chromosome, $ref_pos_bound_low, $ref_pos_bound_up, $ref_ori);

	if ($parse_bool) {
		# "extended" Ensembl format including chromosomal position information. Order of field is NAME:ASSEMBLY:CHROMOSOME:POS1:POS2:ORIENTATION
		# This is used by the custom mouse NCBIm38 library
		($seq_id, $ref_assembly, $ref_chromosome, $ref_pos_bound_low, $ref_pos_bound_up, $ref_ori) = split(/:/, $seq_id, 6);
	} elsif ($seq_id =~ m/NCBI/) {
		# Standard Ensembl format (ie. without chromosomal position information)
		$seq_id = (split(/:/, $seq_id, 2))[0];
	} elsif ($seq_id =~ m/\|/) {
		# IMGT format. ATTENTION: The IMGT listing contains the individual exons of a constant region, but only exon 1 will be inserted into the database
		($seq_id, my $temp_exon) = (split(/\|/, $seq_id, 6))[1,4];
		if (($temp_exon ne "C-REGION") && ($temp_exon ne "CH1")) {
			next;
		}
	} else {
		# currently we do not implement parsing other formats, so just keep $seq_id as it is and issue a warning.
		print "$log_prefix Fasta identifers in $const_fasta could not be parsed to extract segment name like for standard Ensembl or IMGT format. Using fasta identifier as segment name.\n";
	}

	# parse locus from seq_id
	my $locus = "";
	if ($seq_id =~ m/[Hh]/) {
		$locus = "H";
	} elsif ($seq_id =~ m/[Ll]/) {
		$locus = "L";
	} elsif ($seq_id =~ m/[Kk]/) {
		$locus = "K";
	} else {
		print "$log_prefix Fasta identifer $seq_id could not be parsed to extract locus.\n";
	}

	if ($parse_bool) {
		$ins_seq_query->execute($species, $seq_id, $locus, uc($seq -> seq), $ref_assembly, $ref_chromosome, $ref_pos_bound_low, $ref_pos_bound_up, $ref_ori);
	} else {
		$ins_seq_query->execute($species, $seq_id, $locus, uc($seq -> seq));
	}
}

