#!/usr/bin/perl

=head1 NAME

build_VDJ_db

=head1 SYNOPSIS

build_VDJ_db.pl [-h] [-log] [-lu <alternatve lookup file>]

=head1 ARGUMENTS 

optional:
-h	help
-log 	print log text
-lu 	alternative lookup; by default ./$species_lookup.txt is used

=head1 DESCRIPTION

=head1 HISTORY

=cut


use DBI;
use strict;
use warnings;
use Getopt::Long;
use Bio::SeqIO;

# Set up logging
my $log_buffer="";
open(LB,'>',\$log_buffer);
# prefix for logging, telling where log comes from
my $log_prefix = "[build_VDJ_db] [LOG] ";
my $error_prefix = "[build_VDJ_db] [ERR] ";

my $log_bool = 0;
my $parse_bool = 0;
my $lookup = "";
my $library_scheme = "";
my $fasta_dir = "";
my $species = "";
# Variables, path fixed for installation
my $IGDATA_path = "../igdata";
my $mysql_group = "";
my $optional_file_arg = "";


&GetOptions(
	"mysql_group=s"	=> \$mysql_group,
	"lu=s"			=> \$lookup,
	"sp=s"			=> \$species,
	"fa_dir=s"		=> \$fasta_dir,
	"lib_scheme=s"	=> \$library_scheme,
	"igdata_path=s"	=> \$IGDATA_path,
	"log!" 			=> \$log_bool,
	"parse!"		=> \$parse_bool,
	"opt_file=s"	=> \$optional_file_arg
);

die "No library scheme specified with -lib_scheme argument." unless $library_scheme;
die "No fasta directory specified with -fasta_dir argument." unless $fasta_dir;
die "No lookup file specified with -lu argument." unless $lookup;
die "No mysql_group as in ~/.my.cnf file specified with -mysql_group argument." unless $mysql_group;
# Check if the input parameters are meaningfull
unless ($species eq "human" || $species eq "mouse") {
  if ($species) {
    die "$error_prefix Species $species is not supported.\n";
  }
  else { die "$error_prefix No species specified with -sp argument." }
}

# default file locations of optional, internal
my $optional_file;
if ($optional_file_arg) {
  $optional_file = $optional_file_arg;
  print LB "$log_prefix Using command line specified optional file $optional_file\n";
} else {
  $optional_file = "$IGDATA_path/optional_file/$species\_gl.aux";
  print LB "$log_prefix Using default optional file $optional_file\n";
}
  
my $internal_file = "$IGDATA_path/internal_data/$species/$species.ndm.imgt";

# fasta file location of V,D and J database is taken from the config file
my $V_seg_fasta = "$fasta_dir/$species\_gl_V.fasta"; 
my $D_seg_fasta = "$fasta_dir/$species\_gl_D.fasta";
my $J_seg_fasta = "$fasta_dir/$species\_gl_J.fasta";
my @segment_files = (
	$V_seg_fasta,
	$D_seg_fasta,
	$J_seg_fasta,
);


# Get database handle for database passed in the command line. Requires authentication via ".my.cnf" file.
my $dsn = "DBI:mysql:$library_scheme;mysql_read_default_file=~/.my.cnf;mysql_read_default_group=$mysql_group;";
my $dbh = DBI->connect($dsn,undef,undef,{PrintError=>1});

# list of all identifiers that appear in the fasta file
# needed to later determine lacking entries in one of the several input files
my @identifiers = ();
# hash to memorize occuring segment names and their respective type (V,D,J)
# initialized with NULL when going through fasta file
# types defined when going through lookup file
# used to output warnings for V segments that do not get CDR/FWR positions or J segments without frame offset
my %ids_segtype_hash;


# 1. Insert Information from fasta file
#
# Insert segment name, species, sequence. The combination of species and segment name has to be unique in the database.
#
# Switch "--parse" will activative parsing of additional information from FASTA header. These are the following fields:
# reference assembly (e.g. NCBIm38), chromosome, physical position lower boundary [bp] (inclusive), physical position
# upper boundary [bp] (inclusive), orientation.
#
my $insert_seg_statement;
if ($parse_bool) {
	print LB "$log_prefix Switch \"--parse\" is set. Will attempt to parse chromosomal location information from FASTA headers.\n";
	$insert_seg_statement = "INSERT IGNORE INTO $library_scheme.VDJ_library (species_id, seg_name, seg_family, seg_gene, seg_allele, seg_sequence, ref_assembly, ref_chromosome, ref_pos_bound_low, ref_pos_bound_up, ref_ori) values (?,?,?,?,?,?,?,?,?,?,?)";
} else {
	print LB "$log_prefix Switch \"--parse\" is NOT set. Chromosomal location information will be ignored.\n";
	$insert_seg_statement = "INSERT IGNORE INTO $library_scheme.VDJ_library (species_id, seg_name, seg_family, seg_gene, seg_allele, seg_sequence) values (?,?,?,?,?,?)";
}
my $ins_seq_query = $dbh->prepare($insert_seg_statement);

# open and read fasta files in the given database files

for my $fasta_file (@segment_files) {
	# remember whether log was already printed for this file
	my $print_log = 1;
  
	my $fasta_in = Bio::SeqIO->new(-file => "$fasta_file", -format => 'fasta') or die "$error_prefix could not open fasta file $fasta_file";

	while (my $seq = $fasta_in->next_seq()) {
		my $seq_id =  $seq->id;
		my $seg_name = "";
		my ($ref_assembly, $ref_chromosome, $ref_pos_bound_low, $ref_pos_bound_up, $ref_ori);
    
		# $seg_name is parsed differently according to information in fasta header. $parse_bool enforces extended Ensembl format if set
		if ($parse_bool) {
			# "extended" Ensembl format including chromosomal position information. Order of field is NAME:ASSEMBLY:CHROMOSOME:POS1:POS2:ORIENTATION
			# This is used by the custom mouse NCBIm38 library
			($seg_name, $ref_assembly, $ref_chromosome, $ref_pos_bound_low, $ref_pos_bound_up, $ref_ori) = split(/:/, $seq_id, 6);
		} elsif ($seq_id =~ m/NCBI/) {
			# Standard Ensembl format (ie. without chromosomal position information)
			$seg_name = (split(/:/, $seq_id, 2))[0];
		} elsif ($seq_id =~ m/\|/) {
			# IMGT format
			$seg_name = (split(/\|/, $seq_id, 3))[1];
		} else {
			# currently parsing of other formats is not supported, just use complete $seq_id and issue a warning
			$seg_name = $seq_id;
			if ($print_log eq 1) {
				$print_log = 0;
				print LB "$log_prefix Fasta identifers in $fasta_file could not be parsed to extract segment name like for standard IMGT or Ensembl format. Using fasta identifier as segment name.\n";
			}
		}
    
		# if not defined in the next step, family, gene and allele should be empty
		my $seg_family = "";
		my $seg_gene = "";
		my $seg_allele = "";

		# split name in family, gene, allele (different from species to species)
		# human nomenclature example: name = family(-{gene})*allele
		if ($species eq "human") {
			if ($seg_name =~ m/-/) {
				($seg_family, my $rest) = split(/-/, $seg_name, 2);
				($seg_gene, $seg_allele) = split(/\*/, $rest);
			}
			else {
				($seg_family, $seg_allele) = split(/\*/, $seg_name, 2);
			}
		} elsif ($species eq "mouse") {
			# Standard mouse Igh nomenclature is <family>.<segment number within family>.<segment number within locus>,
			# numbering is performed proxminal to distal (relative to DJC location)
			# ATTENTION: VGAM3.8 family uses "-" as separator instead of ".", and thus requires case distinction
			# ATTENTION: Older mouse segment names only use one "."
			# ATTENTION: Ancient mouse segment names are basically complete random strings and do neither contain family nor
			#            positional information
			#
			if ($seg_name =~ m/^VGAM3\.8-/) {
				($seg_family, $seg_gene) = (split(/-/, $seg_name, 3))[0,2]
			}
			elsif ($seg_name =~ m/\.\w+\./) {
				($seg_family, $seg_gene) = (split(/\./, $seg_name, 3))[0,2]
			}
			elsif ($seg_name =~ m/\./) {
				($seg_family, $seg_gene) = split(/\./, $seg_name, 2)
			}
			else { 
				$seg_family = $seg_name; 
				$seg_gene = $seg_name;
			}
		}

		if ($parse_bool) {
			$ins_seq_query->execute($species, $seg_name, $seg_family, $seg_gene, $seg_allele, uc($seq -> seq), $ref_assembly, $ref_chromosome, $ref_pos_bound_low, $ref_pos_bound_up, $ref_ori);
		} else {
			$ins_seq_query->execute($species, $seg_name, $seg_family, $seg_gene, $seg_allele, uc($seq -> seq));
		}

		# store segment names for later consistency checks, both in an array and a hash
		push(@identifiers, $seg_name);
		$ids_segtype_hash{$seg_name} = "";
	}
	close $fasta_file;
}

# 2. Insert Information from lookup file

my @lu_identifiers;
open(LOOKUP, $lookup) or die "$error_prefix could not open lookup file $lookup\n";
while(<LOOKUP>) {
  chomp $_;
  # parse segment name and type_locus
  (my $lu_seg_name, my $lu_seg_type_locus) = split(/\t/, $_);
  (my $type, my $locus) = split(//, $lu_seg_type_locus);
  $dbh->do("UPDATE $library_scheme.VDJ_library SET seg_type='$type' , locus='$locus' WHERE species_id='$species' AND seg_name='$lu_seg_name'");
  
  # store all lookup identifiers
  push(@lu_identifiers, $lu_seg_name);
  # remember the segment type for each segment name
  # in order to later give more specific warnings
  if (exists $ids_segtype_hash{$lu_seg_name}) {
    $ids_segtype_hash{$lu_seg_name} = "$type";
  }
  else {print LB "$log_prefix $lu_seg_name was in the lookup table but not in the provided fasta database.\n";}
}

# check for database sequences not in lookuptable
my @minus_lu;
for my $id (@identifiers) {
  unless ($id ~~ @lu_identifiers) {
    push(@minus_lu, $id);
  }
}
if (@minus_lu) {print LB "$log_prefix The following segments were in the fasta database but not in the segment type lookup table.\t@minus_lu\n";}


# 3. Insert Information from internal file

my @internal_identifiers;

open(INTERNAL, $internal_file) or die "$error_prefix could not open internal file $internal_file\n";
while(<INTERNAL>) {
  chomp $_;
  #print "$_\n";
  my @line = split(/\h+/, $_);
  my $int_seg_name = $line[0];
  #print "$int_seg_name\n";
  my ($fwr1_start, $fwr1_stop, $cdr1_start, $cdr1_stop, $fwr2_start, $fwr2_stop, $cdr2_start, $cdr2_stop, $fwr3_start, $fwr3_stop) = @line[1..10];

  $dbh->do("UPDATE $library_scheme.VDJ_library SET 
	fwr1_start = $fwr1_start , fwr1_stop = $fwr1_stop ,
	cdr1_start = $cdr1_start , cdr1_stop = $cdr1_stop , 
	fwr2_start = $fwr2_start , fwr2_stop = $fwr2_stop , 
	cdr2_start = $cdr2_start , cdr2_stop = $cdr2_stop , 
	fwr3_start = $fwr3_start , fwr3_stop = $fwr3_stop 
	WHERE species_id='$species' AND seg_name='$int_seg_name'");
  
  push(@internal_identifiers, $int_seg_name);
}

# check for database sequences not in internal file
my @minus_int;
for my $id (@identifiers) {
  unless ($id ~~ @internal_identifiers) {
    if (exists $ids_segtype_hash{$id}) {
      # give CDR/FWR warning only for V segments
      if ($ids_segtype_hash{$id} eq 'V') {
	push(@minus_int, $id);
      }
    }
  }
}
if (@minus_int) {print LB "$log_prefix The following segments are V segments. They are in the fasta database but not in the internal file. No CDR/FWR positions are assigned.\t @minus_int\n";}

# 4. Insert information from optional file

my @opt_identifiers;

open(OPTIONAL, $optional_file) or die "$error_prefix could not open $optional_file\n";

while(<OPTIONAL>) {
  chomp $_;
  my @line = split(/\h+/, $_);
  
  if (scalar @line == 3) {
  	my $opt_seg_name = $line[0];
  	my $frame = $line[1];
  	$dbh->do("UPDATE $library_scheme.VDJ_library SET seg_frame = $frame WHERE species_id='$species' AND seg_name='$opt_seg_name'");
  	push(@opt_identifiers, $opt_seg_name);
  }
}

# check for database sequences not in internal file
my @minus_opt;
for my $id (@identifiers) {
  unless ($id ~~ @opt_identifiers) {
    if (exists $ids_segtype_hash{$id}) {
      # give CDR/FWR warning only for V segments
      if ($ids_segtype_hash{$id} eq 'J') {
	push(@minus_opt, $id);
      }
    }
  }
}
if (@minus_opt) {print LB "$log_prefix The following segments are J segments, but did not appear in the optional file. @minus_opt\n";}

if ($log_bool eq 1) {
  print $log_buffer;
}
